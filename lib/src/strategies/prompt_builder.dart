// Pure Dart — no Flutter imports.

import '../icons/icon_registry.dart';
import '../models/answer.dart';
import '../models/constraints.dart';
import '../models/contract.dart';
import '../models/engagement_signal.dart';
import '../models/outcomes.dart';
import '../models/posture.dart';
import '../models/session.dart';
import 'form_config.dart';

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Builds the byte-stable portion of the system prompt from [config] alone.
///
/// This function is a pure function of [FormConfig] — it does not read any
/// per-session state (no history, no currentNode marker, no runningContract
/// deltas). The output is identical for all sessions sharing the same config,
/// which makes it eligible for Gemini's `cachedContents` API.
///
/// Section order:
///   1. Role preamble
///   2. YOUR JOB EACH TURN
///   3. BASE CONTRACT
///   4. CONSTRAINTS
///   5. POSTURE
///   6. OUTCOME TREE (no `<<<` marker)
///   7. INSTRUCTIONS
///   8. JSON-only directive
String buildStaticSystemPrompt(FormConfig config) {
  final contractSection = _renderContract(config.contract);
  final constraintsSection = _renderConstraints(config.constraints);
  final postureSection = _renderPosture(config.posture);
  final treeSection = _renderOutcomeTreeStatic(config.outcomes);
  final iconSection = _renderIconRegistry();

  return '''You are a form designer running an adaptive intake conversation.

YOUR JOB EACH TURN:
- Look at what's been collected so far.
- Look at what's still missing from the running contract.
- Look at where in the outcome tree we are.
- Decide ONE of:
  a) Ask the next question (emit a step)
  b) Offer a graceful exit (we're at a Layer boundary and engagement is weak)
  c) Resolve a Branch (we have enough to pick which path)
  d) Mark the form complete (we've reached an Outcome)

BASE CONTRACT (collected for completion; deltas added per path):
$contractSection

CONSTRAINTS (hard rules — never violate):
$constraintsSection

POSTURE:
$postureSection

OUTCOME TREE:
$treeSection

INSTRUCTIONS:
- Ask ONE focused question per step. Never bundle.
- Adapt wording to the user's level and tone (per posture.voice).
- Skip what's already obvious from prior answers.
- For 'choice' and 'multiChoice', provide 2-7 options. Use icons from: $iconSection.
- If pacing is high and engagement is strong, push toward deeper layers.
- If pacing is low or engagement is negative, offer the current Layer's exit.
- Never invent input types. Use only: slider, choice, multiChoice, text, number, date, noneJustInformation.

Return ONLY valid JSON matching the schema. No prose, no markdown.''';
}

/// Builds a small per-turn context block containing only the information that
/// changes between turns: the current node, any contract deltas relative to
/// the base, and the last engagement signal.
///
/// This block is appended to the final user message in `_buildMessages`, not
/// injected into the system prompt.
///
/// Format:
/// ```
/// [CONTEXT]
/// current_node: <id>
/// contract_delta: <fields not in config.contract, or "(none)">
/// last_engagement: <wireValue>
/// ```
String buildDynamicTurnContext(FormConfig config, Session session) {
  final deltaFields = <String, dynamic>{};
  for (final entry in session.runningContract.fields.entries) {
    if (!config.contract.fields.containsKey(entry.key)) {
      deltaFields[entry.key] = entry.value;
    }
  }

  final deltaSection = deltaFields.isEmpty
      ? '(none)'
      : _renderContract(Contract(fields: Map.fromEntries(
          deltaFields.entries.map((e) => MapEntry(e.key, e.value as dynamic)),
        )));

  return '''[CONTEXT]
current_node: ${session.currentNode.id}
contract_delta: $deltaSection
last_engagement: ${session.lastSignal.wireValue}''';
}

/// Builds the §10.1 generative system prompt from [config] and [session].
///
/// @deprecated Use [buildStaticSystemPrompt] + [buildDynamicTurnContext]
/// separately. This wrapper exists only for backwards-compatible test code
/// that asserts against the combined prompt text. It will be removed once
/// all callers are updated.
String buildGenerativeSystemPrompt(FormConfig config, Session session) {
  return buildStaticSystemPrompt(config);
}

/// Builds a shorter system prompt for [GuidedStrategy].
///
/// The prompt is substantially shorter than the generative one — it only
/// presents the catalog IDs + titles and asks the model to pick the next one.
/// The `< 1500 char` acceptance criterion in the test suite is enforced here.
String buildGuidedSystemPrompt(FormConfig config, Session session) {
  final catalog = config.guidedCatalog;
  if (catalog == null || catalog.isEmpty) {
    return 'Pick the next step ID. No catalog provided — return an empty response.';
  }

  final catalogLines = catalog
      .map((s) => '  - ${s.id}: ${s.title}')
      .join('\n');

  final historySection = _renderCompactHistory(session.history);

  return '''You are a form routing assistant. Pick the next step from the catalog.

CATALOG:
$catalogLines

CONVERSATION SO FAR:
$historySection

ENGAGEMENT SIGNAL FROM LAST ANSWER:
${_renderEngagement(session.lastSignal)}

Return ONLY valid JSON: {"next_step_id": "<id from catalog>", "engagement": "strong" | "weak" | "negative"}''';
}

// ---------------------------------------------------------------------------
// Private rendering helpers
// ---------------------------------------------------------------------------

/// Bullet list of `field_id (Type, required/optional): description`.
String _renderContract(Contract running) {
  if (running.fields.isEmpty) {
    return '  (no fields defined)';
  }
  final lines = running.fields.entries.map((entry) {
    final fieldId = entry.key;
    final spec = entry.value;
    final reqLabel = spec.required ? 'required' : 'optional';
    final desc = spec.description != null ? ': ${spec.description}' : '';
    final enumNote =
        spec.enumValues != null && spec.enumValues!.isNotEmpty
            ? ' [values: ${spec.enumValues!.join(', ')}]'
            : '';
    return '  - $fieldId (${spec.type}, $reqLabel)$enumNote$desc';
  });
  return lines.join('\n');
}

/// Bullet list, one per constraint variant, formatted for LLM readability.
String _renderConstraints(List<Constraint> cs) {
  if (cs.isEmpty) {
    return '  (no constraints)';
  }
  final lines = cs.map((c) => '  - ${_constraintDescription(c)}');
  return lines.join('\n');
}

String _constraintDescription(Constraint c) {
  return switch (c) {
    NeverCollect(:final fieldOrTopic) =>
      'NeverCollect("$fieldOrTopic") — never ask about or collect this field/topic',
    NeverSkip(:final fieldIds) =>
      'NeverSkip(${fieldIds.join(', ')}) — these fields must be collected; never skip them',
    MaxSteps(:final value) =>
      'MaxSteps($value) — hard limit of $value steps; stop before exceeding',
    MinSteps(:final value) =>
      'MinSteps($value) — do not complete before at least $value steps',
    WhitelistChoices(:final fieldId, :final allowed) =>
      'WhitelistChoices("$fieldId", [${allowed.join(', ')}]) — only these choices are permitted for this field',
    EscalateIf(:final trigger) =>
      'EscalateIf("$trigger") — if user mentions this, escalate immediately',
    StopIf(:final trigger) =>
      'StopIf("$trigger") — if user mentions this, stop the form immediately',
    RequireConsent(:final topic) =>
      'RequireConsent("$topic") — obtain explicit consent before collecting this topic',
  };
}

/// Multi-line posture section with numeric knobs and one-sentence interpretations.
String _renderPosture(Posture p) {
  return '''  persistence: ${p.persistence}/5 — ${_persistenceLabel(p.persistence)}
  exploration: ${p.exploration}/5 — ${_explorationLabel(p.exploration)}
  pacing: ${p.pacing}/5 — ${_pacingLabel(p.pacing)}
  skipTolerance: ${p.skipTolerance}/5 — ${_skipToleranceLabel(p.skipTolerance)}
  voice: "${p.voice}"''';
}

String _persistenceLabel(int v) => switch (v) {
      1 => 'let go quickly; one follow-up at most',
      2 => 'gentle nudge; accept vague answers after one probe',
      3 => 'probe twice before accepting vague answers',
      4 => 'push firmly; accept only clear or explicitly declined answers',
      _ => 'maximum persistence; do not accept vague answers under any circumstance',
    };

String _explorationLabel(int v) => switch (v) {
      1 => 'stay strictly on topic; ignore tangents',
      2 => 'mostly on topic; one optional follow-up on notable tangents',
      3 => 'balanced; follow interesting tangents briefly then return',
      4 => 'open to tangents; follow promising threads for several turns',
      _ => 'highly exploratory; follow any tangent that seems valuable',
    };

String _pacingLabel(int v) => switch (v) {
      1 => 'stop at first complete layer; never deepen unprompted',
      2 => 'continue into next layer only if engagement is clearly strong',
      3 => 'continue if signals are positive; exit at first hesitation',
      4 => 'push deeper unless engagement is weak or negative',
      _ => 'push to deepest reachable outcome unless user explicitly bails',
    };

String _skipToleranceLabel(int v) => switch (v) {
      1 => 'strict; treat skips as answers of last resort',
      2 => 'low tolerance; note skips but continue with a follow-up',
      3 => 'moderate; accept a skip gracefully after one probe',
      4 => 'high; accept skips without pushback',
      _ => 'fully accommodating; accept any skip immediately, no follow-up',
    };

/// ASCII tree without any `<<<` current-node marker — stable across sessions.
String _renderOutcomeTreeStatic(OutcomeNode root) {
  final buffer = StringBuffer();
  _renderNodeStatic(root, '', true, buffer);
  return buffer.toString().trimRight();
}

void _renderNodeStatic(
  OutcomeNode node,
  String indent,
  bool isLast,
  StringBuffer buffer,
) {
  final connector = isLast ? '└── ' : '├── ';
  final childIndent = isLast ? '    ' : '│   ';

  switch (node) {
    case Layer(:final id, :final next):
      buffer.writeln('$indent${connector}Layer[$id]');
      if (next != null) {
        _renderNodeStatic(next, indent + childIndent, true, buffer);
      }

    case Branch(:final id, :final options):
      buffer.writeln('$indent${connector}Branch[$id]');
      for (var i = 0; i < options.length; i++) {
        final opt = options[i];
        final optIsLast = i == options.length - 1;
        final optConnector = optIsLast ? '└── ' : '├── ';
        final optChildIndent = optIsLast ? '    ' : '│   ';
        buffer.writeln(
          '$indent$childIndent${optConnector}option[${opt.id}]: ${opt.criterion}',
        );
        _renderNodeStatic(
          opt.child,
          indent + childIndent + optChildIndent,
          true,
          buffer,
        );
      }

    case Outcome(:final id):
      buffer.writeln('$indent${connector}Outcome[$id]');
  }
}

/// Last N=8 answers as `Q: ...\nA: ...`.
String _renderCompactHistory(List<Answer> history) {
  const maxEntries = 8;
  if (history.isEmpty) {
    return '  (no answers yet)';
  }
  final recent = history.length > maxEntries
      ? history.sublist(history.length - maxEntries)
      : history;
  final lines = recent.map((a) {
    final q = a.stepSpec.title;
    final ans = a.answer?.toString() ?? '(no answer)';
    return 'Q: $q\nA: $ans';
  });
  return lines.join('\n');
}

/// Renders the engagement signal as a human-readable label.
String _renderEngagement(EngagementSignal signal) {
  return signal.wireValue;
}

/// Comma-separated list of all registered icon names.
///
/// NOTE: The full registry (~160 names) adds roughly 1,800 characters to the
/// system prompt. See report section on cost flag for trimming recommendations.
String _renderIconRegistry() {
  final names = IconRegistry.registeredIconNames..sort();
  return names.join(', ');
}
