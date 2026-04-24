// Test FFI: JavaScript implementations.
//
// Mirrors plushie_test_ffi.erl for the JS target. Emit is synchronous:
// values are collected in an array as the work function runs, then
// returned as a Gleam list paired with the final return value.

import { toList } from "./gleam.mjs";
import { setPlushieAppConstructor } from "./plushie_bridge_web_ffi.mjs";
import {
  cancelAsync,
  createHandle,
  deferDispatch,
  enqueueDispatch,
  scheduleCoalesceFlush,
  setSendAfter,
  setCoalesce,
  startAsync,
  startStream,
} from "./plushie_runtime_web_ffi.mjs";

const fakePlushieState = {
  sent: [],
  onEvent: null,
  settingsJson: null,
  freed: false,
  immediateClipboardText: null,
};

export function collect_stream_values(workFn) {
  const emitted = [];
  const emit = (value) => {
    emitted.push(value);
    return undefined;
  };
  const finalValue = workFn(emit);
  return [toList(emitted), finalValue];
}

export function identity(value) {
  return value;
}

export function install_fake_plushie_app() {
  fakePlushieState.sent = [];
  fakePlushieState.onEvent = null;
  fakePlushieState.settingsJson = null;
  fakePlushieState.freed = false;
  fakePlushieState.immediateClipboardText = null;
  globalThis.__plushieImmediateEffectTimeouts = false;

  setPlushieAppConstructor(function FakePlushieApp(settingsJson, onEvent) {
    fakePlushieState.settingsJson = settingsJson;
    fakePlushieState.onEvent = onEvent;
    return {
      send_message(json) {
        fakePlushieState.sent.push(json);
        if (fakePlushieState.immediateClipboardText === null) {
          return;
        }

        const message = JSON.parse(json);
        if (message.type !== "effect" || message.kind !== "clipboard_read") {
          return;
        }

        onEvent(
          JSON.stringify({
            type: "effect_response",
            id: message.id,
            status: "ok",
            result: { text: fakePlushieState.immediateClipboardText },
          }),
        );
      },
      free() {
        fakePlushieState.freed = true;
      },
    };
  });
}

export function reset_fake_plushie_app() {
  fakePlushieState.sent = [];
  fakePlushieState.onEvent = null;
  fakePlushieState.settingsJson = null;
  fakePlushieState.freed = false;
  fakePlushieState.immediateClipboardText = null;
  globalThis.__plushieImmediateEffectTimeouts = false;
}

export function fake_transport_sent_messages() {
  return toList(fakePlushieState.sent);
}

export function fake_transport_emit(json) {
  fakePlushieState.onEvent?.(json);
}

export function set_immediate_effect_timeouts(enabled) {
  globalThis.__plushieImmediateEffectTimeouts = enabled;
}

export function set_immediate_clipboard_text_response(text) {
  fakePlushieState.immediateClipboardText = text;
}

export function async_task_cleans_up_when_stopped_during_sync_throw() {
  const handle = createHandle(null, null, null, "", null, null);
  let completions = 0;
  handle.onAsyncComplete = () => {
    completions += 1;
  };

  startAsync(handle, "sync-throw", () => {
    handle.stopped = true;
    throw new Error("stopped");
  });

  return handle.asyncTasks.size === 0 && completions === 0;
}

export function async_task_cleans_up_when_stopped_before_promise_resolve() {
  const handle = createHandle(null, null, null, "", null, null);
  let completions = 0;
  let resolveLater = null;
  handle.onAsyncComplete = () => {
    completions += 1;
  };

  startAsync(handle, "promise-resolve", () => ({
    then(resolve, _reject) {
      resolveLater = resolve;
    },
  }));

  handle.stopped = true;
  resolveLater?.("ok");

  return handle.asyncTasks.size === 0 && completions === 0;
}

export function async_task_cleans_up_when_stopped_before_promise_reject() {
  const handle = createHandle(null, null, null, "", null, null);
  let completions = 0;
  let rejectLater = null;
  handle.onAsyncComplete = () => {
    completions += 1;
  };

  startAsync(handle, "promise-reject", () => ({
    then(_resolve, reject) {
      rejectLater = reject;
    },
  }));

  handle.stopped = true;
  rejectLater?.(new Error("stopped"));

  return handle.asyncTasks.size === 0 && completions === 0;
}

export function async_task_cleans_up_when_cancelled_before_promise_resolve() {
  const handle = createHandle(null, null, null, "", null, null);
  let completions = 0;
  let resolveLater = null;
  handle.onAsyncComplete = () => {
    completions += 1;
  };

  startAsync(handle, "promise-cancel", () => ({
    then(resolve, _reject) {
      resolveLater = resolve;
    },
  }));

  handle.asyncTasks.get("promise-cancel")?.cancel();
  resolveLater?.("ok");

  return handle.asyncTasks.size === 0 && completions === 0;
}

export function stream_task_cleans_up_when_stopped_during_sync_throw() {
  const handle = createHandle(null, null, null, "", null, null);
  let completions = 0;
  handle.onAsyncComplete = () => {
    completions += 1;
  };

  startStream(handle, "stream-throw", () => {
    handle.stopped = true;
    throw new Error("stopped");
  });

  return handle.asyncTasks.size === 0 && completions === 0;
}

export function queued_async_completion_is_dropped_after_tag_reuse() {
  const handle = createHandle(null, null, null, "", null, null);
  const completions = [];
  let resolveOld = null;

  handle.onAsyncComplete = (tag) => {
    completions.push(tag);
  };

  startAsync(handle, "task", () => ({
    then(resolve, _reject) {
      resolveOld = resolve;
    },
  }));

  handle.dispatchDraining = true;
  resolveOld?.("old");
  handle.dispatchDraining = false;

  startAsync(handle, "task", () => ({
    then(_resolve, _reject) {},
  }));

  enqueueDispatch(handle, () => {
    completions.push("drain");
  });

  return completions.join(",") === "drain";
}

export function queued_async_completion_is_dropped_after_cancel() {
  const handle = createHandle(null, null, null, "", null, null);
  const completions = [];
  let resolveTask = null;

  handle.onAsyncComplete = (tag) => {
    completions.push(tag);
  };

  startAsync(handle, "task", () => ({
    then(resolve, _reject) {
      resolveTask = resolve;
    },
  }));

  handle.dispatchDraining = true;
  resolveTask?.("done");
  handle.dispatchDraining = false;

  cancelAsync(handle, "task");

  enqueueDispatch(handle, () => {
    completions.push("drain");
  });

  return completions.join(",") === "drain";
}

export function queued_stream_emit_is_dropped_after_tag_reuse() {
  const handle = createHandle(null, null, null, "", null, null);
  const emissions = [];
  let emitOld = null;

  handle.onStreamEmit = (_tag, value) => {
    emissions.push(value);
  };

  startStream(handle, "stream", (emit) => {
    emitOld = emit;
  });

  handle.dispatchDraining = true;
  emitOld?.("old");
  handle.dispatchDraining = false;

  startStream(handle, "stream", () => {});

  enqueueDispatch(handle, () => {
    emissions.push("drain");
  });

  return emissions.join(",") === "drain";
}

export function scheduled_coalesce_flush_keeps_batch_before_deferred_dispatch() {
  const originalQueueMicrotask = globalThis.queueMicrotask;
  const microtasks = [];
  const handle = createHandle(null, null, null, "", null, null);
  const order = [];

  globalThis.queueMicrotask = (callback) => {
    microtasks.push(callback);
  };

  handle.dispatchDirect = (event) => {
    order.push(event);
    if (event === "first") {
      deferDispatch(handle, () => {
        order.push("deferred");
      });
    }
  };

  try {
    setCoalesce(handle, "first", "first");
    setCoalesce(handle, "second", "second");
    scheduleCoalesceFlush(handle);

    if (order.length !== 0 || microtasks.length !== 1) return false;

    microtasks.shift()();
    if (order.join(",") !== "first,second" || microtasks.length !== 1) {
      return false;
    }

    microtasks.shift()();
    return order.join(",") === "first,second,deferred";
  } finally {
    globalThis.queueMicrotask = originalQueueMicrotask;
  }
}

export function queued_stream_emit_before_sync_throw_is_delivered() {
  const handle = createHandle(null, null, null, "", null, null);
  const events = [];

  handle.onStreamEmit = (_tag, value) => {
    events.push(`emit:${value}`);
  };
  handle.onAsyncComplete = (tag) => {
    events.push(`complete:${tag}`);
  };

  handle.dispatchDraining = true;
  startStream(handle, "stream", (emit) => {
    emit("before");
    throw new Error("sync failure");
  });
  handle.dispatchDraining = false;

  enqueueDispatch(handle, () => {
    events.push("drain");
  });

  return events.join(",") === "emit:before,complete:stream,drain";
}

export function queued_send_after_is_dropped_after_key_reuse() {
  const originalSetTimeout = globalThis.setTimeout;
  const originalClearTimeout = globalThis.clearTimeout;
  const timers = [];
  const fired = [];

  globalThis.setTimeout = (callback, _delayMs) => {
    const timer = { callback, cleared: false };
    timers.push(timer);
    return timer;
  };
  globalThis.clearTimeout = (timer) => {
    timer.cleared = true;
  };

  try {
    const handle = createHandle(null, null, null, "", null, null);
    setSendAfter(handle, "stable", 0, () => {
      fired.push("old");
    });

    handle.dispatchDraining = true;
    timers[0].callback();
    handle.dispatchDraining = false;

    setSendAfter(handle, "stable", 0, () => {
      fired.push("new");
    });

    enqueueDispatch(handle, () => {
      fired.push("drain");
    });

    return (
      fired.join(",") === "drain" &&
      timers.length === 2 &&
      timers[0].cleared === false &&
      handle.sendAfterTimers.get("stable")?.id === timers[1]
    );
  } finally {
    globalThis.setTimeout = originalSetTimeout;
    globalThis.clearTimeout = originalClearTimeout;
  }
}

export function dispatch_queue_serializes_reentrant_callbacks() {
  const handle = createHandle(null, null, null, "", null, null);
  const order = [];

  enqueueDispatch(handle, () => {
    order.push("outer-start");
    enqueueDispatch(handle, () => {
      order.push("inner");
    });
    order.push("outer-end");
  });

  return order.join(",") === "outer-start,outer-end,inner";
}

export function defer_dispatch_enters_queue_before_later_sync_callbacks() {
  const originalQueueMicrotask = globalThis.queueMicrotask;
  const microtasks = [];
  const handle = createHandle(null, null, null, "", null, null);
  const order = [];

  globalThis.queueMicrotask = (callback) => {
    microtasks.push(callback);
  };

  try {
    deferDispatch(handle, () => {
      order.push("deferred");
    });
    enqueueDispatch(handle, () => {
      order.push("sync");
    });

    if (order.length !== 0 || microtasks.length !== 1) return false;

    microtasks.shift()();
    return order.join(",") === "deferred,sync";
  } finally {
    globalThis.queueMicrotask = originalQueueMicrotask;
  }
}

export function dispatch_queue_drops_pending_callbacks_on_stop() {
  const handle = createHandle(null, null, null, "", null, null);
  const order = [];

  enqueueDispatch(handle, () => {
    order.push("outer");
    enqueueDispatch(handle, () => {
      order.push("inner");
    });
    handle.stopped = true;
  });

  return order.join(",") === "outer" && handle.dispatchQueue.length === 0;
}
