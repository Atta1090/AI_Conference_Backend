import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app_config.dart';
import '../../services/ai_client.dart';
import '../../services/calls_repo.dart';
import '../../services/device_tts.dart';
import '../../services/meeting_ai_session.dart';
import '../../services/meeting_translation_bus.dart';
import '../../services/room_utterances.dart';
import '../../services/stage_log.dart';
import '../summary_screen.dart';
import '../widgets/live_caption_overlay.dart';
import 'call_models.dart';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({
    super.key,
    required this.callId,
    required this.autoJoin,
  });

  final String callId;
  final bool autoJoin;

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  // ── Services ─────────────────────────────────────────────────────────
  final _callsRepo = CallsRepo(FirebaseFirestore.instance);
  final _deviceTts = DeviceTts();
  late final MeetingAiSession _aiSession;
  late final MeetingTranslationBus _bus;
  late final RoomUtterances _room = RoomUtterances.call(widget.callId);

  // ── Agora ─────────────────────────────────────────────────────────────
  RtcEngine? _engine;
  bool _joined = false;
  bool _joining = false;
  bool _ending = false;
  bool _reconnectAttempted = false;
  String _status = 'Initializing…';
  String? _pendingChannel;
  String? _lastChannel;
  int? _remoteUid;

  // ── Toggles ───────────────────────────────────────────────────────────
  bool _cameraOn = true;
  bool _micOn = true;
  bool _sharingScreen = false;

  // ── Timer ─────────────────────────────────────────────────────────────
  DateTime? _connectedAt;
  Timer? _durationTimer;
  String _duration = '00:00';

  // ── AI captions ───────────────────────────────────────────────────────
  /// The language I chose: I speak it and I hear the other side in it.
  String _myLang = 'en';
  bool _langSeeded = false;
  bool _langSheetShown = false;
  bool _loggedRinging = false;
  bool? _aiReachable;

  /// My own recognized speech.
  String _lastTranscript = '';

  /// The other side's words, already translated into [_myLang].
  String _lastTranslation = '';
  String _incomingSpeaker = '';

  bool _aiBusy = false;
  bool _translatedVoicePlaying = false;
  String _aiPhase = 'idle'; // listening | processing | speaking | idle

  // ── Names ─────────────────────────────────────────────────────────────
  String? _callerName;
  String? _calleeName;
  String? _namesForCallId;
  bool _namesLoading = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────

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
        setState(() => _aiBusy = busy);
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
        setState(() {
          _incomingSpeaker = speaker;
          _lastTranslation = translated;
        });
      },
      onSpeakingChanged: _onTranslatedSpeechChanged,
      onError: _onAiError,
    );
    _initAgora();
  }

  void _onAiError(Object e) {
    debugPrint('VideoCallScreen AI error: $e');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Call AI error: $e'),
        backgroundColor: Colors.red.shade800,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// Publish my words so the other side can translate them into their own
  /// language.
  Future<void> _publishUtterance(String text, String lang) async {
    try {
      await _room.publish(text: text, lang: lang);
    } catch (e) {
      debugPrint('VideoCallScreen publish failed: $e');
      _onAiError('Firestore publish failed (check firestore.rules): $e');
    }
  }

  /// Pause transcription while translated speech plays, so the microphone
  /// does not pick up our own loudspeaker output.
  void _onTranslatedSpeechChanged(bool speaking) {
    _translatedVoicePlaying = speaking;
    if (mounted) setState(() {});
    if (speaking) {
      unawaited(_aiSession.pauseCapture());
    } else if (_micOn) {
      // Always apply resume when speaking ends (meeting pattern).
      unawaited(_aiSession.resumeCapture());
    }
  }

  /// Seed language once from the call doc — never overwrite mid-call picks.
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
      _incomingSpeaker = '';
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

  /// Always mute the other person's raw voice — hear only translated TTS.
  Future<void> _muteOriginalRemoteAudio() async {
    try {
      await _engine?.muteAllRemoteAudioStreams(true);
    } catch (e) {
      debugPrint('VideoCallScreen mute remote audio failed: $e');
    }
  }

  /// Free the mic for STT (`record`). Agora only carries video in calls.
  Future<void> _releaseAgoraMicForStt() async {
    try {
      await _engine?.enableLocalAudio(false);
      await _engine?.muteLocalAudioStream(true);
      await _engine?.updateChannelMediaOptions(
        const ChannelMediaOptions(publishMicrophoneTrack: false),
      );
    } catch (e) {
      debugPrint('VideoCallScreen release Agora mic failed: $e');
    }
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

  // ── Agora init ────────────────────────────────────────────────────────

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
            });
            _durationTimer =
                Timer.periodic(const Duration(seconds: 1), (_) {
              if (!mounted) return;
              final d = DateTime.now().difference(_connectedAt!);
              setState(() => _duration = _formatDuration(d));
            });
            unawaited(_startAi());
          },
          onLeaveChannel: (connection, stats) {
            if (!mounted) return;
            _durationTimer?.cancel();
            unawaited(_aiSession.stop());
            setState(() {
              _joined = false;
              _joining = false;
              _remoteUid = null;
              _status = 'Call ended';
              _duration = '00:00';
              _connectedAt = null;
            });
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            if (!mounted) return;
            setState(() {
              _remoteUid = remoteUid;
              _status = 'Connected ✓';
            });
            unawaited(_muteOriginalRemoteAudio());
          },
          onUserOffline: (connection, remoteUid, reason) {
            if (!mounted) return;
            setState(() {
              _remoteUid = null;
              _status = 'Other party left';
            });
          },
          onError: (err, msg) {
            if (!mounted) return;
            setState(() => _status = 'Error ${err.index}: $msg');
          },
          onConnectionStateChanged: (connection, state, reason) {
            if (!mounted) return;
            setState(() => _status = '${state.name} — ${reason.name}');
            if (state == ConnectionStateType.connectionStateFailed ||
                state == ConnectionStateType.connectionStateDisconnected) {
              unawaited(_tryReconnect());
            }
          },
        ),
      );

      await engine.enableVideo();
      await engine.enableAudio();
      await engine.setCloudProxy(CloudProxyType.tcpProxy);
      await engine.startPreview();

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
    if (status != 'accepted') {
      if (status == 'ringing' && !_loggedRinging) {
        _loggedRinging = true;
        StageLog.step('CALL', 'Waiting for accept (ringing)');
      }
      return;
    }
    if (_joined || _joining) return;
    StageLog.step('CALL', 'Call accepted — joining Agora video', {
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
      _status = 'Connecting…';
    });
    try {
      await _requestPerms();
      _lastChannel = channelName;
      await _engine!.joinChannel(
        token: '',
        channelId: channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          // Mic kept free for MeetingAiSession STT; meaning goes via Firestore.
          publishMicrophoneTrack: false,
          publishCameraTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
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

  Future<void> _startAi() async {
    try {
      StageLog.step('CALL', 'Starting video-call AI session', {
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
      await Future<void>.delayed(const Duration(milliseconds: 350));
      await _muteOriginalRemoteAudio();
      try {
        await _engine?.setDefaultAudioRouteToSpeakerphone(true);
        await _engine?.setEnableSpeakerphone(true);
      } catch (e) {
        debugPrint('VideoCallScreen speakerphone failed: $e');
      }
      StageLog.step('CALL', 'Remote Agora audio muted; speaker on for TTS');

      // Same order as meetings: bus + STT first, language sheet after.
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

  Future<void> _requestPerms() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) throw StateError('Microphone permission denied.');
    final cam = await Permission.camera.request();
    if (!cam.isGranted) throw StateError('Camera permission denied.');
  }

  // ── Controls ──────────────────────────────────────────────────────────

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

  Future<void> _toggleCamera() async {
    _cameraOn = !_cameraOn;
    await _engine?.muteLocalVideoStream(!_cameraOn);
    setState(() {});
  }

  Future<void> _switchCamera() async {
    await _engine?.switchCamera();
    setState(() {});
  }

  // ── Screen share — agora_rtc_engine 6.5.2 correct API ────────────────

  Future<void> _toggleScreenShare() async {
    if (_sharingScreen) {
      // Stop screen share, go back to camera
      await _engine?.stopScreenCapture();
      await _engine?.updateChannelMediaOptions(
        const ChannelMediaOptions(
          publishScreenCaptureVideo: false,
          publishScreenCaptureAudio: false,
          publishCameraTrack: true,
          publishMicrophoneTrack: false,
        ),
      );
      setState(() => _sharingScreen = false);
    } else {
      // Start screen share
      // ScreenCaptureParameters2 is the correct class for mobile (6.x)
      await _engine?.startScreenCapture(
        const ScreenCaptureParameters2(
          captureAudio: false,
          captureVideo: true,
          videoParams: ScreenVideoParameters(
            dimensions: VideoDimensions(width: 1280, height: 720),
            frameRate: 15,
            bitrate: 600,
          ),
        ),
      );
      await _engine?.updateChannelMediaOptions(
        const ChannelMediaOptions(
          publishScreenCaptureVideo: true,
          publishScreenCaptureAudio: false,
          publishCameraTrack: false,
          publishMicrophoneTrack: false,
        ),
      );
      setState(() => _sharingScreen = true);
    }
  }

  // ── End call ──────────────────────────────────────────────────────────

  Future<void> _endCall() async {
    if (_ending) return;
    _ending = true;
    _durationTimer?.cancel();
    if (_sharingScreen) await _engine?.stopScreenCapture();
    await _aiSession.stop();
    await _bus.dispose();
    await _deviceTts.stop();

    // Summarize both sides of the call, not just my own microphone.
    var transcript = '';
    try {
      transcript = await _room.buildTranscript();
    } catch (e) {
      debugPrint('VideoCallScreen transcript failed: $e');
    }
    if (transcript.trim().isEmpty) transcript = _aiSession.fullTranscript;

    await _callsRepo.endCall(widget.callId);
    await _engine?.leaveChannel();
    if (!mounted) return;
    if (transcript.trim().length >= 20) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SummaryScreen(
            title: 'Video call summary',
            duration: _duration,
            transcript: transcript,
          ),
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  // ── Names ─────────────────────────────────────────────────────────────

  Future<void> _ensureNamesLoaded(CallDoc call) async {
    if (_namesForCallId == call.id || _namesLoading) return;
    _namesLoading = true;
    try {
      final snaps = await Future.wait([
        FirebaseFirestore.instance
            .collection('users')
            .doc(call.callerUid)
            .get(),
        FirebaseFirestore.instance
            .collection('users')
            .doc(call.calleeUid)
            .get(),
      ]);
      if (!mounted) return;
      setState(() {
        _callerName = _trim(snaps[0].data()?['displayName']);
        _calleeName = _trim(snaps[1].data()?['displayName']);
        _namesForCallId = call.id;
        _namesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _namesLoading = false);
    }
  }

  String? _trim(dynamic v) {
    if (v == null) return null;
    final s = (v as String).trim();
    return s.isEmpty ? null : s;
  }

  String _formatDuration(Duration d) {
    final m = (d.inSeconds ~/ 60).clamp(0, 99);
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<CallDoc>(
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

        WidgetsBinding.instance
            .addPostFrameCallback((_) => _ensureNamesLoaded(call));

        final isCaller = call.callerUid == myUid;
        _seedLangFromCall(call, isCaller);

        if (!_joined && call.status == 'ringing') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _joined) return;
            if (_status != 'Ringing…') {
              setState(() => _status = 'Ringing…');
            }
          });
        }

        _joinIfReady(call.channelName, call.status);
        final otherName = isCaller
            ? (_calleeName ?? 'Receiver')
            : (_callerName ?? 'Caller');

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // ── Remote video — full screen ──────────────────────────
              Positioned.fill(
                child: _remoteUid == null || _engine == null
                    ? _WaitingPlaceholder(
                        status: _status, joined: _joined)
                    : AgoraVideoView(
                        controller: VideoViewController.remote(
                          rtcEngine: _engine!,
                          canvas: VideoCanvas(uid: _remoteUid),
                          connection:
                              RtcConnection(channelId: call.channelName),
                        ),
                      ),
              ),

              // ── Local preview — picture-in-picture ──────────────────
              if (_joined && _cameraOn && !_sharingScreen && _engine != null)
                Positioned(
                  top: 56,
                  right: 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 100,
                      height: 140,
                      child: AgoraVideoView(
                        controller: VideoViewController(
                          rtcEngine: _engine!,
                          canvas: const VideoCanvas(uid: 0),
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Screen share badge ──────────────────────────────────
              if (_sharingScreen)
                Positioned(
                  top: 56,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.screen_share,
                            color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Sharing screen',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Top bar ─────────────────────────────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.videocam,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                otherName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                _joined ? _duration : _status,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        // Flip camera — only when camera is on
                        if (_aiReachable == false)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.cloud_off,
                              color: Colors.red.shade300,
                              size: 20,
                            ),
                          ),
                        if (_joined && _cameraOn && !_sharingScreen)
                          _CircleIconButton(
                            icon: Icons.flip_camera_ios,
                            onTap: _switchCamera,
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Live captions ───────────────────────────────────────
              if (_joined)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 110,
                  child: LiveCaptionOverlay(
                    myLang: _myLang,
                    mySpeech: _lastTranscript,
                    incomingSpeaker: _incomingSpeaker,
                    incomingText: _lastTranslation,
                    isBusy: _aiBusy,
                    isSpeaking: _translatedVoicePlaying,
                    phase: _aiPhase,
                    onMyLangChanged: _setMyLang,
                  ),
                ),
              // ── Bottom controls ─────────────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.85),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ControlBtn(
                          icon: _micOn ? Icons.mic : Icons.mic_off,
                          label: _micOn ? 'Mute' : 'Unmute',
                          active: _micOn,
                          onTap: _toggleMic,
                        ),
                        _ControlBtn(
                          icon: _cameraOn
                              ? Icons.videocam
                              : Icons.videocam_off,
                          label: _cameraOn ? 'Cam off' : 'Cam on',
                          active: _cameraOn,
                          onTap: _toggleCamera,
                        ),
                        _ControlBtn(
                          icon: _sharingScreen
                              ? Icons.stop_screen_share
                              : Icons.screen_share,
                          label: _sharingScreen
                              ? 'Stop share'
                              : 'Share screen',
                          active: !_sharingScreen,
                          accentColor: Colors.orange,
                          onTap: _toggleScreenShare,
                        ),
                        _ControlBtn(
                          icon: Icons.call_end,
                          label: 'End',
                          active: false,
                          accentColor: Colors.red,
                          isEndCall: true,
                          onTap: _ending ? null : _endCall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _WaitingPlaceholder extends StatelessWidget {
  const _WaitingPlaceholder({required this.status, required this.joined});
  final String status;
  final bool joined;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person, size: 80, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              joined ? 'Waiting for other party…' : status,
              style: const TextStyle(color: Colors.white54, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            if (!joined) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(color: Colors.white38),
            ],
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: Colors.white12,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  const _ControlBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.accentColor,
    this.isEndCall = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  final Color? accentColor;
  final bool isEndCall;

  @override
  Widget build(BuildContext context) {
    final bgColor = isEndCall
        ? Colors.red
        : (!active && accentColor != null)
            ? accentColor!
            : active
                ? Colors.white24
                : Colors.white12;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: bgColor),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}