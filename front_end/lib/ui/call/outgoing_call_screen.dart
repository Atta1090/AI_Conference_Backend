import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/calls_repo.dart';
import 'call_screen.dart';

class OutgoingCallScreen extends StatefulWidget {
  const OutgoingCallScreen({super.key, required this.calleeUid});

  final String calleeUid;

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final repo = CallsRepo(FirebaseFirestore.instance);
      final callId = await repo.startCall(calleeUid: widget.calleeUid);
      if (!mounted) return;
      // Replace so CallScreen owns the route (no embed/rebuild lifecycle bugs).
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CallScreen(callId: callId, autoJoin: true),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Call')),
        body: Center(child: Text(_error!)),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.call,
                    size: 72, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 14),
                Text(
                  'Starting call…',
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
}
