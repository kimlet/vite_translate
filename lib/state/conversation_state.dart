import 'dart:async';

import 'package:flutter/foundation.dart';
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

  void addMessage(ConversationMessage message) {
    state = state.copyWith(messages: [...state.messages, message]);
  }

  void setPartial(TranscriptionResult? partial) {
    if (partial == null) {
      state = state.copyWith(clearPartial: true);
    } else {
      state = state.copyWith(partialTranscription: partial);
    }
  }

  /// Run a demo conversation simulating real-time multilingual translation.
  Future<void> runDemo(String primaryLanguage) async {
    clearMessages();
    state = state.copyWith(isListening: true);

    final demoMessages = _buildDemoMessages(primaryLanguage);

    for (final demo in demoMessages) {
      // Show partial transcription first
      setPartial(TranscriptionResult(
        text: demo.originalText.substring(
          0,
          (demo.originalText.length * 0.6).round(),
        ),
        languageCode: demo.detectedLanguage,
        languageProbability: 0.95,
        isPartial: true,
      ));
      await Future.delayed(const Duration(milliseconds: 800));

      // Update partial with full text
      setPartial(TranscriptionResult(
        text: demo.originalText,
        languageCode: demo.detectedLanguage,
        languageProbability: 0.97,
        isPartial: true,
      ));
      await Future.delayed(const Duration(milliseconds: 500));

      // Clear partial, add final message
      setPartial(null);
      addMessage(demo);
      await Future.delayed(const Duration(milliseconds: 1200));
    }

    state = state.copyWith(isListening: false);
  }

  static List<ConversationMessage> _buildDemoMessages(String primary) {
    var id = 0;
    final now = DateTime.now();

    if (primary == 'zh') {
      return [
        ConversationMessage(
          id: 'demo_${id++}',
          originalText: 'Hello, how are you today?',
          translatedText: '你好，你今天怎么样？',
          detectedLanguage: 'en',
          targetLanguage: 'zh',
          isPrimaryLanguageSpeaker: false,
          timestamp: now,
        ),
        ConversationMessage(
          id: 'demo_${id++}',
          originalText: '我很好，谢谢！你呢？',
          translatedText: "I'm fine, thank you! And you?",
          detectedLanguage: 'zh',
          targetLanguage: 'en',
          isPrimaryLanguageSpeaker: true,
          timestamp: now.add(const Duration(seconds: 3)),
        ),
        ConversationMessage(
          id: 'demo_${id++}',
          originalText: "I'm great! The weather is beautiful today.",
          translatedText: '我很好！今天天气很好。',
          detectedLanguage: 'en',
          targetLanguage: 'zh',
          isPrimaryLanguageSpeaker: false,
          timestamp: now.add(const Duration(seconds: 6)),
        ),
        ConversationMessage(
          id: 'demo_${id++}',
          originalText: 'Oui, il fait très beau!',
          translatedText: '是的，天气非常好！',
          detectedLanguage: 'fr',
          targetLanguage: 'zh',
          isPrimaryLanguageSpeaker: false,
          timestamp: now.add(const Duration(seconds: 9)),
        ),
        ConversationMessage(
          id: 'demo_${id++}',
          originalText: '你也说法语吗？太棒了！',
          translatedText: 'You also speak French? Amazing!',
          detectedLanguage: 'zh',
          targetLanguage: 'en',
          isPrimaryLanguageSpeaker: true,
          timestamp: now.add(const Duration(seconds: 12)),
        ),
        ConversationMessage(
          id: 'demo_${id++}',
          originalText: 'はい、日本語も少し話せます。',
          translatedText: '是的，我也会说一点日语。',
          detectedLanguage: 'ja',
          targetLanguage: 'zh',
          isPrimaryLanguageSpeaker: false,
          timestamp: now.add(const Duration(seconds: 15)),
        ),
      ];
    }

    // Default: English primary
    return [
      ConversationMessage(
        id: 'demo_${id++}',
        originalText: 'Hola, ¿cómo estás hoy?',
        translatedText: 'Hello, how are you today?',
        detectedLanguage: 'es',
        targetLanguage: 'en',
        isPrimaryLanguageSpeaker: false,
        timestamp: now,
      ),
      ConversationMessage(
        id: 'demo_${id++}',
        originalText: "I'm doing great, thanks for asking!",
        translatedText: '¡Estoy muy bien, gracias por preguntar!',
        detectedLanguage: 'en',
        targetLanguage: 'es',
        isPrimaryLanguageSpeaker: true,
        timestamp: now.add(const Duration(seconds: 3)),
      ),
      ConversationMessage(
        id: 'demo_${id++}',
        originalText: '¿Dónde está la biblioteca?',
        translatedText: 'Where is the library?',
        detectedLanguage: 'es',
        targetLanguage: 'en',
        isPrimaryLanguageSpeaker: false,
        timestamp: now.add(const Duration(seconds: 6)),
      ),
      ConversationMessage(
        id: 'demo_${id++}',
        originalText: "It's on the second floor, turn left.",
        translatedText: 'Está en el segundo piso, gira a la izquierda.',
        detectedLanguage: 'en',
        targetLanguage: 'es',
        isPrimaryLanguageSpeaker: true,
        timestamp: now.add(const Duration(seconds: 9)),
      ),
      ConversationMessage(
        id: 'demo_${id++}',
        originalText: 'Bonjour! Je cherche aussi la bibliothèque.',
        translatedText: "Hello! I'm also looking for the library.",
        detectedLanguage: 'fr',
        targetLanguage: 'en',
        isPrimaryLanguageSpeaker: false,
        timestamp: now.add(const Duration(seconds: 12)),
      ),
      ConversationMessage(
        id: 'demo_${id++}',
        originalText: 'Oh, you speak French! Follow me, I can show you both.',
        translatedText: 'Síganme, puedo mostrarles a los dos.',
        detectedLanguage: 'en',
        targetLanguage: 'es',
        isPrimaryLanguageSpeaker: true,
        timestamp: now.add(const Duration(seconds: 15)),
      ),
      ConversationMessage(
        id: 'demo_${id++}',
        originalText: '你好！我也想去图书馆。',
        translatedText: 'Hello! I also want to go to the library.',
        detectedLanguage: 'zh',
        targetLanguage: 'en',
        isPrimaryLanguageSpeaker: false,
        timestamp: now.add(const Duration(seconds: 18)),
      ),
      ConversationMessage(
        id: 'demo_${id++}',
        originalText: 'Wow, four languages in one conversation! Let\'s all go together.',
        translatedText: '¡Guau, cuatro idiomas en una conversación! Vamos todos juntos.',
        detectedLanguage: 'en',
        targetLanguage: 'es',
        isPrimaryLanguageSpeaker: true,
        timestamp: now.add(const Duration(seconds: 21)),
      ),
    ];
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
  engine.setSampleRate(settings.sampleRate);
  debugPrint('[Provider] ConversationEngine created, primary=${settings.primaryLanguageCode}, sampleRate=${settings.sampleRate}');
  ref.onDispose(() => engine.dispose());
  return engine;
});

final conversationProvider =
    StateNotifierProvider<ConversationNotifier, ConversationState>((ref) {
      final engine = ref.watch(conversationEngineProvider);
      return ConversationNotifier(engine);
    });
