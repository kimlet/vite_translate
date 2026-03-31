import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../core/constants.dart';

enum VadState { silence, speech }

/// Simple energy-based Voice Activity Detection.
/// Computes RMS energy per frame and uses a threshold with hangover timer.
class VadService {
  final double energyThreshold;
  final int silenceTimeoutMs;

  VadState _state = VadState.silence;
  int _silenceFrameCount = 0;
  int _speechFrameCount = 0;

  VadState get state => _state;

  VadService({
    this.energyThreshold = kVadEnergyThreshold,
    this.silenceTimeoutMs = kVadSilenceThresholdMs,
  });

  /// Process a frame of PCM Int16 audio samples.
  /// Returns the current VAD state after processing.
  VadState processFrame(Int16List frame) {
    final energy = _computeRmsEnergy(frame);
    final isSpeech = energy > energyThreshold;

    switch (_state) {
      case VadState.silence:
        if (isSpeech) {
          _speechFrameCount++;
          if (_speechFrameCount >= 3) {
            _state = VadState.speech;
            _silenceFrameCount = 0;
            debugPrint('[VAD] Speech START (energy: ${energy.toStringAsFixed(4)})');
          }
        } else {
          _speechFrameCount = 0;
        }
      case VadState.speech:
        if (!isSpeech) {
          _silenceFrameCount++;
          final silenceDurationMs =
              _silenceFrameCount * kVadFrameDurationMs;
          if (silenceDurationMs >= silenceTimeoutMs) {
            _state = VadState.silence;
            _speechFrameCount = 0;
            debugPrint('[VAD] Speech END (silence: ${silenceDurationMs}ms)');
          }
        } else {
          _silenceFrameCount = 0;
        }
    }

    return _state;
  }

  void reset() {
    _state = VadState.silence;
    _silenceFrameCount = 0;
    _speechFrameCount = 0;
  }

  double _computeRmsEnergy(Int16List frame) {
    if (frame.isEmpty) return 0.0;
    double sumSquares = 0.0;
    for (final sample in frame) {
      final normalized = sample / 32768.0;
      sumSquares += normalized * normalized;
    }
    return sqrt(sumSquares / frame.length);
  }
}
