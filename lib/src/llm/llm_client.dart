import '../models/message.dart';

/// Abstract transport layer for Gemini.
///
/// All concrete implementations — [GeminiApiClient], [VertexProxyClient],
/// [FakeLlmClient] — implement this interface so strategy code can swap
/// transports without modification.
///
/// [generate] returns a [Stream<String>] of incremental text deltas — typically
/// one yield per upstream SSE event. Consumers must accumulate the deltas into
/// a buffer and parse the concatenated text as JSON.
abstract class LlmClient {
  /// Sends a generation request to the underlying model and returns a stream
  /// of incremental text deltas. Deltas concatenate to form the final JSON
  /// response — consumers are expected to accumulate them and parse the
  /// resulting buffer themselves.
  ///
  /// Parameters:
  /// - [systemPrompt] — injected as `systemInstruction` in the Gemini payload.
  ///   Ignored (omitted from the wire payload) when [cachedContent] is non-null,
  ///   because the system instruction is already baked into the cache.
  /// - [messages] — conversation history; mapped to Gemini `contents`.
  /// - [responseSchema] — legacy OpenAPI 3.0 subset. Sent as
  ///   `generationConfig.responseSchema`. Honours `enum`, `minimum`,
  ///   `maximum`, `description`. Does NOT honour `oneOf`,
  ///   `additionalProperties`, `$ref`, `prefixItems`, etc.
  /// - [responseJsonSchema] — fuller JSON Schema (Gemini 2.5+). Sent as
  ///   `generationConfig.responseJsonSchema`. Honours `oneOf`,
  ///   `additionalProperties`, `$ref`, and the rest of JSON Schema draft 7-ish
  ///   semantics. Use this for discriminated-union response shapes.
  /// - [model] — Gemini model ID string (e.g. `'gemini-2.5-flash'`). No enum.
  /// - [temperature] — defaults to 0.7; clamped by the backend to the model's range.
  /// - [cachedContent] — resource name of a previously created cached content
  ///   (e.g. `'cachedContents/abc123'`). When non-null, [systemPrompt] is
  ///   omitted from the wire payload; the cache entry carries it. A 404 on the
  ///   cache reference surfaces as [CacheError] on the error channel.
  ///
  /// Exactly one of [responseSchema] or [responseJsonSchema] must be provided.
  ///
  /// Errors are forwarded on the stream's error channel as [LlmClientError]
  /// subtypes. Do not add a `default` branch when switching on [LlmClientError]
  /// — the sealed class is intentionally exhaustive so callers get compile-time
  /// warnings when new variants are added.
  Stream<String> generate({
    required String systemPrompt,
    required List<Message> messages,
    Map<String, dynamic>? responseSchema,
    Map<String, dynamic>? responseJsonSchema,
    required String model,
    double temperature = 0.7,
    String? cachedContent,
  });

  /// Creates a cached content entry on the Gemini API containing
  /// [systemInstruction] for [model], expiring after [ttl].
  ///
  /// Returns the resource name (e.g. `'cachedContents/abc123'`) which can
  /// then be passed to [generate] as [cachedContent].
  ///
  /// Throws [CacheError] on failure.
  Future<String> createCachedContent({
    required String systemInstruction,
    required String model,
    Duration ttl = const Duration(seconds: 300),
  });

  /// Deletes a previously created cached content entry.
  ///
  /// Best-effort — implementations should swallow 404 and 5xx rather than
  /// throwing. [name] is the resource name returned by [createCachedContent].
  Future<void> deleteCachedContent(String name);
}

// ---------------------------------------------------------------------------
// Error hierarchy
// ---------------------------------------------------------------------------

/// Base class for all errors surfaced through [LlmClient.generate]'s error
/// channel.
///
/// The sealed family is exhaustive — do **not** add a `default` branch when
/// switching on subtypes. This ensures callers get compile-time warnings when
/// new error variants are introduced.
sealed class LlmClientError implements Exception {
  /// Human-readable description of the error.
  final String message;

  const LlmClientError(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// A transport-level failure: socket error, timeout, or HTTP 5xx.
class NetworkError extends LlmClientError {
  /// The underlying exception that caused this error, if available.
  final Object? cause;

  const NetworkError(super.message, {this.cause});
}

/// The API key or OAuth token was rejected (HTTP 401 or 403).
class AuthError extends LlmClientError {
  const AuthError(super.message);
}

/// The model's rate limit was exceeded (HTTP 429).
///
/// [retryAfter] is parsed from the `Retry-After` response header when present.
/// If the header is absent, [retryAfter] is `null` — callers must implement
/// their own back-off strategy.
class RateLimitError extends LlmClientError {
  /// How long to wait before retrying, or `null` if the server did not specify.
  final Duration? retryAfter;

  const RateLimitError(super.message, {this.retryAfter});
}

/// The model returned a response that could not be parsed as valid JSON, or
/// whose structure does not satisfy [LlmClient.generate]'s [responseSchema].
class SchemaError extends LlmClientError {
  const SchemaError(super.message);
}

/// A cached content reference was invalid or expired (HTTP 404 on a
/// cachedContent resource, or a failure during cache creation).
class CacheError extends LlmClientError {
  const CacheError(super.message);
}

/// Any error not covered by the other subtypes.
class UnknownError extends LlmClientError {
  /// The raw exception or object that triggered this error.
  final Object? cause;

  const UnknownError(super.message, {this.cause});
}
