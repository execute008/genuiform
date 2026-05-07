// ignore_for_file: lines_longer_than_80_chars

import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/genuiform.dart';

import 'package:genuiform_workbench/src/parser/lexer.dart';
import 'package:genuiform_workbench/src/parser/parse_dsl.dart';
import 'package:genuiform_workbench/src/parser/parse_error.dart';
import 'package:genuiform_workbench/src/scenarios/scenario_strings.dart';

void main() {
  // ───────────────────────────────────────────────────────────────────────────
  // 1. Lexer tests
  // ───────────────────────────────────────────────────────────────────────────

  group('Lexer', () {
    test('tokenizes simple punctuation', () {
      final tokens = Lexer('( ) { } [ ] , : . =').tokenize();
      final kinds = tokens.map((t) => t.kind).toList();
      expect(
        kinds,
        containsAllInOrder([
          TokenKind.lParen,
          TokenKind.rParen,
          TokenKind.lBrace,
          TokenKind.rBrace,
          TokenKind.lBrack,
          TokenKind.rBrack,
          TokenKind.comma,
          TokenKind.colon,
          TokenKind.dot,
          TokenKind.equals,
          TokenKind.eof,
        ]),
      );
    });

    test('strips single-line comments', () {
      final tokens = Lexer('foo // this is a comment\nbar').tokenize();
      expect(tokens.where((t) => t.kind != TokenKind.eof).map((t) => t.value).toList(), ['foo', 'bar']);
    });

    test('strips block comments', () {
      final tokens = Lexer('foo /* block comment */ bar').tokenize();
      expect(tokens.where((t) => t.kind != TokenKind.eof).map((t) => t.value).toList(), ['foo', 'bar']);
    });

    test('throws on unterminated block comment', () {
      expect(
        () => Lexer('foo /* unterminated').tokenize(),
        throwsA(isA<ParseError>().having((e) => e.message, 'message', contains('Unterminated block comment'))),
      );
    });

    test('throws on unterminated string literal', () {
      expect(
        () => Lexer("'unterminated").tokenize(),
        throwsA(isA<ParseError>().having((e) => e.message, 'message', contains('Unterminated string literal'))),
      );
    });

    test('throws on string interpolation', () {
      // The DSL string 'hello ${name}' contains a bare interpolation sequence.
      // We build the test string at runtime to keep the Dart source literal
      // free of actual interpolation syntax.
      final dslWithInterpolation = "'hello \${name}'";
      expect(
        () => Lexer(dslWithInterpolation).tokenize(),
        throwsA(
          isA<ParseError>().having(
            (e) => e.message,
            'message',
            contains("DSL doesn't support string interpolation"),
          ),
        ),
      );
    });

    test('lexes bool tokens', () {
      final tokens = Lexer('true false').tokenize();
      expect(tokens[0].kind, TokenKind.bool_);
      expect(tokens[0].value, 'true');
      expect(tokens[1].kind, TokenKind.bool_);
      expect(tokens[1].value, 'false');
    });

    test('lexes integer and double numbers', () {
      final tokens = Lexer('42 3.14').tokenize();
      expect(tokens[0].kind, TokenKind.number);
      expect(tokens[0].value, '42');
      expect(tokens[1].kind, TokenKind.number);
      expect(tokens[1].value, '3.14');
    });

    test('tracks line and column numbers', () {
      final tokens = Lexer('foo\nbar').tokenize();
      expect(tokens[0].line, 1);
      expect(tokens[0].column, 1);
      expect(tokens[1].line, 2);
      expect(tokens[1].column, 1);
    });

    test('lexes double-quoted and single-quoted strings', () {
      final tokens = Lexer('"hello" \'world\'').tokenize();
      expect(tokens[0].kind, TokenKind.string);
      expect(tokens[0].value, 'hello');
      expect(tokens[1].kind, TokenKind.string);
      expect(tokens[1].value, 'world');
    });

    test('handles standard escape sequences in strings', () {
      final tokens = Lexer(r"'line\nnewline\ttab\\backslash'").tokenize();
      expect(tokens[0].value, 'line\nnewline\ttab\\backslash');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 2. Parser error tests
  // ───────────────────────────────────────────────────────────────────────────

  group('Parser errors', () {
    ParseError firstError(String source) {
      final result = parseDsl(source);
      expect(result.errors, isNotEmpty, reason: 'Expected at least one error');
      return result.errors.first;
    }

    test('missing all required args produces error mentioning contract', () {
      final err = firstError('final form = GenuiForm();');
      expect(err.message, contains('contract'));
    });

    test("unexpected token 'if' produces a helpful message", () {
      final err = firstError('''
final form = GenuiForm(
  contract: Contract(fields: {}),
  constraints: [if (true) MaxSteps(5)],
  posture: Posture.salesDiscovery(),
  outcomes: Outcome('done', contractDelta: Contract(fields: {}), handoff: Handoff(onReached: politeDecline)),
);
''');
      expect(err.message, contains('if'));
    });

    test('Layer without id produces descriptive error', () {
      final err = firstError('''
final form = GenuiForm(
  contract: Contract(fields: {}),
  constraints: [],
  posture: Posture.salesDiscovery(),
  outcomes: Layer(contractDelta: Contract(fields: {})),
);
''');
      expect(err.message, contains('Layer'));
    });

    test('Branch without options produces error', () {
      final err = firstError('''
final form = GenuiForm(
  contract: Contract(fields: {}),
  constraints: [],
  posture: Posture.salesDiscovery(),
  outcomes: Branch('split'),
);
''');
      expect(err.message, contains('options'));
    });

    test('MaxSteps with string argument produces type error', () {
      final err = firstError('''
final form = GenuiForm(
  contract: Contract(fields: {}),
  constraints: [MaxSteps('not-a-number')],
  posture: Posture.salesDiscovery(),
  outcomes: Outcome('done', contractDelta: Contract(fields: {}), handoff: Handoff(onReached: politeDecline)),
);
''');
      expect(err.message, contains('MaxSteps'));
    });

    test('Unknown Posture preset produces error', () {
      final err = firstError('''
final form = GenuiForm(
  contract: Contract(fields: {}),
  constraints: [],
  posture: Posture.unknownPreset(),
  outcomes: Outcome('done', contractDelta: Contract(fields: {}), handoff: Handoff(onReached: politeDecline)),
);
''');
      expect(err.message, contains('unknownPreset'));
    });

    test('Unknown handoff key produces error from builder', () {
      final result = parseDsl('''
final form = GenuiForm(
  contract: Contract(fields: {}),
  constraints: [],
  posture: Posture.salesDiscovery(),
  outcomes: Outcome('done',
    contractDelta: Contract(fields: {}),
    handoff: Handoff(onReached: bookFoo),
  ),
);
''');
      expect(result.errors, isNotEmpty);
      expect(result.errors.first.message, contains('bookFoo'));
    });

    test('Unsupported FieldSpec type produces error', () {
      final err = firstError('''
final form = GenuiForm(
  contract: Contract(fields: {
    'x': FieldSpec(type: Symbol, required: true),
  }),
  constraints: [],
  posture: Posture.salesDiscovery(),
  outcomes: Outcome('done', contractDelta: Contract(fields: {}), handoff: Handoff(onReached: politeDecline)),
);
''');
      expect(err.message, contains('Symbol'));
    });

    test('Unknown constraint name produces helpful error', () {
      final err = firstError('''
final form = GenuiForm(
  contract: Contract(fields: {}),
  constraints: [BannedWords('foo')],
  posture: Posture.salesDiscovery(),
  outcomes: Outcome('done', contractDelta: Contract(fields: {}), handoff: Handoff(onReached: politeDecline)),
);
''');
      expect(err.message, contains('BannedWords'));
      expect(err.hint, isNotNull);
    });

    test('ParseError.toString includes line number', () {
      final err = ParseError(line: 12, column: 5, message: 'test error');
      expect(err.toString(), contains('Line 12'));
      expect(err.toString(), contains('test error'));
    });

    test('ParseError.toFormatted includes line and column', () {
      final err = ParseError(line: 7, column: 3, message: 'oops', hint: 'try this');
      final formatted = err.toFormatted();
      expect(formatted, contains('Line 7'));
      expect(formatted, contains('col 3'));
      expect(formatted, contains('Hint: try this'));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 3. Sugar tests (trailing commas, comments, posture presets)
  // ───────────────────────────────────────────────────────────────────────────

  group('DSL sugar', () {
    const minimal = '''
final form = GenuiForm(
  contract: Contract(fields: {
    'name': FieldSpec(type: String, required: true,),
  },),
  constraints: [MaxSteps(5),],
  posture: Posture.salesDiscovery(),
  outcomes: Outcome('done',
    contractDelta: Contract(fields: {}),
    handoff: Handoff(onReached: politeDecline),
  ),
);
''';

    test('trailing commas everywhere parse without error', () {
      final result = parseDsl(minimal);
      expect(result.errors, isEmpty);
      expect(result.hasForm, isTrue);
    });

    test('block and line comments are ignored', () {
      final result = parseDsl('''
// top-level comment
/* block comment */
final form = GenuiForm(
  // contract comment
  contract: Contract(fields: {/* empty */}),
  constraints: [/* no constraints */],
  posture: Posture.salesDiscovery(), // inline comment
  outcomes: Outcome('done',
    contractDelta: Contract(fields: {}),
    handoff: Handoff(onReached: politeDecline),
  ),
);
''');
      expect(result.errors, isEmpty);
      expect(result.hasForm, isTrue);
    });

    test('Posture.salesDiscovery() preset resolves correctly', () {
      final result = parseDsl(minimal.replaceAll('salesDiscovery', 'salesDiscovery'));
      expect(result.errors, isEmpty);
      final posture = result.posture;
      expect(posture?.persistence, 4);
      expect(posture?.exploration, 2);
    });

    test('Posture.supportiveOnboarding() resolves correctly', () {
      final result = parseDsl(minimal.replaceAll('salesDiscovery', 'supportiveOnboarding'));
      expect(result.errors, isEmpty);
      final posture = result.posture;
      expect(posture?.persistence, 2);
      expect(posture?.skipTolerance, 4);
    });

    test('Posture.clinicalIntake() resolves correctly', () {
      final result = parseDsl(minimal.replaceAll('salesDiscovery', 'clinicalIntake'));
      expect(result.errors, isEmpty);
      final posture = result.posture;
      expect(posture?.persistence, 5);
      expect(posture?.pacing, 2);
    });

    test('Posture literal parses all knobs correctly', () {
      final result = parseDsl(r'''
final form = GenuiForm(
  contract: Contract(fields: {}),
  constraints: [],
  posture: Posture(
    persistence: 3,
    exploration: 2,
    pacing: 4,
    skipTolerance: 1,
    voice: 'Friendly and direct.',
  ),
  outcomes: Outcome('done',
    contractDelta: Contract(fields: {}),
    handoff: Handoff(onReached: politeDecline),
  ),
);
''');
      expect(result.errors, isEmpty);
      final posture = result.posture;
      expect(posture?.persistence, 3);
      expect(posture?.exploration, 2);
      expect(posture?.pacing, 4);
      expect(posture?.skipTolerance, 1);
      expect(posture?.voice, 'Friendly and direct.');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 4. Round-trip tests — all four scenarios
  // ───────────────────────────────────────────────────────────────────────────

  group('Round-trip: lead_qualification', () {
    late ParseResult result;

    setUpAll(() {
      result = parseDsl(kLeadQualificationDsl);
    });

    test('parses without errors', () {
      expect(result.errors, isEmpty);
      expect(result.hasForm, isTrue);
    });

    test('has 6 contract fields', () {
      final fields = result.contract!.fields;
      expect(fields.keys, containsAll(['name', 'company', 'pain_point', 'timeline', 'budget_eur', 'role']));
      expect(fields.length, 6);
    });

    test('has 4 constraints', () {
      expect(result.constraints!.length, 4);
    });

    test('constraint types are correct', () {
      final c = result.constraints!;
      expect(c[0], isA<NeverCollect>());
      expect(c[1], isA<NeverCollect>());
      expect(c[2], isA<MaxSteps>());
      expect(c[3], isA<EscalateIf>());
    });

    test('NeverCollect fields are correct', () {
      final c0 = result.constraints![0] as NeverCollect;
      final c1 = result.constraints![1] as NeverCollect;
      expect(c0.fieldOrTopic, 'payment_info');
      expect(c1.fieldOrTopic, 'personal_id_numbers');
    });

    test('MaxSteps value is 8', () {
      final maxSteps = result.constraints![2] as MaxSteps;
      expect(maxSteps.value, 8);
    });

    test('EscalateIf trigger is correct', () {
      final escalate = result.constraints![3] as EscalateIf;
      expect(escalate.trigger, 'legal threats or hostile language');
    });

    test('posture is salesDiscovery', () {
      expect(result.posture!, Posture.salesDiscovery());
    });

    test('outcomes is a Branch with 3 options', () {
      final outcomes = result.outcomes;
      expect(outcomes, isA<Branch>());
      final branch = outcomes as Branch;
      expect(branch.id, 'lead_split');
      expect(branch.options.length, 3);
    });

    test('branch option ids are correct', () {
      final options = (result.outcomes! as Branch).options;
      expect(options.map((o) => o.id).toList(), ['book_call', 'send_proposal', 'decline']);
    });

    test('each branch child is an Outcome', () {
      final options = (result.outcomes! as Branch).options;
      for (final opt in options) {
        expect(opt.child, isA<Outcome>());
      }
    });

    test('required fields have correct types', () {
      final fields = result.contract!.fields;
      expect(fields['name']!.type, 'String');
      expect(fields['name']!.required, true);
      expect(fields['budget_eur']!.type, 'int');
      expect(fields['budget_eur']!.required, false);
    });

    test('timeline field has enumValues', () {
      final timeline = result.contract!.fields['timeline']!;
      expect(timeline.enumValues, ['immediate', '1-3 months', '3-6 months', '6+']);
    });
  });

  group('Round-trip: gymgeist_onboarding', () {
    late ParseResult result;

    setUpAll(() {
      result = parseDsl(kGymgeistOnboardingDsl);
    });

    test('parses without errors', () {
      expect(result.errors, isEmpty);
      expect(result.hasForm, isTrue);
    });

    test('root contract has 2 fields (email, name)', () {
      final fields = result.contract!.fields;
      expect(fields.keys, containsAll(['email', 'name']));
      expect(fields.length, 2);
    });

    test('has 4 constraints', () {
      expect(result.constraints!.length, 4);
    });

    test('has NeverSkip, MaxSteps, StopIf, EscalateIf constraints', () {
      final c = result.constraints!;
      expect(c[0], isA<NeverSkip>());
      expect(c[1], isA<MaxSteps>());
      expect(c[2], isA<StopIf>());
      expect(c[3], isA<EscalateIf>());
    });

    test('NeverSkip fieldIds are correct', () {
      final ns = result.constraints![0] as NeverSkip;
      expect(ns.fieldIds, containsAll(['height_cm', 'weight_kg']));
    });

    test('MaxSteps value is 10', () {
      final ms = result.constraints![1] as MaxSteps;
      expect(ms.value, 10);
    });

    test('posture is supportiveOnboarding', () {
      expect(result.posture!, Posture.supportiveOnboarding());
    });

    test('outcomes is a Layer ladder', () {
      expect(result.outcomes, isA<Layer>());
      final layer1 = result.outcomes! as Layer;
      expect(layer1.id, 'account_only');
      expect(layer1.next, isA<Layer>());

      final layer2 = layer1.next as Layer;
      expect(layer2.id, 'with_workout_plan');
      expect(layer2.next, isA<Branch>());

      final branch = layer2.next as Branch;
      expect(branch.id, 'nutrition_path');
      expect(branch.options.length, 2);
    });

    test('nutrition branch option ids are correct', () {
      final layer1 = result.outcomes! as Layer;
      final layer2 = layer1.next as Layer;
      final branch = layer2.next as Branch;
      expect(branch.options.map((o) => o.id).toList(), ['with_meal_plan', 'skip_nutrition']);
    });
  });

  group('Round-trip: newsletter_signup', () {
    late ParseResult result;

    setUpAll(() {
      result = parseDsl(kNewsletterSignupDsl);
    });

    test('parses without errors', () {
      expect(result.errors, isEmpty);
      expect(result.hasForm, isTrue);
    });

    test('has 2 contract fields', () {
      expect(result.contract!.fields.length, 2);
    });

    test('has 1 constraint (MaxSteps(3))', () {
      expect(result.constraints!.length, 1);
      final ms = result.constraints![0] as MaxSteps;
      expect(ms.value, 3);
    });

    test('posture is a literal with persistence=1', () {
      expect(result.posture!.persistence, 1);
      expect(result.posture!.skipTolerance, 5);
    });

    test('outcomes is a single Outcome', () {
      expect(result.outcomes, isA<Outcome>());
      final outcome = result.outcomes! as Outcome;
      expect(outcome.id, 'subscribed');
    });

    test('frequency_preference has enumValues', () {
      final field = result.contract!.fields['frequency_preference']!;
      expect(field.enumValues, ['daily', 'weekly', 'monthly']);
    });
  });

  group('Round-trip: medical_intake', () {
    late ParseResult result;

    setUpAll(() {
      result = parseDsl(kMedicalIntakeDsl);
    });

    test('parses without errors', () {
      expect(result.errors, isEmpty);
      expect(result.hasForm, isTrue);
    });

    test('has 6 contract fields', () {
      expect(result.contract!.fields.length, 6);
    });

    test('has 4 constraints', () {
      expect(result.constraints!.length, 4);
    });

    test('has RequireConsent, EscalateIf, StopIf, MaxSteps', () {
      final c = result.constraints!;
      expect(c[0], isA<RequireConsent>());
      expect(c[1], isA<EscalateIf>());
      expect(c[2], isA<StopIf>());
      expect(c[3], isA<MaxSteps>());
    });

    test('RequireConsent topic is correct', () {
      final rc = result.constraints![0] as RequireConsent;
      expect(rc.topic, 'medical_history_collection');
    });

    test('EscalateIf trigger is self-harm', () {
      final ei = result.constraints![1] as EscalateIf;
      expect(ei.trigger, 'mentions of self-harm');
    });

    test('StopIf trigger is consent revocation', () {
      final si = result.constraints![2] as StopIf;
      expect(si.trigger, 'user revokes consent');
    });

    test('MaxSteps is 12', () {
      final ms = result.constraints![3] as MaxSteps;
      expect(ms.value, 12);
    });

    test('posture is clinicalIntake', () {
      expect(result.posture!, Posture.clinicalIntake());
    });

    test('outcomes is a single Outcome', () {
      expect(result.outcomes, isA<Outcome>());
    });

    test('severity field has NumRange(1, 10)', () {
      final severity = result.contract!.fields['severity']!;
      expect(severity.range?.min, 1);
      expect(severity.range?.max, 10);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // 5. The existing DSL string from lead_qualification_dsl.dart
  // ───────────────────────────────────────────────────────────────────────────

  group('Existing DSL string compatibility', () {
    test('leadQualificationDsl (from lead_qualification_dsl.dart) parses cleanly', () {
      final result = parseDsl(leadQualificationDsl);
      expect(result.errors, isEmpty);
      expect(result.hasForm, isTrue);
      expect(result.contract!.fields.length, 6);
      expect(result.constraints!.length, 4);
    });
  });
}
