class ConversationMessage {
  final String id;
  final String originalText;
  final String translatedText;
  final String detectedLanguage; // Whisper ISO 639-1 code
  final String targetLanguage; // Whisper ISO 639-1 code
  final bool isPrimaryLanguageSpeaker;
  final DateTime timestamp;

  const ConversationMessage({
    required this.id,
    required this.originalText,
    required this.translatedText,
    required this.detectedLanguage,
    required this.targetLanguage,
    required this.isPrimaryLanguageSpeaker,
    required this.timestamp,
  });

  bool get needsTranslation => detectedLanguage != targetLanguage;
}
