import 'package:flutter/material.dart';
import 'package:genuiform/genuiform.dart';

import 'src/llm/workbench_mock_llm_client.dart';
import 'src/shell/api_key_panel.dart';
import 'src/shell/app_shell.dart';
import 'src/shell/theme.dart';

void main() {
  runApp(const WorkbenchApp());
}

class WorkbenchApp extends StatelessWidget {
  const WorkbenchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'genuiform workbench',
      theme: workbenchTheme,
      home: const _WorkbenchRoot(),
    );
  }
}

class _WorkbenchRoot extends StatefulWidget {
  const _WorkbenchRoot();

  @override
  State<_WorkbenchRoot> createState() => _WorkbenchRootState();
}

class _WorkbenchRootState extends State<_WorkbenchRoot> {
  // Public Gemini API path (free-tier AI Studio key from
  // aistudio.google.com/apikey). The workbench only supports this transport
  // — Vertex AI from a Flutter client must go through Firebase, not via a
  // baked-in API key.
  static const _envGeminiKey = String.fromEnvironment('GEMINI_API_KEY');

  /// When true, bypass all credential checks and use the local mock client.
  /// Enable with `--dart-define=USE_MOCK=true`.
  static const _useMock = bool.fromEnvironment('USE_MOCK');

  /// Initial model on first paint. Runtime-mutable via the toolbar dropdown.
  static const _initialModel = 'gemini-flash-latest';

  /// Initial sampling temperature. Runtime-mutable via the toolbar slider.
  static const _initialTemperature = 0.7;

  late final ValueNotifier<String> _geminiKey;
  late final ValueNotifier<String> _model;
  late final ValueNotifier<double> _temperature;

  @override
  void initState() {
    super.initState();
    _geminiKey = ValueNotifier(_envGeminiKey);
    _model = ValueNotifier(_initialModel);
    _temperature = ValueNotifier(_initialTemperature);
  }

  @override
  void dispose() {
    _geminiKey.dispose();
    _model.dispose();
    _temperature.dispose();
    super.dispose();
  }

  bool get _hasGemini => _geminiKey.value.isNotEmpty;

  LlmClient _buildClient() {
    if (_useMock) return WorkbenchMockLlmClient();
    return GeminiApiClient(apiKey: _geminiKey.value);
  }

  @override
  Widget build(BuildContext context) {
    if (_useMock) {
      return AppShell(
        client: _buildClient(),
        model: _model,
        temperature: _temperature,
        showMockBadge: true,
      );
    }

    if (_hasGemini) {
      return AppShell(
        client: _buildClient(),
        model: _model,
        temperature: _temperature,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('genuiform workbench')),
      body: ListenableBuilder(
        listenable: _geminiKey,
        builder: (context, _) {
          if (_hasGemini) {
            return AppShell(
        client: _buildClient(),
        model: _model,
        temperature: _temperature,
      );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Pick a transport to start',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Google AI Studio (Gemini API key)',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    ApiKeyPanel(
                      notifier: _geminiKey,
                      label: 'Gemini API key (AIza…)',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Free tier from aistudio.google.com/apikey — no GCP setup.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Or build with --dart-define=GEMINI_API_KEY=xxx to skip '
                      'this screen.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
