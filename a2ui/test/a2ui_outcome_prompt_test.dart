// Tests for workbench/lib/src/prompts/a2ui_outcome_prompt.dart
//
// These tests validate:
//   1. Prompt content — outcome id, handoff label, catalogId, prohibitions.
//   2. Schema shape — positive sample passes structural checks; an unknown
//      component name fails the `component` enum constraint.
//
// There is no stdlib JSON Schema validator in Dart; we inline a small helper
// that exercises the schema's structural requirements (required keys, enum
// constraints) rather than adding a new dependency.

// ignore_for_file: lines_longer_than_80_chars

import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform_a2ui/genuiform_a2ui.dart';

// ─── Inline schema validation helpers ────────────────────────────────────────

/// Checks that [value] satisfies the top-level schema produced by
/// [a2uiOutcomeJsonSchema].
///
/// Returns null on success, or a human-readable error string on failure.
/// Covers the structural constraints that matter for the bug-fix regression
/// guard: required keys, anyOf-discriminator on `component`, per-branch
/// required keys.
String? _validateSchema(
  Map<String, dynamic> schema,
  Map<String, dynamic> value,
) {
  final topRequired = (schema['required'] as List).cast<String>();
  for (final key in topRequired) {
    if (!value.containsKey(key)) {
      return 'Missing required top-level key: "$key"';
    }
  }

  final csSchema =
      schema['properties']['createSurface'] as Map<String, dynamic>;
  final csValue = value['createSurface'] as Map<String, dynamic>;
  final csRequired = (csSchema['required'] as List).cast<String>();
  for (final key in csRequired) {
    if (!csValue.containsKey(key)) {
      return 'createSurface: missing required key "$key"';
    }
  }
  final catalogIdEnum =
      (csSchema['properties']['catalogId']['enum'] as List).cast<String>();
  if (!catalogIdEnum.contains(csValue['catalogId'])) {
    return 'createSurface.catalogId "${csValue['catalogId']}" not in enum $catalogIdEnum';
  }

  final ucSchema =
      schema['properties']['updateComponents'] as Map<String, dynamic>;
  final ucValue = value['updateComponents'] as Map<String, dynamic>;
  final ucRequired = (ucSchema['required'] as List).cast<String>();
  for (final key in ucRequired) {
    if (!ucValue.containsKey(key)) {
      return 'updateComponents: missing required key "$key"';
    }
  }

  // components array — items use anyOf discriminated by `component`.
  final itemSchema =
      ucSchema['properties']['components']['items'] as Map<String, dynamic>;
  final branches = (itemSchema['anyOf'] as List).cast<Map<String, dynamic>>();

  final components = (ucValue['components'] as List).cast<Map<String, dynamic>>();
  for (var i = 0; i < components.length; i++) {
    final item = components[i];
    final componentType = item['component'] as String?;
    if (componentType == null) {
      return 'components[$i]: missing required key "component"';
    }
    final match = branches.where((b) {
      final names =
          ((b['properties'] as Map)['component']['enum'] as List).cast<String>();
      return names.contains(componentType);
    }).firstOrNull;
    if (match == null) {
      final allowed = branches
          .map((b) =>
              ((b['properties'] as Map)['component']['enum'] as List).first)
          .toList();
      return 'components[$i].component "$componentType" matches no anyOf branch (allowed: $allowed)';
    }
    final branchRequired = (match['required'] as List).cast<String>();
    for (final key in branchRequired) {
      if (!item.containsKey(key)) {
        return 'components[$i] (component=$componentType): missing required key "$key"';
      }
    }
  }

  return null; // valid
}

/// Recursively walks a JSON Schema map and yields every property descriptor
/// (any sub-map with a `type` key). Used by regression tests that assert
/// no unbounded numerics survive.
Iterable<Map<String, dynamic>> _allTypedNodes(Object? node) sync* {
  if (node is Map<String, dynamic>) {
    if (node.containsKey('type')) yield node;
    for (final v in node.values) {
      yield* _allTypedNodes(v);
    }
  } else if (node is List) {
    for (final v in node) {
      yield* _allTypedNodes(v);
    }
  }
}

// ─── Test data ───────────────────────────────────────────────────────────────

/// A well-formed positive sample: Column + Text + Button (matching the
/// example in the prompt).
Map<String, dynamic> _positiveSample() => {
      'createSurface': {
        'surfaceId': kA2uiOutcomeSurfaceId,
        'catalogId': kA2uiBasicCatalogId,
        'sendDataModel': false,
      },
      'updateComponents': {
        'surfaceId': kA2uiOutcomeSurfaceId,
        'components': [
          {
            'id': 'root',
            'component': 'Column',
            'justify': 'center',
            'align': 'center',
            'children': ['headline', 'restart_btn'],
          },
          {
            'id': 'headline',
            'component': 'Text',
            'text': 'Book a call',
            'variant': 'h2',
          },
          {
            'id': 'restart_label',
            'component': 'Text',
            'text': 'Restart form',
          },
          {
            'id': 'restart_btn',
            'component': 'Button',
            'child': 'restart_label',
            'variant': 'primary',
            'action': {
              'event': {'name': 'genuiform/restart'},
            },
          },
        ],
      },
    };

/// A negative sample: one component has an unknown type not in the catalog.
Map<String, dynamic> _negativeSampleUnknownComponent() => {
      'createSurface': {
        'surfaceId': kA2uiOutcomeSurfaceId,
        'catalogId': kA2uiBasicCatalogId,
      },
      'updateComponents': {
        'surfaceId': kA2uiOutcomeSurfaceId,
        'components': [
          {
            'id': 'root',
            'component': 'MagicWidget', // not in the catalog
            'children': ['text1'],
          },
          {
            'id': 'text1',
            'component': 'Text',
            'text': 'Hello',
          },
        ],
      },
    };

/// A negative sample: missing the required `updateComponents` top-level key.
Map<String, dynamic> _negativeSampleMissingKey() => {
      'createSurface': {
        'surfaceId': kA2uiOutcomeSurfaceId,
        'catalogId': kA2uiBasicCatalogId,
      },
      // 'updateComponents' intentionally absent
    };

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('buildA2uiOutcomePrompt', () {
    test('contains the outcome id', () {
      final prompt = buildA2uiOutcomePrompt(
        outcomeId: 'book_call',
        handoff: null,
        summary: 'Some summary.',
      );
      expect(prompt, contains('book_call'));
    });

    test('contains the handoff label when a handoff is provided', () {
      const handoff = SimulatedHandoff(label: 'Book a call', icon: 'calendar');
      final prompt = buildA2uiOutcomePrompt(
        outcomeId: 'book_call',
        handoff: handoff,
        summary: 'Qualified lead.',
      );
      expect(prompt, contains('Book a call'));
      expect(prompt, contains('book_call'));
    });

    test('does not mention a label when handoff is null', () {
      final prompt = buildA2uiOutcomePrompt(
        outcomeId: 'generic_outcome',
        handoff: null,
        summary: 'No handoff registered.',
      );
      // Should still contain the outcomeId
      expect(prompt, contains('generic_outcome'));
      // Should not contain a label from the registry
      expect(prompt, isNot(contains('Book a call')));
    });

    test('contains the basicCatalogId', () {
      final prompt = buildA2uiOutcomePrompt(
        outcomeId: 'any',
        handoff: null,
        summary: '',
      );
      expect(prompt, contains(kA2uiBasicCatalogId));
    });

    test('contains the surfaceId constant', () {
      final prompt = buildA2uiOutcomePrompt(
        outcomeId: 'any',
        handoff: null,
        summary: '',
      );
      expect(prompt, contains(kA2uiOutcomeSurfaceId));
    });

    test('explicitly forbids string interpolation', () {
      final prompt = buildA2uiOutcomePrompt(
        outcomeId: 'any',
        handoff: null,
        summary: '',
      );
      // The prompt must contain a hard prohibition about interpolation.
      expect(prompt.toLowerCase(), contains('interpolation'));
    });

    test('explicitly forbids conditionals', () {
      final prompt = buildA2uiOutcomePrompt(
        outcomeId: 'any',
        handoff: null,
        summary: '',
      );
      expect(prompt.toLowerCase(), contains('conditional'));
    });

    test('explicitly forbids deviation from the v0.9 message shape', () {
      final prompt = buildA2uiOutcomePrompt(
        outcomeId: 'any',
        handoff: null,
        summary: '',
      );
      // The prompt must mention v0.9 to anchor its constraint.
      expect(prompt, contains('v0.9'));
    });

    test('specifies that the root component must have id "root"', () {
      final prompt = buildA2uiOutcomePrompt(
        outcomeId: 'any',
        handoff: null,
        summary: '',
      );
      expect(prompt, contains('"root"'));
    });

    test('specifies the restart_btn action as genuiform/restart', () {
      final prompt = buildA2uiOutcomePrompt(
        outcomeId: 'any',
        handoff: null,
        summary: '',
      );
      expect(prompt, contains('restart_btn'));
      expect(prompt, contains('genuiform/restart'));
    });

    test('includes the session summary in the prompt', () {
      final prompt = buildA2uiOutcomePrompt(
        outcomeId: 'any',
        handoff: null,
        summary: 'Senior CTO with immediate timeline.',
      );
      expect(prompt, contains('Senior CTO with immediate timeline.'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Schema tests
  // ─────────────────────────────────────────────────────────────────────────

  group('a2uiOutcomeJsonSchema', () {
    late Map<String, dynamic> schema;

    setUp(() {
      schema = a2uiOutcomeJsonSchema();
    });

    test('schema has type object', () {
      expect(schema['type'], equals('object'));
    });

    test('schema requires createSurface and updateComponents', () {
      final required = (schema['required'] as List).cast<String>();
      expect(required, containsAll(['createSurface', 'updateComponents']));
    });

    test('createSurface catalogId enum contains the basicCatalogId', () {
      final catalogIdSchema = schema['properties']['createSurface']['properties']
          ['catalogId'] as Map<String, dynamic>;
      final enumValues = (catalogIdSchema['enum'] as List).cast<String>();
      expect(enumValues, contains(kA2uiBasicCatalogId));
    });

    test('components items use anyOf discriminated by component', () {
      final itemSchema = schema['properties']['updateComponents']['properties']
          ['components']['items'] as Map<String, dynamic>;
      expect(itemSchema, contains('anyOf'));
      final branches = (itemSchema['anyOf'] as List).cast<Map<String, dynamic>>();
      expect(branches, isNotEmpty);
      for (final b in branches) {
        final required = (b['required'] as List).cast<String>();
        expect(required, containsAll(['id', 'component']));
      }
    });

    test('anyOf branches cover Column, Row, Text, Button, Icon, Card, Divider',
        () {
      final itemSchema = schema['properties']['updateComponents']['properties']
          ['components']['items'] as Map<String, dynamic>;
      final branches = (itemSchema['anyOf'] as List).cast<Map<String, dynamic>>();
      final names = branches
          .map((b) =>
              ((b['properties'] as Map)['component']['enum'] as List).first
                  as String)
          .toSet();
      expect(
        names,
        containsAll(['Column', 'Row', 'Text', 'Button', 'Icon', 'Card', 'Divider']),
      );
      // Image and List were schema-only in the legacy schema and forbidden
      // in the prompt — they must NOT survive the migration.
      expect(names, isNot(contains('Image')));
      expect(names, isNot(contains('List')));
    });

    test('positive sample (Column + Text + Button) passes schema validation', () {
      final error = _validateSchema(schema, _positiveSample());
      expect(error, isNull, reason: 'Expected no error, got: $error');
    });

    test('negative sample with unknown component name fails schema validation',
        () {
      final error = _validateSchema(schema, _negativeSampleUnknownComponent());
      expect(error, isNotNull);
      expect(error, contains('MagicWidget'));
    });

    test('negative sample missing updateComponents key fails validation', () {
      final error = _validateSchema(schema, _negativeSampleMissingKey());
      expect(error, isNotNull);
      expect(error, contains('updateComponents'));
    });

    test('schema returns a new map instance on each call', () {
      final s1 = a2uiOutcomeJsonSchema();
      final s2 = a2uiOutcomeJsonSchema();
      expect(identical(s1, s2), isFalse);
    });

    // ── Regression guards for the gemini "infinite digit loop" bug ─────────

    test('contains no unbounded number/integer types', () {
      // Bug: Gemini's structured-output sampler enters an infinite digit loop
      // on `{type: number}` properties without min/max bounds. Reproduced on
      // gemini-2.5-flash and gemini-3-flash-preview, both locking on a
      // `weight: 1000000…` token. The fix is to remove every unbounded
      // numeric slot from the response schema; this test is the regression
      // guard that future edits don't reintroduce one.
      for (final node in _allTypedNodes(schema)) {
        final type = node['type'];
        if (type == 'number' || type == 'integer') {
          final hasBounds = node.containsKey('minimum') ||
              node.containsKey('maximum') ||
              node.containsKey('enum');
          expect(
            hasBounds,
            isTrue,
            reason: 'Found unbounded $type slot: $node — Gemini is known to '
                'lock into an infinite digit loop on these.',
          );
        }
      }
    });

    test('uses only keywords supported by Gemini responseJsonSchema', () {
      // Source: python-genai SDK, google/genai/types.py
      // (GenerateContentConfig.response_json_schema docstring). Anything
      // outside this allow-list triggers HTTP 400 INVALID_ARGUMENT from
      // Gemini with no field-level detail — historically `maxLength` (which
      // is widely supported in JSON Schema generally) tripped the entire
      // request. New keywords must be added here only after confirming the
      // SDK source still lists them as supported.
      const supported = {
        // Identity / referencing
        r'$id', r'$defs', r'$ref', r'$anchor',
        // Type / docs
        'type', 'format', 'title', 'description',
        // Enum (strings + numbers ONLY, never booleans)
        'enum',
        // Arrays
        'items', 'prefixItems', 'minItems', 'maxItems',
        // Numbers
        'minimum', 'maximum',
        // Composition
        'anyOf', 'oneOf',
        // Objects
        'properties', 'additionalProperties', 'required',
        // Non-standard but documented
        'propertyOrdering',
      };

      void walk(Object? node, String path) {
        if (node is Map<String, dynamic>) {
          for (final key in node.keys) {
            // Keys inside `properties: {...}` are user-defined property
            // names, not schema keywords — skip them.
            final isUnderProperties = path.endsWith('.properties');
            if (!isUnderProperties && !supported.contains(key)) {
              fail(
                'Unsupported responseJsonSchema keyword "$key" at $path. '
                'See google/genai/types.py for the supported set.',
              );
            }
            walk(node[key], '$path.$key');
          }
        } else if (node is List) {
          for (var i = 0; i < node.length; i++) {
            walk(node[i], '$path[$i]');
          }
        }
      }

      walk(schema, r'$');
    });

    test('every object level closes additionalProperties', () {
      // Without `additionalProperties: false` the model can invent fields,
      // which is the second amplifier of the infinite-digit-loop bug (a
      // hallucinated property gets a free pass through the validator).
      for (final node in _allTypedNodes(schema)) {
        if (node['type'] == 'object') {
          expect(
            node['additionalProperties'],
            isFalse,
            reason: 'Object schema is open-world — model can invent fields: $node',
          );
        }
      }
    });
  });
}
