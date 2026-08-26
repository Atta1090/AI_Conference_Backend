import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app_config.dart';
import '../../services/ai_client.dart';
import '../../services/device_tts.dart';
import '../../services/meeting_ai_session.dart';
import '../../services/meeting_translation_bus.dart';
import '../../services/stage_log.dart';
import '../summary_screen.dart';
import '../widgets/live_caption_overlay.dart';
import 'meeting_repo.dart';

/// Meeting ke liye dedicated video screen.
/// Existing VideoCallScreen ka structure reuse kiya gaya hai
/// lekin CallDoc ki jagah MeetingDoc use hoti hai.
class MeetingVideoScreen extends StatefulWidget {
  const MeetingVideoScreen({
    super.key,
    required this.meetingId,
    required this.isHost,
  });

  final String meetingId;

  /// Host (creator) hai ya join karne wala
  final bool isHost;

  @override
  State<MeetingVideoScreen> createState() => _MeetingVideoScreenState();
}

class _MeetingVideoScreenState extends State<MeetingVideoScreen> {
  // ── Repo ──────────────────────────────────────────────────────────────
  final _repo = MeetingRepo(FirebaseFirestore.instance);
  final _deviceTts = DeviceTts();
  late final MeetingAiSession _aiSession;
  late final MeetingTranslationBus _bus;

  // ── Agora ─────────────────────────────────────────────────────────────
  RtcEngine? _engine;
  bool _joined = false;
  bool _joining = false;
  bool _ending = false;
  bool _reconnectAttempted = false;
  String _status = 'Initializing…';
  String? _pendingChannel;
  String? _lastChannel;

  // Remote participants UIDs (Agora integer UIDs)
  final List<int> _remoteUids = [];

  // ── Toggles ───────────────────────────────────────────────────────────
  bool _cameraOn = true;
  bool _micOn = true;
  bool _sharingScreen = false;

  // ── Timer ─────────────────────────────────────────────────────────────
  DateTime? _connectedAt;
  Timer? _durationTimer;
  String _duration = '00:00';

  // ── Meeting info ──────────────────────────────────────────────────────
  String _meetingCode = '';
  bool _codeCopied = false;

  // ── AI captions ───────────────────────────────────────────────────────
  /// The one language I picked: I speak it, and I hear + read everyone
  /// else in it. Other participants each pick their own, independently.
  String _myLang = 'en';

  /// What I just said, in my own language.
  String _myCaption = '';

  /// What somebody else just said, already translated into [_myLang].
  String _incomingSpeaker = '';
  String _incomingCaption = '';

  bool _aiBusy = false;
  bool _translatedVoicePlaying = false;
  String _aiPhase = 'idle'; // listening | processing | speaking | idle
  /// null = not checked yet, true/false after /health probe.
  bool? _aiReachable;

  bool _langSheetShown = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _aiSession = MeetingAiSession(
      onCaption: (text) {
        if (!mounted) return;
        setState(() => _myCaption = text);
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
    );
    _bus = MeetingTranslationBus(
      room: _repo.bus(widget.meetingId),
      tts: _deviceTts,
      onCaption: (speaker, translated, original) {
        if (!mounted) return;
        setState(() {
          _incomingSpeaker = speaker;
          _incomingCaption = translated;
        });
      },
      onSpeakingChanged: _onTranslatedSpeechChanged,
    );
    unawaited(_loadPreferredLang());
    _initAgora();
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

  Future<void> _loadPreferredLang() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final lang = (snap.data()?['defaultLang'] as String?) ?? 'en';
      if (!mounted) return;
      setState(() => _myLang = lang);
      _aiSession.setMyLanguage(lang);
      _bus.setMyLanguage(lang);
      unawaited(_repo.setMyLanguage(widget.meetingId, lang));
    } catch (_) {}
  }

  /// Publish what I said so the other participants can translate it into
  /// their own languages.
  Future<void> _publishUtterance(String text, String lang) async {
    try {
      await _repo.bus(widget.meetingId).publish(text: text, lang: lang);
    } catch (e) {
      debugPrint('MeetingVideoScreen publish failed: $e');
      // Most common cause: Firestore rules block meetings/*/utterances.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not send speech to other phones. Check Firestore rules '
            'for meetings/.../utterances. ($e)',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// While a translated line plays through the loudspeaker, stop transcribing
  /// so the microphone does not pick up our own output and republish it.
  ///
  /// Always apply resume when [speaking] is false (no early-return), so a
  /// raced pause cannot leave the mic muted and make the call one-way.
  void _onTranslatedSpeechChanged(bool speaking) {
    _translatedVoicePlaying = speaking;
    if (mounted) setState(() {});
    if (speaking) {
      unawaited(_aiSession.pauseCapture());
    } else if (_micOn) {
      // Respect Mute: do not restart STT while the user is muted.
      unawaited(_aiSession.resumeCapture());
    }
  }

  /// Stop Agora from capturing the mic so `record`/STT can hear every
  /// participant (host and joiner). Meaning travels via Firestore, not Agora audio.
  Future<void> _releaseAgoraMicForStt() async {
    try {
      await _engine?.enableLocalAudio(false);
      await _engine?.muteLocalAudioStream(true);
      await _engine?.updateChannelMediaOptions(
        const ChannelMediaOptions(publishMicrophoneTrack: false),
      );
      StageLog.step('MEETING', 'Agora mic released for STT recorder');
    } catch (e) {
      debugPrint('MeetingVideoScreen release Agora mic failed: $e');
    }
  }

  /// Change the language I want to speak, read and hear.
  Future<void> _setMyLang(String lang) async {
    if (lang == _myLang) return;
    setState(() {
      _myLang = lang;
      _incomingCaption = '';
      _incomingSpeaker = '';
    });
    _aiSession.setMyLanguage(lang);
    _bus.setMyLanguage(lang);
    await _deviceTts.stop();
    unawaited(_repo.setMyLanguage(widget.meetingId, lang));

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      unawaited(FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'defaultLang': lang}, SetOptions(merge: true)));
    }
  }

  /// Always mute the other person's raw Agora voice. The user picked a
  /// preferred language and should hear only the translated TTS in that
  /// language — never both voices at once.
  Future<void> _muteOriginalRemoteAudio() async {
    try {
      await _engine?.muteAllRemoteAudioStreams(true);
      await _engine?.setDefaultAudioRouteToSpeakerphone(true);
      await _engine?.setEnableSpeakerphone(true);
    } catch (e) {
      debugPrint('MeetingVideoScreen mute remote audio failed: $e');
    }
  }

  /// Asked once on join so each participant explicitly picks their language.
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
                'You will speak in this language, and everyone else will be '
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

  // ── Agora init (VideoCallScreen se same pattern) ──────────────────────

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
              setState(() => _duration = _fmt(d));
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
              _remoteUids.clear();
              _status = 'Meeting ended';
              _duration = '00:00';
              _connectedAt = null;
            });
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            if (!mounted) return;
            setState(() {
              if (!_remoteUids.contains(remoteUid)) {
                _remoteUids.add(remoteUid);
              }
              _status = 'Connected ✓';
            });
            // New joiners publish audio by default — mute them so we keep
            // hearing only the translated voice in my language.
            unawaited(_muteOriginalRemoteAudio());
          },
          onUserOffline: (connection, remoteUid, reason) {
            if (!mounted) return;
            setState(() => _remoteUids.remove(remoteUid));
          },
          onError: (err, msg) {
            if (!mounted) return;
            setState(() => _status = 'Error ${err.index}: $msg');
          },
          onConnectionStateChanged: (connection, state, reason) {
            if (!mounted) return;
            setState(() => _status = '${state.name}');
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

  void _joinIfReady(String channelName) {
    if (_joined || _joining) return;
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
          // Mic kept free for MeetingAiSession STT on host AND joiner.
          // Meaning travels via Firestore → translate → device TTS.
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
      StageLog.step('MEETING', 'Starting AI session', {
        'meetingId': widget.meetingId,
        'isHost': widget.isHost,
        'lang': _myLang,
        'aiServer': AppConfig.aiServerBaseUrl,
      });
      await _probeAiServer();
      StageLog.step(
        'MEETING',
        _aiReachable == true
            ? 'AI server reachable'
            : 'AI server unreachable — check IP/Wi‑Fi',
      );

      // Critical for two-way: free mic before STT on every phone (incl. joiner).
      await _releaseAgoraMicForStt();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      await _muteOriginalRemoteAudio();
      StageLog.step('MEETING', 'Remote Agora audio muted; speaker on for TTS');

      // Receive side first, so we never miss what somebody says early on.
      _bus.start(myLang: _myLang);
      if (!_aiSession.isRunning) {
        _aiSession.setMyLanguage(_myLang);
        await _aiSession.start(
          srcLang: _myLang,
          meetingId: widget.meetingId,
        );
      }
      unawaited(_repo.setMyLanguage(widget.meetingId, _myLang));
      StageLog.step('MEETING', 'STT + utterance bus active (two-way)');

      if (mounted && !_langSheetShown) {
        _langSheetShown = true;
        await _promptForLanguage();
      }
    } catch (e) {
      StageLog.step('MEETING', 'AI start failed: $e');
      debugPrint('MeetingVideoScreen _startAi failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Meeting AI failed to start: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  /// Fail loudly when the phone cannot reach the PC backend — otherwise the
  /// user just sees empty captions and thinks translation is broken.
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
    // Agora mic stays unpublished; Mute must stop AI STT publish too,
    // otherwise the other side still gets captions/voice from this phone.
    if (_micOn) {
      if (!_translatedVoicePlaying) {
        unawaited(_aiSession.resumeCapture());
      }
      StageLog.step('MEETING', 'Mic unmuted — STT listening');
    } else {
      unawaited(_aiSession.pauseCapture());
      StageLog.step('MEETING', 'Mic muted — STT paused');
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
  }

  Future<void> _toggleScreenShare() async {
    if (_sharingScreen) {
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

  // ── End meeting ───────────────────────────────────────────────────────

  Future<void> _endMeeting() async {
    if (_ending) return;
    _ending = true;
    _durationTimer?.cancel();
    if (_sharingScreen) await _engine?.stopScreenCapture();
    await _aiSession.stop();
    await _bus.dispose();
    await _deviceTts.stop();

    // The summary has to cover the whole meeting, so read every participant's
    // utterances back rather than only what this microphone heard. Each line
    // keeps its spoken language so a mixed English/Urdu meeting can still be
    // summarized in the language this user picked.
    var transcript = '';
    var entries = const <TranscriptEntry>[];
    try {
      entries = await _repo.buildTranscriptEntries(widget.meetingId);
      transcript = TranscriptEntry.renderTranscript(entries);
    } catch (e) {
      debugPrint('MeetingVideoScreen transcript failed: $e');
    }
    if (transcript.trim().isEmpty) {
      transcript = _aiSession.fullTranscript;
      entries = const [];
    }

    // Host meeting end karta hai, participant sirf leave karta hai
    if (widget.isHost) {
      await _repo.endMeeting(widget.meetingId);
    }
    await _engine?.leaveChannel();

    if (!mounted) return;
    if (transcript.trim().length >= 20) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SummaryScreen(
            title: 'Meeting summary',
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

  // ── Copy code ─────────────────────────────────────────────────────────

  Future<void> _copyCode() async {
    if (_meetingCode.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _meetingCode));
    setState(() => _codeCopied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _codeCopied = false);
  }

  String _fmt(Duration d) {
    final m = (d.inSeconds ~/ 60).clamp(0, 99);
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MeetingDoc>(
      stream: _repo.watchMeeting(widget.meetingId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final meeting = snap.data!;

        // Meeting code save karo (top bar mein dikhayenge)
        if (_meetingCode.isEmpty && meeting.meetingCode.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => setState(() => _meetingCode = meeting.meetingCode),
          );
        }

        // Meeting end hui to screen close karo
        if (meeting.status == 'ended' && !_ending) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _endMeeting());
        }

        // Agora channel join karo
        _joinIfReady(meeting.channelName);

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // ── Remote video (pehla participant full screen) ──────────
              Positioned.fill(
                child: _remoteUids.isEmpty || _engine == null
                    ? _WaitingView(status: _status, joined: _joined)
                    : AgoraVideoView(
                        controller: VideoViewController.remote(
                          rtcEngine: _engine!,
                          canvas: VideoCanvas(uid: _remoteUids.first),
                          connection: RtcConnection(
                            channelId: meeting.channelName,
                          ),
                        ),
                      ),
              ),

              // ── Baaki remote participants (thumbnail strip) ───────────
              if (_remoteUids.length > 1)
                Positioned(
                  top: 100,
                  right: 8,
                  child: Column(
                    children: _remoteUids.skip(1).map((uid) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 80,
                            height: 110,
                            child: _engine == null
                                ? const SizedBox()
                                : AgoraVideoView(
                                    controller:
                                        VideoViewController.remote(
                                      rtcEngine: _engine!,
                                      canvas: VideoCanvas(uid: uid),
                                      connection: RtcConnection(
                                        channelId: meeting.channelName,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              // ── Local PiP preview ─────────────────────────────────────
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

              // ── Screen share badge ────────────────────────────────────
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

              // ── Top bar (meeting code + timer) ────────────────────────
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
                              Row(
                                children: [
                                  Text(
                                    'Code: $_meetingCode',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: _copyCode,
                                    child: Icon(
                                      _codeCopied
                                          ? Icons.check_circle
                                          : Icons.copy,
                                      color: _codeCopied
                                          ? Colors.greenAccent
                                          : Colors.white70,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                _joined ? _duration : _status,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        // My language — tap to change at any time
                        GestureDetector(
                          onTap: _promptForLanguage,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.language,
                                    color: Colors.white70, size: 15),
                                const SizedBox(width: 5),
                                Text(
                                  _myLang.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Flip camera button
                        if (_joined && _cameraOn && !_sharingScreen)
                          _CircleBtn(
                            icon: Icons.flip_camera_ios,
                            onTap: _switchCamera,
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Live captions ─────────────────────────────────────────
              if (_joined)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 110,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_aiReachable == false)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade800,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'AI offline — phone cannot reach '
                            '${AppConfig.aiServerBaseUrl}\n'
                            'Restart: python run_dev.py  |  same Wi‑Fi required',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      LiveCaptionOverlay(
                        myLang: _myLang,
                        onMyLangChanged: _setMyLang,
                        mySpeech: _myCaption,
                        incomingSpeaker: _incomingSpeaker,
                        incomingText: _incomingCaption,
                        isBusy: _aiBusy,
                        isSpeaking: _translatedVoicePlaying,
                        phase: _aiPhase,
                      ),
                    ],
                  ),
                ),

              // ── Bottom controls ───────────────────────────────────────
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
                          label: widget.isHost ? 'End' : 'Leave',
                          active: false,
                          accentColor: Colors.red,
                          isEndCall: true,
                          onTap: _ending ? null : _endMeeting,
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

class _WaitingView extends StatelessWidget {
  const _WaitingView({required this.status, required this.joined});
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
            const Icon(Icons.groups, size: 80, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              joined ? 'Waiting for others to join…' : status,
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

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, required this.onTap});
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



