import 'dart:async';

import 'package:genuiform/genuiform.dart';

/// A scripted [LlmClient] used in demo/mock mode (`--dart-define=USE_MOCK=true`).
///
/// Returns canned step JSON matching the [GenerativeStrategy] schema for the
/// lead_qualification scenario: four [ask_step] responses followed by a
/// [complete] response with `outcome_id: 'book_call'`.
///
/// This is intentionally separate from [FakeLlmClient] (which lives in the
/// library and is test-scoped). This one is workbench-local and simulates a
/// realistic timing delay so the demo feels alive.
class WorkbenchMockLlmClient extends LlmClient {
  WorkbenchMockLlmClient();

  int _callCount = 0;

  static const _delay = Duration(milliseconds: 600);

  /// Scripted responses for the lead_qualification scenario.
  static const _responses = <String>[
    // Turn 1 — ask for name
    '{"decision":"ask_step","engagement":"strong","step":{"id":"step_name","title":"What\'s your name?","inputType":"text"}}',
    // Turn 2 — ask for company
    '{"decision":"ask_step","engagement":"strong","step":{"id":"step_company","title":"What company are you from?","inputType":"text"}}',
    // Turn 3 — ask for pain point
    '{"decision":"ask_step","engagement":"strong","step":{"id":"step_pain","title":"What problem are you trying to solve?","description":"Be as specific as you like.","inputType":"text"}}',
    // Turn 4 — ask for timeline
    '{"decision":"ask_step","engagement":"strong","step":{"id":"step_timeline","title":"When are you looking to get started?","inputType":"choice","choices":[{"id":"immediate","label":"Immediately"},{"id":"1-3 months","label":"1–3 months"},{"id":"3-6 months","label":"3–6 months"},{"id":"6+","label":"6+ months"}]}}',
    // Turn 5 — resolve branch
    '{"decision":"resolve_branch","engagement":"strong","branch_resolution":{"branch_id":"lead_split","option_id":"book_call","rationale":"Qualified lead with clear brief and immediate timeline."}}',
    // Turn 6 — complete
    '{"decision":"complete","engagement":"strong","outcome":{"outcome_id":"book_call","summary":"Qualified senior decision-maker with clear brief and immediate timeline."}}',
  ];

  @override
  Stream<String> generate({
    required String systemPrompt,
    required List<Message> messages,
    required Map<String, dynamic> responseSchema,
    required String model,
    double temperature = 0.7,
  }) {
    final index = _callCount < _responses.length ? _callCount : _responses.length - 1;
    _callCount++;
    final response = _responses[index];
    return Stream.fromFuture(
      Future.delayed(_delay, () => response),
    );
  }
}
