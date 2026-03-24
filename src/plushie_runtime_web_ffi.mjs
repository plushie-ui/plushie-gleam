// JavaScript runtime FFI -- mutable state container and async primitives.
//
// The WebRuntimeHandle is a plain JS object holding all mutable state.
// Gleam code passes it around opaquely; only the functions in this
// module read/write its fields.

import { Some, None } from "./gleam.mjs";

// -- Handle (mutable state container) ----------------------------------------

export function createHandle(
  model,
  app,
  transport,
  session,
  emptySubs,
  emptyWindows,
) {
  return {
    model,
    app,
    transport,
    session,
    tree: new None(), // Option(Node) -- Gleam None
    gleamActiveSubs: emptySubs, // Gleam Dict(String, Subscription)
    gleamWindows: emptyWindows, // Gleam Set(String)
    asyncTasks: new Map(), // tag -> { nonce, cancel }
    nextNonce: 0,
    timerSubs: new Map(), // key -> JS intervalId
    sendAfterTimers: new Map(), // key -> JS timeoutId
    pendingCoalesce: new Map(), // key -> Gleam Event
    coalescePending: false,
    stopped: false,
  };
}

// -- Model access ------------------------------------------------------------

export function getModel(handle) {
  return handle.model;
}

export function setModel(handle, model) {
  handle.model = model;
}

// -- Tree access -------------------------------------------------------------

export function getTree(handle) {
  return handle.tree;
}

export function setTree(handle, tree) {
  handle.tree = tree;
}

// -- App and session access --------------------------------------------------

export function getApp(handle) {
  return handle.app;
}

export function getSession(handle) {
  return handle.session;
}

// -- Subscriptions -----------------------------------------------------------

export function getActiveSubs(handle) {
  return handle.gleamActiveSubs;
}

export function setActiveSubs(handle, subs) {
  handle.gleamActiveSubs = subs;
}

// -- Windows -----------------------------------------------------------------

export function getWindows(handle) {
  return handle.gleamWindows;
}

export function setWindows(handle, windows) {
  handle.gleamWindows = windows;
}

// -- Transport ---------------------------------------------------------------

export function sendToTransport(handle, data) {
  if (handle.stopped || !handle.transport) return;
  // Convert BitArray to string for WASM transport (JSON only)
  const decoder = new TextDecoder();
  const json = decoder.decode(data.buffer);
  // The bridge_web.send expects a JSON string
  handle.transport.app?.send_message(json);
}

// -- Stop --------------------------------------------------------------------

export function stop(handle) {
  handle.stopped = true;

  // Clear all timer subscriptions
  for (const [, id] of handle.timerSubs) {
    clearInterval(id);
  }
  handle.timerSubs.clear();

  // Clear all send_after timers
  for (const [, id] of handle.sendAfterTimers) {
    clearTimeout(id);
  }
  handle.sendAfterTimers.clear();

  // Cancel all async tasks
  for (const [, task] of handle.asyncTasks) {
    task.cancel?.();
  }
  handle.asyncTasks.clear();

  // Clear coalesce state
  handle.pendingCoalesce.clear();
  handle.coalescePending = false;
}

// -- Coalescing --------------------------------------------------------------

export function setCoalesce(handle, key, event) {
  handle.pendingCoalesce.set(key, event);
}

export function scheduleCoalesceFlush(handle, app) {
  if (handle.coalescePending) return;
  handle.coalescePending = true;
  queueMicrotask(() => {
    if (handle.stopped) return;
    flushCoalesced(handle, app);
  });
}

export function flushCoalesced(handle, app) {
  handle.coalescePending = false;
  const events = [...handle.pendingCoalesce.values()];
  handle.pendingCoalesce.clear();
  // Import the dispatch_update from the Gleam module at call time
  // to avoid circular dependency. We call handle_event instead.
  for (const event of events) {
    // We need to call the Gleam dispatch_update, but we don't have
    // direct access to it from JS. Instead, the Gleam-side
    // flush_coalesced calls dispatch_update for each event.
    // This FFI version just returns the events.
  }
}

// -- Deferred execution ------------------------------------------------------

export function defer(f) {
  queueMicrotask(f);
}

// -- Timer subscriptions -----------------------------------------------------

export function startTimerSub(handle, app, key, intervalMs, tag) {
  // Clear existing if any
  if (handle.timerSubs.has(key)) {
    clearInterval(handle.timerSubs.get(key));
  }

  const id = setInterval(() => {
    if (handle.stopped) return;
    // Create a TimerFired event and dispatch it
    // We need to call back into Gleam's handle_event
    // This is stored and called back from the Gleam side
    handle._onTimerFired?.(handle, app, tag);
  }, intervalMs);

  handle.timerSubs.set(key, id);
}

export function clearTimerSub(handle, key) {
  const id = handle.timerSubs.get(key);
  if (id !== undefined) {
    clearInterval(id);
    handle.timerSubs.delete(key);
  }
}

// -- SendAfter ---------------------------------------------------------------

export function setSendAfter(handle, app, key, delayMs, msg) {
  // Cancel existing timer for same key
  const existing = handle.sendAfterTimers.get(key);
  if (existing !== undefined) {
    clearTimeout(existing);
  }

  const id = setTimeout(() => {
    if (handle.stopped) return;
    handle.sendAfterTimers.delete(key);
    handle._onSendAfter?.(handle, app, msg);
  }, delayMs);

  handle.sendAfterTimers.set(key, id);
}

// -- Async tasks -------------------------------------------------------------

export function startAsync(handle, app, tag, work) {
  // Cancel existing task with same tag
  cancelAsync(handle, tag);

  const nonce = ++handle.nextNonce;
  let cancelled = false;

  const cancel = () => {
    cancelled = true;
  };

  handle.asyncTasks.set(tag, { nonce, cancel });

  // Run work asynchronously
  try {
    // work() might return a Promise (if the user's function is async)
    // or a plain value. Handle both.
    const result = work();

    if (result && typeof result.then === "function") {
      // Promise-based async
      result.then(
        (value) => {
          if (cancelled || handle.stopped) return;
          const current = handle.asyncTasks.get(tag);
          if (!current || current.nonce !== nonce) return;
          handle.asyncTasks.delete(tag);
          handle._onAsyncComplete?.(handle, app, tag, { ok: true, value });
        },
        (error) => {
          if (cancelled || handle.stopped) return;
          const current = handle.asyncTasks.get(tag);
          if (!current || current.nonce !== nonce) return;
          handle.asyncTasks.delete(tag);
          handle._onAsyncComplete?.(handle, app, tag, {
            ok: false,
            value: error,
          });
        },
      );
    } else {
      // Synchronous result -- defer to next microtask
      queueMicrotask(() => {
        if (cancelled || handle.stopped) return;
        const current = handle.asyncTasks.get(tag);
        if (!current || current.nonce !== nonce) return;
        handle.asyncTasks.delete(tag);
        handle._onAsyncComplete?.(handle, app, tag, { ok: true, value: result });
      });
    }
  } catch (error) {
    if (!cancelled && !handle.stopped) {
      handle.asyncTasks.delete(tag);
      handle._onAsyncComplete?.(handle, app, tag, { ok: false, value: error });
    }
  }
}

export function startStream(handle, app, tag, work) {
  cancelAsync(handle, tag);

  const nonce = ++handle.nextNonce;
  let cancelled = false;

  const cancel = () => {
    cancelled = true;
  };

  handle.asyncTasks.set(tag, { nonce, cancel });

  const emit = (value) => {
    if (cancelled || handle.stopped) return;
    const current = handle.asyncTasks.get(tag);
    if (!current || current.nonce !== nonce) return;
    handle._onStreamEmit?.(handle, app, tag, value);
  };

  try {
    work(emit);
  } catch (error) {
    if (!cancelled && !handle.stopped) {
      handle.asyncTasks.delete(tag);
      handle._onAsyncComplete?.(handle, app, tag, { ok: false, value: error });
    }
  }
}

export function cancelAsync(handle, tag) {
  const task = handle.asyncTasks.get(tag);
  if (task) {
    task.cancel();
    handle.asyncTasks.delete(tag);
  }
}
