/// One transcript line together with the language it was spoken in.
///
/// A meeting transcript is multilingual: every participant's caption is stored
/// in that participant's own language. The backend needs the per-line tag to
/// normalise the transcript with the correct translation pair before it runs
/// the summary or the chatbot — a plain `Name: text` blob loses that.
class TranscriptEntry {
  const TranscriptEntry({
    required this.speaker,
    required this.text,
    required this.lang,
  });

  final String speaker;
  final String text;
  final String lang;

  Map<String, dynamic> toJson() => {
        'speaker': speaker,
        'text': text,
        'lang': lang,
      };

  /// The plain `Name: text` rendering, kept for display and for older
  /// backends that only accept a single transcript string.
  String get line => '$speaker: $text';

  static String renderTranscript(List<TranscriptEntry> entries) =>
      entries.map((e) => e.line).join('\n');
}
