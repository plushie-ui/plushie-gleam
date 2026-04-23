// Cross-target platform utilities: JavaScript implementations.
//
// Each function here corresponds to a dual @external in platform.gleam.
// On BEAM these route to plushie_ffi.erl; on JS they land here.

import { Ok, Error, BitArray } from "./gleam.mjs";

// -- Logging ------------------------------------------------------------------
// Maps to console methods. On BEAM these go through the Erlang logger.

export function logInfo(message) {
  console.info(message);
}

export function logWarning(message) {
  console.warn(message);
}

export function logError(message) {
  console.error(message);
}

// -- Identity and time --------------------------------------------------------

// Monotonic counter for unique IDs. Prefixed with a timestamp base
// so IDs are unique across page reloads (unlike a bare counter).
// On BEAM this is erlang:unique_integer([monotonic, positive]).
const idBase = Date.now().toString(36);
let nextId = 0;

export function uniqueId() {
  nextId += 1;
  return idBase + "-" + nextId.toString(36);
}

// Returns monotonic milliseconds (integer). On BEAM this is
// erlang:monotonic_time(millisecond). In JS, performance.now()
// starts from process/page load, same relative semantics.
export function monotonicTimeMs() {
  return Math.floor(performance.now());
}

// -- Error handling -----------------------------------------------------------

// Wraps a zero-arity function in try/catch, returning Result.
// On BEAM this is a :try/:catch wrapper in plushie_ffi.erl.
export function tryCall(f) {
  try {
    return new Ok(f());
  } catch (e) {
    return new Error(e);
  }
}

// Identity function: returns the value unchanged. Used for narrow
// type boundary crossings where the type system can't prove equality
// (e.g., simple() apps where msg = Event but Gleam doesn't have
// type equality witnesses).
export function identity(value) {
  return value;
}

// Returns a deterministic string key for deduplication purposes.
// Uses a DJB2 hash of JSON.stringify for compact, consistent output.
// BEAM uses erlang:phash2 (also compact). Neither is cryptographic;
// both are sufficient for SendAfter timer dedup within a platform.
export function stableHashKey(value) {
  const str = JSON.stringify(value);
  let hash = 5381;
  for (let i = 0; i < str.length; i++) {
    hash = ((hash << 5) + hash + str.charCodeAt(i)) >>> 0;
  }
  return String(hash);
}

export function isFiniteFloat(value) {
  return Number.isFinite(value);
}

// -- Math ---------------------------------------------------------------------

export function mathSin(x) {
  return Math.sin(x);
}

export function mathCos(x) {
  return Math.cos(x);
}

export function mathPow(base, exponent) {
  return Math.pow(base, exponent);
}

export function mathSqrt(x) {
  return Math.sqrt(x);
}

export function mathAtan2(y, x) {
  return Math.atan2(y, x);
}

export function mathPi() {
  return Math.PI;
}

export function mathFloor(x) {
  return Math.floor(x);
}

// -- Environment and filesystem -----------------------------------------------
// These functions degrade gracefully in browser contexts where
// process.env and fs are not available.

export function getEnv(name) {
  if (typeof globalThis.process !== "undefined" && globalThis.process.env) {
    const val = globalThis.process.env[name];
    if (val !== undefined) return new Ok(val);
  }
  return new Error(undefined);
}

export function setEnv(name, value) {
  if (typeof globalThis.process !== "undefined" && globalThis.process.env) {
    globalThis.process.env[name] = value;
  }
}

export function unsetEnv(name) {
  if (typeof globalThis.process !== "undefined" && globalThis.process.env) {
    delete globalThis.process.env[name];
  }
}

// Synchronous file existence check. Returns false in browser contexts.
// Uses globalThis.process to avoid issues with bundlers that shim
// the bare `process` identifier.
export function fileExists(path) {
  try {
    if (typeof globalThis.process !== "undefined") {
      // Node.js / Bun / Deno with Node compat
      const { existsSync } = await_or_require("fs");
      return existsSync(path);
    }
  } catch (_) {
    // fs not available (browser, restricted environment)
  }
  return false;
}

// Helper: try require() first (CJS/Node), fall back to unavailable.
// We can't use dynamic import() because fileExists must be synchronous.
function await_or_require(mod) {
  if (typeof globalThis.require === "function") {
    return globalThis.require(mod);
  }
  // In ESM-only environments without require(), we can't do sync imports.
  // Throwing here will be caught by the caller's try/catch.
  throw new globalThis.Error("require not available");
}

export function platformString() {
  if (typeof globalThis.process !== "undefined" && globalThis.process.platform) {
    const p = globalThis.process.platform;
    if (p === "linux") return "linux";
    if (p === "darwin") return "darwin";
    if (p === "win32") return "windows";
    return p;
  }
  return "unknown";
}

export function archString() {
  if (typeof globalThis.process !== "undefined" && globalThis.process.arch) {
    const a = globalThis.process.arch;
    if (a === "x64") return "x86_64";
    if (a === "arm64") return "aarch64";
    return a;
  }
  return "unknown";
}

export function getLocale() {
  const navigatorLocale = localeFromNavigator();
  if (navigatorLocale) return navigatorLocale;

  try {
    const intlLocale = Intl.DateTimeFormat().resolvedOptions().locale;
    const normalized = normalizeLocale(intlLocale);
    if (normalized) return normalized;
  } catch (_) {
    // Fall through to the stable default.
  }

  return "en-US";
}

export function formatNumber(number, locale) {
  const intlLocale = supportedLocale(locale, "number");
  try {
    return new Intl.NumberFormat(intlLocale || "en-US").format(number);
  } catch (_) {
    return String(number);
  }
}

export function formatDate(year, month, day, locale) {
  const intlLocale = supportedLocale(locale, "date");
  if (!intlLocale) return isoDate(year, month, day);

  try {
    const date = new Date(Date.UTC(year, month - 1, day));
    return new Intl.DateTimeFormat(intlLocale, {
      year: "numeric",
      month: "numeric",
      day: "numeric",
      timeZone: "UTC",
    }).format(date);
  } catch (_) {
    return isoDate(year, month, day);
  }
}

function localeFromNavigator() {
  const nav = globalThis.navigator;
  if (!nav) return null;

  const candidates = Array.isArray(nav.languages) ? nav.languages : [];
  for (const candidate of candidates) {
    const normalized = normalizeLocale(candidate);
    if (normalized) return normalized;
  }

  return normalizeLocale(nav.language || nav.userLanguage);
}

function supportedLocale(locale, formatter) {
  const normalized = normalizeLocale(locale);
  if (!normalized) return null;

  try {
    const supported = formatter === "date"
      ? Intl.DateTimeFormat.supportedLocalesOf([normalized])
      : Intl.NumberFormat.supportedLocalesOf([normalized]);
    return supported.length > 0 ? supported[0] : null;
  } catch (_) {
    return null;
  }
}

function normalizeLocale(locale) {
  if (typeof locale !== "string") return null;

  const raw = locale.trim();
  if (raw === "") return null;

  const first = raw.split(":")[0].split(".")[0].split("@")[0];
  const parts = first.replaceAll("_", "-").split("-").filter(Boolean);
  if (parts.length === 0) return null;

  const language = parts[0].toLowerCase();
  if (language === "c" || language === "posix") return null;
  if (!/^[a-z]{2,3}$/.test(language)) return null;

  const normalized = [language];
  for (const part of parts.slice(1)) {
    if (/^[a-zA-Z]{2}$/.test(part) || /^[0-9]{3}$/.test(part)) {
      normalized.push(part.toUpperCase());
    } else if (/^[a-zA-Z]{4}$/.test(part)) {
      normalized.push(part[0].toUpperCase() + part.slice(1).toLowerCase());
    } else {
      normalized.push(part.toLowerCase());
    }
  }
  return normalized.join("-");
}

function isoDate(year, month, day) {
  return `${year}-${pad2(month)}-${pad2(day)}`;
}

function pad2(value) {
  return value >= 0 && value <= 9 ? `0${value}` : String(value);
}

// -- Hashing and compression --------------------------------------------------
// These are used by testing infrastructure (snapshots, screenshots,
// tree hashes). They require Node.js crypto/zlib modules. Browser
// equivalents would need async Web Crypto APIs which don't match
// the synchronous Gleam signatures; those can be added when
// browser-side testing is implemented.

export function sha256Hex(data) {
  const crypto = await_or_require("crypto");
  const buf = data.buffer instanceof ArrayBuffer
    ? data.buffer
    : new Uint8Array(data.buffer).buffer;
  return crypto.createHash("sha256").update(Buffer.from(buf)).digest("hex");
}

export function crc32(data) {
  const raw = data.buffer;
  const buf = raw instanceof Uint8Array || raw instanceof ArrayBuffer
    ? (raw instanceof ArrayBuffer ? new Uint8Array(raw) : raw)
    : new Uint8Array(raw);
  let crc = 0xffffffff;
  for (let i = 0; i < buf.length; i++) {
    crc = (crc >>> 8) ^ crc32Table[(crc ^ buf[i]) & 0xff];
  }
  return (crc ^ 0xffffffff) >>> 0;
}

const crc32Table = new Uint32Array(256);
for (let i = 0; i < 256; i++) {
  let c = i;
  for (let j = 0; j < 8; j++) {
    c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  }
  crc32Table[i] = c;
}

export function zlibCompress(data) {
  const zlib = await_or_require("zlib");
  const raw = data.buffer instanceof ArrayBuffer
    ? data.buffer
    : new Uint8Array(data.buffer).buffer;
  const result = zlib.deflateSync(Buffer.from(raw));
  return new BitArray(new Uint8Array(result));
}
