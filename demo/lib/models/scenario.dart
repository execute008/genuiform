import 'field_spec.dart';

enum FormPosture { reassuring, confident, casual }

class Scenario {
  final String key;
  final String label;
  final String formName;
  final FormPosture posture;
  final List<FieldSpec> fields;
  final List<String> paths;

  const Scenario({
    required this.key,
    required this.label,
    required this.formName,
    required this.posture,
    required this.fields,
    required this.paths,
  });
}

class ScenarioLibrary {
  static const medical = Scenario(
    key: 'medical',
    label: 'Medical intake',
    formName: 'Medical intake',
    posture: FormPosture.reassuring,
    fields: [
      FieldSpec(
        key: 'symptoms',
        type: 'String',
        required: true,
        input: FieldInputStyle.outlined,
        label: "What's going on today?",
        hint: 'A short description is enough — your clinician will follow up.',
      ),
      FieldSpec(
        key: 'duration',
        type: 'String',
        required: true,
        input: FieldInputStyle.outlined,
        label: 'How long has this been happening?',
      ),
      FieldSpec(
        key: 'severity',
        type: 'int',
        required: true,
        range: NumRange(1, 10),
        input: FieldInputStyle.slider,
        label: 'On a scale of 1–10, how bad does it feel?',
        hint: "1 = barely noticeable · 10 = the worst you've felt",
      ),
      FieldSpec(
        key: 'medications',
        type: 'List',
        required: false,
        input: FieldInputStyle.tonalCard,
        label: "Any medications you're currently taking?",
        hint: 'Optional — include over-the-counter and supplements.',
      ),
      FieldSpec(
        key: 'allergies',
        type: 'List',
        required: false,
        input: FieldInputStyle.choiceChips,
        label: 'Known allergies',
        hint: 'Tap any that apply.',
        options: ['Penicillin', 'Latex', 'Peanuts', 'Shellfish', 'None'],
      ),
      FieldSpec(
        key: 'consent_given',
        type: 'bool',
        required: true,
        input: FieldInputStyle.switchControl,
        label: 'Consent to collect medical history',
        hint: 'We use it only for care decisions. You can revoke anytime.',
      ),
    ],
    paths: ['intake_complete', 'escalate_clinician', 'consent_revoked'],
  );

  static const signup = Scenario(
    key: 'signup',
    label: 'Fintech signup',
    formName: 'Open your account',
    posture: FormPosture.confident,
    fields: [
      FieldSpec(
        key: 'full_name',
        type: 'String',
        required: true,
        input: FieldInputStyle.filled,
        label: 'What should we call you?',
      ),
      FieldSpec(
        key: 'email',
        type: 'String',
        required: true,
        input: FieldInputStyle.filled,
        label: 'Where can we reach you?',
        hint: "We'll send a verification link.",
      ),
      FieldSpec(
        key: 'use_case',
        type: 'enum',
        required: true,
        input: FieldInputStyle.choiceChips,
        label: 'What are you here for?',
        options: ['Personal', 'Business', 'Freelance', 'Other'],
      ),
      FieldSpec(
        key: 'monthly_volume',
        type: 'int',
        required: true,
        range: NumRange(0, 100),
        input: FieldInputStyle.slider,
        label: 'Roughly, how much do you process each month?',
        hint: 'In thousands of dollars.',
      ),
      FieldSpec(
        key: 'tos_accepted',
        type: 'bool',
        required: true,
        input: FieldInputStyle.switchControl,
        label: 'Terms of service',
      ),
    ],
    paths: ['account_created', 'kyc_required', 'rejected_underage'],
  );

  static const feedback = Scenario(
    key: 'feedback',
    label: 'NPS feedback',
    formName: 'How are we doing?',
    posture: FormPosture.casual,
    fields: [
      FieldSpec(
        key: 'score',
        type: 'int',
        required: true,
        range: NumRange(0, 10),
        input: FieldInputStyle.slider,
        label: 'How likely are you to recommend us?',
        hint: '0 = not at all · 10 = absolutely',
      ),
      FieldSpec(
        key: 'reason',
        type: 'String',
        required: false,
        input: FieldInputStyle.outlined,
        label: "What's the main reason for your score?",
        hint: 'Optional — but it really helps.',
      ),
      FieldSpec(
        key: 'features_loved',
        type: 'List',
        required: false,
        input: FieldInputStyle.choiceChips,
        label: 'Which parts hit?',
        hint: 'Pick as many as apply.',
        options: ['Speed', 'Design', 'Reliability', 'Support', 'Pricing'],
      ),
      FieldSpec(
        key: 'follow_up_ok',
        type: 'bool',
        required: false,
        input: FieldInputStyle.switchControl,
        label: 'OK if we follow up?',
      ),
    ],
    paths: ['thanks', 'route_to_sales', 'route_to_support'],
  );

  static const all = [medical, signup, feedback];

  static Scenario byKey(String key) => all.firstWhere(
        (s) => s.key == key,
        orElse: () => medical,
      );

  static String inferKey(String prompt) {
    final t = prompt.toLowerCase();
    if (t.contains('medical') ||
        t.contains('intake') ||
        t.contains('clinic') ||
        t.contains('patient')) {
      return 'medical';
    }
    if (t.contains('nps') ||
        t.contains('feedback') ||
        t.contains('survey')) {
      return 'feedback';
    }
    if (t.contains('signup') ||
        t.contains('sign up') ||
        t.contains('onboard') ||
        t.contains('fintech') ||
        t.contains('account')) {
      return 'signup';
    }
    return 'medical';
  }
}
