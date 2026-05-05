import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/genuiform.dart';

import '../../_fixtures/sessions.dart';

void main() {
  group('FormConfig', () {
    late FormConfig config;
    late FakeLlmClient client;

    setUp(() {
      client = FakeLlmClient(scriptedResponses: []);
      config = FormConfig(
        contract: sampleContract(),
        constraints: [MaxSteps(value: 10)],
        posture: Posture.salesDiscovery(),
        outcomes: gymgeistTree(),
        client: client,
        model: 'gemini-2.5-flash',
        temperature: 0.7,
      );
    });

    test('default temperature is 0.7', () {
      final c = FormConfig(
        contract: sampleContract(),
        constraints: const [],
        posture: Posture.salesDiscovery(),
        outcomes: gymgeistTree(),
        client: client,
        model: 'gemini-2.5-flash',
      );
      expect(c.temperature, 0.7);
    });

    test('guidedCatalog defaults to null', () {
      expect(config.guidedCatalog, isNull);
    });

    test('equality — two identical configs are equal', () {
      final config2 = FormConfig(
        contract: sampleContract(),
        constraints: [MaxSteps(value: 10)],
        posture: Posture.salesDiscovery(),
        outcomes: gymgeistTree(),
        client: FakeLlmClient(scriptedResponses: []), // different client instance
        model: 'gemini-2.5-flash',
        temperature: 0.7,
      );
      expect(config, equals(config2));
    });

    test('equality — different model strings are not equal', () {
      final config2 = FormConfig(
        contract: sampleContract(),
        constraints: [MaxSteps(value: 10)],
        posture: Posture.salesDiscovery(),
        outcomes: gymgeistTree(),
        client: client,
        model: 'gemini-3-flash',
        temperature: 0.7,
      );
      expect(config, isNot(equals(config2)));
    });

    test('equality — different temperatures are not equal', () {
      final config2 = FormConfig(
        contract: sampleContract(),
        constraints: [MaxSteps(value: 10)],
        posture: Posture.salesDiscovery(),
        outcomes: gymgeistTree(),
        client: client,
        model: 'gemini-2.5-flash',
        temperature: 0.5,
      );
      expect(config, isNot(equals(config2)));
    });

    test('equality — client is excluded from equality check', () {
      // Two different FakeLlmClient instances → same equality
      final clientA = FakeLlmClient(scriptedResponses: ['a']);
      final clientB = FakeLlmClient(scriptedResponses: ['b']);
      final c1 = FormConfig(
        contract: sampleContract(),
        constraints: const [],
        posture: Posture.salesDiscovery(),
        outcomes: gymgeistTree(),
        client: clientA,
        model: 'gemini-2.5-flash',
      );
      final c2 = FormConfig(
        contract: sampleContract(),
        constraints: const [],
        posture: Posture.salesDiscovery(),
        outcomes: gymgeistTree(),
        client: clientB,
        model: 'gemini-2.5-flash',
      );
      expect(c1, equals(c2));
    });

    test('equality — different constraints are not equal', () {
      final c1 = FormConfig(
        contract: sampleContract(),
        constraints: [MaxSteps(value: 10)],
        posture: Posture.salesDiscovery(),
        outcomes: gymgeistTree(),
        client: client,
        model: 'gemini-2.5-flash',
      );
      final c2 = FormConfig(
        contract: sampleContract(),
        constraints: [MaxSteps(value: 5)],
        posture: Posture.salesDiscovery(),
        outcomes: gymgeistTree(),
        client: client,
        model: 'gemini-2.5-flash',
      );
      expect(c1, isNot(equals(c2)));
    });

    test('equality — guidedCatalog is included in props', () {
      final step = sampleStep(id: 'step_1', title: 'Q1');
      final c1 = FormConfig(
        contract: sampleContract(),
        constraints: const [],
        posture: Posture.salesDiscovery(),
        outcomes: gymgeistTree(),
        client: client,
        model: 'gemini-2.5-flash',
        guidedCatalog: [step],
      );
      final c2 = FormConfig(
        contract: sampleContract(),
        constraints: const [],
        posture: Posture.salesDiscovery(),
        outcomes: gymgeistTree(),
        client: client,
        model: 'gemini-2.5-flash',
        guidedCatalog: null,
      );
      expect(c1, isNot(equals(c2)));
    });

    test('toString includes model and temperature', () {
      expect(config.toString(), contains('gemini-2.5-flash'));
      expect(config.toString(), contains('0.7'));
    });
  });
}
