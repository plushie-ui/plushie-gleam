// JavaScript runtime FFI -- mutable state container and async primitives.
//
// The WebRuntimeHandle is a plain JS object holding all mutable state.
// Gleam code passes it around opaquely; only the functions in this
// module read/write its fields.

import { Ok, Error, Some, None } from "./gleam.mjs";

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
    // Gleam callbacks -- registered after handle creation
    dispatch: null, // fn(Event) -> Nil -- goes through handle_event
    dispatchDirect: null, // fn(Event) -> Nil -- goes straight to dispatch_update
    onTimerFired: null, // fn(String) -> Nil
    onAsyncComplete: null, // fn(String, Result(Dynamic, Dynamic)) -> Nil
    onStreamEmit: null, // fn(String, Dynamic) -> Nil
  };
}

// -- Callback registration ---------------------------------------------------
// Called once after createHandle, before any events are processed.

export function registerDispatch(handle, dispatch, dispatchDirect) {
  handle.dispatch = dispatch;
  handle.dispatchDirect = dispatchDirect;
}

export function registerTimerCallback(handle, callback) {
  handle.onTimerFired = callback;
}

export function registerAsyncCallback(handle, callback) {
  handle.onAsyncComplete = callback;
}

export function registerStreamCallback(handle, callback) {
  handle.onStreamEmit = callback;
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

export function getTransport(handle) {
  return handle.transport;
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

export function scheduleCoalesceFlush(handle) {
  if (handle.coalescePending) return;
  handle.coalescePending = true;
  queueMicrotask(() => {
    if (handle.stopped) return;
    // Drain pending events and dispatch each directly (bypassing
    // coalesce checks to avoid re-coalescing flushed events).
    handle.coalescePending = false;
    const events = [...handle.pendingCoalesce.values()];
    handle.pendingCoalesce.clear();
    for (const event of events) {
      handle.dispatchDirect?.(event);
    }
  });
}

// flushCoalesced is called synchronously from the Gleam side when
// a non-coalescable event arrives. It drains and dispatches pending
// coalesced events immediately, bypassing coalesce checks.
export function flushCoalesced(handle) {
  handle.coalescePending = false;
  const events = [...handle.pendingCoalesce.values()];
  handle.pendingCoalesce.clear();
  for (const event of events) {
    handle.dispatchDirect?.(event);
  }
}

// -- Deferred execution ------------------------------------------------------

export function defer(f) {
  queueMicrotask(f);
}

// -- Timer subscriptions -----------------------------------------------------

export function startTimerSub(handle, _app, key, intervalMs, _tag) {
  // Clear existing if any
  if (handle.timerSubs.has(key)) {
    clearInterval(handle.timerSubs.get(key));
  }

  const id = setInterval(() => {
    if (handle.stopped) return;
    // Call the Gleam-side timer callback which constructs a
    // TimerTick event and dispatches it through handle_event.
    handle.onTimerFired?.(_tag);
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

export function setSendAfter(handle, key, delayMs, callback) {
  // Cancel existing timer for same key
  const existing = handle.sendAfterTimers.get(key);
  if (existing !== undefined) {
    clearTimeout(existing);
  }

  const id = setTimeout(() => {
    if (handle.stopped) return;
    handle.sendAfterTimers.delete(key);
    // callback is a Gleam closure that dispatches the msg
    // directly to dispatch_update (already typed as msg)
    callback();
  }, delayMs);

  handle.sendAfterTimers.set(key, id);
}

// -- Async tasks -------------------------------------------------------------

export function startAsync(handle, _app, tag, work) {
  // Cancel existing task with same tag
  cancelAsync(handle, tag);

  const nonce = ++handle.nextNonce;
  let cancelled = false;

  const cancel = () => {
    cancelled = true;
  };

  handle.asyncTasks.set(tag, { nonce, cancel });

  // Run work -- might return a Promise or a plain value
  try {
    const result = work();

    if (result && typeof result.then === "function") {
      // Promise-based async
      result.then(
        (value) => {
          if (cancelled || handle.stopped) return;
          const current = handle.asyncTasks.get(tag);
          if (!current || current.nonce !== nonce) return;
          handle.asyncTasks.delete(tag);
          handle.onAsyncComplete?.(tag, new Ok(value));
        },
        (error) => {
          if (cancelled || handle.stopped) return;
          const current = handle.asyncTasks.get(tag);
          if (!current || current.nonce !== nonce) return;
          handle.asyncTasks.delete(tag);
          handle.onAsyncComplete?.(tag, new Error(error));
        },
      );
    } else {
      // Synchronous result -- defer to next microtask
      queueMicrotask(() => {
        if (cancelled || handle.stopped) return;
        const current = handle.asyncTasks.get(tag);
        if (!current || current.nonce !== nonce) return;
        handle.asyncTasks.delete(tag);
        handle.onAsyncComplete?.(tag, new Ok(result));
      });
    }
  } catch (error) {
    if (!cancelled && !handle.stopped) {
      handle.asyncTasks.delete(tag);
      handle.onAsyncComplete?.(tag, new Error(error));
    }
  }
}

export function startStream(handle, _app, tag, work) {
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
    handle.onStreamEmit?.(tag, value);
  };

  try {
    work(emit);
  } catch (error) {
    if (!cancelled && !handle.stopped) {
      handle.asyncTasks.delete(tag);
      handle.onAsyncComplete?.(tag, new Error(error));
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
