import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/genuiform.dart';

import '../../_fixtures/sessions.dart';

// A trivial concrete Strategy used only to verify the abstract contract.
class _StubStrategy extends Strategy {
  @override
  Stream<StepEvent> nextStep(Session session, FormConfig config) async* {
    yield StepReady(spec: sampleStep());
  }
}

void main() {
  group('Strategy abstract contract', () {
    test('concrete implementation can be instantiated and called', () async {
      final strategy = _StubStrategy();
      final config = FormConfig(
        contract: sampleContract(),
        constraints: const [],
        posture: Posture.salesDiscovery(),
        outcomes: gymgeistTree(),
        client: FakeLlmClient(scriptedResponses: []),
        model: 'gemini-2.5-flash',
      );
      final session = sampleSession();

      final events = await strategy.nextStep(session, config).toList();
      expect(events, hasLength(1));
      expect(events.first, isA<StepReady>());
    });
  });
}
