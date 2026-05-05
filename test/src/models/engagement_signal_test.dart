import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/src/models/engagement_signal.dart';
import 'package:genuiform/src/models/session_status.dart';

void main() {
  group('EngagementSignal', () {
    test('has three values', () {
      expect(EngagementSignal.values.length, 3);
    });

    test('has strong, weak, negative', () {
      expect(EngagementSignal.values, containsAll([
        EngagementSignal.strong,
        EngagementSignal.weak,
        EngagementSignal.negative,
      ]));
    });

    test('JSON round-trip: strong', () {
      const e = EngagementSignal.strong;
      final json = engagementSignalToJson(e);
      expect(json, 'strong');
      expect(engagementSignalFromJson(json), e);
    });

    test('JSON round-trip: weak', () {
      const e = EngagementSignal.weak;
      final json = engagementSignalToJson(e);
      expect(json, 'weak');
      expect(engagementSignalFromJson(json), e);
    });

    test('JSON round-trip: negative', () {
      const e = EngagementSignal.negative;
      final json = engagementSignalToJson(e);
      expect(json, 'negative');
      expect(engagementSignalFromJson(json), e);
    });
  });

  group('SessionStatus', () {
    test('has four values', () {
      expect(SessionStatus.values.length, 4);
    });

    test('has active, completed, abandoned, escalated', () {
      expect(SessionStatus.values, containsAll([
        SessionStatus.active,
        SessionStatus.completed,
        SessionStatus.abandoned,
        SessionStatus.escalated,
      ]));
    });

    test('JSON round-trip: active', () {
      const s = SessionStatus.active;
      final json = sessionStatusToJson(s);
      expect(json, 'active');
      expect(sessionStatusFromJson(json), s);
    });

    test('JSON round-trip: completed', () {
      final json = sessionStatusToJson(SessionStatus.completed);
      expect(json, 'completed');
      expect(sessionStatusFromJson(json), SessionStatus.completed);
    });

    test('JSON round-trip: abandoned', () {
      final json = sessionStatusToJson(SessionStatus.abandoned);
      expect(json, 'abandoned');
    });

    test('JSON round-trip: escalated', () {
      final json = sessionStatusToJson(SessionStatus.escalated);
      expect(json, 'escalated');
    });
  });
}
