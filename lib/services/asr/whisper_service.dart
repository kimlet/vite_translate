import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../core/errors.dart';
import '../../models/transcription_result.dart';
import 'whisper_bindings.dart';

/// High-level service wrapping whisper.cpp for transcription + language detection.
class WhisperService {
  WhisperBindings? _bindings;
  Pointer<Void>? _context;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Initialize the whisper model from the given file path.
  void initialize(String modelPath) {
    _bindings = WhisperBindings();
    final pathPtr = modelPath.toNativeUtf8();
    try {
      _context = _bindings!.init(pathPtr.cast());
      if (_context == null || _context == nullptr) {
        throw WhisperException('Failed to initialize whisper model: $modelPath');
      }
      _isInitialized = true;
    } finally {
      calloc.free(pathPtr);
    }
  }

  /// Transcribe audio samples and return the result with detected language.
  TranscriptionResult transcribe(
    Float32List samples, {
    bool detectLanguage = true,
    bool isPartial = false,
  }) {
    if (!_isInitialized || _context == null) {
      throw WhisperException('Whisper service not initialized');
    }

    // Allocate native float array
    final nativeSamples = calloc<Float>(samples.length);
    try {
      for (var i = 0; i < samples.length; i++) {
        nativeSamples[i] = samples[i];
      }

      final result = _bindings!.transcribe(
        _context!.cast(),
        nativeSamples,
        samples.length,
        detectLanguage ? 1 : 0,
      );

      if (result == nullptr) {
        return TranscriptionResult(
          text: '',
          languageCode: 'en',
          languageProbability: 0.0,
          isPartial: isPartial,
        );
      }

      try {
        final text = result.ref.text.toDartString();
        final language = result.ref.language.toDartString();
        final probability = result.ref.languageProbability;

        return TranscriptionResult(
          text: text.trim(),
          languageCode: language,
          languageProbability: probability,
          isPartial: isPartial,
        );
      } finally {
        _bindings!.freeResult(result);
      }
    } finally {
      calloc.free(nativeSamples);
    }
  }

  void dispose() {
    if (_isInitialized && _context != null) {
      _bindings!.free(_context!.cast());
      _context = null;
      _isInitialized = false;
    }
  }
}
