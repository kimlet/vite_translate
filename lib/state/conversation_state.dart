import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/conversation_message.dart';
import '../models/transcription_result.dart';
import '../services/conversation_engine.dart';
import 'settings_state.dart';

/// State for the conversation: messages + partial transcription.
class ConversationState {
  final List<ConversationMessage> messages;
  final TranscriptionResult? partialTranscription;
  final bool isListening;
  final String? error;

  const ConversationState({
    this.messages = const [],
    this.partialTranscription,
    this.isListening = false,
    this.error,
  });

  ConversationState copyWith({
    List<ConversationMessage>? messages,
    TranscriptionResult? partialTranscription,
    bool? clearPartial,
    bool? isListening,
    String? error,
    bool? clearError,
  }) {
    return ConversationState(
      messages: messages ?? this.messages,
      partialTranscription:
          clearPartial == true
              ? null
              : (partialTranscription ?? this.partialTranscription),
      isListening: isListening ?? this.isListening,
      error: clearError == true ? null : (error ?? this.error),
    );
  }
}

class ConversationNotifier extends StateNotifier<ConversationState> {
  final ConversationEngine _engine;
  StreamSubscription<ConversationMessage>? _messageSub;
  StreamSubscription<TranscriptionResult>? _partialSub;
  StreamSubscription<String>? _errorSub;

  ConversationNotifier(this._engine) : super(const ConversationState()) {
    _messageSub = _engine.messageStream.listen((message) {
      state = state.copyWith(
        messages: [...state.messages, message],
        clearPartial: true,
      );
    });

    _partialSub = _engine.partialStream.listen((partial) {
      if (partial.isEmpty) {
        state = state.copyWith(clearPartial: true);
      } else {
        state = state.copyWith(partialTranscription: partial);
      }
    });

    _errorSub = _engine.errorStream.listen((error) {
      state = state.copyWith(error: error);
    });
  }

  Future<void> startListening() async {
    await _engine.start();
    state = state.copyWith(isListening: true);
  }

  Future<void> stopListening() async {
    await _engine.stop();
    state = state.copyWith(isListening: false);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void clearMessages() {
    state = state.copyWith(messages: []);
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _partialSub?.cancel();
    _errorSub?.cancel();
    super.dispose();
  }
}

final conversationEngineProvider = Provider<ConversationEngine>((ref) {
  final engine = ConversationEngine();
  final settings = ref.watch(settingsProvider);
  engine.setPrimaryLanguage(settings.primaryLanguageCode);
  ref.onDispose(() => engine.dispose());
  return engine;
});

final conversationProvider =
    StateNotifierProvider<ConversationNotifier, ConversationState>((ref) {
      final engine = ref.watch(conversationEngineProvider);
      return ConversationNotifier(engine);
    });
