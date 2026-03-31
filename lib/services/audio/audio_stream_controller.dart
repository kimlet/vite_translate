import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../core/constants.dart';
import 'vad_service.dart';

/// Manages the audio stream, applies VAD, and emits complete utterances.
class AudioStreamController {
  final VadService _vad = VadService();
  final List<Int16List> _speechBuffer = [];
  final _utteranceController = StreamController<Float32List>.broadcast();
  final _partialController = StreamController<Float32List>.broadcast();

  VadState _previousState = VadState.silence;
  int _samplesInBuffer = 0;
  Timer? _partialTimer;
  int _inputSampleRate = kSampleRate; // actual recording rate

  void setInputSampleRate(int rate) {
    _inputSampleRate = rate;
    debugPrint('[AudioStream] Input sample rate set to ${rate}Hz');
  }

  /// Stream of complete utterances (after speech ends).
  Stream<Float32List> get utteranceStream => _utteranceController.stream;

  /// Stream of partial audio (for partial transcription while speaking).
  Stream<Float32List> get partialStream => _partialController.stream;

  int _chunkCount = 0;

  /// Process incoming raw PCM Uint8List from the recorder.
  void processAudioChunk(Uint8List rawBytes) {
    _chunkCount++;
    if (_chunkCount == 1 || _chunkCount % 100 == 0) {
      debugPrint('[AudioStream] Chunk #$_chunkCount received (${rawBytes.length} bytes)');
    }
    // Convert Uint8List to Int16List (copy to ensure alignment)
    final evenLength = rawBytes.length - (rawBytes.length % 2);
    if (evenLength < 2) return;
    final aligned = Uint8List.fromList(rawBytes.sublist(0, evenLength));
    final int16Data = aligned.buffer.asInt16List();

    // Process through VAD in frames
    final frameSamples = kSampleRate * kVadFrameDurationMs ~/ 1000;
    for (var i = 0; i < int16Data.length; i += frameSamples) {
      final end =
          (i + frameSamples > int16Data.length)
              ? int16Data.length
              : i + frameSamples;
      final frame = Int16List.sublistView(int16Data, i, end);
      final currentState = _vad.processFrame(frame);

      if (currentState == VadState.speech) {
        _speechBuffer.add(Int16List.fromList(frame));
        _samplesInBuffer += frame.length;

        // Start partial transcription timer if not running
        _partialTimer ??= Timer.periodic(
          const Duration(milliseconds: kPartialTranscriptionIntervalMs),
          (_) => _emitPartial(),
        );
      }

      // Transition from speech -> silence: emit complete utterance
      if (_previousState == VadState.speech &&
          currentState == VadState.silence) {
        _emitUtterance();
      }

      _previousState = currentState;
    }
  }

  void _emitPartial() {
    if (_speechBuffer.isEmpty) return;
    final floatData = _bufferToFloat32();
    if (floatData.isNotEmpty) {
      _partialController.add(floatData);
    }
  }

  void _emitUtterance() {
    _partialTimer?.cancel();
    _partialTimer = null;

    if (_speechBuffer.isEmpty) return;

    // Only emit if we have enough audio (at least 0.5 seconds)
    if (_samplesInBuffer < kSampleRate ~/ 2) {
      debugPrint('[AudioStream] Utterance too short ($_samplesInBuffer samples), discarding');
      _speechBuffer.clear();
      _samplesInBuffer = 0;
      return;
    }

    final floatData = _bufferToFloat32();
    final durationSec = floatData.length / kSampleRate;
    debugPrint('[AudioStream] Emitting utterance: ${floatData.length} samples (${durationSec.toStringAsFixed(1)}s)');
    _speechBuffer.clear();
    _samplesInBuffer = 0;

    if (floatData.isNotEmpty) {
      _utteranceController.add(floatData);
    }
  }

  Float32List _bufferToFloat32() {
    final totalSamples = _speechBuffer.fold<int>(
      0,
      (sum, chunk) => sum + chunk.length,
    );
    final raw = Float32List(totalSamples);
    var offset = 0;
    for (final chunk in _speechBuffer) {
      for (var i = 0; i < chunk.length; i++) {
        raw[offset + i] = chunk[i] / 32768.0;
      }
      offset += chunk.length;
    }

    // Resample to 16kHz if needed (whisper requires 16kHz)
    if (_inputSampleRate != kSampleRate && _inputSampleRate > 0) {
      return _resample(raw, _inputSampleRate, kSampleRate);
    }
    return raw;
  }

  /// Simple linear interpolation resampler.
  static Float32List _resample(Float32List input, int fromRate, int toRate) {
    if (fromRate == toRate) return input;
    final ratio = fromRate / toRate;
    final outputLen = (input.length / ratio).floor();
    final output = Float32List(outputLen);
    for (var i = 0; i < outputLen; i++) {
      final srcIdx = i * ratio;
      final idx0 = srcIdx.floor();
      final idx1 = (idx0 + 1).clamp(0, input.length - 1);
      final frac = srcIdx - idx0;
      output[i] = input[idx0] * (1.0 - frac) + input[idx1] * frac;
    }
    return output;
  }

  void reset() {
    _partialTimer?.cancel();
    _partialTimer = null;
    _speechBuffer.clear();
    _samplesInBuffer = 0;
    _vad.reset();
    _previousState = VadState.silence;
  }

  void dispose() {
    reset();
    _utteranceController.close();
    _partialController.close();
  }
}
