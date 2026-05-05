import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/src/models/posture.dart';

void main() {
  group('Posture', () {
    test('constructs with explicit values', () {
      const p = Posture(
        persistence: 3,
        exploration: 2,
        pacing: 4,
        skipTolerance: 1,
        voice: 'Direct and professional.',
      );
      expect(p.persistence, 3);
      expect(p.exploration, 2);
      expect(p.pacing, 4);
      expect(p.skipTolerance, 1);
      expect(p.voice, 'Direct and professional.');
    });

    test('equality holds', () {
      const a = Posture(persistence: 1, exploration: 1, pacing: 1, skipTolerance: 1, voice: 'X');
      const b = Posture(persistence: 1, exploration: 1, pacing: 1, skipTolerance: 1, voice: 'X');
      expect(a, equals(b));
    });

    test('JSON round-trip', () {
      const p = Posture(
        persistence: 3,
        exploration: 2,
        pacing: 4,
        skipTolerance: 1,
        voice: 'Direct.',
      );
      final json = p.toJson();
      final restored = Posture.fromJson(json);
      expect(restored, equals(p));
    });

    group('salesDiscovery preset', () {
      test('persistence is 4', () {
        expect(Posture.salesDiscovery().persistence, 4);
      });
      test('exploration is 2', () {
        expect(Posture.salesDiscovery().exploration, 2);
      });
      test('pacing is 3', () {
        expect(Posture.salesDiscovery().pacing, 3);
      });
      test('skipTolerance is 2', () {
        expect(Posture.salesDiscovery().skipTolerance, 2);
      });
      test('voice matches spec exactly', () {
        expect(
          Posture.salesDiscovery().voice,
          'Sovereign, curious, never desperate. Senior consultant tone.',
        );
      });
    });

    group('supportiveOnboarding preset', () {
      test('persistence is 2', () {
        expect(Posture.supportiveOnboarding().persistence, 2);
      });
      test('exploration is 1', () {
        expect(Posture.supportiveOnboarding().exploration, 1);
      });
      test('pacing is 3', () {
        expect(Posture.supportiveOnboarding().pacing, 3);
      });
      test('skipTolerance is 4', () {
        expect(Posture.supportiveOnboarding().skipTolerance, 4);
      });
      test('voice matches spec exactly', () {
        expect(
          Posture.supportiveOnboarding().voice,
          'Encouraging, brief, momentum-focused. Coach, not drill sergeant.',
        );
      });
    });

    group('clinicalIntake preset', () {
      test('persistence is 5', () {
        expect(Posture.clinicalIntake().persistence, 5);
      });
      test('exploration is 1', () {
        expect(Posture.clinicalIntake().exploration, 1);
      });
      test('pacing is 2', () {
        expect(Posture.clinicalIntake().pacing, 2);
      });
      test('skipTolerance is 1', () {
        expect(Posture.clinicalIntake().skipTolerance, 1);
      });
      test('voice matches spec exactly', () {
        expect(
          Posture.clinicalIntake().voice,
          'Precise, professional, non-judgmental.',
        );
      });
    });
  });
}
