import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/language_codes.dart';
import '../models/conversation_message.dart';
import '../models/transcription_result.dart';
import 'asr/whisper_isolate.dart';
import 'audio/audio_recorder.dart';
import 'audio/audio_stream_controller.dart';
import 'model_manager.dart';
import 'translation/translation_isolate.dart';

/// Orchestrates the full pipeline: audio → ASR → translate → messages.
class ConversationEngine {
  final AudioRecorderService _recorder = AudioRecorderService();
  final AudioStreamController _streamController = AudioStreamController();
  final WhisperIsolate _whisper = WhisperIsolate();
  final TranslationIsolate _translation = TranslationIsolate();
  final ModelManager _modelManager = ModelManager();

  final _messageController =
      StreamController<ConversationMessage>.broadcast();
  final _partialController =
      StreamController<TranscriptionResult>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  String _primaryLanguage = 'en';
  final Set<String> _detectedForeignLanguages = {};
  bool _isRunning = false;
  bool _translationAvailable = false;
  int _messageCounter = 0;

  StreamSubscription<Float32List>? _utteranceSub;
  StreamSubscription<Float32List>? _partialSub;

  /// Stream of completed, translated conversation messages.
  Stream<ConversationMessage> get messageStream => _messageController.stream;

  /// Stream of partial transcription results (while user is speaking).
  Stream<TranscriptionResult> get partialStream => _partialController.stream;

  /// Stream of error messages.
  Stream<String> get errorStream => _errorController.stream;

  bool get isRunning => _isRunning;
  bool get translationAvailable => _translationAvailable;
  WhisperIsolate get whisperIsolate => _whisper;
  String get primaryLanguage => _primaryLanguage;
  Set<String> get detectedForeignLanguages =>
      Set.unmodifiable(_detectedForeignLanguages);

  void setPrimaryLanguage(String langCode) {
    _primaryLanguage = langCode;
  }

  /// Initialize models. Must be called before start().
  /// Whisper is required; translation is optional (graceful degradation).
  Future<void> initialize() async {
    // Always initialize whisper (required for ASR)
    final whisperReady = await _modelManager.isWhisperModelReady();
    if (!whisperReady) {
      throw StateError('Whisper model not downloaded. Run onboarding first.');
    }

    final whisperPath = await _modelManager.getWhisperModelPath();
    final modelFile = File(whisperPath);
    final exists = modelFile.existsSync();
    final size = exists ? modelFile.lengthSync() : 0;
    debugPrint('[Engine] Whisper model path: $whisperPath');
    debugPrint('[Engine] Whisper model exists=$exists size=${(size / 1024 / 1024).toStringAsFixed(1)}MB');

    if (!exists) {
      throw StateError('Whisper model file not found at: $whisperPath');
    }

    await _whisper.initialize(whisperPath);
    debugPrint('[Engine] Whisper model loaded successfully');

    // Try to initialize translation (optional)
    final nllbReady = await _modelManager.isNllbModelReady();
    if (nllbReady) {
      try {
        final nllbDir = await _modelManager.getNllbModelDir();
        await _translation.initialize(nllbDir);
        _translationAvailable = true;
        debugPrint('Translation engine initialized');
      } catch (e) {
        debugPrint('Translation init failed (will run transcription-only): $e');
        _translationAvailable = false;
      }
    } else {
      debugPrint('NLLB model not found — running in transcription-only mode');
      _translationAvailable = false;
    }
  }

  /// Start listening and translating.
  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    debugPrint('[Engine] Starting audio capture...');

    final audioStream = await _recorder.startRecording();

    // Feed audio chunks to the stream controller
    audioStream.listen(_streamController.processAudioChunk);
    debugPrint('[Engine] Listening for speech (primary=$_primaryLanguage, translation=$_translationAvailable)');

    // Listen for complete utterances
    _utteranceSub = _streamController.utteranceStream.listen(
      _handleUtterance,
    );

    // Listen for partial audio (for live transcription)
    _partialSub = _streamController.partialStream.listen(
      _handlePartialAudio,
    );
  }

  /// Stop listening.
  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;

    await _utteranceSub?.cancel();
    await _partialSub?.cancel();
    await _recorder.stopRecording();
    _streamController.reset();
  }

  Future<void> _handleUtterance(Float32List audioSamples) async {
    try {
      debugPrint('[Engine] Transcribing ${audioSamples.length} samples...');
      // 1. Transcribe with language detection
      final transcription = await _whisper.transcribe(audioSamples);

      if (transcription.isEmpty) {
        debugPrint('[Engine] Transcription empty, skipping');
        return;
      }

      debugPrint('[Engine] Transcribed: lang=${transcription.languageCode} '
          'prob=${transcription.languageProbability.toStringAsFixed(2)} '
          'text="${transcription.text}"');

      // Clear partial transcription
      _partialController.add(TranscriptionResult(
        text: '',
        languageCode: transcription.languageCode,
        languageProbability: 0,
        isPartial: false,
      ));

      final detectedLang = transcription.languageCode;
      final isPrimary = detectedLang == _primaryLanguage;

      if (isPrimary) {
        await _handlePrimaryLanguageUtterance(transcription);
      } else {
        _detectedForeignLanguages.add(detectedLang);
        await _handleForeignLanguageUtterance(transcription);
      }
    } catch (e, stack) {
      debugPrint('[Engine] Transcription error: $e\n$stack');
      _errorController.add('Transcription error: $e');
    }
  }

  Future<void> _handlePrimaryLanguageUtterance(
    TranscriptionResult transcription,
  ) async {
    if (!_translationAvailable || _detectedForeignLanguages.isEmpty) {
      // No translation available or no foreign languages detected — show as-is
      _messageController.add(ConversationMessage(
        id: 'msg_${_messageCounter++}',
        originalText: transcription.text,
        translatedText: transcription.text,
        detectedLanguage: _primaryLanguage,
        targetLanguage: _primaryLanguage,
        isPrimaryLanguageSpeaker: true,
        timestamp: DateTime.now(),
      ));
      return;
    }

    // Translate to each detected foreign language
    for (final targetLang in _detectedForeignLanguages) {
      try {
        final translated = await _translation.translate(
          transcription.text,
          _primaryLanguage,
          targetLang,
        );

        _messageController.add(ConversationMessage(
          id: 'msg_${_messageCounter++}',
          originalText: transcription.text,
          translatedText: translated,
          detectedLanguage: _primaryLanguage,
          targetLanguage: targetLang,
          isPrimaryLanguageSpeaker: true,
          timestamp: DateTime.now(),
        ));
      } catch (e) {
        _errorController.add(
          'Translation to ${LanguageCodes.getLanguageName(targetLang)} failed: $e',
        );
      }
    }
  }

  Future<void> _handleForeignLanguageUtterance(
    TranscriptionResult transcription,
  ) async {
    if (!_translationAvailable) {
      // No translation — show original text with detected language
      _messageController.add(ConversationMessage(
        id: 'msg_${_messageCounter++}',
        originalText: transcription.text,
        translatedText: transcription.text,
        detectedLanguage: transcription.languageCode,
        targetLanguage: transcription.languageCode,
        isPrimaryLanguageSpeaker: false,
        timestamp: DateTime.now(),
      ));
      return;
    }

    try {
      final translated = await _translation.translate(
        transcription.text,
        transcription.languageCode,
        _primaryLanguage,
      );

      _messageController.add(ConversationMessage(
        id: 'msg_${_messageCounter++}',
        originalText: transcription.text,
        translatedText: translated,
        detectedLanguage: transcription.languageCode,
        targetLanguage: _primaryLanguage,
        isPrimaryLanguageSpeaker: false,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      _errorController.add('Translation failed: $e');
    }
  }

  Future<void> _handlePartialAudio(Float32List audioSamples) async {
    try {
      final result = await _whisper.transcribe(
        audioSamples,
        isPartial: true,
      );
      if (!result.isEmpty) {
        debugPrint('[Engine] Partial: "${result.text}" (${result.languageCode})');
        _partialController.add(result);
      }
    } catch (e) {
      debugPrint('[Engine] Partial transcription error: $e');
    }
  }

  Future<void> dispose() async {
    await stop();
    _whisper.dispose();
    _translation.dispose();
    _streamController.dispose();
    await _recorder.dispose();
    await _messageController.close();
    await _partialController.close();
    await _errorController.close();
  }
}
