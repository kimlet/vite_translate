import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';

/// Saves Float32 PCM audio samples to WAV files on disk.
class AudioSaver {
  String? _audioDir;

  Future<String> get audioDir async {
    if (_audioDir != null) return _audioDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _audioDir = '${appDir.path}/audio';
    await Directory(_audioDir!).create(recursive: true);
    return _audioDir!;
  }

  /// Save float32 PCM samples as a 16kHz mono 16-bit WAV file.
  /// Returns the file path.
  Future<String> saveUtterance(Float32List samples, String messageId) async {
    final dir = await audioDir;
    final path = '$dir/$messageId.wav';
    final file = File(path);

    final int16Samples = Int16List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      final clamped = samples[i].clamp(-1.0, 1.0);
      int16Samples[i] = (clamped * 32767).round();
    }

    final dataSize = int16Samples.length * 2;
    final fileSize = 44 + dataSize;

    final header = ByteData(44);
    // RIFF header
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, fileSize - 8, Endian.little);
    header.setUint8(8, 0x57);  // W
    header.setUint8(9, 0x41);  // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E
    // fmt chunk
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // (space)
    header.setUint32(16, 16, Endian.little); // chunk size
    header.setUint16(20, 1, Endian.little); // PCM format
    header.setUint16(22, kChannels, Endian.little);
    header.setUint32(24, kSampleRate, Endian.little);
    header.setUint32(28, kSampleRate * kChannels * 2, Endian.little); // byte rate
    header.setUint16(32, kChannels * 2, Endian.little); // block align
    header.setUint16(34, 16, Endian.little); // bits per sample
    // data chunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little);

    final wavBytes = BytesBuilder();
    wavBytes.add(header.buffer.asUint8List());
    wavBytes.add(int16Samples.buffer.asUint8List());

    await file.writeAsBytes(wavBytes.toBytes());
    debugPrint('[AudioSaver] Saved ${samples.length} samples to $path');
    return path;
  }

  /// Delete all saved audio files.
  Future<void> clearAll() async {
    final dir = await audioDir;
    final d = Directory(dir);
    if (d.existsSync()) {
      await d.delete(recursive: true);
      await d.create();
    }
  }
}
