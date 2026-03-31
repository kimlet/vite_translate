class WhisperException implements Exception {
  final String message;
  WhisperException(this.message);

  @override
  String toString() => 'WhisperException: $message';
}

class TranslationException implements Exception {
  final String message;
  TranslationException(this.message);

  @override
  String toString() => 'TranslationException: $message';
}

class AudioException implements Exception {
  final String message;
  AudioException(this.message);

  @override
  String toString() => 'AudioException: $message';
}

class ModelException implements Exception {
  final String message;
  ModelException(this.message);

  @override
  String toString() => 'ModelException: $message';
}
