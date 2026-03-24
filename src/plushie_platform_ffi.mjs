// Cross-target platform utilities -- JavaScript implementations.

import { Ok, Error } from "./gleam.mjs";

export function logInfo(message) {
  console.info(message);
}

export function logWarning(message) {
  console.warn(message);
}

export function logError(message) {
  console.error(message);
}

let nextId = 0;

export function uniqueId() {
  nextId += 1;
  return String(nextId);
}

export function monotonicTimeMs() {
  return Math.floor(performance.now());
}

export function tryCall(f) {
  try {
    return new Ok(f());
  } catch (e) {
    return new Error(e);
  }
}

export function stableHashKey(value) {
  return JSON.stringify(value);
}

export function mathSin(x) {
  return Math.sin(x);
}

export function mathPow(base, exponent) {
  return Math.pow(base, exponent);
}
