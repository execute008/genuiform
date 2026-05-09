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

/// Hard caps that defend against gzip-bomb URLs. The largest bundled scenario
/// is ~3 KB of source; an attacker-supplied hash that decompresses far beyond
/// these limits is rejected as malicious.
const int _maxCompressedBytes = 16 * 1024; // 16 KB compressed input
const int _maxDecompressedBytes = 256 * 1024; // 256 KB decompressed output
const int _maxDslChars = 64 * 1024; // 64 KB of DSL text

/// Decodes a hash produced by [encodeDslToHash] back into the original DSL.
///
/// Returns `null` when [hash] is empty, contains invalid base64url characters,
/// the compressed payload is too large, the decompressed payload is too large,
/// or the bytes are not valid UTF-8.
String? decodeDslFromHash(String hash) {
  if (hash.isEmpty) return null;
  try {
    final compressed = base64Url.decode(base64Url.normalize(hash));
    if (compressed.length > _maxCompressedBytes) return null;
    final decoder = GZipDecoder();
    final bytes = decoder.decodeBytes(compressed);
    if (bytes.length > _maxDecompressedBytes) return null;
    final decoded = utf8.decode(bytes);
    if (decoded.length > _maxDslChars) return null;
    return decoded;
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
