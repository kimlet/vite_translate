class ConversationMessage {
  final String id;
  final String originalText;
  final String translatedText;
  final String detectedLanguage;
  final String targetLanguage;
  final bool isPrimaryLanguageSpeaker;
  final DateTime timestamp;
  final String? audioPath; // Path to saved WAV file

  const ConversationMessage({
    required this.id,
    required this.originalText,
    required this.translatedText,
    required this.detectedLanguage,
    required this.targetLanguage,
    required this.isPrimaryLanguageSpeaker,
    required this.timestamp,
    this.audioPath,
  });

  bool get needsTranslation => detectedLanguage != targetLanguage;
  bool get hasAudio => audioPath != null;
}
