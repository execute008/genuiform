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
/// [a2uiOutcomeResponseSchema].
///
/// Returns null on success, or a human-readable error string on failure.
/// This is not a full JSON Schema validator — it covers the constraints that
/// matter for Phase 1: required keys, enum on `catalogId`, required keys in
/// `components` items, and the `component` enum.
String? _validateSchema(
  Map<String, dynamic> schema,
  Map<String, dynamic> value,
) {
  // Top-level required keys
  final topRequired = (schema['required'] as List).cast<String>();
  for (final key in topRequired) {
    if (!value.containsKey(key)) {
      return 'Missing required top-level key: "$key"';
    }
  }

  // createSurface sub-object
  final csSchema =
      schema['properties']['createSurface'] as Map<String, dynamic>;
  final csValue = value['createSurface'] as Map<String, dynamic>;
  final csRequired = (csSchema['required'] as List).cast<String>();
  for (final key in csRequired) {
    if (!csValue.containsKey(key)) {
      return 'createSurface: missing required key "$key"';
    }
  }
  // catalogId enum
  final catalogIdEnum =
      (csSchema['properties']['catalogId']['enum'] as List).cast<String>();
  if (!catalogIdEnum.contains(csValue['catalogId'])) {
    return 'createSurface.catalogId "${csValue['catalogId']}" not in enum $catalogIdEnum';
  }

  // updateComponents sub-object
  final ucSchema =
      schema['properties']['updateComponents'] as Map<String, dynamic>;
  final ucValue = value['updateComponents'] as Map<String, dynamic>;
  final ucRequired = (ucSchema['required'] as List).cast<String>();
  for (final key in ucRequired) {
    if (!ucValue.containsKey(key)) {
      return 'updateComponents: missing required key "$key"';
    }
  }

  // components array items
  final itemSchema =
      ucSchema['properties']['components']['items'] as Map<String, dynamic>;
  final itemRequired = (itemSchema['required'] as List).cast<String>();
  final componentEnum =
      (itemSchema['properties']['component']['enum'] as List).cast<String>();

  final components = (ucValue['components'] as List).cast<Map<String, dynamic>>();
  for (var i = 0; i < components.length; i++) {
    final item = components[i];
    for (final key in itemRequired) {
      if (!item.containsKey(key)) {
        return 'components[$i]: missing required key "$key"';
      }
    }
    final componentType = item['component'] as String;
    if (!componentEnum.contains(componentType)) {
      return 'components[$i].component "$componentType" not in allowed enum $componentEnum';
    }
  }

  return null; // valid
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

  group('a2uiOutcomeResponseSchema', () {
    late Map<String, dynamic> schema;

    setUp(() {
      schema = a2uiOutcomeResponseSchema();
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

    test('components items require id and component', () {
      final itemSchema = schema['properties']['updateComponents']['properties']
          ['components']['items'] as Map<String, dynamic>;
      final required = (itemSchema['required'] as List).cast<String>();
      expect(required, containsAll(['id', 'component']));
    });

    test('component enum includes Column, Text, Button', () {
      final itemSchema = schema['properties']['updateComponents']['properties']
          ['components']['items'] as Map<String, dynamic>;
      final componentEnum =
          (itemSchema['properties']['component']['enum'] as List).cast<String>();
      expect(componentEnum, containsAll(['Column', 'Text', 'Button']));
    });

    test('positive sample (Column + Text + Button) passes schema validation', () {
      final error = _validateSchema(schema, _positiveSample());
      expect(error, isNull, reason: 'Expected no error, got: $error');
    });

    test(
        'negative sample with unknown component name fails schema validation',
        () {
      final error =
          _validateSchema(schema, _negativeSampleUnknownComponent());
      expect(
        error,
        isNotNull,
        reason: 'Expected a validation error for unknown component type',
      );
      expect(error, contains('MagicWidget'));
    });

    test('negative sample missing updateComponents key fails validation', () {
      final error = _validateSchema(schema, _negativeSampleMissingKey());
      expect(error, isNotNull);
      expect(error, contains('updateComponents'));
    });

    test('schema returns a new map instance on each call', () {
      final s1 = a2uiOutcomeResponseSchema();
      final s2 = a2uiOutcomeResponseSchema();
      expect(identical(s1, s2), isFalse);
    });
  });
}
