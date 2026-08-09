import 'dart:async';
import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'ai_client.dart';
import 'device_tts.dart';
import 'room_utterances.dart';
import 'stage_log.dart';

/// The receiving half of the meeting pipeline.
///
/// Listens for utterances published by the **other** participants, translates
/// each one into *my* preferred language, then shows it as a caption and
/// speaks it through the phone's TTS engine.
///
/// Playback is strictly serialized: two people talking at once produce two
/// queued utterances, never two overlapping voices. The mic is paused only
/// for each individual TTS play so the listener can answer between sentences.
class MeetingTranslationBus {
  MeetingTranslationBus({
    required RoomUtterances room,
    AiClient? ai,
    DeviceTts? tts,
    this.onCaption,
    this.onSpeakingChanged,
    this.onError,
  })  : _room = room,
        _ai = ai ?? AiClient(),
        _tts = tts ?? DeviceTts();

  /// Never let a backlog build up: an old sentence spoken a minute late is
  /// worse than dropping it.
  static const int maxQueued = 4;

  final RoomUtterances _room;
  final AiClient _ai;
  final DeviceTts _tts;

  /// (speakerName, textInMyLanguage, originalText)
  final void Function(String speaker, String translated, String original)?
      onCaption;

  /// True while translated speech is actually playing.
  final void Function(bool speaking)? onSpeakingChanged;

  final void Function(Object error)? onError;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  final Queue<Utterance> _queue = Queue<Utterance>();
  final Set<String> _seen = <String>{};

  String _myLang = 'en';
  String _myUid = '';
  String _lastSpokenNorm = '';
  bool _primed = false;
  bool _working = false;
  bool _disposed = false;

  /// When false, captions still appear but nothing is spoken.
  bool speakEnabled = true;

  bool get isSpeaking => _working;

  void start({required String myLang}) {
    // Allow restart after dispose()/endCall races (calls hit this often).
    _disposed = false;
    _primed = false;
    _working = false;
    _queue.clear();
    _lastSpokenNorm = '';
    _myLang = myLang;
    _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _sub?.cancel();
    StageLog.step('BUS', 'Listening for remote utterances', {'myLang': myLang});
    _sub = _room.watch().listen(
      _onSnapshot,
      onError: (Object e) {
        StageLog.step('BUS', 'Firestore stream error: $e');
        debugPrint('MeetingTranslationBus stream error: $e');
        onError?.call(e);
      },
    );
  }

  void setMyLanguage(String lang) {
    _myLang = lang;
  }

  Future<void> dispose() async {
    _disposed = true;
    await _sub?.cancel();
    _sub = null;
    _queue.clear();
    _working = false;
    await _tts.stop();
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    for (final change in snap.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      final data = change.doc.data();
      if (data == null) continue;

      final u = Utterance.fromJson(change.doc.id, data);
      if (_seen.contains(u.id)) continue;
      _seen.add(u.id);

      // First snapshot is the backlog from before I joined — mark it seen but
      // do not replay it into my ear.
      if (!_primed) continue;
      if (u.speakerUid == _myUid) continue;
      if (u.text.trim().isEmpty) continue;

      _queue.add(u);
      while (_queue.length > maxQueued) {
        _queue.removeFirst();
      }
    }
    _primed = true;
    unawaited(_pump());
  }

  Future<void> _pump() async {
    if (_working || _disposed) return;
    _working = true;

    try {
      while (_queue.isNotEmpty && !_disposed) {
        final u = _queue.removeFirst();
        final original = u.text.trim();

        String translated = original;
        StageLog.step('BUS', 'Remote utterance received', {
          'from': u.speakerName,
          'lang': u.lang,
        });
        if (u.lang != _myLang) {
          try {
            StageLog.step('TRANSLATE', 'POST /translate', {
              'from': u.lang,
              'to': _myLang,
            });
            final res = await _ai.translate(
              text: original,
              sourceLanguage: u.lang,
              targetLanguage: _myLang,
            );
            final out = res.translatedText.trim();
            if (out.isNotEmpty) translated = out;
            StageLog.step('TRANSLATE', 'Done for caption/TTS');
          } catch (e) {
            StageLog.step('TRANSLATE', 'Failed: $e');
            debugPrint('MeetingTranslationBus translate error: $e');
            onError?.call(e);
          }
        }

        if (_disposed) break;

        final spokenNorm = _normalize(translated);
        // Skip Firestore redelivery / identical back-to-back lines.
        if (spokenNorm.isNotEmpty && spokenNorm == _lastSpokenNorm) {
          debugPrint('MeetingTranslationBus skip duplicate: $translated');
          continue;
        }

        onCaption?.call(u.speakerName, translated, original);

        if (speakEnabled && translated.isNotEmpty) {
          // Pause mic only for this one TTS play so the listener can answer
          // as soon as this sentence finishes (two-way conversation).
          StageLog.step('TTS', 'Speaking on device', {'lang': _myLang});
          onSpeakingChanged?.call(true);
          try {
            // DeviceTts already waits for completion + audio focus.
            final ok = await _tts.speak(translated, _myLang);
            if (!ok) {
              StageLog.step(
                'TTS',
                'Speak failed — install $_myLang voice in phone TTS settings',
              );
            }
          } catch (e) {
            StageLog.step('TTS', 'Error: $e');
            debugPrint('MeetingTranslationBus tts error: $e');
          } finally {
            // Always release the mic — never leave one-way mode stuck on.
            onSpeakingChanged?.call(false);
          }
          _lastSpokenNorm = spokenNorm;
        } else if (spokenNorm.isNotEmpty) {
          _lastSpokenNorm = spokenNorm;
        }
      }
    } finally {
      _working = false;
      onSpeakingChanged?.call(false);
    }
  }

  static String _normalize(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
