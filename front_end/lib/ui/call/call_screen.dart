import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import '../../app_config.dart';
import '../../services/ai_client.dart';
import '../../services/calls_repo.dart';
import '../../services/device_tts.dart';
import '../../services/meeting_ai_session.dart';
import '../../services/meeting_translation_bus.dart';
import '../../services/room_utterances.dart';
import '../../services/stage_log.dart';
import '../summary_screen.dart';
import 'call_models.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key, required this.callId, required this.autoJoin});

  final String callId;
  final bool autoJoin;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _callsRepo = CallsRepo(FirebaseFirestore.instance);
  final _deviceTts = DeviceTts();
  late final MeetingAiSession _aiSession;
  late final MeetingTranslationBus _bus;
  late final RoomUtterances _room = RoomUtterances.call(widget.callId);

  RtcEngine? _engine;
  bool _joined = false;
  bool _joining = false;
  bool _ending = false;
  bool _reconnectAttempted = false;
  String _status = 'Initializing…';
  String? _pendingChannel;
  String? _lastChannel;
  DateTime? _connectedAt;
  Timer? _durationTimer;
  String _duration = '00:00';

  // Translation state
  bool _isSending = false;
  String _aiPhase = 'idle'; // listening | processing | speaking | idle
  String _lastTranscript = '';
  String _lastTranslation = '';

  // Languages
  /// The language I chose: I speak it and I hear the other side in it.
  String _myLang = 'en';

  /// The other side's own choice — shown in the UI only.
  String _otherLang = 'en';

  bool _langSeeded = false;
  bool _langSheetShown = false;
  bool _loggedRinging = false;
  bool? _aiReachable;
  bool _micOn = true;
  bool _translatedVoicePlaying = false;

  // Display names (optional UI polish)
  String? _callerName;
  String? _calleeName;
  String? _namesForCallId;
  bool _namesLoading = false;

  @override
  void initState() {
    super.initState();
    _aiSession = MeetingAiSession(
      onCaption: (text) {
        if (!mounted) return;
        setState(() => _lastTranscript = text);
      },
      onUtterance: _publishUtterance,
      onBusyChanged: (busy) {
        if (!mounted) return;
        setState(() => _isSending = busy);
      },
      onPhaseChanged: (phase) {
        if (!mounted) return;
        setState(() => _aiPhase = phase);
      },
      onError: _onAiError,
    );
    _bus = MeetingTranslationBus(
      room: _room,
      tts: _deviceTts,
      onCaption: (speaker, translated, original) {
        if (!mounted) return;
        setState(() => _lastTranslation = translated);
      },
      onSpeakingChanged: _onTranslatedSpeechChanged,
      onError: _onAiError,
    );
    _initAgora();
  }

  void _onAiError(Object e) {
    debugPrint('CallScreen AI error: $e');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Call AI error: $e'),
        backgroundColor: Colors.red.shade800,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// Publish my words so the other side hears them in their own language.
  Future<void> _publishUtterance(String text, String lang) async {
    try {
      await _room.publish(text: text, lang: lang);
    } catch (e) {
      debugPrint('CallScreen publish failed: $e');
      _onAiError('Firestore publish failed (check firestore.rules): $e');
    }
  }

  /// Pause transcription while translated speech plays, so the microphone does
  /// not pick up our own loudspeaker output.
  void _onTranslatedSpeechChanged(bool speaking) {
    _translatedVoicePlaying = speaking;
    if (mounted) setState(() {});
    if (speaking) {
      unawaited(_aiSession.pauseCapture());
    } else {
      // Always resume like meetings — a raced pause must not leave one-way mode.
      // Mute still honored inside resume path via _micOn gate below.
      if (_micOn) {
        unawaited(_aiSession.resumeCapture());
      }
    }
  }

  void _seedLangFromCall(CallDoc call, bool isCaller) {
    if (_langSeeded) return;
    _langSeeded = true;
    _myLang = isCaller ? call.callerLang : call.calleeLang;
  }

  Future<void> _setMyLang(String lang) async {
    if (lang == _myLang) return;
    setState(() {
      _myLang = lang;
      _lastTranslation = '';
    });
    _aiSession.setMyLanguage(lang);
    _bus.setMyLanguage(lang);
    await _deviceTts.stop();
    unawaited(_room.setMyLanguage(lang));
    unawaited(_callsRepo.updateMyLanguage(widget.callId, lang));

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      unawaited(FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'defaultLang': lang}, SetOptions(merge: true)));
    }
  }

  Future<void> _promptForLanguage() async {
    if (!mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1B1B1D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(
                'Choose your language',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Text(
                'You will speak in this language, and hear the other person '
                'translated into it — captions and voice.',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ),
            ...LangCodes.nameToCode.entries.map(
              (e) => ListTile(
                leading: Icon(
                  _myLang == e.value
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: _myLang == e.value
                      ? const Color(0xFF39A935)
                      : Colors.white38,
                ),
                title: Text(
                  e.key,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                onTap: () => Navigator.of(ctx).pop(e.value),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) await _setMyLang(picked);
  }

  Future<void> _probeAiServer() async {
    try {
      await AiClient().health().timeout(const Duration(seconds: 4));
      if (!mounted) return;
      setState(() => _aiReachable = true);
    } catch (e) {
      debugPrint('AI health failed (${AppConfig.aiServerBaseUrl}): $e');
      if (!mounted) return;
      setState(() => _aiReachable = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'AI server unreachable at ${AppConfig.aiServerBaseUrl}. '
            'Restart backend with python run_dev.py (0.0.0.0) and ensure '
            'phone + PC are on the same Wi‑Fi.',
          ),
          duration: const Duration(seconds: 8),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  Future<void> _muteOriginalRemoteAudio() async {
    try {
      await _engine?.muteAllRemoteAudioStreams(true);
    } catch (e) {
      debugPrint('CallScreen mute remote audio failed: $e');
    }
  }

  /// Stop Agora from capturing the mic so `record`/STT can hear speech.
  /// muteLocalAudioStream alone is NOT enough — enableLocalAudio(false) is.
  Future<void> _releaseAgoraMicForStt() async {
    try {
      await _engine?.enableLocalAudio(false);
      await _engine?.muteLocalAudioStream(true);
      await _engine?.updateChannelMediaOptions(
        const ChannelMediaOptions(publishMicrophoneTrack: false),
      );
    } catch (e) {
      debugPrint('CallScreen release Agora mic failed: $e');
    }
  }

  Future<void> _toggleMic() async {
    _micOn = !_micOn;
    // Agora mic stays unpublished; mute only controls local STT capture.
    if (_micOn) {
      if (!_translatedVoicePlaying) unawaited(_aiSession.resumeCapture());
    } else {
      unawaited(_aiSession.pauseCapture());
    }
    setState(() {});
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    unawaited(_aiSession.dispose());
    unawaited(_bus.dispose());
    unawaited(_deviceTts.stop());
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  Future<void> _initAgora() async {
    if (AppConfig.agoraAppId.isEmpty) {
      if (mounted) setState(() => _status = 'Missing AGORA_APP_ID.');
      return;
    }

    try {
      final engine = createAgoraRtcEngine();
      await engine.initialize(
        const RtcEngineContext(
          appId: AppConfig.agoraAppId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            if (!mounted) return;
            setState(() {
              _joined = true;
              _joining = false;
              _status = 'Connected ✓';
              _connectedAt = DateTime.now();
              _durationTimer?.cancel();
              _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
                if (!mounted) return;
                final d = _connectedAt == null ? Duration.zero : DateTime.now().difference(_connectedAt!);
                setState(() => _duration = _formatDuration(d));
              });
            });
            unawaited(_startAiSession());
          },
          onLeaveChannel: (connection, stats) {
            if (!mounted) return;
            unawaited(_aiSession.stop());
            setState(() {
              _joined = false;
              _joining = false;
              _status = 'Call ended';
              _connectedAt = null;
              _durationTimer?.cancel();
              _durationTimer = null;
              _duration = '00:00';
            });
          },
          onError: (err, msg) {
            if (!mounted) return;
            setState(() => _status = 'Error ${err.index}: $msg');
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            if (!mounted) return;
            setState(() => _status = 'Connected ✓');
            unawaited(_muteOriginalRemoteAudio());
          },
          onUserOffline: (connection, remoteUid, reason) {
            if (!mounted) return;
            setState(() => _status = 'Other party left');
          },
          onConnectionStateChanged: (connection, state, reason) {
            if (!mounted) return;
            setState(() => _status = '${state.name} — ${reason.name}');
            if (state == ConnectionStateType.connectionStateFailed ||
                state == ConnectionStateType.connectionStateDisconnected) {
              unawaited(_tryReconnect());
            }
          },
          onProxyConnected: (channel, uid, proxyType, localProxyIp, elapsed) {
            if (!mounted) return;
            setState(() => _status = 'Proxy OK — joining…');
          },
        ),
      );

      await engine.enableAudio();
      // Do NOT use audioScenarioChatroom — it can exclusive-lock the mic so
      // MeetingAiSession/`record` never hears speech (no loading, no STT).
      await engine.setCloudProxy(CloudProxyType.tcpProxy);

      _engine = engine;

      if (_pendingChannel != null) {
        await _doJoin(_pendingChannel!);
        _pendingChannel = null;
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'Init error: $e');
    }
  }

  void _joinIfReady(String channelName, String status) {
    if (!widget.autoJoin) return;
    // Caller must wait until the other side accepts — joining while "ringing"
    // starts STT early and the callee's bus primes away those utterances.
    if (status != 'accepted') {
      if (status == 'ringing' && !_loggedRinging) {
        _loggedRinging = true;
        StageLog.step('CALL', 'Waiting for accept (ringing)');
      }
      return;
    }
    if (_joined || _joining) return;
    StageLog.step('CALL', 'Call accepted — joining Agora', {
      'channel': channelName,
    });
    if (_engine == null) {
      _pendingChannel = channelName;
      return;
    }
    _doJoin(channelName);
  }

  Future<void> _doJoin(String channelName) async {
    if (_joined || _joining) return;
    setState(() {
      _joining = true;
      _status = 'Connecting via proxy…';
    });

    try {
      await _requestPerms();
      _lastChannel = channelName;
      await _engine!.joinChannel(
        token: '',
        channelId: channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          // Voice meaning travels via STT → Firestore → translate → device TTS.
          // Keep Agora mic free for the recorder.
          publishMicrophoneTrack: false,
          autoSubscribeAudio: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _joining = false;
          _status = 'Join failed: $e';
        });
      }
    }
  }

  Future<void> _requestPerms() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) throw StateError('Microphone permission denied.');
  }

  Future<void> _startAiSession() async {
    try {
      StageLog.step('CALL', 'Starting AI session', {
        'callId': widget.callId,
        'lang': _myLang,
        'aiServer': AppConfig.aiServerBaseUrl,
      });
      await _probeAiServer();
      StageLog.step(
        'CALL',
        _aiReachable == true
            ? 'AI server reachable'
            : 'AI server unreachable — check IP/Wi‑Fi',
      );
      await _releaseAgoraMicForStt();
      StageLog.step('CALL', 'Agora mic released for STT recorder');
      // Give Android a moment to release AudioRecord to the `record` package.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      await _muteOriginalRemoteAudio();
      try {
        await _engine?.setDefaultAudioRouteToSpeakerphone(true);
        await _engine?.setEnableSpeakerphone(true);
      } catch (e) {
        debugPrint('CallScreen speakerphone failed: $e');
      }
      StageLog.step('CALL', 'Remote Agora audio muted; speaker on for TTS');

      // Same order as meetings: receive + record FIRST, language sheet after.
      _bus.start(myLang: _myLang);
      unawaited(_room.setMyLanguage(_myLang));
      if (!_aiSession.isRunning) {
        _aiSession.setMyLanguage(_myLang);
        await _aiSession.start(
          srcLang: _myLang,
          callId: widget.callId,
        );
      }
      if (mounted) {
        setState(() {
          _lastTranscript = 'Listening…';
          _aiPhase = 'listening';
        });
      }

      if (mounted && !_langSheetShown) {
        _langSheetShown = true;
        await _promptForLanguage();
      }
    } catch (e) {
      _onAiError(e);
    }
  }

  Future<void> _tryReconnect() async {
    if (_reconnectAttempted || _lastChannel == null || _engine == null) return;
    _reconnectAttempted = true;
    if (mounted) setState(() => _status = 'Reconnecting…');
    await Future<void>.delayed(const Duration(seconds: 2));
    try {
      await _engine!.leaveChannel();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      _joined = false;
      _joining = false;
      await _doJoin(_lastChannel!);
    } catch (e) {
      if (mounted) setState(() => _status = 'Reconnect failed: $e');
    }
  }

  Future<void> _endCall() async {
    if (_ending) return;
    _ending = true;
    _durationTimer?.cancel();
    await _aiSession.stop();
    await _bus.dispose();
    await _deviceTts.stop();

    // Summarize both sides of the call, not just my own microphone. Language
    // tags travel with each line so the summary can be written in _myLang.
    var transcript = '';
    var entries = const <TranscriptEntry>[];
    try {
      entries = await _room.buildTranscriptEntries();
      transcript = TranscriptEntry.renderTranscript(entries);
    } catch (e) {
      debugPrint('CallScreen transcript failed: $e');
    }
    if (transcript.trim().isEmpty) {
      transcript = _aiSession.fullTranscript;
      entries = const [];
    }

    await _callsRepo.endCall(widget.callId);
    await _engine?.leaveChannel();
    if (!mounted) return;
    if (transcript.trim().length >= 20) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SummaryScreen(
            title: 'Call summary',
            duration: _duration,
            transcript: transcript,
            language: _myLang,
            utterances: entries.isEmpty ? null : entries,
          ),
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  String _formatDuration(Duration d) {
    final totalSeconds = d.inSeconds;
    final minutes = (totalSeconds ~/ 60).clamp(0, 99);
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _ensureNamesLoaded(CallDoc call) async {
    if (_namesForCallId == call.id || _namesLoading) return;
    _namesLoading = true;
    try {
      final callers = FirebaseFirestore.instance.collection('users').doc(call.callerUid);
      final callees = FirebaseFirestore.instance.collection('users').doc(call.calleeUid);
      final snaps = await Future.wait([callers.get(), callees.get()]);
      if (!mounted) return;
      final callerName = snaps[0].data()?['displayName'] as String?;
      final calleeName = snaps[1].data()?['displayName'] as String?;
      setState(() {
        _callerName = (callerName == null || callerName.trim().isEmpty) ? null : callerName.trim();
        _calleeName = (calleeName == null || calleeName.trim().isEmpty) ? null : calleeName.trim();
        _namesForCallId = call.id;
        _namesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _namesLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder(
      stream: _callsRepo.watchCall(widget.callId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final call = snap.data!;

        if (call.status == 'ended' && !_ending) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _endCall());
        }

        final isCaller = call.callerUid == myUid;
        _seedLangFromCall(call, isCaller);
        // Other side may change language mid-call — keep the label fresh.
        _otherLang = isCaller ? call.calleeLang : call.callerLang;

        if (!_joined && call.status == 'ringing') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _joined) return;
            if (_status != 'Ringing…') {
              setState(() => _status = 'Ringing…');
            }
          });
        }

        _joinIfReady(call.channelName, call.status);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _ensureNamesLoaded(call);
        });

        final myName = isCaller ? (_callerName ?? 'You') : (_calleeName ?? 'You');
        final otherName =
            isCaller ? (_calleeName ?? 'Receiver') : (_callerName ?? 'Caller');
        final myInitial = (myName.trim().isNotEmpty) ? myName.trim()[0].toUpperCase() : 'Y';

        final roleTitle = isCaller ? 'Calling' : 'Receiving';
        final headline = _joined ? 'In call' : roleTitle;

        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary.withOpacity(0.18),
                        Theme.of(context).colorScheme.secondary.withOpacity(0.12),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.9),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                myInitial,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  headline,
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _joined
                                      ? '$otherName • $_duration • '
                                          '${_translatedVoicePlaying ? 'speaking' : _aiPhase}'
                                      : '$otherName • $_status',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          if (_aiReachable == false)
                            Icon(Icons.cloud_off,
                                color: Colors.red.shade400, size: 22),
                          if (_joined)
                            TextButton.icon(
                              onPressed: _promptForLanguage,
                              icon: const Icon(Icons.translate, size: 18),
                              label: Text(_myLang.toUpperCase()),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _StatusBadge(status: _status, joined: _joined),
                          const SizedBox(height: 12),
                          if (!_joined)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                'Waiting for connection…',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            )
                          else ...[
                            _ChatBubbles(
                              myLang: _myLang,
                              otherLang: _otherLang,
                              transcript: _lastTranscript,
                              translation: _lastTranslation,
                              isSending: _isSending,
                              phase: _aiPhase,
                              aiReachable: _aiReachable,
                              micOn: _micOn,
                              onPickMyLang: _promptForLanguage,
                            ),
                          ],
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            if (_joined) ...[
                              SizedBox(
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed: _toggleMic,
                                  icon: Icon(
                                    _micOn ? Icons.mic : Icons.mic_off,
                                  ),
                                  label: Text(_micOn ? 'Mute' : 'Unmute'),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: _ending ? null : _endCall,
                                  icon: const Icon(Icons.call_end),
                                  label: const Text('End call'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.joined});
  final String status;
  final bool joined;

  @override
  Widget build(BuildContext context) {
    final color = joined ? Colors.green : Colors.orange;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
            child: Text(status,
                style: Theme.of(context).textTheme.titleMedium)),
      ],
    );
  }
}

class _ChatBubbles extends StatelessWidget {
  const _ChatBubbles({
    required this.myLang,
    required this.otherLang,
    required this.transcript,
    required this.translation,
    required this.isSending,
    required this.phase,
    required this.micOn,
    this.aiReachable,
    this.onPickMyLang,
  });

  final String myLang;
  final String otherLang;
  final String transcript;
  final String translation;
  final bool isSending;
  final String phase;
  final bool micOn;
  final bool? aiReachable;
  final VoidCallback? onPickMyLang;

  String get _statusLabel {
    if (aiReachable == false) return 'AI server offline';
    if (!micOn) return 'Muted';
    if (isSending || phase == 'processing') return 'Processing speech…';
    if (phase == 'speaking') return 'Playing translation…';
    if (phase == 'listening') return 'Listening…';
    return phase;
  }

  @override
  Widget build(BuildContext context) {
    final showSpinner =
        isSending || phase == 'processing' || phase == 'listening';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Languages',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onPickMyLang,
                borderRadius: BorderRadius.circular(14),
                child: _MiniInfo(
                  label: 'Your language (tap to change)',
                  value: myLang.toUpperCase(),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniInfo(
                label: 'Other language',
                value: otherLang.toUpperCase(),
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (showSpinner) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                _statusLabel,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: aiReachable == false
                          ? Colors.red
                          : Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Bubble(
          alignment: Alignment.centerRight,
          color: Colors.green.withOpacity(0.18),
          border: Colors.green.withOpacity(0.4),
          title: 'You',
          value: transcript.isEmpty ? '...' : transcript,
        ),
        const SizedBox(height: 10),
        _Bubble(
          alignment: Alignment.centerLeft,
          color: Colors.blue.withOpacity(0.14),
          border: Colors.blue.withOpacity(0.35),
          title: 'Other person (in your language)',
          value: translation.isEmpty ? '...' : translation,
        ),
      ],
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
        color: color.withOpacity(0.08),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.alignment,
    required this.color,
    required this.border,
    required this.title,
    required this.value,
  });

  final Alignment alignment;
  final Color color;
  final Color border;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: alignment == Alignment.centerRight
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}