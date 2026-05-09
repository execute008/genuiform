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
  // Public Gemini API path (free-tier AI Studio key). Wins over Vertex when set.
  static const _envGeminiKey = String.fromEnvironment('GEMINI_API_KEY');

  // Vertex AI path (OAuth bearer + project + location).
  static const _envApiKey = String.fromEnvironment('VERTEX_API_KEY');
  static const _envProjectId = String.fromEnvironment('VERTEX_PROJECT_ID');
  static const _envLocation =
      String.fromEnvironment('VERTEX_LOCATION', defaultValue: 'europe-west1');

  /// When true, bypass all credential checks and use the local mock client.
  /// Enable with `--dart-define=USE_MOCK=true`.
  static const _useMock = bool.fromEnvironment('USE_MOCK');

  static const _model = 'gemini-2.5-flash';

  late final ValueNotifier<String> _geminiKey;
  late final ValueNotifier<String> _apiKey;
  late final ValueNotifier<String> _projectId;

  @override
  void initState() {
    super.initState();
    _geminiKey = ValueNotifier(_envGeminiKey);
    _apiKey = ValueNotifier(_envApiKey);
    _projectId = ValueNotifier(_envProjectId);
  }

  @override
  void dispose() {
    _geminiKey.dispose();
    _apiKey.dispose();
    _projectId.dispose();
    super.dispose();
  }

  bool get _hasGemini => _geminiKey.value.isNotEmpty;
  bool get _hasVertex => _apiKey.value.isNotEmpty && _projectId.value.isNotEmpty;

  LlmClient _buildClient() {
    if (_useMock) return WorkbenchMockLlmClient();
    if (_hasGemini) return GeminiApiClient(apiKey: _geminiKey.value);
    return VertexDirectClient(
      apiKey: _apiKey.value,
      projectId: _projectId.value,
      location: _envLocation,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_useMock) {
      return AppShell(
        client: _buildClient(),
        model: _model,
        showMockBadge: true,
      );
    }

    if (_hasGemini || _hasVertex) {
      return AppShell(client: _buildClient(), model: _model);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('genuiform workbench')),
      body: ListenableBuilder(
        listenable: Listenable.merge([_geminiKey, _apiKey, _projectId]),
        builder: (context, _) {
          if (_hasGemini || _hasVertex) {
            return AppShell(client: _buildClient(), model: _model);
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
                      'Option A — Google AI Studio (recommended for demos)',
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
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'Option B — Vertex AI',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    ApiKeyPanel(
                      notifier: _apiKey,
                      label: 'Vertex OAuth token',
                    ),
                    const SizedBox(height: 12),
                    ApiKeyPanel(
                      notifier: _projectId,
                      label: 'GCP Project ID',
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Or build with --dart-define=GEMINI_API_KEY=xxx '
                      '(or VERTEX_API_KEY + VERTEX_PROJECT_ID) to skip this screen.',
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
