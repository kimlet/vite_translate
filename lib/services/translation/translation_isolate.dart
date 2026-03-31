import 'dart:async';

import 'translation_service.dart';

/// Wraps TranslationService with async interface.
/// Since flutter_onnxruntime is already async (platform channels),
/// we don't need a separate Dart isolate — just a clean async wrapper.
class TranslationIsolate {
  TranslationService? _service;

  bool get isInitialized => _service?.isInitialized ?? false;

  Future<void> initialize(String modelDir) async {
    _service = TranslationService();
    await _service!.initialize(modelDir);
  }

  Future<String> translate(
    String text,
    String srcLang,
    String tgtLang,
  ) async {
    if (_service == null || !_service!.isInitialized) {
      throw StateError('TranslationIsolate not initialized');
    }
    return _service!.translate(text, srcLang, tgtLang);
  }

  void dispose() {
    _service?.dispose();
    _service = null;
  }
}
