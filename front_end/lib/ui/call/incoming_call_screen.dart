import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../services/calls_repo.dart';
import 'call_models.dart';
import 'call_screen.dart';
import 'video_call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key, required this.callId});

  final String callId;

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final _repo = CallsRepo(FirebaseFirestore.instance);
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  String? _lastCallStatus;
  String? _callerName;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _ringtonePlayer.stop();
    _ringtonePlayer.dispose();
    super.dispose();
  }

  Future<void> _updateRingtone(String status) async {
    try {
      if (status == 'ringing') {
        // Simple loop ringtone.
        await _ringtonePlayer.setAsset('assets/ringtone.mp3');
        await _ringtonePlayer.setLoopMode(LoopMode.one);
        await _ringtonePlayer.play();
      } else {
        await _ringtonePlayer.stop();
      }
    } catch (_) {
      // Don't crash the call UI if audio fails.
    }
  }

  Future<void> _loadCallerName(String callerUid) async {
    if (_callerName != null) return;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(callerUid)
        .get();
    final name = snap.data()?['displayName'] as String?;
    if (!mounted) return;
    setState(() =>
        _callerName = (name == null || name.trim().isEmpty) ? null : name.trim());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CallDoc>(
      stream: _repo.watchCall(widget.callId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: SafeArea(child: Center(child: CircularProgressIndicator())),
          );
        }

        final call = snap.data!;
        final status = call.status;

        // Sync ringtone with Firestore call status.
        if (_lastCallStatus != status) {
          _lastCallStatus = status;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateRingtone(status);
          });
        }

        final isEnded = call.status == 'ended';
        final isVideo = call.callType == 'video';
        final callerUid = call.callerUid;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_callerName == null && callerUid.isNotEmpty) {
            _loadCallerName(callerUid);
          }
        });

        final callerInitial = (_callerName?.trim().isNotEmpty ?? false)
            ? _callerName!.trim()[0].toUpperCase()
            : (callerUid.isNotEmpty ? callerUid[0].toUpperCase() : '?');

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
                        Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.18),
                        Theme.of(context)
                            .colorScheme
                            .secondary
                            .withOpacity(0.12),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _IncomingRingAvatar(
                        initial: callerInitial,
                        isVideo: isVideo,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        isVideo ? 'Incoming video call' : 'Incoming call',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _callerName ?? 'Unknown caller',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Caller: ${call.callerLang.toUpperCase()} • You: ${call.calleeLang.toUpperCase()}',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      if (isEnded)
                        const Text(
                          'Call ended',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.redAccent),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await _ringtonePlayer.stop();
                                  await _repo.endCall(widget.callId);
                                  if (!context.mounted) return;
                                  Navigator.of(context).pop();
                                },
                                icon: const Icon(Icons.call_end,
                                    color: Colors.red),
                                label: const Text('Decline'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () async {
                                  await _ringtonePlayer.stop();
                                  await _repo.acceptCall(widget.callId);
                                  if (!context.mounted) return;
                                  // Route to correct screen based on callType
                                  if (isVideo) {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (_) => VideoCallScreen(
                                          callId: widget.callId,
                                          autoJoin: true,
                                        ),
                                      ),
                                    );
                                  } else {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (_) => CallScreen(
                                          callId: widget.callId,
                                          autoJoin: true,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: Icon(isVideo
                                    ? Icons.videocam
                                    : Icons.call),
                                label: const Text('Accept'),
                              ),
                            ),
                          ],
                        ),
                    ],
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

class _IncomingRingAvatar extends StatelessWidget {
  const _IncomingRingAvatar({required this.initial, required this.isVideo});

  final String initial;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(seconds: 2),
            curve: Curves.easeInOut,
            builder: (context, t, child) {
              final opacity = (1 - t).clamp(0.0, 1.0);
              final radius = 44.0 + (t * 26.0);
              return Container(
                width: radius * 2,
                height: radius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.green.withOpacity(0.65 * opacity),
                    width: 3,
                  ),
                ),
              );
            },
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(seconds: 2),
            curve: Curves.easeInOut,
            builder: (context, t, child) {
              final opacity = (1 - t).clamp(0.0, 1.0);
              final radius = 44.0 + (t * 26.0);
              return Container(
                width: radius * 2,
                height: radius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.green.withOpacity(0.45 * opacity),
                    width: 2,
                  ),
                ),
              );
            },
          ),
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  initial,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (isVideo) ...[
                  const SizedBox(height: 4),
                  Icon(
                    Icons.videocam,
                    size: 16,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}