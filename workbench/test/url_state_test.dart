// ignore_for_file: lines_longer_than_80_chars

import 'package:flutter_test/flutter_test.dart';

import 'package:genuiform_workbench/src/persistence/url_state.dart';
import 'package:genuiform_workbench/src/scenarios/scenario_strings.dart';

void main() {
  group('encodeDslToHash / decodeDslFromHash', () {
    // ── Round-trip tests ──────────────────────────────────────────────────────

    test('round-trip: kLeadQualificationDsl', () {
      final encoded = encodeDslToHash(kLeadQualificationDsl);
      expect(decodeDslFromHash(encoded), equals(kLeadQualificationDsl));
    });

    test('round-trip: kGymgeistOnboardingDsl', () {
      final encoded = encodeDslToHash(kGymgeistOnboardingDsl);
      expect(decodeDslFromHash(encoded), equals(kGymgeistOnboardingDsl));
    });

    test('round-trip: kNewsletterSignupDsl', () {
      final encoded = encodeDslToHash(kNewsletterSignupDsl);
      expect(decodeDslFromHash(encoded), equals(kNewsletterSignupDsl));
    });

    test('round-trip: kMedicalIntakeDsl', () {
      final encoded = encodeDslToHash(kMedicalIntakeDsl);
      expect(decodeDslFromHash(encoded), equals(kMedicalIntakeDsl));
    });

    test('round-trip: empty string', () {
      final encoded = encodeDslToHash('');
      expect(decodeDslFromHash(encoded), equals(''));
    });

    // ── decodeDslFromHash — malformed input ───────────────────────────────────

    test('decodeDslFromHash returns null on empty string', () {
      expect(decodeDslFromHash(''), isNull);
    });

    test('decodeDslFromHash returns null on raw garbage', () {
      expect(decodeDslFromHash('!!!not_base64!!!'), isNull);
    });

    test('decodeDslFromHash returns null on valid base64 that is not gzip', () {
      // "hello world" encoded in plain base64url — not gzip-compressed.
      const notGzip = 'aGVsbG8gd29ybGQ=';
      expect(decodeDslFromHash(notGzip), isNull);
    });

    // ── Compression sanity ────────────────────────────────────────────────────

    test('encoded hash for lead_qualification is shorter than raw UTF-8', () {
      final encoded = encodeDslToHash(kLeadQualificationDsl);
      // The raw DSL is well over 500 chars; gzip + base64 should still be
      // shorter because base64 adds ~33% overhead but gzip saves far more.
      expect(encoded.length, lessThan(kLeadQualificationDsl.length));
    });
  });
}
