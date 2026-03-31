import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../../core/constants.dart';
import '../../core/errors.dart';

/// Captures raw PCM audio at configurable sample rate, mono 16-bit.
class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<RecordState>? _stateSubscription;
  Stream<Uint8List>? _audioStream;
  bool _isRecording = false;
  int _sampleRate = kSampleRate;

  bool get isRecording => _isRecording;
  int get sampleRate => _sampleRate;

  /// Start recording and return a stream of raw PCM Int16 audio chunks.
  Future<Stream<Uint8List>> startRecording({int? sampleRate}) async {
    _sampleRate = sampleRate ?? kSampleRate;

    debugPrint('[AudioRecorder] Checking microphone permission...');
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      debugPrint('[AudioRecorder] Permission denied!');
      throw AudioException('Microphone permission not granted');
    }
    debugPrint('[AudioRecorder] Permission granted, starting stream...');

    _audioStream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: kChannels,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      ),
    );

    _isRecording = true;
    debugPrint('[AudioRecorder] Stream started (${_sampleRate}Hz, ${kChannels}ch, PCM16)');
    return _audioStream!;
  }

  Future<void> stopRecording() async {
    if (_isRecording) {
      await _recorder.stop();
      _isRecording = false;
    }
  }

  Future<void> dispose() async {
    await _stateSubscription?.cancel();
    await stopRecording();
    _recorder.dispose();
  }
}
