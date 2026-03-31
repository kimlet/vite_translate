import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../core/errors.dart';
import '../../models/transcription_result.dart';
import 'whisper_bindings.dart';

/// High-level service wrapping whisper.cpp for transcription + translation.
class WhisperService {
  WhisperBindings? _bindings;
  Pointer<Void>? _context;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  void initialize(String modelPath) {
    _bindings = WhisperBindings();
    final pathPtr = modelPath.toNativeUtf8();
    try {
      _context = _bindings!.init(pathPtr.cast());
      if (_context == null || _context == nullptr) {
        throw WhisperException('Failed to load whisper model: $modelPath');
      }
      _isInitialized = true;
    } finally {
      calloc.free(pathPtr);
    }
  }

  /// Transcribe audio — keeps original language.
  TranscriptionResult transcribe(Float32List samples, {bool isPartial = false}) {
    return _run(samples, translate: false, isPartial: isPartial);
  }

  /// Translate audio to English — whisper's built-in translation.
  TranscriptionResult translateToEnglish(Float32List samples, {bool isPartial = false}) {
    return _run(samples, translate: true, isPartial: isPartial);
  }

  TranscriptionResult _run(
    Float32List samples, {
    required bool translate,
    required bool isPartial,
  }) {
    if (!_isInitialized || _context == null) {
      throw WhisperException('Whisper not initialized');
    }

    final nativeSamples = calloc<Float>(samples.length);
    try {
      for (var i = 0; i < samples.length; i++) {
        nativeSamples[i] = samples[i];
      }

      final Pointer<WhisperBridgeResult> result;
      if (translate) {
        result = _bindings!.translate(
          _context!.cast(),
          nativeSamples,
          samples.length,
        );
      } else {
        result = _bindings!.transcribe(
          _context!.cast(),
          nativeSamples,
          samples.length,
          1,
        );
      }

      if (result == nullptr) {
        return TranscriptionResult(
          text: '',
          languageCode: 'en',
          languageProbability: 0.0,
          isPartial: isPartial,
        );
      }

      try {
        return TranscriptionResult(
          text: result.ref.text.toDartString().trim(),
          languageCode: result.ref.language.toDartString(),
          languageProbability: result.ref.languageProbability,
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
