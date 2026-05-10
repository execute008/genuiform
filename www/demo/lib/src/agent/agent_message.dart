enum AgentRole { user, agent }

class AgentMessage {
  const AgentMessage({
    required this.role,
    required this.text,
    this.isStreaming = false,
  });

  final AgentRole role;
  final String text;
  final bool isStreaming;

  // Extracts the first ```...``` or ```dsl...``` block from text, or null.
  String? get extractedDsl {
    final re = RegExp(r'```(?:dsl)?\n?([\s\S]*?)```');
    final match = re.firstMatch(text);
    return match?.group(1)?.trim();
  }

  AgentMessage copyWith({String? text, bool? isStreaming}) => AgentMessage(
        role: role,
        text: text ?? this.text,
        isStreaming: isStreaming ?? this.isStreaming,
      );
}
