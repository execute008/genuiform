import 'package:freezed_annotation/freezed_annotation.dart';

part 'message.freezed.dart';
part 'message.g.dart';

/// The role of a participant in an LLM conversation.
///
/// Wire values match the Vertex AI / OpenAI message format.
@JsonEnum(valueField: 'wireValue')
enum MessageRole {
  /// The system prompt — sets context, instructions, and constraints.
  @JsonValue('system')
  system('system'),

  /// A message from the end user.
  @JsonValue('user')
  user('user'),

  /// A message from the LLM (model response).
  @JsonValue('assistant')
  assistant('assistant');

  const MessageRole(this.wireValue);
  final String wireValue;
}

/// A single message in the conversation history sent to the LLM.
///
/// [Message] is the unit of the `messages` list passed to [LlmClient.generate].
/// The list should contain interleaved [user] and [assistant] messages,
/// typically preceded by a [system] message baked into the `systemPrompt`
/// parameter instead of the list itself (follow the Vertex AI convention).
@freezed
abstract class Message with _$Message {
  const factory Message({
    /// Who authored this message.
    @JsonKey(
      toJson: _messageRoleToJson,
      fromJson: _messageRoleFromJson,
    )
    required MessageRole role,

    /// The text content of the message.
    required String content,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
}

String _messageRoleToJson(MessageRole role) => role.wireValue;

MessageRole _messageRoleFromJson(String value) {
  return MessageRole.values.firstWhere(
    (r) => r.wireValue == value,
    orElse: () => throw ArgumentError('Unknown MessageRole: $value'),
  );
}
