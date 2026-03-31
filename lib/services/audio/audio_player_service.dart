import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays back saved WAV audio files.
class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._();
  factory AudioPlayerService() => _instance;

  AudioPlayerService._() {
    _player.onPlayerComplete.listen((_) {
      final path = _currentPath;
      _currentPath = null;
      if (path != null) {
        _stateController.add(PlaybackEvent(path, false));
      }
    });
  }

  final AudioPlayer _player = AudioPlayer();
  String? _currentPath;

  final _stateController = StreamController<PlaybackEvent>.broadcast();
  Stream<PlaybackEvent> get events => _stateController.stream;
  String? get currentPath => _currentPath;

  /// Play or toggle a WAV file.
  Future<void> play(String filePath) async {
    if (_currentPath == filePath && _player.state == PlayerState.playing) {
      await _player.stop();
      _currentPath = null;
      _stateController.add(PlaybackEvent(filePath, false));
      debugPrint('[AudioPlayer] Stopped: $filePath');
      return;
    }

    await _player.stop();
    _currentPath = filePath;
    _stateController.add(PlaybackEvent(filePath, true));

    debugPrint('[AudioPlayer] Playing: $filePath');
    await _player.play(DeviceFileSource(filePath));
  }

  Future<void> stop() async {
    final path = _currentPath;
    await _player.stop();
    _currentPath = null;
    if (path != null) {
      _stateController.add(PlaybackEvent(path, false));
    }
  }

  void dispose() {
    _player.dispose();
    _stateController.close();
  }
}

class PlaybackEvent {
  final String filePath;
  final bool isPlaying;
  PlaybackEvent(this.filePath, this.isPlaying);
}
