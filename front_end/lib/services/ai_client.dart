import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../app_config.dart';
import 'transcript_entry.dart';

export 'transcript_entry.dart';

/// ISO language codes supported by the FastAPI backend (`app/core/languages.py`).
/// Pakistan-focused set: English, Urdu (must), Arabic, Hindi.
class LangCodes {
  static const Map<String, String> nameToCode = {
    'English': 'en',
    'Urdu': 'ur',
    'Arabic': 'ar',
    'Hindi': 'hi',
  };

  static const List<String> displayNames = [
    'English',
    'Urdu',
    'Arabic',
    'Hindi',
  ];

  static String toIso(String nameOrCode) {
    final trimmed = nameOrCode.trim();
    if (trimmed.length <= 3 && trimmed == trimmed.toLowerCase()) {
      return trimmed;
    }
    return nameToCode[trimmed] ?? trimmed.toLowerCase();
  }
}

class AiPipelineResult {
  final String transcript;
  final String translation;
  final String? detectedLanguage;
  final String? ttsAudioUrl;
  final Uint8List? ttsAudio;
  final String? ttsMime;

  const AiPipelineResult({
    required this.transcript,
    required this.translation,
    this.detectedLanguage,
    this.ttsAudioUrl,
    this.ttsAudio,
    this.ttsMime,
  });
}

class AiTranslateResult {
  final String sourceLanguage;
  final String targetLanguage;
  final String sourceText;
  final String translatedText;

  const AiTranslateResult({
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.sourceText,
    required this.translatedText,
  });
}

class AiSummarizeResult {
  final String? meetingId;
  final String summary;
  final List<String> keyPoints;
  final List<String> actionItems;

  /// Language the fields above are written in (ISO-639-1).
  final String language;
  final String raw;

  const AiSummarizeResult({
    required this.meetingId,
    required this.summary,
    required this.keyPoints,
    required this.actionItems,
    required this.raw,
    this.language = 'en',
  });
}

class AiChatResult {
  final String question;
  final String answer;
  final String? meetingId;

  /// Language the answer is written in (ISO-639-1).
  final String language;
  final bool usedSampleTranscript;

  const AiChatResult({
    required this.question,
    required this.answer,
    this.meetingId,
    this.language = 'en',
    this.usedSampleTranscript = false,
  });
}

/// HTTP client for the real ConvoBridge FastAPI backend (`app/`).
class AiClient {
  AiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  Uri _uri(String path) {
    final base = AppConfig.aiServerBaseUrl.replaceAll(RegExp(r'/$'), '');
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$normalized');
  }

  Map<String, String> _headers({bool json = false}) {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (json) {
      headers['Content-Type'] = 'application/json';
    }
    if (AppConfig.isNgrok) {
      headers['ngrok-skip-browser-warning'] = 'true';
    }
    return headers;
  }

  Future<Map<String, dynamic>> health() async {
    final res = await _http.get(_uri('/health'), headers: _headers());
    _ensureOk(res.statusCode, res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Live speech pipeline: denoise → STT → translate → optional TTS.
  ///
  /// Calls real backend `POST /pipeline/process`.
  Future<AiPipelineResult> pipeline({
    required Uint8List audioBytes,
    required String srcLang,
    required String tgtLang,
    bool includeTts = false,
    bool denoise = true,
    String filename = 'audio.wav',
  }) async {
    final req = http.MultipartRequest('POST', _uri('/pipeline/process'));
    req.headers.addAll(_headers());
    req.fields['target_language'] = LangCodes.toIso(tgtLang);
    req.fields['source_language'] = LangCodes.toIso(srcLang);
    req.fields['denoise'] = denoise ? 'true' : 'false';
    req.fields['synthesize_speech'] = includeTts ? 'true' : 'false';
    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        audioBytes,
        filename: filename,
      ),
    );

    final streamed = await _http.send(req);
    final body = await streamed.stream.bytesToString();
    _ensureOk(streamed.statusCode, body);

    final json = jsonDecode(body) as Map<String, dynamic>;
    final transcript = (json['transcript'] as String?) ?? '';
    final translation = (json['translated_text'] as String?) ?? '';
    final ttsPath = json['tts_audio_url'] as String?;

    Uint8List? ttsAudio;
    String? ttsMime;
    if (includeTts && ttsPath != null && ttsPath.isNotEmpty) {
      final audio = await downloadMedia(ttsPath);
      ttsAudio = audio;
      ttsMime = 'audio/wav';
    }

    return AiPipelineResult(
      transcript: transcript,
      translation: translation,
      detectedLanguage: json['detected_language'] as String?,
      ttsAudioUrl: ttsPath,
      ttsAudio: ttsAudio,
      ttsMime: ttsMime,
    );
  }

  /// Speech-to-text only via `POST /stt/transcribe` (faster than full pipeline).
  Future<String> transcribe({
    required Uint8List audioBytes,
    String? language,
    bool denoise = false,
    String filename = 'audio.wav',
  }) async {
    final req = http.MultipartRequest('POST', _uri('/stt/transcribe'));
    req.headers.addAll(_headers());
    if (language != null && language.trim().isNotEmpty) {
      req.fields['language'] = LangCodes.toIso(language);
    }
    req.fields['denoise'] = denoise ? 'true' : 'false';
    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        audioBytes,
        filename: filename,
      ),
    );

    final streamed = await _http.send(req);
    final body = await streamed.stream.bytesToString();
    _ensureOk(streamed.statusCode, body);
    final json = jsonDecode(body) as Map<String, dynamic>;
    return (json['text'] as String?) ??
        (json['transcript'] as String?) ??
        '';
  }

  /// Download a media path returned by the backend (e.g. `/media/tts/x.wav`).
  Future<Uint8List> downloadMedia(String relativeOrAbsoluteUrl) async {
    final uri = relativeOrAbsoluteUrl.startsWith('http')
        ? Uri.parse(relativeOrAbsoluteUrl)
        : _uri(relativeOrAbsoluteUrl);
    final res = await _http.get(uri, headers: _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError(
        'Media download failed (${res.statusCode}): ${res.body}',
      );
    }
    return res.bodyBytes;
  }

  /// Text translation via `POST /translate`.
  Future<AiTranslateResult> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final res = await _http.post(
      _uri('/translate'),
      headers: _headers(json: true),
      body: jsonEncode({
        'text': text,
        'source_language': LangCodes.toIso(sourceLanguage),
        'target_language': LangCodes.toIso(targetLanguage),
      }),
    );
    _ensureOk(res.statusCode, res.body);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return AiTranslateResult(
      sourceLanguage: (json['source_language'] as String?) ?? sourceLanguage,
      targetLanguage: (json['target_language'] as String?) ?? targetLanguage,
      sourceText: (json['source_text'] as String?) ?? text,
      translatedText: (json['translated_text'] as String?) ?? '',
    );
  }

  /// Meeting summarization via `POST /summarize`.
  ///
  /// [language] is the language the summary must be written in (the language
  /// the user picked in the meeting). [utterances] carries each line's spoken
  /// language so the backend can normalise a mixed-language transcript.
  Future<AiSummarizeResult> summarize({
    required String transcript,
    String? meetingId,
    String? language,
    List<TranscriptEntry>? utterances,
  }) async {
    final payload = <String, dynamic>{
      'transcript': transcript,
      if (meetingId != null) 'meeting_id': meetingId,
      if (language != null) 'language': LangCodes.toIso(language),
      if (utterances != null && utterances.isNotEmpty)
        'utterances': utterances.map((e) => e.toJson()).toList(),
    };
    final res = await _http.post(
      _uri('/summarize'),
      headers: _headers(json: true),
      body: jsonEncode(payload),
    );
    _ensureOk(res.statusCode, res.body);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return AiSummarizeResult(
      meetingId: json['meeting_id'] as String?,
      summary: (json['summary'] as String?) ?? '',
      keyPoints: (json['key_points'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      actionItems: (json['action_items'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      language: (json['language'] as String?) ?? 'en',
      raw: (json['raw'] as String?) ?? '',
    );
  }

  /// Meeting Q&A chatbot via `POST /chatbot/ask`.
  ///
  /// [language] forces the answer language; when omitted the backend answers
  /// in whatever language the question was typed in.
  Future<AiChatResult> askChatbot({
    required String question,
    String? transcript,
    String? meetingId,
    String? language,
    List<TranscriptEntry>? utterances,
  }) async {
    final payload = <String, dynamic>{
      'question': question,
      if (transcript != null && transcript.trim().isNotEmpty)
        'transcript': transcript,
      if (meetingId != null) 'meeting_id': meetingId,
      if (language != null) 'language': LangCodes.toIso(language),
      if (utterances != null && utterances.isNotEmpty)
        'utterances': utterances.map((e) => e.toJson()).toList(),
    };
    final res = await _http.post(
      _uri('/chatbot/ask'),
      headers: _headers(json: true),
      body: jsonEncode(payload),
    );
    _ensureOk(res.statusCode, res.body);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return AiChatResult(
      question: (json['question'] as String?) ?? question,
      answer: (json['answer'] as String?) ?? '',
      meetingId: json['meeting_id'] as String?,
      language: (json['language'] as String?) ?? 'en',
      usedSampleTranscript: json['used_sample_transcript'] as bool? ?? false,
    );
  }

  void _ensureOk(int statusCode, String body) {
    if (statusCode < 200 || statusCode >= 300) {
      throw StateError('AI server error ($statusCode): $body');
    }
  }
}
