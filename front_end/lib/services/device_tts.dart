import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// On-device speech via the phone TTS engine (replaces backend XTTS).
///
/// [speak] waits until playback finishes (with a hard timeout) so a stuck
/// Android TTS engine cannot leave the meeting mic paused forever.
class DeviceTts {
  DeviceTts() {
    _ready = _init();
  }

  final FlutterTts _tts = FlutterTts();
  late final Future<void> _ready;

  final Set<String> _available = <String>{};
  final Set<String> _warned = <String>{};

  static const Map<String, List<String>> _localeCandidates = {
    'en': ['en-US', 'en-GB', 'en-IN'],
    'ur': ['ur-PK', 'ur-IN'],
    'ar': ['ar-SA', 'ar-EG', 'ar-AE'],
    'hi': ['hi-IN'],
  };

  Future<void> _init() async {
    try {
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
    } catch (e) {
      debugPrint('DeviceTts init error: $e');
    }

    try {
      final languages = await _tts.getLanguages;
      if (languages is List) {
        for (final entry in languages) {
          _available.add(entry.toString().toLowerCase());
        }
      }
    } catch (e) {
      debugPrint('DeviceTts getLanguages failed: $e');
    }
  }

  bool supports(String language) => _resolveLocale(language) != null;

  Set<String> get availableLocales => Set.unmodifiable(_available);

  String? _resolveLocale(String language) {
    final candidates = _localeCandidates[language] ?? [language];
    if (_available.isEmpty) return candidates.first;

    for (final candidate in candidates) {
      if (_available.contains(candidate.toLowerCase())) return candidate;
    }

    final prefix = language.toLowerCase();
    for (final locale in _available) {
      if (locale == prefix ||
          locale.startsWith('$prefix-') ||
          locale.startsWith('${prefix}_')) {
        return locale;
      }
    }
    return null;
  }

  Duration _timeoutFor(String text) {
    // ~12 chars/sec speaking + buffer; clamp so we never hang the mic.
    final sec = (text.length / 10).ceil().clamp(4, 25);
    return Duration(seconds: sec);
  }

  /// Speak [text] in [language], waiting until playback finishes or times out.
  Future<bool> speak(String text, String language) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    await _ready;

    final locale = _resolveLocale(language);
    if (locale == null) {
      if (_warned.add(language)) {
        debugPrint(
          'DeviceTts: no installed voice for "$language". Install the '
          'language in Settings > Text-to-speech output. Captions still work. '
          'Available: ${_available.join(", ")}',
        );
      }
      return false;
    }

    try {
      await _tts.stop();
      await _tts.setLanguage(locale);
      await _tts.speak(trimmed).timeout(_timeoutFor(trimmed));
      return true;
    } on TimeoutException {
      debugPrint('DeviceTts speak timed out ($locale); forcing stop');
      try {
        await _tts.stop();
      } catch (_) {}
      return true;
    } catch (e) {
      debugPrint('DeviceTts speak error ($locale): $e');
      try {
        await _tts.stop();
      } catch (_) {}
      return false;
    }
  }

  Future<void> stop() async {
    await _ready;
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
