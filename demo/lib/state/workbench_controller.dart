import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../models/persona.dart';
import '../models/scenario.dart';
import '../services/gemini_service.dart';

/// Centralized state for the workbench. Owns scenario, persona, and chat
/// history; simulates the Gemini → contract pipeline.
class WorkbenchController extends ChangeNotifier {
  String _scenarioKey = 'medical';
  String _activePersonaId = 'p1';
  bool _generating = false;
  bool _debug = true;
  int _personaCount = 4;
  String _streamingText = '';
  
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
  Scenario get scenario => ScenarioLibrary.byKey(_scenarioKey);
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
  
  Future<void> init() async {
    await _geminiService.init();
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
        final inferred = ScenarioLibrary.inferKey(text);
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

      final inferred = ScenarioLibrary.inferKey(text);
      _scenarioKey = inferred;
      final personas = PersonaLibrary.byScenario[inferred];
      if (personas != null && personas.isNotEmpty) {
        _activePersonaId = personas.first.id;
      }

      final scenario = ScenarioLibrary.byKey(inferred);
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
}
