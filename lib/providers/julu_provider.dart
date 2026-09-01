import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class JuluState {
  final List<ChatMessage> messages;

  const JuluState({
    this.messages = const [],
  });

  JuluState copyWith({
    List<ChatMessage>? messages,
  }) {
    return JuluState(
      messages: messages ?? this.messages,
    );
  }
}

class JuluNotifier extends StateNotifier<JuluState> {
  JuluNotifier()
      : super(JuluState(messages: [
          ChatMessage(
            text: 'Hi! I am Julu, your personal AI music assistant. How can I help you today?',
            isUser: false,
          )
        ]));

  void addUserMessage(String text) {
    state = state.copyWith(
      messages: [...state.messages, ChatMessage(text: text, isUser: true)],
    );
  }

  void addJuluMessage(String text) {
    state = state.copyWith(
      messages: [...state.messages, ChatMessage(text: text, isUser: false)],
    );
  }

  void clearHistory() {
    state = JuluState(messages: [
      ChatMessage(
        text: 'Hi! I am Julu, your personal AI music assistant. How can I help you today?',
        isUser: false,
      )
    ]);
  }
}

final juluProvider = StateNotifierProvider<JuluNotifier, JuluState>((ref) {
  return JuluNotifier();
});
