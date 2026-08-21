import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'stage_log.dart';

/// On-device speech via the phone TTS engine (replaces backend XTTS).
///
/// Hardened for Android 11+ and Agora calls:
/// * requests audio focus while speaking
/// * prefers Google TTS when installed
/// * verifies language availability before speak
/// * longer timeouts so Urdu/Arabic lines are not cut off
class DeviceTts {
  DeviceTts() {
    _ready = _init();
  }

  final FlutterTts _tts = FlutterTts();
  late final Future<void> _ready;

  final Set<String> _available = <String>{};
  final Set<String> _warned = <String>{};
  bool _engineReady = false;

  static const Map<String, List<String>> _localeCandidates = {
    'en': ['en-US', 'en-GB', 'en-IN', 'en'],
    // Urdu voice is often missing; Hindi can read Arabic-script poorly but
    // is better than silent. Prefer real Urdu locales first.
    'ur': ['ur-PK', 'ur-IN', 'ur', 'hi-IN', 'hi'],
    'ar': ['ar-SA', 'ar-EG', 'ar-AE', 'ar'],
    'hi': ['hi-IN', 'hi'],
  };

  Future<void> _init() async {
    try {
      await _tts.setSharedInstance(true);
      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(0.42);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.setQueueMode(1);

      if (Platform.isAndroid) {
        await _preferGoogleEngine();
      }

      await _refreshLanguages();
      _engineReady = true;
      StageLog.step('TTS', 'Engine ready', {
        'locales': _available.length,
      });
    } catch (e) {
      StageLog.step('TTS', 'Init error: $e');
      debugPrint('DeviceTts init error: $e');
    }
  }

  Future<void> _preferGoogleEngine() async {
    try {
      final engines = await _tts.getEngines;
      if (engines is! List) return;
      final names = engines.map((e) => e.toString()).toList();
      const preferred = 'com.google.android.tts';
      if (names.any((e) => e.contains(preferred))) {
        await _tts.setEngine(preferred);
        StageLog.step('TTS', 'Using Google TTS engine');
      } else if (names.isNotEmpty) {
        await _tts.setEngine(names.first);
        StageLog.step('TTS', 'Using TTS engine', {'engine': names.first});
      }
    } catch (e) {
      debugPrint('DeviceTts setEngine failed: $e');
    }
  }

  Future<void> _refreshLanguages() async {
    _available.clear();
    try {
      final languages = await _tts.getLanguages;
      if (languages is List) {
        for (final entry in languages) {
          _available.add(_norm(entry.toString()));
        }
      }
    } catch (e) {
      debugPrint('DeviceTts getLanguages failed: $e');
    }
  }

  static String _norm(String value) =>
      value.trim().toLowerCase().replaceAll('_', '-');

  bool supports(String language) => _resolveLocale(language) != null;

  Set<String> get availableLocales => Set.unmodifiable(_available);

  String? _resolveLocale(String language) {
    final candidates = _localeCandidates[language] ?? [language];
    if (_available.isEmpty) return candidates.first;

    for (final candidate in candidates) {
      final n = _norm(candidate);
      if (_available.contains(n)) return candidate;
    }

    final prefix = _norm(language);
    for (final locale in _available) {
      if (locale == prefix || locale.startsWith('$prefix-')) {
        return locale;
      }
    }
    return null;
  }

  Future<String?> _pickWorkingLocale(String language) async {
    final candidates = <String>[
      ...?_localeCandidates[language],
      if (_resolveLocale(language) != null) _resolveLocale(language)!,
    ];
    // De-dupe while preserving order.
    final seen = <String>{};
    for (final raw in candidates) {
      final candidate = raw;
      if (!seen.add(_norm(candidate))) continue;
      try {
        final ok = await _tts.isLanguageAvailable(candidate);
        final available = ok == true || ok == 1 || ok == '1';
        if (available) return candidate;
      } catch (_) {
        // Some engines throw; fall through to setLanguage try.
        return candidate;
      }
    }
    return _resolveLocale(language);
  }

  Duration _timeoutFor(String text, String language) {
    // Urdu/Arabic/Hindi need more time at our slower speech rate.
    final slow = language == 'ur' || language == 'ar' || language == 'hi';
    final divisor = slow ? 6 : 10;
    final minSec = slow ? 12 : 6;
    final sec = (text.length / divisor).ceil().clamp(minSec, 60);
    return Duration(seconds: sec);
  }

  /// Speak [text] in [language], waiting until playback finishes or times out.
  Future<bool> speak(String text, String language) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    await _ready;
    if (!_engineReady) {
      StageLog.step('TTS', 'Engine not ready — retrying init');
      await _init();
    }

    // Refresh once if we looked empty at startup (common on cold start).
    if (_available.isEmpty) await _refreshLanguages();

    var locale = await _pickWorkingLocale(language);
    if (locale == null) {
      if (_warned.add(language)) {
        StageLog.step('TTS', 'No voice installed for $language', {
          'available': _available.take(12).join(','),
        });
        debugPrint(
          'DeviceTts: no installed voice for "$language". Install the '
          'language in Settings > Text-to-speech output. '
          'Available: ${_available.join(", ")}',
        );
      }
      // Last resort: still try default locale so something is heard.
      locale = _localeCandidates[language]?.first ?? 'en-US';
    }

    final done = Completer<void>();
    void completeOk() {
      if (!done.isCompleted) done.complete();
    }

    void completeErr(dynamic msg) {
      if (!done.isCompleted) {
        done.completeError(StateError('TTS error: $msg'));
      }
    }

    _tts.setCompletionHandler(completeOk);
    _tts.setCancelHandler(completeOk);
    _tts.setErrorHandler(completeErr);

    try {
      await _tts.stop();
      final langResult = await _tts.setLanguage(locale);
      final langOk = langResult == 1 || langResult == true || langResult == '1';
      if (!langOk) {
        StageLog.step('TTS', 'setLanguage failed, trying anyway', {
          'locale': locale,
          'result': '$langResult',
        });
      }

      StageLog.step('TTS', 'Speaking', {
        'locale': locale,
        'chars': trimmed.length,
      });

      // focus:true is Android-only — requests audio focus over Agora/call audio.
      final dynamic speakResult = Platform.isAndroid
          ? await _tts.speak(trimmed, focus: true)
          : await _tts.speak(trimmed);

      if (speakResult == 0 || speakResult == false) {
        StageLog.step('TTS', 'speak() returned failure — retry once');
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final retry = Platform.isAndroid
            ? await _tts.speak(trimmed, focus: true)
            : await _tts.speak(trimmed);
        if (retry == 0 || retry == false) {
          StageLog.step('TTS', 'speak() failed again');
          return false;
        }
      }

      await done.future.timeout(_timeoutFor(trimmed, language));
      StageLog.step('TTS', 'Playback finished', {'locale': locale});
      return true;
    } on TimeoutException {
      // Do NOT force-stop immediately — audio may still be playing; give a
      // short grace period then stop so the mic can resume.
      StageLog.step('TTS', 'Completion timed out — grace stop', {
        'locale': locale,
      });
      await Future<void>.delayed(const Duration(milliseconds: 400));
      try {
        await _tts.stop();
      } catch (_) {}
      return true;
    } catch (e) {
      StageLog.step('TTS', 'Speak error: $e', {'locale': locale});
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
