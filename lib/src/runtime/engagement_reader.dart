// Pure Dart — no Flutter imports.

import '../models/answer.dart';
import '../models/engagement_signal.dart';

// ────────────────────────────────────────────────────────────────────────────
// EngagementReader
// ────────────────────────────────────────────────────────────────────────────

/// Extracts an [EngagementSignal] from an LLM report or from a heuristic
/// analysis of the answer content and history.
///
/// ### Two backends
///
/// - **[readFromLlm]** — parses the LLM's structured engagement string.
///   Conservative fallback to [EngagementSignal.weak] on null or malformed
///   input.
/// - **[readHeuristic]** — pure function over answer text and prior history.
///   Five ordered rules; see method doc for details. Used as a fallback when
///   the LLM signal seems wrong (per spec §15 open question).
///
/// ### Combining signals
///
/// [combine] merges an LLM signal and a heuristic signal conservatively:
/// - `negative` propagates from either source.
/// - `weak` propagates when either source is weak (but neither is negative).
/// - `strong` requires both sources to agree.
class EngagementReader {
  // ── LLM-reported signal ───────────────────────────────────────────────────

  /// Parses the LLM's engagement string (`'strong'`, `'weak'`, `'negative'`).
  ///
  /// Matching is **case-insensitive**. On `null` or any unrecognised string,
  /// returns [EngagementSignal.weak] as the conservative default. This ensures
  /// that a bad LLM response degrades gracefully rather than causing errors.
  EngagementSignal readFromLlm(String? llmReport) {
    if (llmReport == null) return EngagementSignal.weak;
    return switch (llmReport.trim().toLowerCase()) {
      'strong' => EngagementSignal.strong,
      'weak' => EngagementSignal.weak,
      'negative' => EngagementSignal.negative,
      // Malformed / unexpected value — conservative fallback
      _ => EngagementSignal.weak,
    };
  }

  // ── Heuristic signal ──────────────────────────────────────────────────────

  /// Computes an [EngagementSignal] purely from the answer's text content and
  /// prior answer history.
  ///
  /// ### Rules (applied in order; first match wins)
  ///
  /// 1. **Terse-after-long collapse** (`negative`): if `answerText.length < 5`
  ///    AND any prior answer had length > 50. Classic engagement drop-off
  ///    pattern — the user was engaged, then suddenly gave up.
  ///
  /// 2. **Hedge tokens** (`weak`): if the answer contains any of the hedge
  ///    tokens (`'idk'`, `"i don't know"`, `'whatever'`, `'doesnt matter'`,
  ///    `"doesn't matter"`, `'no idea'`, `'not sure'`). Case-insensitive
  ///    substring match. The user is signalling uncertainty or disengagement.
  ///
  /// 3. **Long answer** (`strong`): `answerText.length >= 80`. The user wrote
  ///    a detailed response — strong engagement signal.
  ///
  /// 4. **Short answer** (`weak`): `answerText.length <= 10`. Low-effort
  ///    response. Note: answers of length 1–4 that would have triggered Rule 1
  ///    require a prior long answer; without one, they fall here.
  ///
  /// 5. **Default** (`weak`): conservative fallback for medium-length answers
  ///    (11–79 chars) with no hedge tokens. A neutral, non-committal signal.
  ///
  /// ### Tuning note
  ///
  /// All thresholds are constants defined at the top of this file so they can
  /// be adjusted in one place. The hedge-token list is similarly a single
  /// constant. No regex or NLP is used — this is intentionally simple for v1
  /// (spec §15 engagement signal calibration open question).
  EngagementSignal readHeuristic(Answer current, List<Answer> history) {
    final answerText = current.answer?.toString() ?? '';

    // ── Rule 1: terse-after-long collapse → negative ───────────────────────
    // The answer is very short (< 5 chars) AND the user previously gave a
    // long answer (> 50 chars). This pattern signals a drop-off in engagement.
    if (answerText.length < _terseThreshold) {
      final hadLongPrior =
          history.any((a) => (a.answer?.toString() ?? '').length > _longPriorThreshold);
      if (hadLongPrior) return EngagementSignal.negative;
    }

    // ── Rule 2: hedge tokens → weak ────────────────────────────────────────
    // Case-insensitive substring match. Any hedge token present signals
    // uncertainty or disengagement, regardless of answer length.
    final lower = answerText.toLowerCase();
    for (final hedge in _hedgeTokens) {
      if (lower.contains(hedge)) return EngagementSignal.weak;
    }

    // ── Rule 3: long answer → strong ────────────────────────────────────────
    // A detailed response of >= 80 chars is a strong engagement signal.
    if (answerText.length >= _strongLengthThreshold) {
      return EngagementSignal.strong;
    }

    // ── Rule 4: short answer → weak ─────────────────────────────────────────
    // A short response (<= 10 chars, no prior long answer to trigger Rule 1)
    // is a weak engagement signal — low effort, possibly distracted.
    if (answerText.length <= _weakLengthThreshold) {
      return EngagementSignal.weak;
    }

    // ── Rule 5: default → weak ───────────────────────────────────────────────
    // Medium-length answer (11–79 chars) with no hedge tokens. Conservative
    // default — we don't have enough signal to call it strong.
    return EngagementSignal.weak;
  }

  // ── Signal combination ────────────────────────────────────────────────────

  /// Combines an LLM-reported signal with a heuristic signal.
  ///
  /// Truth table (9 cases):
  ///
  /// | LLM      | Heuristic | Result   |
  /// |----------|-----------|----------|
  /// | strong   | strong    | strong   |
  /// | strong   | weak      | weak     |
  /// | strong   | negative  | negative |
  /// | weak     | strong    | weak     |
  /// | weak     | weak      | weak     |
  /// | weak     | negative  | negative |
  /// | negative | strong    | negative |
  /// | negative | weak      | negative |
  /// | negative | negative  | negative |
  ///
  /// Rules:
  /// 1. If either signal is `negative` → `negative`.
  /// 2. Else if either signal is `weak` → `weak`.
  /// 3. Else (both `strong`) → `strong`.
  EngagementSignal combine(EngagementSignal llm, EngagementSignal heuristic) {
    if (llm == EngagementSignal.negative ||
        heuristic == EngagementSignal.negative) {
      return EngagementSignal.negative;
    }
    if (llm == EngagementSignal.weak || heuristic == EngagementSignal.weak) {
      return EngagementSignal.weak;
    }
    return EngagementSignal.strong;
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Heuristic tuning constants
// ────────────────────────────────────────────────────────────────────────────
//
// Adjust these to tune heuristic sensitivity without touching the rule logic.

/// Rule 1: answer length below this triggers the terse-after-long check.
const int _terseThreshold = 5;

/// Rule 1: a prior answer above this length qualifies as "long".
const int _longPriorThreshold = 50;

/// Rule 3: answer length at or above this is considered a strong signal.
const int _strongLengthThreshold = 80;

/// Rule 4: answer length at or below this is considered a weak signal
/// (if Rule 1 did not already fire negative).
const int _weakLengthThreshold = 10;

/// Rule 2: hedge tokens indicating uncertainty or disengagement.
///
/// Case-insensitive substring match. List ordered by specificity (longer
/// phrases first) to avoid missing matches on partial strings, though in
/// practice substring search makes ordering irrelevant for correctness.
const List<String> _hedgeTokens = [
  "i don't know",
  "doesn't matter",
  'doesnt matter',
  'no idea',
  'not sure',
  'whatever',
  'idk',
];
