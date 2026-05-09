enum ChatRole { user, ai }

class ChatMessage {
  final ChatRole role;
  final String text;
  final List<String>? followups;

  const ChatMessage({
    required this.role,
    required this.text,
    this.followups,
  });
}
