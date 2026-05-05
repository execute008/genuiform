import 'package:freezed_annotation/freezed_annotation.dart';

part 'posture.freezed.dart';
part 'posture.g.dart';

/// The soft behavioural layer of a form — style knobs the LLM interprets to
/// shape the user's experience without changing *what* gets collected.
///
/// Posture is a **soft primitive**: its knobs can be ignored by the LLM
/// without breaking anything. An ignored `pacing` is bad UX, not a bug.
/// Contrast with [Constraint], which is hard-enforced by the runtime.
///
/// ### Knobs (all 1–5 unless noted)
///
/// - **[persistence]** — how hard to push when answers are vague.
/// - **[exploration]** — how willing to follow tangents.
/// - **[pacing]** — how aggressively to deepen the conversation through the
///   outcome tree based on engagement signals. This is the most important knob:
///   combined with [EngagementSignal] it determines whether the form continues
///   to the next [Layer] or offers an exit.
/// - **[skipTolerance]** — how easily to accept "I don't want to answer".
/// - **[voice]** — free-text tone description fed verbatim to the LLM.
@freezed
abstract class Posture with _$Posture {
  const factory Posture({
    /// How hard to push when answers are vague. Range: 1 (gentle) – 5 (persistent).
    required int persistence,

    /// How willing the form is to follow tangents. Range: 1 (focused) – 5 (open).
    required int exploration,

    /// How aggressively to deepen through the outcome tree based on engagement.
    ///
    /// - **1**: stop at first complete layer, never deepen unprompted.
    /// - **3**: continue if signals are positive, exit at first hesitation.
    /// - **5**: push to deepest reachable outcome unless user explicitly bails.
    required int pacing,

    /// How easily to accept "I don't want to answer". Range: 1 (strict) – 5 (accommodating).
    required int skipTolerance,

    /// Free-text tone description. Fed verbatim to the LLM as part of the
    /// system prompt. Describes vocal register, persona, and energy.
    required String voice,
  }) = _Posture;

  factory Posture.fromJson(Map<String, dynamic> json) =>
      _$PostureFromJson(json);

  /// Sales-discovery preset — assertive, curious, professional.
  ///
  /// `persistence: 4, exploration: 2, pacing: 3, skipTolerance: 2`
  static Posture salesDiscovery() => const Posture(
        persistence: 4,
        exploration: 2,
        pacing: 3,
        skipTolerance: 2,
        voice: 'Sovereign, curious, never desperate. Senior consultant tone.',
      );

  /// Supportive-onboarding preset — encouraging, momentum-focused.
  ///
  /// `persistence: 2, exploration: 1, pacing: 3, skipTolerance: 4`
  static Posture supportiveOnboarding() => const Posture(
        persistence: 2,
        exploration: 1,
        pacing: 3,
        skipTolerance: 4,
        voice: 'Encouraging, brief, momentum-focused. Coach, not drill sergeant.',
      );

  /// Clinical-intake preset — precise, professional, non-judgmental.
  ///
  /// `persistence: 5, exploration: 1, pacing: 2, skipTolerance: 1`
  static Posture clinicalIntake() => const Posture(
        persistence: 5,
        exploration: 1,
        pacing: 2,
        skipTolerance: 1,
        voice: 'Precise, professional, non-judgmental.',
      );
}
