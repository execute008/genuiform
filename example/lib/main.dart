import 'package:flutter/material.dart';
import 'package:genuiform/genuiform.dart';

import 'api_key_panel.dart';
import 'scenarios/freelance_qualification.dart';
import 'scenarios/gymgeist_onboarding.dart';

void main() {
  runApp(const GenuiformExampleApp());
}

class GenuiformExampleApp extends StatelessWidget {
  const GenuiformExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'genuiform examples',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Priority 1: compile-time --dart-define=GEMINI_API_KEY=xxx
  static const _envApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _envProjectId = String.fromEnvironment('GEMINI_PROJECT_ID');

  // The notifiers are pre-seeded with the compile-time values (may be '').
  late final ValueNotifier<String> _apiKey;
  late final ValueNotifier<String> _projectId;

  static const _model = 'gemini-2.5-flash';

  @override
  void initState() {
    super.initState();
    _apiKey = ValueNotifier(_envApiKey);
    _projectId = ValueNotifier(_envProjectId);
  }

  @override
  void dispose() {
    _apiKey.dispose();
    _projectId.dispose();
    super.dispose();
  }

  LlmClient _buildClient() => VertexDirectClient(
        apiKey: _apiKey.value,
        projectId: _projectId.value,
        location: 'europe-west1',
      );

  void _showFeedback(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openScenario(Widget scenario) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => scenario),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('genuiform examples')),
      body: ListenableBuilder(
        listenable: Listenable.merge([_apiKey, _projectId]),
        builder: (context, _) {
          final hasKey =
              _apiKey.value.isNotEmpty && _projectId.value.isNotEmpty;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── API key inputs ──────────────────────────────────────────
                ApiKeyPanel(
                  notifier: _apiKey,
                  label: 'Gemini API key / OAuth token',
                ),
                const SizedBox(height: 8),
                ApiKeyPanel(
                  notifier: _projectId,
                  label: 'GCP Project ID',
                ),
                const SizedBox(height: 16),

                // ── Demo 1 ──────────────────────────────────────────────────
                FilledButton.icon(
                  onPressed: hasKey
                      ? () => _openScenario(
                            Scaffold(
                              appBar: AppBar(
                                title: const Text('Freelance qualification'),
                              ),
                              body: freelanceQualificationForm(
                                client: _buildClient(),
                                model: _model,
                                showFeedback: _showFeedback,
                              ),
                            ),
                          )
                      : null,
                  icon: const Icon(Icons.support_agent),
                  label: const Text(
                    'Demo 1 — Freelance qualification (branching)',
                  ),
                ),
                const SizedBox(height: 12),

                // ── Demo 2 ──────────────────────────────────────────────────
                FilledButton.icon(
                  onPressed: hasKey
                      ? () => _openScenario(
                            Scaffold(
                              appBar: AppBar(
                                title: const Text('GymGeist onboarding'),
                              ),
                              body: gymgeistOnboardingForm(
                                client: _buildClient(),
                                model: _model,
                                showFeedback: _showFeedback,
                              ),
                            ),
                          )
                      : null,
                  icon: const Icon(Icons.fitness_center),
                  label: const Text(
                    'Demo 2 — GymGeist onboarding (ladder + branch)',
                  ),
                ),

                // ── No-key hint ─────────────────────────────────────────────
                if (!hasKey) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Paste your Vertex AI access token + GCP project ID above '
                    'to enable the demos.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
