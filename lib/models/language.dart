class Language {
  final String code; // Whisper ISO 639-1 code
  final String name; // Human-readable name
  final String nllbCode; // NLLB flores200 code

  const Language({
    required this.code,
    required this.name,
    required this.nllbCode,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Language && code == other.code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => '$name ($code)';
}
