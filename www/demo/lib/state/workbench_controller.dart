import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:genuiform/genuiform.dart';

import '../models/chat_message.dart';
import '../models/persona.dart';
import '../models/scenario.dart' as DemoScenario;
import '../services/gemini_service.dart';
import '../src/parser/parse_dsl.dart';
import '../src/llm/workbench_mock_llm_client.dart';
import '../src/scenarios/scenarios.dart';

/// Enhanced workbench controller with DSL editing and LLM client support.
/// Combines demo UI with workbench functionality.
class WorkbenchController extends ChangeNotifier {
  String _scenarioKey = 'medical';
  String _activePersonaId = 'p1';
  bool _generating = false;
  bool _debug = true;
  int _personaCount = 4;
  String _streamingText = '';
  
  // DSL Editor state
  bool _showDslEditor = false;
  String _currentScenarioId = 'lead_qualification';
  late String _dsl;
  late ParseResult _parseResult;
  late ParseResult _committedParseResult;
  int _formKey = 0;
  Timer? _debounce;
  Timer? _commitDebounce;
  // String _lastSyncedDsl = '';  // Removed unused field
  
  // LLM Client configuration
  static const _envGeminiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _useMock = bool.fromEnvironment('USE_MOCK');
  static const _initialModel = 'gemini-flash-latest';

  late final ValueNotifier<String> _geminiKey;
  late final ValueNotifier<String> _model;
  
  // Form controller reference for progress drawer
  final ValueNotifier<FormController?> controllerRef = ValueNotifier<FormController?>(null);
  
  static const Duration _kCommitDebounce = Duration(milliseconds: 2000);
  
  final GeminiService _geminiService = GeminiService();

  final List<ChatMessage> _history = [
    const ChatMessage(
      role: ChatRole.user,
      text:
          'I need a medical intake form for a clinic. Reassuring tone. Cap at 12 steps. Escalate if symptoms suggest self-harm.',
    ),
    const ChatMessage(
      role: ChatRole.ai,
      text:
          "Here's a draft for Medical intake. I picked a reassuring posture and routed all inputs through tokens in tdl/v3. The form will branch to one of: intake_complete, escalate_clinician, consent_revoked.",
      followups: [
        'Make consent more prominent',
        'Add an escalation for self-harm mentions',
        'Cap at 12 steps',
      ],
    ),
  ];

  // Getters for DSL functionality
  bool get showDslEditor => _showDslEditor;
  String get currentScenarioId => _currentScenarioId;
  String get dsl => _dsl;
  ParseResult get parseResult => _parseResult;
  ParseResult get committedParseResult => _committedParseResult;
  int get formKey => _formKey;
  ValueNotifier<String> get model => _model;
  
  bool get hasGemini => _geminiKey.value.isNotEmpty || _geminiService.hasApiKey;
  
  static const candidateModels = <String>[
    'gemini-flash-latest',
    'gemini-2.5-flash',
    'gemini-2.5-pro',
    'gemini-3-flash-preview',
    'gemini-3-pro-preview',
  ];

  static const Map<String, List<String>> _followups = {
    'medical': [
      'Make consent more prominent',
      'Add an escalation for self-harm mentions',
      'Cap at 12 steps',
    ],
    'signup': [
      'Add OAuth options',
      'Soften the volume slider copy',
      'Branch by use_case',
    ],
    'feedback': [
      'Add an open comment for low scores',
      'Skip optional fields under 30s focus',
    ],
  };

  String get scenarioKey => _scenarioKey;
  DemoScenario.Scenario get scenario => DemoScenario.ScenarioLibrary.byKey(_scenarioKey);
  String get activePersonaId => _activePersonaId;
  Persona? get activePersona {
    final list = PersonaLibrary.byScenario[_scenarioKey] ?? [];
    return list.firstWhere(
      (p) => p.id == _activePersonaId,
      orElse: () => list.isNotEmpty
          ? list.first
          : PersonaLibrary.byScenario['medical']!.first,
    );
  }

  List<Persona> get visiblePersonas {
    final list = PersonaLibrary.byScenario[_scenarioKey] ?? const [];
    return list.take(_personaCount).toList();
  }

  bool get generating => _generating;
  bool get debug => _debug;
  List<ChatMessage> get history => List.unmodifiable(_history);
  String get streamingText => _streamingText;
  GeminiService get geminiService => _geminiService;
  
  void refresh() => notifyListeners();

  Future<void> init() async {
    await _geminiService.init();
    
    // Initialize LLM client configuration
    _geminiKey = ValueNotifier(_envGeminiKey);
    _model = ValueNotifier(_initialModel);
    
    // Initialize DSL with first scenario
    _dsl = kScenarios.first.dsl;
    _currentScenarioId = kScenarios.first.id;
    _parseResult = parseDsl(_dsl);
    _committedParseResult = _parseResult;
    
    notifyListeners();
  }

  void setScenarioKey(String key) {
    if (_scenarioKey == key) return;
    _scenarioKey = key;
    final personas = PersonaLibrary.byScenario[key];
    if (personas != null && personas.isNotEmpty) {
      _activePersonaId = personas.first.id;
    }
    notifyListeners();
  }

  void setActivePersona(String id) {
    _activePersonaId = id;
    notifyListeners();
  }

  void setDebug(bool v) {
    _debug = v;
    notifyListeners();
  }

  void addPersona() {
    final list = PersonaLibrary.byScenario[_scenarioKey] ?? const [];
    if (_personaCount < list.length) {
      _personaCount += 1;
      notifyListeners();
    }
  }

  void shufflePersonas() {
    _personaCount = (_personaCount % 4) + 1;
    notifyListeners();
  }

  void addMockMessage(String text) {
    if (text.trim().isEmpty) return;
    _history.add(ChatMessage(role: ChatRole.user, text: text.trim()));
    
    // Add a simple mock response
    Future.delayed(const Duration(milliseconds: 500), () {
      _history.add(const ChatMessage(
        role: ChatRole.ai,
        text: "I'll help you create that form. Switch to Code view to see and edit the DSL, then click Run to generate the form.",
        followups: [
          'Show me an example',
          'Explain the DSL syntax',
          'Add more fields',
        ],
      ));
      notifyListeners();
    });
    
    notifyListeners();
  }
  
  Future<void> submitPrompt(String text) async {
    if (text.trim().isEmpty || _generating) return;
    _history.add(ChatMessage(role: ChatRole.user, text: text.trim()));
    _generating = true;
    _streamingText = '';
    notifyListeners();

    // Use real API if available, otherwise fallback to simulation
    if (_geminiService.hasApiKey) {
      try {
        final fullResponse = StringBuffer();
        await for (final chunk in _geminiService.generateFormContractStream(text)) {
          fullResponse.write(chunk);
          _streamingText = fullResponse.toString();
          notifyListeners();
        }
        
        // Infer scenario from response
        final inferred = DemoScenario.ScenarioLibrary.inferKey(text);
        _scenarioKey = inferred;
        final personas = PersonaLibrary.byScenario[inferred];
        if (personas != null && personas.isNotEmpty) {
          _activePersonaId = personas.first.id;
        }
        
        _history.add(ChatMessage(
          role: ChatRole.ai,
          text: fullResponse.toString(),
          followups: _followups[inferred],
        ));
      } catch (e) {
        _history.add(ChatMessage(
          role: ChatRole.ai,
          text: 'Error: ${e.toString()}. Please check your API key.',
        ));
      }
    } else {
      // Fallback to simulation
      await Future<void>.delayed(const Duration(milliseconds: 1400));

      final inferred = DemoScenario.ScenarioLibrary.inferKey(text);
      _scenarioKey = inferred;
      final personas = PersonaLibrary.byScenario[inferred];
      if (personas != null && personas.isNotEmpty) {
        _activePersonaId = personas.first.id;
      }

      final scenario = DemoScenario.ScenarioLibrary.byKey(inferred);
      final reply =
          "Here's a draft for ${scenario.label}. The form will branch to one of: ${scenario.paths.join(', ')}.";

      _history.add(ChatMessage(
        role: ChatRole.ai,
        text: reply,
        followups: _followups[inferred],
      ));
    }
    
    _generating = false;
    _streamingText = '';
    notifyListeners();
  }
  
  // DSL Editor functionality
  void toggleDslEditor() {
    _showDslEditor = !_showDslEditor;
    notifyListeners();
  }
  
  void onDslChanged(String newDsl) {
    _dsl = newDsl;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final result = parseDsl(_dsl);
      _parseResult = result;
      notifyListeners();
      
      _commitDebounce?.cancel();
      if (result.isClean) {
        _commitDebounce = Timer(_kCommitDebounce, () {
          if (_parseResult.isClean && !identical(_parseResult, _committedParseResult)) {
            _committedParseResult = _parseResult;
            notifyListeners();
          }
        });
      }
    });
  }
  
  void onScenarioPicked(String scenarioId) {
    final scenario = kScenarios.firstWhere((s) => s.id == scenarioId);
    _debounce?.cancel();
    _commitDebounce?.cancel();
    _currentScenarioId = scenario.id;
    _dsl = scenario.dsl;
    _parseResult = parseDsl(_dsl);
    _committedParseResult = _parseResult;
    _formKey++;
    notifyListeners();
  }
  
  void runOrReset() {
    _debounce?.cancel();
    _commitDebounce?.cancel();
    _parseResult = parseDsl(_dsl);
    _committedParseResult = _parseResult;
    _formKey++;
    notifyListeners();
  }
  
  LlmClient buildClient() {
    if (_useMock) return WorkbenchMockLlmClient();
    final key = _geminiKey.value.isNotEmpty
        ? _geminiKey.value
        : (_geminiService.apiKey ?? '');
    return GeminiApiClient(apiKey: key);
  }
  
  @override
  void dispose() {
    _debounce?.cancel();
    _commitDebounce?.cancel();
    _geminiKey.dispose();
    _model.dispose();
    super.dispose();
  }
}
