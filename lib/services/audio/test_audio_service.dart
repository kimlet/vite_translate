import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Loads test WAV audio files from assets and converts to Float32 PCM
/// samples suitable for whisper.cpp input.
class TestAudioService {
  /// Load a WAV file from assets and return Float32List of PCM samples.
  /// The WAV must be 16kHz mono 16-bit PCM.
  static Future<Float32List> loadWavAsset(String assetPath) async {
    debugPrint('[TestAudio] Loading asset: $assetPath');
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();

    // Parse WAV header (44 bytes for standard PCM WAV)
    if (bytes.length < 44) {
      throw Exception('WAV file too small');
    }

    // Verify RIFF header
    final riff = String.fromCharCodes(bytes.sublist(0, 4));
    final wave = String.fromCharCodes(bytes.sublist(8, 12));
    if (riff != 'RIFF' || wave != 'WAVE') {
      throw Exception('Not a valid WAV file (got: $riff / $wave)');
    }

    // Read format info
    final audioFormat = bytes.buffer.asByteData().getUint16(20, Endian.little);
    final numChannels = bytes.buffer.asByteData().getUint16(22, Endian.little);
    final sampleRate = bytes.buffer.asByteData().getUint32(24, Endian.little);
    final bitsPerSample = bytes.buffer.asByteData().getUint16(34, Endian.little);

    debugPrint('[TestAudio] WAV: ${sampleRate}Hz, ${numChannels}ch, '
        '${bitsPerSample}bit, format=$audioFormat');

    if (audioFormat != 1) {
      throw Exception('Only PCM WAV supported (got format: $audioFormat)');
    }

    // Find data chunk
    var dataOffset = 12;
    while (dataOffset < bytes.length - 8) {
      final chunkId = String.fromCharCodes(bytes.sublist(dataOffset, dataOffset + 4));
      final chunkSize = bytes.buffer.asByteData().getUint32(dataOffset + 4, Endian.little);
      if (chunkId == 'data') {
        dataOffset += 8;
        break;
      }
      dataOffset += 8 + chunkSize;
    }

    // Convert Int16 PCM to Float32
    final pcmBytes = bytes.sublist(dataOffset);
    final evenLength = pcmBytes.length - (pcmBytes.length % 2);
    final aligned = Uint8List.fromList(pcmBytes.sublist(0, evenLength));
    final int16Samples = aligned.buffer.asInt16List();
    final float32Samples = Float32List(int16Samples.length);

    for (var i = 0; i < int16Samples.length; i++) {
      float32Samples[i] = int16Samples[i] / 32768.0;
    }

    final durationSec = float32Samples.length / sampleRate;
    debugPrint('[TestAudio] Loaded ${float32Samples.length} samples '
        '(${durationSec.toStringAsFixed(1)}s)');

    return float32Samples;
  }
}
