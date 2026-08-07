import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import 'ai_client.dart';

/// Captures **my own** speech and turns it into text.
///
/// Idle listening uses a throwaway buffer. When real speech starts, recording
/// restarts so the WAV contains only the current sentence. After silence,
/// that clip is STT'd once and published.
class MeetingAiSession {
  MeetingAiSession({
    AiClient? ai,
    AudioRecorder? recorder,
    FirebaseFirestore? db,
    this.onCaption,
    this.onUtterance,
    this.onError,
    this.onBusyChanged,
    this.onPhaseChanged,
  })  : _ai = ai ?? AiClient(),
        _rec = recorder ?? AudioRecorder(),
        _db = db ?? FirebaseFirestore.instance;

  static const Duration silenceToEnd = Duration(milliseconds: 1500);
  static const Duration minSpeechDuration = Duration(milliseconds: 600);
  static const double speechDbThreshold = -35;
  static const int minAudioBytes = 4000;

  final AiClient _ai;
  final AudioRecorder _rec;
  final FirebaseFirestore _db;

  final void Function(String myTranscript)? onCaption;
  final Future<void> Function(String text, String lang)? onUtterance;
  final void Function(Object error)? onError;
  final void Function(bool busy)? onBusyChanged;
  final void Function(String phase)? onPhaseChanged;

  StreamSubscription<Amplitude>? _ampSub;

  String? _recordPath;
  bool _busy = false;
  bool _running = false;
  bool _paused = false;
  bool _heardSpeech = false;
  bool _finalizeQueued = false;
  bool _recordingFromSpeechOnset = false;
  DateTime? _lastSpeechAt;
  DateTime? _speechStartedAt;

  /// Serializes pause/resume/onset-restart so a late pause cannot mute the mic
  /// forever after TTS has already finished (one-way call bug).
  Future<void> _recGate = Future<void>.value();
  int _captureEpoch = 0;
  Future<void>? _onsetRestart;

  String _srcLang = 'en';
  String? _sessionId;
  String? _meetingId;
  String? _callId;
  String _lastPublishedNorm = '';

  final StringBuffer _fullTranscript = StringBuffer();

  bool get isRunning => _running;
  bool get isBusy => _busy;
  String get fullTranscript => _fullTranscript.toString().trim();
  String? get sessionId => _sessionId;

  Future<void> start({
    required String srcLang,
    String? meetingId,
    String? callId,
    String? sessionId,
  }) async {
    if (_running) return;
    _srcLang = srcLang;
    _meetingId = meetingId;
    _callId = callId;
    _fullTranscript.clear();
    _heardSpeech = false;
    _finalizeQueued = false;
    _recordingFromSpeechOnset = false;
    _paused = false;
    _lastSpeechAt = null;
    _speechStartedAt = null;
    _lastPublishedNorm = '';
    _captureEpoch = 0;
    _running = true;

    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    _sessionId = sessionId ?? const Uuid().v4();
    await _db.collection('sessions').doc(_sessionId).set({
      'participantUid': uid,
      'meetingId': meetingId,
      'callId': callId,
      'transcript': '',
      'srcLang': srcLang,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _startRecording();
    _listenAmplitude();
    onPhaseChanged?.call('listening');
    onCaption?.call('');
  }

  void setMyLanguage(String srcLang) {
    _srcLang = srcLang;
  }

  Future<void> pauseCapture() {
    final epoch = ++_captureEpoch;
    _recGate = _recGate.catchError((_) {}).then((_) => _pauseImpl(epoch));
    return _recGate;
  }

  Future<void> resumeCapture() {
    final epoch = ++_captureEpoch;
    _recGate = _recGate.catchError((_) {}).then((_) => _resumeImpl(epoch));
    return _recGate;
  }

  Future<void> _pauseImpl(int epoch) async {
    if (!_running || epoch != _captureEpoch) return;
    _paused = true;
    try {
      await _rec.stop();
    } catch (_) {}
    if (epoch != _captureEpoch) return;
    _recordPath = null;
    _heardSpeech = false;
    _lastSpeechAt = null;
    _speechStartedAt = null;
    _recordingFromSpeechOnset = false;
    _onsetRestart = null;
  }

  Future<void> _resumeImpl(int epoch) async {
    if (!_running || epoch != _captureEpoch) return;
    _paused = false;
    _heardSpeech = false;
    _lastSpeechAt = null;
    _speechStartedAt = null;
    _recordingFromSpeechOnset = false;
    _onsetRestart = null;
    await _startRecording();
    if (epoch != _captureEpoch) return;
    onPhaseChanged?.call('listening');
  }

  Future<String> stop() async {
    if (!_running) return fullTranscript;
    _running = false;
    _captureEpoch++;
    await _ampSub?.cancel();
    _ampSub = null;
    try {
      await _rec.stop();
    } catch (_) {}
    _recordPath = null;
    onPhaseChanged?.call('idle');

    final text = fullTranscript;
    if (_sessionId != null) {
      await _db.collection('sessions').doc(_sessionId).set({
        'transcript': text,
        'status': 'ended',
        'updatedAt': FieldValue.serverTimestamp(),
        'endedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    return text;
  }

  Future<void> dispose() async {
    await stop();
    await _rec.dispose();
  }

  void _listenAmplitude() {
    _ampSub?.cancel();
    _ampSub = _rec
        .onAmplitudeChanged(const Duration(milliseconds: 200))
        .listen((amp) {
      if (!_running || _paused || _busy) return;

      if (amp.current > speechDbThreshold) {
        if (!_heardSpeech) {
          _speechStartedAt = DateTime.now();
          onPhaseChanged?.call('listening');
          onCaption?.call('Listening…');
          if (!_recordingFromSpeechOnset) {
            _recordingFromSpeechOnset = true;
            _onsetRestart = _restartRecordingAtSpeechOnset();
          }
        }
        _heardSpeech = true;
        _lastSpeechAt = DateTime.now();
        return;
      }

      if (!_heardSpeech || _lastSpeechAt == null || _speechStartedAt == null) {
        return;
      }

      final quietFor = DateTime.now().difference(_lastSpeechAt!);
      if (quietFor < silenceToEnd) return;

      final spokenFor = _lastSpeechAt!.difference(_speechStartedAt!);
      if (spokenFor < minSpeechDuration) {
        _heardSpeech = false;
        _lastSpeechAt = null;
        _speechStartedAt = null;
        _recordingFromSpeechOnset = false;
        onCaption?.call('');
        unawaited(_discardAndRestart());
        return;
      }

      unawaited(_finalizeUtterance());
    }, onError: (e) {
      debugPrint('MeetingAiSession amplitude error: $e');
    });
  }

  Future<void> _restartRecordingAtSpeechOnset() async {
    if (!_running || _paused || _busy) return;
    try {
      await _rec.stop();
    } catch (_) {}
    final old = _recordPath;
    _recordPath = null;
    if (old != null) {
      try {
        await File(old).delete();
      } catch (_) {}
    }
    if (_running && !_paused && !_busy) {
      await _startRecording();
    }
  }

  Future<void> _finalizeUtterance() async {
    if (!_running || _paused) return;
    if (_busy) {
      _finalizeQueued = true;
      return;
    }

    _busy = true;
    onBusyChanged?.call(true);
    onPhaseChanged?.call('processing');
    _heardSpeech = false;
    _lastSpeechAt = null;
    _speechStartedAt = null;
    _recordingFromSpeechOnset = false;
    _finalizeQueued = false;

    try {
      // Wait for speech-onset restart so we never STT the idle silence file.
      final onset = _onsetRestart;
      if (onset != null) {
        try {
          await onset.timeout(const Duration(seconds: 2));
        } catch (_) {}
        _onsetRestart = null;
      }

      final bytes = await _stopRecordingBytes();
      if (bytes == null || bytes.length < minAudioBytes) {
        if (_running && !_paused) await _startRecording();
        onPhaseChanged?.call('listening');
        return;
      }

      final source = (await _ai.transcribe(
        audioBytes: bytes,
        language: _srcLang,
        denoise: false,
      ))
          .trim();

      if (source.isEmpty) {
        onCaption?.call('');
        if (_running && !_paused) await _startRecording();
        onPhaseChanged?.call('listening');
        return;
      }

      final norm = _normalize(source);
      if (norm.isEmpty) {
        if (_running && !_paused) await _startRecording();
        onPhaseChanged?.call('listening');
        return;
      }

      if (norm == _lastPublishedNorm) {
        debugPrint('MeetingAiSession skip exact duplicate: $source');
        onCaption?.call(source);
        if (_running && !_paused) await _startRecording();
        onPhaseChanged?.call('listening');
        return;
      }

      if (_lastPublishedNorm.length > 8 && norm.startsWith(_lastPublishedNorm)) {
        final tail = _newTailOnly(_lastPublishedNorm, source);
        if (tail == null) {
          debugPrint('MeetingAiSession skip cumulative replay: $source');
          onCaption?.call(source);
          if (_running && !_paused) await _startRecording();
          onPhaseChanged?.call('listening');
          return;
        }
        await _publishUtterance(tail);
        return;
      }

      await _publishUtterance(source);
    } catch (e) {
      debugPrint('MeetingAiSession finalize error: $e');
      onError?.call(e);
    } finally {
      if (_running && !_paused) {
        await _startRecording();
        onPhaseChanged?.call('listening');
      }
      _busy = false;
      onBusyChanged?.call(false);
      if (_finalizeQueued && _running && !_paused) {
        _finalizeQueued = false;
        unawaited(_finalizeUtterance());
      }
    }
  }

  Future<void> _publishUtterance(String source) async {
    _appendTranscript(source);
    onCaption?.call(source);
    _lastPublishedNorm = _normalize(source);
    if (onUtterance != null) {
      await onUtterance!(source, _srcLang);
    }
  }

  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String? _newTailOnly(String olderNorm, String raw) {
    final olderWords = olderNorm.split(' ').where((w) => w.isNotEmpty).length;
    final rawWords = raw.trim().split(RegExp(r'\s+'));
    if (rawWords.length <= olderWords) return null;
    final tail = rawWords.skip(olderWords).join(' ').trim();
    if (tail.length < 4) return null;
    return tail;
  }

  Future<void> _discardAndRestart() async {
    if (_busy || !_running || _paused) return;
    try {
      await _rec.stop();
    } catch (_) {}
    final path = _recordPath;
    _recordPath = null;
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    if (_running && !_paused) await _startRecording();
  }

  Future<Uint8List?> _stopRecordingBytes() async {
    if (_recordPath == null) return null;
    try {
      await _rec.stop();
    } catch (_) {}
    final path = _recordPath!;
    _recordPath = null;

    final file = File(path);
    if (!await file.exists()) return null;
    try {
      return await file.readAsBytes();
    } finally {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  void _appendTranscript(String piece) {
    if (_fullTranscript.isNotEmpty) _fullTranscript.write(' ');
    _fullTranscript.write(piece);
    unawaited(_persistRolling());
  }

  Future<void> _startRecording() async {
    try {
      final dir = Directory.systemTemp;
      _recordPath =
          '${dir.path}/utt_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _rec.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          numChannels: 1,
        ),
        path: _recordPath!,
      );
    } catch (e) {
      debugPrint('MeetingAiSession record start error: $e');
      onError?.call(e);
    }
  }

  Future<void> _persistRolling() async {
    if (_sessionId == null) return;
    try {
      await _db.collection('sessions').doc(_sessionId).set({
        'transcript': fullTranscript,
        'meetingId': _meetingId,
        'callId': _callId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('MeetingAiSession persist error: $e');
    }
  }
}
