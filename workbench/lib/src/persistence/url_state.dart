/// URL-hash state persistence for the workbench.
///
/// Encodes the current DSL into the browser URL hash as gzip + base64url so
/// that a workbench session can be shared as a plain URL.
///
/// Uses a conditional import to select the real web implementation on Flutter
/// Web and a no-op stub when running under the Dart VM (e.g. `flutter test`).
library;

import 'dart:convert';

import 'package:archive/archive.dart';

import 'url_io_stub.dart'
    if (dart.library.js_interop) 'url_io_web.dart' as url_io;

// ─────────────────────────────────────────────────────────────────────────────
// Encode / decode (pure Dart — no platform dependency)
// ─────────────────────────────────────────────────────────────────────────────

/// Gzip-compresses [dsl] and returns the result as a URL-safe base64 string.
String encodeDslToHash(String dsl) {
  final bytes = utf8.encode(dsl);
  final encoder = GZipEncoder();
  final compressed = encoder.encode(bytes);
  // base64Url encoding is safe in URL fragments without percent-encoding.
  return base64Url.encode(compressed);
}

/// Decodes a hash produced by [encodeDslToHash] back into the original DSL.
///
/// Returns `null` when [hash] is empty, contains invalid base64url characters,
/// or the decompressed bytes are not valid UTF-8.
String? decodeDslFromHash(String hash) {
  if (hash.isEmpty) return null;
  try {
    final compressed = base64Url.decode(base64Url.normalize(hash));
    final decoder = GZipDecoder();
    final bytes = decoder.decodeBytes(compressed);
    return utf8.decode(bytes);
  } catch (_) {
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Platform-aware URL I/O
// ─────────────────────────────────────────────────────────────────────────────

/// Reads the browser URL hash and attempts to decode a DSL from it.
///
/// Returns the decoded DSL string when successful, or `null` when there is no
/// hash, the hash is not valid base64url, or decompression fails.
String? readDslFromUrlHash() {
  final raw = url_io.readRawHash();
  if (raw.isEmpty) return null;
  return decodeDslFromHash(raw);
}

/// Encodes [dsl] and updates the browser URL hash via `history.replaceState`.
///
/// On non-web targets this is a no-op.
void syncHashToUrl(String dsl) {
  final encoded = encodeDslToHash(dsl);
  url_io.writeRawHash(encoded);
}
