class TranscriptionResult {
  final String text;
  final String languageCode; // Whisper ISO 639-1 code
  final double languageProbability;
  final bool isPartial;

  const TranscriptionResult({
    required this.text,
    required this.languageCode,
    required this.languageProbability,
    required this.isPartial,
  });

  bool get isEmpty => text.trim().isEmpty;
}
