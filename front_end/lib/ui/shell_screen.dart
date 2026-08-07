import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'call/incoming_call_screen.dart';
import 'tabs/call_tab.dart';
import 'tabs/contacts_tab.dart';
import 'tabs/profile_tab.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  // ── Global incoming call listener ─────────────────────────────────────
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _callSub;
  final _navigatedCalls = <String>{};

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _callSub?.cancel();
    super.dispose();
  }

  void _startListening() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _callSub = FirebaseFirestore.instance
        .collection('calls')
        .where('calleeUid', isEqualTo: uid)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      if (snap.docs.isEmpty) return;

      final callId = snap.docs.first.id;

      // Ensure we only navigate once per call
      if (_navigatedCalls.contains(callId)) return;
      _navigatedCalls.add(callId);

      // Push IncomingCallScreen on top of whatever screen is open
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => IncomingCallScreen(callId: callId),
        ),
      );
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pages = const [
      ContactsTab(),
      CallTab(),
      ProfileTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Translation Call'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_alt_outlined),
            selectedIcon: Icon(Icons.people_alt),
            label: 'Contacts',
          ),
          NavigationDestination(
            icon: Icon(Icons.call_outlined),
            selectedIcon: Icon(Icons.call),
            label: 'Call',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}