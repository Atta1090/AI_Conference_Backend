import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/calls_repo.dart';
import 'video_call_screen.dart';

class OutgoingVideoCallScreen extends StatefulWidget {
  const OutgoingVideoCallScreen({super.key, required this.calleeUid});

  final String calleeUid;

  @override
  State<OutgoingVideoCallScreen> createState() =>
      _OutgoingVideoCallScreenState();
}

class _OutgoingVideoCallScreenState extends State<OutgoingVideoCallScreen> {
  String? _callId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final repo = CallsRepo(FirebaseFirestore.instance);
      final callId = await repo.startVideoCall(calleeUid: widget.calleeUid);
      if (!mounted) return;
      setState(() => _callId = callId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Video call')),
        body: Center(child: Text(_error!)),
      );
    }
    if (_callId == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.videocam,
                    size: 72,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Starting video call…',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return VideoCallScreen(callId: _callId!, autoJoin: true);
  }
}