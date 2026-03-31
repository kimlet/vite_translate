import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/conversation_message.dart';
import '../models/transcription_result.dart';
import 'asr/whisper_isolate.dart';
import 'audio/audio_recorder.dart';
import 'audio/audio_saver.dart';
import 'audio/audio_stream_controller.dart';
import 'model_manager.dart';

/// Orchestrates: audio → whisper transcribe + translate → conversation messages.
///
/// Translation strategy using whisper's built-in capabilities:
/// - Foreign speech → whisper transcribes (original) + translates to English
/// - Primary language speech → whisper transcribes only (shown as-is)
///
/// This means the primary language MUST be English for whisper translation to work.
/// For non-English primary languages, we fall back to transcription-only mode.
class ConversationEngine {
  final AudioRecorderService _recorder = AudioRecorderService();
  final AudioStreamController _streamController = AudioStreamController();
  final WhisperIsolate _whisper = WhisperIsolate();
  final ModelManager _modelManager = ModelManager();
  final AudioSaver _audioSaver = AudioSaver();

  final _messageController =
      StreamController<ConversationMessage>.broadcast();
  final _partialController =
      StreamController<TranscriptionResult>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  String _primaryLanguage = 'en';
  int _sampleRate = 16000;
  bool _isRunning = false;
  bool _canTranslate = false;
  int _messageCounter = 0;

  StreamSubscription<Float32List>? _utteranceSub;
  StreamSubscription<Float32List>? _partialSub;

  Stream<ConversationMessage> get messageStream => _messageController.stream;
  Stream<TranscriptionResult> get partialStream => _partialController.stream;
  Stream<String> get errorStream => _errorController.stream;

  bool get isRunning => _isRunning;
  bool get canTranslate => _canTranslate;
  String get primaryLanguage => _primaryLanguage;
  WhisperIsolate get whisperIsolate => _whisper;

  void setPrimaryLanguage(String langCode) {
    _primaryLanguage = langCode;
    _canTranslate = langCode == 'en';
  }

  void setSampleRate(int rate) {
    _sampleRate = rate;
  }

  Future<void> initialize() async {
    final whisperPath = await _modelManager.getWhisperModelPath();
    if (whisperPath == null) {
      // List what's in the models dir for debugging
      final dir = await _modelManager.modelsDir;
      final contents = Directory(dir).listSync();
      debugPrint('[Engine] Models dir ($dir) contents:');
      for (final f in contents) {
        debugPrint('[Engine]   ${f.path}');
      }
      throw StateError('No whisper model found. Download via onboarding.');
    }

    final modelFile = File(whisperPath);
    debugPrint('[Engine] Model: $whisperPath (${(modelFile.lengthSync() / 1024 / 1024).toStringAsFixed(1)}MB)');

    await _whisper.initialize(whisperPath);
    _canTranslate = _primaryLanguage == 'en';
    debugPrint('[Engine] Ready. primary=$_primaryLanguage canTranslate=$_canTranslate');
  }

  Future<void> start() async {
    if (_isRunning) return;
    if (!_whisper.isInitialized) {
      debugPrint('[Engine] Cannot start — whisper not initialized');
      return;
    }
    _isRunning = true;
    debugPrint('[Engine] Starting (sampleRate=$_sampleRate)...');

    _streamController.setInputSampleRate(_sampleRate);
    final audioStream = await _recorder.startRecording(sampleRate: _sampleRate);
    audioStream.listen(_streamController.processAudioChunk);

    _utteranceSub = _streamController.utteranceStream.listen(_handleUtterance);
    _partialSub = _streamController.partialStream.listen(_handlePartialAudio);

    debugPrint('[Engine] Listening (primary=$_primaryLanguage)');
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;
    await _utteranceSub?.cancel();
    await _partialSub?.cancel();
    await _recorder.stopRecording();
    _streamController.reset();
    debugPrint('[Engine] Stopped');
  }

  Future<void> _handleUtterance(Float32List audioSamples) async {
    try {
      final sw = Stopwatch()..start();
      final msgId = 'msg_${_messageCounter++}';

      // Save audio to disk
      final audioPath = await _audioSaver.saveUtterance(audioSamples, msgId);

      // Step 1: Transcribe to get original text + detected language
      final transcription = await _whisper.transcribe(audioSamples);
      debugPrint('[Engine] Transcribe: ${sw.elapsedMilliseconds}ms '
          'lang=${transcription.languageCode} "${transcription.text}"');

      if (transcription.isEmpty) return;

      // Clear partial
      _partialController.add(TranscriptionResult(
        text: '', languageCode: transcription.languageCode,
        languageProbability: 0, isPartial: false,
      ));

      final detectedLang = transcription.languageCode;
      final isPrimary = detectedLang == _primaryLanguage;

      if (isPrimary) {
        _messageController.add(ConversationMessage(
          id: msgId,
          originalText: transcription.text,
          translatedText: transcription.text,
          detectedLanguage: detectedLang,
          targetLanguage: _primaryLanguage,
          isPrimaryLanguageSpeaker: true,
          timestamp: DateTime.now(),
          audioPath: audioPath,
        ));
      } else if (_canTranslate) {
        final translation = await _whisper.translateToEnglish(audioSamples);
        debugPrint('[Engine] Translate: ${sw.elapsedMilliseconds}ms "${translation.text}"');

        _messageController.add(ConversationMessage(
          id: msgId,
          originalText: transcription.text,
          translatedText: translation.text.isNotEmpty ? translation.text : transcription.text,
          detectedLanguage: detectedLang,
          targetLanguage: 'en',
          isPrimaryLanguageSpeaker: false,
          timestamp: DateTime.now(),
          audioPath: audioPath,
        ));
      } else {
        _messageController.add(ConversationMessage(
          id: msgId,
          originalText: transcription.text,
          translatedText: transcription.text,
          detectedLanguage: detectedLang,
          targetLanguage: detectedLang,
          isPrimaryLanguageSpeaker: false,
          timestamp: DateTime.now(),
          audioPath: audioPath,
        ));
      }

      debugPrint('[Engine] Total pipeline: ${sw.elapsedMilliseconds}ms');
    } catch (e, stack) {
      debugPrint('[Engine] Error: $e\n$stack');
      _errorController.add('Error: $e');
    }
  }

  Future<void> _handlePartialAudio(Float32List audioSamples) async {
    try {
      final result = await _whisper.transcribe(audioSamples, isPartial: true);
      if (!result.isEmpty) {
        debugPrint('[Engine] Partial: "${result.text}"');
        _partialController.add(result);
      }
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
    _whisper.dispose();
    _streamController.dispose();
    await _recorder.dispose();
    await _messageController.close();
    await _partialController.close();
    await _errorController.close();
  }
}
