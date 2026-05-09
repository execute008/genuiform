// ignore_for_file: deprecated_member_use_from_same_package
import 'llm_client.dart';
import '../models/message.dart';

/// A single recorded invocation of [FakeLlmClient.generate].
///
/// Consumers can inspect [FakeLlmClient.invocations] after running their
/// code under test to assert that the strategy called [LlmClient.generate]
/// with the expected parameters.
class FakeLlmInvocation {
  /// The [LlmClient.generate] `systemPrompt` argument.
  final String systemPrompt;

  /// The [LlmClient.generate] `messages` argument.
  final List<Message> messages;

  /// The legacy `responseSchema` argument (null when the caller used
  /// [responseJsonSchema] instead).
  final Map<String, dynamic>? responseSchema;

  /// The newer `responseJsonSchema` argument (null when the caller used
  /// [responseSchema] instead). Exactly one of the two is non-null.
  final Map<String, dynamic>? responseJsonSchema;

  /// The [LlmClient.generate] `model` argument.
  final String model;

  /// The [LlmClient.generate] `temperature` argument.
  final double temperature;

  /// The [LlmClient.generate] `cachedContent` argument, if provided.
  final String? cachedContent;

  const FakeLlmInvocation({
    required this.systemPrompt,
    required this.messages,
    required this.responseSchema,
    required this.responseJsonSchema,
    required this.model,
    required this.temperature,
    this.cachedContent,
  });
}

/// A recorded invocation of [FakeLlmClient.createCachedContent].
class FakeCachedContentCreation {
  final String systemInstruction;
  final String model;
  final Duration ttl;
  final String returnedName;

  const FakeCachedContentCreation({
    required this.systemInstruction,
    required this.model,
    required this.ttl,
    required this.returnedName,
  });
}

/// A scripted [LlmClient] for use in unit tests.
///
/// Responses are popped from [scriptedResponses] in order. Each [generate]
/// call records its arguments in [invocations] so test code can assert what
/// the production caller sent.
///
/// This class lives in `lib/src/llm/` (not under `test/`) so that downstream
/// consumers of `genuiform` can also use it in their own test suites without
/// adding a dev dependency on a separate test-utilities package.
///
/// Example:
/// ```dart
/// final fake = FakeLlmClient(
///   scriptedResponses: ['{"decision":"ask_step","engagement":"strong"}'],
/// );
/// final strategy = GenerativeStrategy(client: fake, ...);
/// await strategy.nextStep(session, config).first;
/// expect(fake.invocations.first.model, 'gemini-2.5-flash');
/// ```
class FakeLlmClient extends LlmClient {
  final List<String> _remaining;
  final Duration? _responseDelay;
  final List<FakeLlmInvocation> _invocations = [];
  final List<FakeCachedContentCreation> _cachedContents = [];
  final List<String> _deletedCachedContents = [];
  int _cacheCounter = 0;

  /// Creates a [FakeLlmClient] with [scriptedResponses].
  ///
  /// [scriptedResponses] is consumed in order — index 0 is returned on the
  /// first [generate] call, index 1 on the second, and so on.
  ///
  /// [responseDelay] introduces an artificial delay before emitting each
  /// response, useful for testing latency-sensitive UI behaviour.
  FakeLlmClient({
    required List<String> scriptedResponses,
    Duration? responseDelay,
  })  : _remaining = List<String>.from(scriptedResponses),
        _responseDelay = responseDelay;

  /// All [generate] invocations recorded so far, in call order.
  List<FakeLlmInvocation> get invocations => List.unmodifiable(_invocations);

  /// All [createCachedContent] invocations recorded so far, in call order.
  List<FakeCachedContentCreation> get cachedContents =>
      List.unmodifiable(_cachedContents);

  /// All resource names passed to [deleteCachedContent], in call order.
  List<String> get deletedCachedContents =>
      List.unmodifiable(_deletedCachedContents);

  @override
  Stream<String> generate({
    required String systemPrompt,
    required List<Message> messages,
    Map<String, dynamic>? responseSchema,
    Map<String, dynamic>? responseJsonSchema,
    required String model,
    double temperature = 0.7,
    String? cachedContent,
  }) {
    assert(
      (responseSchema == null) != (responseJsonSchema == null),
      'FakeLlmClient.generate: pass exactly one of responseSchema / '
      'responseJsonSchema.',
    );
    if (_remaining.isEmpty) {
      throw StateError(
        'FakeLlmClient: scripted responses exhausted '
        '(called ${_invocations.length + 1} times, '
        'scripted ${_invocations.length} total).',
      );
    }

    final response = _remaining.removeAt(0);
    _invocations.add(
      FakeLlmInvocation(
        systemPrompt: systemPrompt,
        messages: messages,
        responseSchema: responseSchema,
        responseJsonSchema: responseJsonSchema,
        model: model,
        temperature: temperature,
        cachedContent: cachedContent,
      ),
    );

    return _responseDelay == null
        ? Stream.value(response)
        : Stream.fromFuture(
            Future.delayed(_responseDelay, () => response),
          );
  }

  @override
  Future<String> createCachedContent({
    required String systemInstruction,
    required String model,
    Duration ttl = const Duration(seconds: 300),
  }) async {
    final name = 'cachedContents/fake-${++_cacheCounter}';
    _cachedContents.add(FakeCachedContentCreation(
      systemInstruction: systemInstruction,
      model: model,
      ttl: ttl,
      returnedName: name,
    ));
    return name;
  }

  @override
  Future<void> deleteCachedContent(String name) async {
    _deletedCachedContents.add(name);
  }
}
