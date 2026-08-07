import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _displayName = TextEditingController();
  String _defaultLang = 'en';
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _displayName.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final snap = await _userDoc(uid).get();
    final data = snap.data();
    if (!mounted) return;
    setState(() {
      _displayName.text = (data?['displayName'] as String?) ?? '';
      _defaultLang = (data?['defaultLang'] as String?) ?? 'en';
    });
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await _userDoc(uid).set(
        {
          'displayName': _displayName.text.trim(),
          'defaultLang': _defaultLang,
          'updatedAt': FieldValue.serverTimestamp(),
          'email': FirebaseAuth.instance.currentUser!.email,
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final initial = (() {
      final name = _displayName.text.trim();
      if (name.isNotEmpty) return name[0].toUpperCase();
      if (email.isNotEmpty) return email[0].toUpperCase();
      return '?';
    })();

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.14),
              Theme.of(context).colorScheme.secondary.withOpacity(0.10),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.88),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.6),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.18),
                          child: Text(
                            initial,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Signed in as',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                email,
                                style: Theme.of(context).textTheme.titleMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _displayName,
                      enabled: !_isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _defaultLang,
                      decoration: const InputDecoration(
                        labelText: 'Default language (ISO-639-1)',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English (en)')),
                        DropdownMenuItem(value: 'ur', child: Text('Urdu (ur)')),
                        DropdownMenuItem(value: 'ar', child: Text('Arabic (ar)')),
                        DropdownMenuItem(value: 'hi', child: Text('Hindi (hi)')),
                      ],
                      onChanged: _isSaving ? null : (v) => setState(() => _defaultLang = v!),
                    ),
                    const SizedBox(height: 12),
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSaving ? null : _save,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save profile'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

