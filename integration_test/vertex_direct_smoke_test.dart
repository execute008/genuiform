// Smoke test for [VertexDirectClient] against real Vertex AI.
//
// **Never run by `flutter test`.** This file lives under `integration_test/`
// and is only executed manually or in CI with the environment variable
// `GENUIFORM_RUN_INTEGRATION=1` set.
//
// Run with:
//   GENUIFORM_RUN_INTEGRATION=1 \
//   VERTEX_API_KEY=<access-token> \
//   VERTEX_PROJECT_ID=<gcp-project> \
//   flutter test integration_test/vertex_direct_smoke_test.dart
//
// All tests in this file are skipped unless
// String.fromEnvironment('GENUIFORM_RUN_INTEGRATION') == '1'.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/src/llm/schemas.dart';
import 'package:genuiform/src/llm/vertex_direct_client.dart';
import 'package:genuiform/src/models/message.dart';

const _runIntegration =
    String.fromEnvironment('GENUIFORM_RUN_INTEGRATION') == '1';

void main() {
  group('VertexDirectClient smoke test (real Vertex AI)', () {
    test('generates a non-empty JSON response from gemini-2.5-flash', () async {
      if (!_runIntegration) {
        // ignore: avoid_print
        print(
          'Skipping integration test. '
          'Set GENUIFORM_RUN_INTEGRATION=1 to run.',
        );
        return;
      }

      final apiKey = Platform.environment['VERTEX_API_KEY'] ?? '';
      final projectId = Platform.environment['VERTEX_PROJECT_ID'] ?? '';
      const location = 'europe-west1';

      expect(
        apiKey,
        isNotEmpty,
        reason: 'Set VERTEX_API_KEY env var to a valid GCP access token.',
      );
      expect(
        projectId,
        isNotEmpty,
        reason: 'Set VERTEX_PROJECT_ID env var to your GCP project ID.',
      );

      final client = VertexDirectClient(
        apiKey: apiKey,
        projectId: projectId,
        location: location,
      );

      final result = await client
          .generate(
            systemPrompt:
                'You are a test assistant. Return only valid JSON matching '
                'the provided schema. Ask a simple text question about the '
                'user\'s favourite colour.',
            messages: [
              Message(role: MessageRole.user, content: 'Start the form.'),
            ],
            responseSchema: generativeStrategyResponseSchema(),
            model: 'gemini-2.5-flash',
          )
          .first;

      // Verify the response is non-empty and valid JSON.
      expect(result, isNotEmpty);
      final decoded = jsonDecode(result) as Map<String, dynamic>;
      expect(decoded.containsKey('decision'), isTrue);
      expect(decoded.containsKey('engagement'), isTrue);

      // ignore: avoid_print
      print('Smoke test response: $result');
    }, timeout: const Timeout(Duration(seconds: 30)),);
  });
}
