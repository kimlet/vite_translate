import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import '../core/errors.dart';

/// Manages downloading, verifying, and locating ML models.
class ModelManager {
  final Dio _dio = Dio();
  String? _modelsDir;

  Future<String> get modelsDir async {
    if (_modelsDir != null) return _modelsDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _modelsDir = '${appDir.path}/models';
    await Directory(_modelsDir!).create(recursive: true);
    return _modelsDir!;
  }

  /// Check if any whisper model is downloaded.
  Future<bool> isWhisperModelReady() async {
    final path = await getWhisperModelPath();
    if (path == null) return false;
    final file = File(path);
    return file.existsSync() && file.lengthSync() > 1024 * 1024;
  }

  /// Check if the NLLB translation model is downloaded and valid.
  Future<bool> isNllbModelReady() async {
    final dir = await modelsDir;
    final modelDir = Directory('$dir/$kNllbModelDirName');
    if (!modelDir.existsSync()) return false;

    // Check that the required files actually exist
    final encoderFile = File('${modelDir.path}/encoder_model.onnx');
    final spFile = File('${modelDir.path}/sentencepiece.bpe.model');
    return encoderFile.existsSync() && spFile.existsSync();
  }

  /// Get the path to the whisper model file.
  /// Tries tiny first, falls back to base if it exists.
  Future<String?> getWhisperModelPath() async {
    final dir = await modelsDir;
    // Prefer tiny (faster), fall back to base
    for (final name in ['ggml-tiny.bin', 'ggml-base.bin', 'ggml-small.bin']) {
      final file = File('$dir/$name');
      if (file.existsSync() && file.lengthSync() > 1024 * 1024) {
        return file.path;
      }
    }
    // Return the preferred path for download
    return null;
  }

  /// Get the expected download path for the whisper model.
  Future<String> getWhisperModelDownloadPath() async {
    final dir = await modelsDir;
    return '$dir/$kWhisperModelFileName';
  }

  /// Get the path to the NLLB model directory.
  Future<String> getNllbModelDir() async {
    final dir = await modelsDir;
    return '$dir/$kNllbModelDirName';
  }

  /// Download the whisper model with progress callback.
  /// [onProgress] receives values from 0.0 to 1.0.
  Future<void> downloadWhisperModel({
    void Function(double progress)? onProgress,
  }) async {
    final filePath = await getWhisperModelDownloadPath();

    if (await File(filePath).exists()) return;

    try {
      await _dio.download(
        kWhisperModelUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress?.call(received / total);
          }
        },
      );
    } catch (e) {
      // Clean up partial download
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      throw ModelException('Failed to download whisper model: $e');
    }
  }

  /// Download the NLLB model with progress callback.
  /// NOTE: The NLLB ONNX model must be exported first with scripts/export_nllb_onnx.py
  /// and hosted on a CDN, or pushed to the device manually for development.
  Future<void> downloadNllbModel({
    void Function(double progress)? onProgress,
  }) async {
    final dir = await modelsDir;
    final modelDir = '$dir/$kNllbModelDirName';

    if (await isNllbModelReady()) return;

    // Create the directory so the app doesn't crash,
    // but the model files need to be pushed manually for now:
    //   adb push nllb-onnx/ /data/local/tmp/
    //   adb shell run-as com.vibetranslate.vibe_translate \
    //     cp -r /data/local/tmp/nllb-onnx/ files/models/nllb-200-distilled-600M-ct2-int8/
    await Directory(modelDir).create(recursive: true);

    // TODO: Implement actual download from CDN when model is hosted.
    // For now, mark as complete so onboarding can proceed.
    onProgress?.call(1.0);
  }

  /// Get total download size in bytes for models that aren't yet downloaded.
  Future<int> getRemainingDownloadSize() async {
    var total = 0;
    if (!await isWhisperModelReady()) {
      total += 142 * 1024 * 1024; // ~142MB for whisper-base
    }
    if (!await isNllbModelReady()) {
      total += 300 * 1024 * 1024; // ~300MB for NLLB int8
    }
    return total;
  }

  void dispose() {
    _dio.close();
  }
}
