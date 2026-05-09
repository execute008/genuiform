// Single source of truth for the workbench DSL surface.
//
// Every primitive the parser accepts is enumerated here with:
//   • [name]         — the identifier as written in source
//   • [signature]    — human-readable form for the legend (e.g. `Layer(id, …)`)
//   • [description]  — one-line summary
//   • [snippetTemplate] — what the editor inserts; may contain a single
//                        `«placeholder»` marker. The marker is stripped, the
//                        cursor lands at its position, and the placeholder
//                        text (if any) is left selected so the user can
//                        overtype it. Use `«»` to mean "cursor here, no
//                        selection".
//
// Adding a new primitive in the parser? Mirror it here so that completion and
// the legend drawer pick it up automatically.

import 'package:flutter/widgets.dart';
import 'package:re_editor/re_editor.dart';

import '../registry/handoff_registry.dart';

enum DslGroup {
  topLevel('Top-level'),
  contract('Contract & fields'),
  fieldType('Field types'),
  constraints('Constraints'),
  posture('Posture'),
  outcomes('Outcomes & flow'),
  handoffs('Handoff keys');

  const DslGroup(this.label);
  final String label;
}

@immutable
class DslPrimitive {
  const DslPrimitive({
    required this.name,
    required this.signature,
    required this.description,
    required this.group,
    required this.snippetTemplate,
    this.relatedTo,
  });

  /// The identifier as written in source — also the trigger word.
  final String name;

  /// Human-readable signature shown in the legend & popup.
  final String signature;

  /// One-line summary shown alongside the signature.
  final String description;

  final DslGroup group;

  /// Template containing zero or one `«placeholder»` marker; see file header.
  final String snippetTemplate;

  /// If set, this primitive is only suggested after `relatedTo.` has been
  /// typed (e.g. `salesDiscovery` follows `Posture.`).
  final String? relatedTo;

  // ── Snippet expansion ─────────────────────────────────────────────────────

  static final RegExp _markerRe = RegExp('«([^»]*)»');

  /// The text actually inserted (markers stripped).
  String get snippet =>
      snippetTemplate.replaceAllMapped(_markerRe, (m) => m.group(1)!);

  /// Caret offset inside [snippet] after insertion. If the template contains
  /// a marker, the caret lands at its start; otherwise at the end of the snippet.
  int get _cursorOffset {
    final match = _markerRe.firstMatch(snippetTemplate);
    if (match == null) return snippet.length;
    return match.start;
  }

  /// Length of the selected placeholder, or 0 if none.
  int get _selectLength {
    final match = _markerRe.firstMatch(snippetTemplate);
    if (match == null) return 0;
    return match.group(1)!.length;
  }

  TextSelection get _selection => TextSelection(
        baseOffset: _cursorOffset,
        extentOffset: _cursorOffset + _selectLength,
      );

  CodeAutocompleteResult get autocomplete => CodeAutocompleteResult(
        input: '',
        word: snippet,
        selection: _selection,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// The catalog
// ─────────────────────────────────────────────────────────────────────────────

const _genuiFormSnippet = 'GenuiForm(\n'
    '  contract: Contract(fields: {«»}),\n'
    '  constraints: [],\n'
    '  posture: Posture.salesDiscovery(),\n'
    '  outcomes: Outcome(\'done\', contractDelta: Contract(fields: {})),\n'
    ')';

/// All DSL primitives, grouped by [DslGroup]. Order within each group is the
/// order the legend renders them.
final List<DslPrimitive> kDslCatalog = <DslPrimitive>[
  // ── Top-level ──────────────────────────────────────────────────────────────
  const DslPrimitive(
    name: 'GenuiForm',
    signature: 'GenuiForm({contract, constraints, posture, outcomes})',
    description: 'The DSL root. Wires a Contract, list of constraints, '
        'a Posture, and an outcome tree into a runnable form.',
    group: DslGroup.topLevel,
    snippetTemplate: _genuiFormSnippet,
  ),

  // ── Contract & fields ──────────────────────────────────────────────────────
  const DslPrimitive(
    name: 'Contract',
    signature: 'Contract({fields: { name: FieldSpec(...) }})',
    description: 'Declares the fields the form may collect.',
    group: DslGroup.contract,
    snippetTemplate: 'Contract(fields: {«»})',
  ),
  const DslPrimitive(
    name: 'FieldSpec',
    signature:
        'FieldSpec({type, required, description?, enumValues?, range?, minLength?, maxLength?})',
    description: 'A typed field. `type` is one of the field types below.',
    group: DslGroup.contract,
    snippetTemplate: 'FieldSpec(type: «String», required: true)',
  ),
  const DslPrimitive(
    name: 'NumRange',
    signature: 'NumRange(min, max)',
    description: 'Inclusive numeric range used inside FieldSpec.range.',
    group: DslGroup.contract,
    snippetTemplate: 'NumRange(«0», 100)',
  ),

  // ── Field types ────────────────────────────────────────────────────────────
  for (final t in const ['String', 'int', 'double', 'bool', 'DateTime', 'List', 'Enum'])
    DslPrimitive(
      name: t,
      signature: t,
      description: _fieldTypeDescription(t),
      group: DslGroup.fieldType,
      snippetTemplate: t,
    ),

  // ── Constraints ────────────────────────────────────────────────────────────
  const DslPrimitive(
    name: 'NeverCollect',
    signature: "NeverCollect('field-or-topic')",
    description: 'Forbid the form from ever asking about this field/topic.',
    group: DslGroup.constraints,
    snippetTemplate: "NeverCollect('«topic»')",
  ),
  const DslPrimitive(
    name: 'NeverSkip',
    signature: "NeverSkip(['fieldId', ...])",
    description: 'Field IDs that must be answered before the form may end.',
    group: DslGroup.constraints,
    snippetTemplate: "NeverSkip(['«fieldId»'])",
  ),
  const DslPrimitive(
    name: 'MaxSteps',
    signature: 'MaxSteps(n)',
    description: 'Cap the number of conversational turns.',
    group: DslGroup.constraints,
    snippetTemplate: 'MaxSteps(«8»)',
  ),
  const DslPrimitive(
    name: 'MinSteps',
    signature: 'MinSteps(n)',
    description: 'Floor on the number of conversational turns.',
    group: DslGroup.constraints,
    snippetTemplate: 'MinSteps(«3»)',
  ),
  const DslPrimitive(
    name: 'WhitelistChoices',
    signature: "WhitelistChoices('fieldId', [allowed, ...])",
    description: 'Restrict the values a field may take.',
    group: DslGroup.constraints,
    snippetTemplate: "WhitelistChoices('«fieldId»', [])",
  ),
  const DslPrimitive(
    name: 'EscalateIf',
    signature: "EscalateIf('trigger')",
    description: 'Hand off to a human when this trigger phrase matches.',
    group: DslGroup.constraints,
    snippetTemplate: "EscalateIf('«trigger»')",
  ),
  const DslPrimitive(
    name: 'StopIf',
    signature: "StopIf('trigger')",
    description: 'Terminate the form when this trigger matches.',
    group: DslGroup.constraints,
    snippetTemplate: "StopIf('«trigger»')",
  ),
  const DslPrimitive(
    name: 'RequireConsent',
    signature: "RequireConsent('topic')",
    description: 'Require explicit user consent before collecting this topic.',
    group: DslGroup.constraints,
    snippetTemplate: "RequireConsent('«topic»')",
  ),

  // ── Posture ────────────────────────────────────────────────────────────────
  const DslPrimitive(
    name: 'Posture',
    signature:
        'Posture({persistence, exploration, pacing, skipTolerance, voice})',
    description: 'Tunes the agent’s conversational style. Use a preset '
        '(Posture.salesDiscovery() …) or pass all five fields explicitly.',
    group: DslGroup.posture,
    snippetTemplate:
        "Posture(persistence: «4», exploration: 2, pacing: 3, skipTolerance: 2, voice: 'warm')",
  ),
  const DslPrimitive(
    name: 'salesDiscovery',
    signature: 'Posture.salesDiscovery()',
    description: 'Persistent, exploratory, fast-paced — for sales intake.',
    group: DslGroup.posture,
    snippetTemplate: 'salesDiscovery()',
    relatedTo: 'Posture',
  ),
  const DslPrimitive(
    name: 'supportiveOnboarding',
    signature: 'Posture.supportiveOnboarding()',
    description: 'Gentle, low-pressure — for first-time onboarding flows.',
    group: DslGroup.posture,
    snippetTemplate: 'supportiveOnboarding()',
    relatedTo: 'Posture',
  ),
  const DslPrimitive(
    name: 'clinicalIntake',
    signature: 'Posture.clinicalIntake()',
    description: 'Methodical, never skips — for medical / legal intake.',
    group: DslGroup.posture,
    snippetTemplate: 'clinicalIntake()',
    relatedTo: 'Posture',
  ),

  // ── Outcomes ───────────────────────────────────────────────────────────────
  const DslPrimitive(
    name: 'Layer',
    signature: "Layer('id', {contractDelta, next?, handoff?})",
    description: 'A linear stage that adds fields, then continues to `next`.',
    group: DslGroup.outcomes,
    snippetTemplate:
        "Layer('«id»',\n  contractDelta: Contract(fields: {}),\n  next: ,\n)",
  ),
  const DslPrimitive(
    name: 'Branch',
    signature: "Branch('id', {options: [BranchOption(...), ...]})",
    description: 'A fork. Each option carries a criterion and a child node.',
    group: DslGroup.outcomes,
    snippetTemplate: "Branch('«id»', options: [])",
  ),
  const DslPrimitive(
    name: 'BranchOption',
    signature:
        "BranchOption('id', {criterion, contractDelta?, child})",
    description:
        'One arm of a Branch. `criterion` is a natural-language matcher.',
    group: DslGroup.outcomes,
    snippetTemplate:
        "BranchOption('«id»',\n  criterion: '',\n  child: ,\n)",
  ),
  const DslPrimitive(
    name: 'Outcome',
    signature: "Outcome('id', {contractDelta, handoff?})",
    description: 'A terminal leaf. Form ends here; the optional handoff fires.',
    group: DslGroup.outcomes,
    snippetTemplate:
        "Outcome('«id»', contractDelta: Contract(fields: {}))",
  ),
  const DslPrimitive(
    name: 'Handoff',
    signature: 'Handoff({onReached: registryKey})',
    description:
        'Fires the named handoff (see Handoff keys) when the node is reached.',
    group: DslGroup.outcomes,
    snippetTemplate: 'Handoff(onReached: «bookCalendly»)',
  ),

  // ── Handoff registry keys ──────────────────────────────────────────────────
  // Generated from the same registry the parser/builder reads.
  for (final entry in kHandoffRegistry.entries)
    DslPrimitive(
      name: entry.key,
      signature: entry.key,
      description: '${entry.value.label} (icon: ${entry.value.icon})',
      group: DslGroup.handoffs,
      snippetTemplate: entry.key,
    ),
];

String _fieldTypeDescription(String t) {
  switch (t) {
    case 'String':
      return 'Free-text field.';
    case 'int':
      return 'Integer.';
    case 'double':
      return 'Floating-point number.';
    case 'bool':
      return 'true / false.';
    case 'DateTime':
      return 'ISO-8601 timestamp.';
    case 'List':
      return 'Multi-select list. Pair with enumValues to constrain.';
    case 'Enum':
      return 'Single-select. Use enumValues to declare options.';
    default:
      return '';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers consumed by the prompts builder & legend drawer.
// ─────────────────────────────────────────────────────────────────────────────

/// Catalog grouped by [DslGroup] in declaration order. Used by the legend.
Map<DslGroup, List<DslPrimitive>> get kDslCatalogByGroup {
  final out = <DslGroup, List<DslPrimitive>>{};
  for (final p in kDslCatalog) {
    out.putIfAbsent(p.group, () => <DslPrimitive>[]).add(p);
  }
  return out;
}

/// Primitives offered as bare-identifier completions (anything without a
/// [DslPrimitive.relatedTo]).
Iterable<DslPrimitive> get kDirectPrimitives =>
    kDslCatalog.where((p) => p.relatedTo == null);

/// Primitives offered after `<owner>.`, grouped by owner.
Map<String, List<DslPrimitive>> get kRelatedPrimitives {
  final out = <String, List<DslPrimitive>>{};
  for (final p in kDslCatalog) {
    final owner = p.relatedTo;
    if (owner == null) continue;
    out.putIfAbsent(owner, () => <DslPrimitive>[]).add(p);
  }
  return out;
}
