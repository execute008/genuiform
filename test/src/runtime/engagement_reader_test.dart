// Pure Dart unit tests — no Flutter / pumpWidget.

import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/genuiform.dart';

import '../../_fixtures/sessions.dart';

void main() {
  late EngagementReader reader;

  setUp(() {
    reader = EngagementReader();
  });

  // ── readFromLlm ───────────────────────────────────────────────────────────

  group('readFromLlm', () {
    test('parses "strong"', () {
      expect(reader.readFromLlm('strong'), EngagementSignal.strong);
    });

    test('parses "weak"', () {
      expect(reader.readFromLlm('weak'), EngagementSignal.weak);
    });

    test('parses "negative"', () {
      expect(reader.readFromLlm('negative'), EngagementSignal.negative);
    });

    test('case-insensitive: "STRONG" parses to strong', () {
      expect(reader.readFromLlm('STRONG'), EngagementSignal.strong);
    });

    test('case-insensitive: "Weak" parses to weak', () {
      expect(reader.readFromLlm('Weak'), EngagementSignal.weak);
    });

    test('case-insensitive: "NEGATIVE" parses to negative', () {
      expect(reader.readFromLlm('NEGATIVE'), EngagementSignal.negative);
    });

    test('null returns weak (conservative fallback)', () {
      expect(reader.readFromLlm(null), EngagementSignal.weak);
    });

    test('malformed string returns weak (conservative fallback)', () {
      expect(reader.readFromLlm('bogus'), EngagementSignal.weak);
    });

    test('empty string returns weak', () {
      expect(reader.readFromLlm(''), EngagementSignal.weak);
    });
  });

  // ── readHeuristic ─────────────────────────────────────────────────────────

  group('readHeuristic', () {
    // Rule 1: terse-after-long collapse (length < 5 AND prior > 50)
    group('Rule 1: terse-after-long collapse → negative', () {
      test('short answer after a long one returns negative', () {
        final longAnswer = sampleAnswer(answer: 'A' * 60); // > 50 chars
        final shortAnswer = sampleAnswer(answer: 'ok'); // < 5 chars
        final result = reader.readHeuristic(shortAnswer, [longAnswer]);
        expect(result, EngagementSignal.negative);
      });

      test('short answer with NO prior long answers does not return negative', () {
        final shortAnswer = sampleAnswer(answer: 'ok');
        final result = reader.readHeuristic(shortAnswer, []);
        // Falls through to Rule 4 (length <= 10) → weak
        expect(result, EngagementSignal.weak);
      });

      test('length == 4 (< 5) after prior length 51 → negative', () {
        final prior = sampleAnswer(answer: 'B' * 51);
        final current = sampleAnswer(answer: 'nope'); // 4 chars
        expect(reader.readHeuristic(current, [prior]), EngagementSignal.negative);
      });

      test('length == 5 (not < 5) after prior > 50 — Rule 1 does NOT fire', () {
        final prior = sampleAnswer(answer: 'C' * 60);
        final current = sampleAnswer(answer: 'hello'); // 5 chars exactly
        // Does not fire Rule 1; falls to Rule 4 (≤ 10 chars) → weak
        expect(reader.readHeuristic(current, [prior]), EngagementSignal.weak);
      });
    });

    // Rule 2: hedge tokens → weak
    group('Rule 2: hedge tokens → weak', () {
      const hedges = [
        'idk',
        "i don't know",
        'whatever',
        'doesnt matter',
        "doesn't matter",
        'no idea',
        'not sure',
      ];

      for (final hedge in hedges) {
        test('hedge "$hedge" in longer answer → weak', () {
          // Use a longer answer to ensure we don't hit Rule 4 before Rule 2
          final answer = sampleAnswer(answer: 'Well, $hedge about the rest');
          final result = reader.readHeuristic(answer, []);
          expect(result, EngagementSignal.weak,
              reason: 'Hedge token "$hedge" should produce weak signal');
        });
      }

      test('hedge is case-insensitive: IDK → weak', () {
        final answer = sampleAnswer(answer: 'IDK what to say here honestly');
        expect(reader.readHeuristic(answer, []), EngagementSignal.weak);
      });
    });

    // Rule 3: long answer → strong
    group('Rule 3: long answer (>= 80 chars) → strong', () {
      test('answer of 80 chars → strong', () {
        final answer = sampleAnswer(answer: 'x' * 80);
        expect(reader.readHeuristic(answer, []), EngagementSignal.strong);
      });

      test('answer of 120 chars → strong', () {
        final answer = sampleAnswer(answer: 'A very detailed answer that explains everything in great depth and shows the user is very engaged');
        expect(answer.answer.toString().length, greaterThanOrEqualTo(80));
        expect(reader.readHeuristic(answer, []), EngagementSignal.strong);
      });

      test('answer of 79 chars does NOT trigger Rule 3', () {
        final answer = sampleAnswer(answer: 'x' * 79);
        // 79 chars, no hedge, no terse-after-long → falls to Rule 4 (≤10? no) → otherwise weak
        expect(reader.readHeuristic(answer, []), EngagementSignal.weak);
      });
    });

    // Rule 4: short answer → weak
    group('Rule 4: short answer (<= 10 chars) → weak', () {
      test('answer of 10 chars → weak', () {
        final answer = sampleAnswer(answer: 'x' * 10);
        expect(reader.readHeuristic(answer, []), EngagementSignal.weak);
      });

      test('answer of 1 char → weak', () {
        final answer = sampleAnswer(answer: 'x');
        expect(reader.readHeuristic(answer, []), EngagementSignal.weak);
      });

      test('null answer treated as empty string → weak (length 0 ≤ 10)', () {
        final answer = sampleAnswer(answer: null);
        expect(reader.readHeuristic(answer, []), EngagementSignal.weak);
      });
    });

    // Rule 5: default → weak
    group('Rule 5: default fallback → weak', () {
      test('medium answer (11–79 chars, no hedge) → weak (fallback)', () {
        final answer = sampleAnswer(answer: 'Moderate response.'); // 18 chars
        expect(reader.readHeuristic(answer, []), EngagementSignal.weak);
      });
    });
  });

  // ── combine — full 3×3 truth table (9 cases) ─────────────────────────────

  group('combine truth table', () {
    // strong + strong = strong
    test('strong + strong = strong', () {
      expect(
        reader.combine(EngagementSignal.strong, EngagementSignal.strong),
        EngagementSignal.strong,
      );
    });

    // strong + weak = weak
    test('strong + weak = weak', () {
      expect(
        reader.combine(EngagementSignal.strong, EngagementSignal.weak),
        EngagementSignal.weak,
      );
    });

    // strong + negative = negative
    test('strong + negative = negative', () {
      expect(
        reader.combine(EngagementSignal.strong, EngagementSignal.negative),
        EngagementSignal.negative,
      );
    });

    // weak + strong = weak
    test('weak + strong = weak', () {
      expect(
        reader.combine(EngagementSignal.weak, EngagementSignal.strong),
        EngagementSignal.weak,
      );
    });

    // weak + weak = weak
    test('weak + weak = weak', () {
      expect(
        reader.combine(EngagementSignal.weak, EngagementSignal.weak),
        EngagementSignal.weak,
      );
    });

    // weak + negative = negative
    test('weak + negative = negative', () {
      expect(
        reader.combine(EngagementSignal.weak, EngagementSignal.negative),
        EngagementSignal.negative,
      );
    });

    // negative + strong = negative
    test('negative + strong = negative', () {
      expect(
        reader.combine(EngagementSignal.negative, EngagementSignal.strong),
        EngagementSignal.negative,
      );
    });

    // negative + weak = negative
    test('negative + weak = negative', () {
      expect(
        reader.combine(EngagementSignal.negative, EngagementSignal.weak),
        EngagementSignal.negative,
      );
    });

    // negative + negative = negative
    test('negative + negative = negative', () {
      expect(
        reader.combine(EngagementSignal.negative, EngagementSignal.negative),
        EngagementSignal.negative,
      );
    });
  });
}
