import 'dart:async';

import 'package:genuiform/genuiform.dart';

/// A scripted [LlmClient] used in demo/mock mode (`--dart-define=USE_MOCK=true`).
///
/// Returns canned step JSON matching the [GenerativeStrategy] schema.
/// Detects the scenario from the system prompt and returns appropriate outcomes.
///
/// This is intentionally separate from [FakeLlmClient] (which lives in the
/// library and is test-scoped). This one is workbench-local and simulates a
/// realistic timing delay so the demo feels alive.
class WorkbenchMockLlmClient extends LlmClient {
  WorkbenchMockLlmClient();

  int _callCount = 0;

  static const _delay = Duration(milliseconds: 600);

  /// Detect which scenario we're in from the system prompt
  String _detectScenario(String systemPrompt) {
    if (systemPrompt.contains('full_meal_plan') || systemPrompt.contains('workout_only')) {
      return 'gymgeist';
    } else if (systemPrompt.contains('subscribed')) {
      return 'newsletter';
    } else if (systemPrompt.contains('intake_complete')) {
      return 'medical';
    } else if (systemPrompt.contains('book_call') || systemPrompt.contains('send_proposal')) {
      return 'lead_qualification';
    }
    return 'lead_qualification'; // default
  }

  /// Get the appropriate completion response for each scenario
  String _getCompletionForScenario(String scenario) {
    switch (scenario) {
      case 'gymgeist':
        // For GymGeist, we need to handle the branch resolution first
        if (_callCount == 5) {
          return '{"decision":"resolve_branch","engagement":"strong","branch_resolution":{"branch_id":"nutrition_path","option_id":"with_meal_plan","rationale":"User wants meal planning."}}';
        }
        return '{"decision":"complete","engagement":"strong","outcome":{"outcome_id":"full_meal_plan","summary":"Complete fitness and nutrition setup."}}';
      case 'newsletter':
        return '{"decision":"complete","engagement":"strong","outcome":{"outcome_id":"subscribed","summary":"Successfully subscribed to newsletter."}}';
      case 'medical':
        return '{"decision":"complete","engagement":"strong","outcome":{"outcome_id":"intake_complete","summary":"Medical intake form completed."}}';
      case 'lead_qualification':
      default:
        if (_callCount == 5) {
          return '{"decision":"resolve_branch","engagement":"strong","branch_resolution":{"branch_id":"lead_split","option_id":"book_call","rationale":"Qualified lead with clear brief and immediate timeline."}}';
        }
        return '{"decision":"complete","engagement":"strong","outcome":{"outcome_id":"book_call","summary":"Qualified senior decision-maker with clear brief and immediate timeline."}}';
    }
  }

  /// Generic ask steps that work for any scenario
  static const _genericSteps = <String>[
    // Turn 1 — ask for name
    '{"decision":"ask_step","engagement":"strong","step":{"id":"step_name","title":"What\'s your name?","inputType":"text"}}',
    // Turn 2 — ask for email
    '{"decision":"ask_step","engagement":"strong","step":{"id":"step_email","title":"What\'s your email?","inputType":"text"}}',
    // Turn 3 — ask for details
    '{"decision":"ask_step","engagement":"strong","step":{"id":"step_details","title":"Tell me more about your needs","description":"Be as specific as you like.","inputType":"text"}}',
    // Turn 4 — ask for preference
    '{"decision":"ask_step","engagement":"strong","step":{"id":"step_preference","title":"What\'s most important to you?","inputType":"choice","choices":[{"id":"option1","label":"Option 1"},{"id":"option2","label":"Option 2"},{"id":"option3","label":"Option 3"}]}}',
  ];

  @override
  Stream<String> generate({
    required String systemPrompt,
    required List<Message> messages,
    Map<String, dynamic>? responseSchema,
    Map<String, dynamic>? responseJsonSchema,
    required String model,
    double temperature = 0.7,
  }) {
    final scenario = _detectScenario(systemPrompt);
    String response;
    
    if (_callCount < _genericSteps.length) {
      // Use generic steps for the first few interactions
      response = _genericSteps[_callCount];
    } else {
      // Use scenario-specific completion
      response = _getCompletionForScenario(scenario);
    }
    
    _callCount++;
    return Stream.fromFuture(
      Future.delayed(_delay, () => response),
    );
  }
}
