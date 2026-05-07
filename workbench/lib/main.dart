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
  // Priority 1: compile-time --dart-define values.
  static const _envApiKey = String.fromEnvironment('VERTEX_API_KEY');
  static const _envProjectId = String.fromEnvironment('VERTEX_PROJECT_ID');
  static const _envLocation =
      String.fromEnvironment('VERTEX_LOCATION', defaultValue: 'europe-west1');

  /// When true, bypass all credential checks and use the local mock client.
  /// Enable with `--dart-define=USE_MOCK=true`.
  static const _useMock = bool.fromEnvironment('USE_MOCK');

  static const _model = 'gemini-2.5-flash';

  late final ValueNotifier<String> _apiKey;
  late final ValueNotifier<String> _projectId;

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

  LlmClient _buildClient() {
    if (_useMock) return WorkbenchMockLlmClient();
    return VertexDirectClient(
      apiKey: _apiKey.value,
      projectId: _projectId.value,
      location: _envLocation,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mock mode: skip credential gate entirely.
    if (_useMock) {
      return AppShell(
        client: _buildClient(),
        model: _model,
        showMockBadge: true,
      );
    }

    // If compile-time defines are present, go straight to the shell.
    if (_envApiKey.isNotEmpty && _envProjectId.isNotEmpty) {
      return AppShell(client: _buildClient(), model: _model);
    }

    // Otherwise gate behind the key-paste panels.
    return Scaffold(
      appBar: AppBar(title: const Text('genuiform workbench')),
      body: ListenableBuilder(
        listenable: Listenable.merge([_apiKey, _projectId]),
        builder: (context, _) {
          final hasKey =
              _apiKey.value.isNotEmpty && _projectId.value.isNotEmpty;

          if (hasKey) {
            return AppShell(client: _buildClient(), model: _model);
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Enter your Vertex AI credentials to start',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ApiKeyPanel(
                      notifier: _apiKey,
                      label: 'Vertex AI API key',
                    ),
                    const SizedBox(height: 12),
                    ApiKeyPanel(
                      notifier: _projectId,
                      label: 'GCP Project ID',
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Or build with --dart-define=VERTEX_API_KEY=xxx '
                      '--dart-define=VERTEX_PROJECT_ID=xxx to skip this screen.',
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
