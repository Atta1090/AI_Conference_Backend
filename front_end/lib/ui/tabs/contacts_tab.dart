import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../call/outgoing_call_screen.dart';
import '../call/outgoing_video_call_screen.dart';

class ContactsTab extends StatefulWidget {
  const ContactsTab({super.key});

  @override
  State<ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<ContactsTab> {
  final _emailToAdd = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _emailToAdd.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> _usersCol() =>
      FirebaseFirestore.instance.collection('users');

  CollectionReference<Map<String, dynamic>> _contactsCol(String uid) =>
      _usersCol().doc(uid).collection('contacts');

  Future<void> _addContactByEmail() async {
    setState(() => _error = null);
    try {
      final myUid = FirebaseAuth.instance.currentUser!.uid;
      final email = _emailToAdd.text.trim();
      if (email.isEmpty) throw const FormatException('Enter an email.');

      final q = await _usersCol().where('email', isEqualTo: email).limit(1).get();
      if (q.docs.isEmpty) throw StateError('No user found for that email.');
      final other = q.docs.first;
      if (other.id == myUid) throw StateError('You cannot add yourself.');

      await _contactsCol(myUid).doc(other.id).set({
        'uid': other.id,
        'email': email,
        'addedAt': FieldValue.serverTimestamp(),
      });

      _emailToAdd.clear();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _emailToAdd,
                decoration: const InputDecoration(
                  labelText: 'Add contact by email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _addContactByEmail,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _contactsCol(myUid).orderBy('addedAt', descending: true).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text('No contacts yet.'));
              }
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final d = docs[i].data();
                  final uid = d['uid'] as String? ?? docs[i].id;
                  final email = d['email'] as String? ?? 'unknown';
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        email.isNotEmpty ? email[0].toUpperCase() : '?',
                      ),
                    ),
                    title: Text(email),
                    subtitle: Text(
                      uid,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // ── Two call buttons ──────────────────────────────
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Audio call
                        IconButton.filled(
                          tooltip: 'Audio call',
                          style: IconButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    OutgoingCallScreen(calleeUid: uid),
                              ),
                            );
                          },
                          icon: const Icon(Icons.call),
                        ),
                        const SizedBox(width: 8),
                        // Video call
                        IconButton.filled(
                          tooltip: 'Video call',
                          style: IconButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.secondary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onSecondary,
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    OutgoingVideoCallScreen(calleeUid: uid),
                              ),
                            );
                          },
                          icon: const Icon(Icons.videocam),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}