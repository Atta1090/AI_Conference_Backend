/*import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MainDashboard extends StatelessWidget {
  const MainDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF3FA534);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      // ================= APP BAR =================
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "ConvoBridge",
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();

              // logout → back to login
              Navigator.pushReplacementNamed(context, '/login');
            },
            icon: const Icon(Icons.person, color: green),
          )
        ],
      ),

      // ================= BODY =================
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ===== GREEN CARD =====
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Smart Meeting Hub",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "AI summaries • Live translation • Smart captions",
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                          ),
                          onPressed: () {},
                          child: const Text(
                            "Create Meeting",
                            style: TextStyle(color: green),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white24,
                          ),
                          onPressed: () {},
                          child: const Text("Join"),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ===== STATS =====
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                _StatCard("32", "Meetings"),
                _StatCard("21h", "Time Saved"),
                _StatCard("98%", "Accuracy"),
              ],
            ),

            const SizedBox(height: 25),

            const Text(
              "Quick Actions",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            // ===== GRID =====
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                _ActionItem(Icons.smart_toy, "AI Chat"),
                _ActionItem(Icons.description, "Summary"),
                _ActionItem(Icons.translate, "Translate"),
                _ActionItem(Icons.schedule, "Schedule"),
                _ActionItem(Icons.history, "History"),
                _ActionItem(Icons.person, "Profile"),
              ],
            ),

            const SizedBox(height: 20),

            // ===== AI CARD =====
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Row(
                children: [
                  Icon(Icons.psychology, color: green),
                  SizedBox(width: 10),
                  Text(
                    "AI Assistant Active",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  )
                ],
              ),
            )
          ],
        ),
      ),

      // ===== FLOATING BUTTON =====
      floatingActionButton: FloatingActionButton(
        backgroundColor: green,
        onPressed: () {},
        child: const Icon(Icons.video_call),
      ),
    );
  }
}

// ================= SMALL WIDGETS =================

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        width: 100,
        height: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String title;

  const _ActionItem(this.icon, this.title);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.white,
          child: Icon(icon, color: Colors.green),
        ),
        const SizedBox(height: 8),
        Text(title),
      ],
    );
  }
}*/


/*import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MainDashboard extends StatelessWidget {
  const MainDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF3FA534);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      // ================= APP BAR =================
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,

        // 🔥 LOGOUT ARROW (LEFT)
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();

            // go back to login
            Navigator.pushReplacementNamed(context, '/login');
          },
        ),

        title: const Text(
          "ConvoBridge",
          style: TextStyle(color: Colors.black),
        ),

        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.person, color: green),
          )
        ],
      ),

      // ================= BODY =================
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ===== GREEN CARD =====
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Smart Meeting Hub",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "AI summaries • Live translation • Smart captions",
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                          ),
                          onPressed: () {},
                          child: const Text(
                            "Create Meeting",
                            style: TextStyle(color: green),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white24,
                          ),
                          onPressed: () {},
                          child: const Text("Join"),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ===== STATS =====
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                _StatCard("32", "Meetings"),
                _StatCard("21h", "Time Saved"),
                _StatCard("98%", "Accuracy"),
              ],
            ),

            const SizedBox(height: 25),

            const Text(
              "Quick Actions",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            // ===== GRID =====
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                _ActionItem(Icons.smart_toy, "AI Chat"),
                _ActionItem(Icons.description, "Summary"),
                _ActionItem(Icons.translate, "Translate"),
                _ActionItem(Icons.schedule, "Schedule"),
                _ActionItem(Icons.history, "History"),
                _ActionItem(Icons.person, "Profile"),
              ],
            ),

            const SizedBox(height: 20),

            // ===== AI CARD =====
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Row(
                children: [
                  Icon(Icons.psychology, color: green),
                  SizedBox(width: 10),
                  Text(
                    "AI Assistant Active",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  )
                ],
              ),
            )
          ],
        ),
      ),

      // ===== FLOATING BUTTON =====
      floatingActionButton: FloatingActionButton(
        backgroundColor: green,
        onPressed: () {},
        child: const Icon(Icons.video_call),
      ),
    );
  }
}

// ================= SMALL WIDGETS =================

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        width: 100,
        height: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String title;

  const _ActionItem(this.icon, this.title);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.white,
          child: Icon(icon, color: Colors.green),
        ),
        const SizedBox(height: 8),
        Text(title),
      ],
    );
  }
}*/



/*import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'meeting/meeting_repo.dart';
import 'meeting/meeting_video_screen.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  static const _green = Color(0xFF3FA534);

  final _repo = MeetingRepo(FirebaseFirestore.instance);

  bool _creatingMeeting = false;

  // ── Create Meeting ────────────────────────────────────────────────────

  Future<void> _createMeeting() async {
    if (_creatingMeeting) return;
    setState(() => _creatingMeeting = true);

    try {
      final meetingId = await _repo.createMeeting();

      if (!mounted) return;

      // Meeting screen par navigate karo
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MeetingVideoScreen(
            meetingId: meetingId,
            isHost: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create meeting: $e')),
      );
    } finally {
      if (mounted) setState(() => _creatingMeeting = false);
    }
  }

  // ── Join Meeting dialog ───────────────────────────────────────────────

  void _showJoinDialog() {
    final codeCtrl = TextEditingController();
    String? dialogError;
    bool joining = false;

    showDialog(
      context: context,
      barrierDismissible: !joining,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Join Meeting'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter the 6-character meeting code shared by the host.',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'Meeting Code',
                      hintText: 'e.g. A3B9XZ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.meeting_room),
                      errorText: dialogError,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      joining ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: joining
                      ? null
                      : () async {
                          final code = codeCtrl.text.trim().toUpperCase();
                          if (code.length != 6) {
                            setDlgState(
                              () => dialogError = 'Enter a 6-character code',
                            );
                            return;
                          }

                          setDlgState(() {
                            joining = true;
                            dialogError = null;
                          });

                          try {
                            final meetingId =
                                await _repo.findMeetingByCode(code);
                            await _repo.joinMeeting(
                              meetingId,
                              displayName: FirebaseAuth
                                      .instance.currentUser?.displayName ??
                                  'Guest',
                            );

                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop(); // dialog band karo

                            if (!mounted) return;
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MeetingVideoScreen(
                                  meetingId: meetingId,
                                  isHost: false,
                                ),
                              ),
                            );
                          } catch (e) {
                            setDlgState(() {
                              joining = false;
                              dialogError = e.toString().replaceAll(
                                  'StateError: ', '');
                            });
                          }
                        },
                  child: joining
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Join'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      // ── App bar ──────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'ConvoBridge',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.of(context).pushReplacementNamed('/login');
            },
            icon: const Icon(Icons.person, color: _green),
          ),
        ],
      ),

      // ── Body ─────────────────────────────────────────────────────────
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Green card ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Smart Meeting Hub',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'AI summaries • Live translation • Smart captions',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      // ── Create Meeting button ──────────────────────
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed:
                              _creatingMeeting ? null : _createMeeting,
                          child: _creatingMeeting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _green,
                                  ),
                                )
                              : const Text('Create Meeting'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // ── Join button ────────────────────────────────
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white24,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _showJoinDialog,
                          child: const Text('Join'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Stats ──────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                _StatCard('32', 'Meetings'),
                _StatCard('21h', 'Time Saved'),
                _StatCard('98%', 'Accuracy'),
              ],
            ),

            const SizedBox(height: 25),

            const Text(
              'Quick Actions',
              style:
                  TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            // ── Quick actions grid ─────────────────────────────────────
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                _ActionItem(Icons.smart_toy, 'AI Chat'),
                _ActionItem(Icons.description, 'Summary'),
                _ActionItem(Icons.translate, 'Translate'),
                _ActionItem(Icons.schedule, 'Schedule'),
                _ActionItem(Icons.history, 'History'),
                _ActionItem(Icons.person, 'Profile'),
              ],
            ),

            const SizedBox(height: 20),

            // ── AI badge ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Row(
                children: [
                  Icon(Icons.psychology, color: _green),
                  SizedBox(width: 10),
                  Text(
                    'AI Assistant Active',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // ── FAB ────────────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        backgroundColor: _green,
        onPressed: _creatingMeeting ? null : _createMeeting,
        tooltip: 'New Meeting',
        child: const Icon(Icons.video_call),
      ),
    );
  }
}

// ── Small reusable widgets ─────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        width: 100,
        height: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String title;

  const _ActionItem(this.icon, this.title);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.white,
          child: Icon(icon, color: Colors.green),
        ),
        const SizedBox(height: 8),
        Text(title),
      ],
    );
  }
}*/




/*import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'meeting/meeting_repo.dart';
import 'meeting/meeting_video_screen.dart';
import 'chatbot_screen.dart'; // 👈 ADD THIS

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  static const _green = Color(0xFF3FA534);

  final _repo = MeetingRepo(FirebaseFirestore.instance);

  bool _creatingMeeting = false;

  // ── Create Meeting ────────────────────────────────────────────────────

  Future<void> _createMeeting() async {
    if (_creatingMeeting) return;
    setState(() => _creatingMeeting = true);

    try {
      final meetingId = await _repo.createMeeting();

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MeetingVideoScreen(
            meetingId: meetingId,
            isHost: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create meeting: $e')),
      );
    } finally {
      if (mounted) setState(() => _creatingMeeting = false);
    }
  }

  // ── Join Meeting dialog ───────────────────────────────────────────────

  void _showJoinDialog() {
    final codeCtrl = TextEditingController();
    String? dialogError;
    bool joining = false;

    showDialog(
      context: context,
      barrierDismissible: !joining,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Join Meeting'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter the 6-character meeting code shared by the host.',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'Meeting Code',
                      hintText: 'e.g. A3B9XZ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.meeting_room),
                      errorText: dialogError,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      joining ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                  ),
                  onPressed: joining
                      ? null
                      : () async {
                          final code = codeCtrl.text.trim().toUpperCase();
                          if (code.length != 6) {
                            setDlgState(
                              () => dialogError = 'Enter a 6-character code',
                            );
                            return;
                          }

                          setDlgState(() {
                            joining = true;
                            dialogError = null;
                          });

                          try {
                            final meetingId =
                                await _repo.findMeetingByCode(code);
                            await _repo.joinMeeting(
                              meetingId,
                              displayName: FirebaseAuth
                                      .instance.currentUser?.displayName ??
                                  'Guest',
                            );

                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop();

                            if (!mounted) return;
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MeetingVideoScreen(
                                  meetingId: meetingId,
                                  isHost: false,
                                ),
                              ),
                            );
                          } catch (e) {
                            setDlgState(() {
                              joining = false;
                              dialogError =
                                  e.toString().replaceAll('StateError: ', '');
                            });
                          }
                        },
                  child: joining
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Join'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'ConvoBridge',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.of(context).pushReplacementNamed('/login');
            },
            icon: const Icon(Icons.person, color: _green),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // GREEN CARD
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Smart Meeting Hub',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'AI summaries • Live translation • Smart captions',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              _creatingMeeting ? null : _createMeeting,
                          child: _creatingMeeting
                              ? const CircularProgressIndicator()
                              : const Text('Create Meeting'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _showJoinDialog,
                          child: const Text('Join'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                _StatCard('32', 'Meetings'),
                _StatCard('21h', 'Time Saved'),
                _StatCard('98%', 'Accuracy'),
              ],
            ),

            const SizedBox(height: 25),

            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            // 🔥 UPDATED GRID
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _ActionItem(
                  Icons.smart_toy,
                  'AI Chat',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatbotScreen(),
                      ),
                    );
                  },
                ),
                _ActionItem(Icons.description, 'Summary'),
                _ActionItem(Icons.translate, 'Translate'),
                _ActionItem(Icons.schedule, 'Schedule'),
                _ActionItem(Icons.history, 'History'),
                _ActionItem(Icons.person, 'Profile'),
              ],
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Row(
                children: [
                  Icon(Icons.psychology, color: _green),
                  SizedBox(width: 10),
                  Text(
                    'AI Assistant Active',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: _green,
        onPressed: _creatingMeeting ? null : _createMeeting,
        child: const Icon(Icons.video_call),
      ),
    );
  }
}

// ── Widgets ─────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        width: 100,
        height: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const _ActionItem(this.icon, this.title, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            child: Icon(icon, color: Colors.green),
          ),
          const SizedBox(height: 8),
          Text(title),
        ],
      ),
    );
  }
}*/


/*import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'meeting/meeting_repo.dart';
import 'meeting/meeting_video_screen.dart';

// ✅ ALL SCREENS IMPORT
import 'chatbot_screen.dart';
import 'summary_screen.dart';
import 'translate_screen.dart';
import 'schedule_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  static const _green = Color(0xFF3FA534);

  final _repo = MeetingRepo(FirebaseFirestore.instance);

  bool _creatingMeeting = false;

  // ================= CREATE MEETING =================
  Future<void> _createMeeting() async {
    if (_creatingMeeting) return;

    setState(() => _creatingMeeting = true);

    try {
      final meetingId = await _repo.createMeeting();

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MeetingVideoScreen(
            meetingId: meetingId,
            isHost: true,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create meeting: $e')),
      );
    } finally {
      setState(() => _creatingMeeting = false);
    }
  }

  // ================= JOIN MEETING =================
  void _showJoinDialog() {
    final codeCtrl = TextEditingController();
    String? dialogError;
    bool joining = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              title: const Text('Join Meeting'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeCtrl,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'Meeting Code',
                      errorText: dialogError,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                  ),
                  onPressed: joining
                      ? null
                      : () async {
                          final code =
                              codeCtrl.text.trim().toUpperCase();

                          if (code.length != 6) {
                            setDlgState(() =>
                                dialogError = 'Enter valid code');
                            return;
                          }

                          setDlgState(() {
                            joining = true;
                            dialogError = null;
                          });

                          try {
                            final meetingId =
                                await _repo.findMeetingByCode(code);

                            await _repo.joinMeeting(
                              meetingId,
                              displayName: FirebaseAuth
                                      .instance.currentUser?.displayName ??
                                  'Guest',
                            );

                            Navigator.pop(ctx);

                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MeetingVideoScreen(
                                  meetingId: meetingId,
                                  isHost: false,
                                ),
                              ),
                            );
                          } catch (e) {
                            setDlgState(() {
                              joining = false;
                              dialogError = e.toString();
                            });
                          }
                        },
                  child: joining
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Join'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      // ===== APP BAR =====
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'ConvoBridge',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: _green),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),

      // ===== BODY =====
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ===== GREEN CARD =====
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Smart Meeting Hub',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'AI summaries • Live translation • Smart captions',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              _creatingMeeting ? null : _createMeeting,
                          child: _creatingMeeting
                              ? const CircularProgressIndicator()
                              : const Text('Create Meeting'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _showJoinDialog,
                          child: const Text('Join'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ===== STATS =====
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                _StatCard('32', 'Meetings'),
                _StatCard('21h', 'Time Saved'),
                _StatCard('98%', 'Accuracy'),
              ],
            ),

            const SizedBox(height: 25),

            const Text(
              'Quick Actions',
              style:
                  TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            // ===== GRID =====
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [

                // AI CHAT
                _ActionItem(Icons.smart_toy, 'AI Chat', onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ChatbotScreen()));
                }),

                // SUMMARY
                _ActionItem(Icons.description, 'Summary', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SummaryScreen(
                        title: "Meeting",
                        duration: "30 min",
                        participants: ["Ali", "Sara"],
                        transcript:
                            "This meeting discussed app development and planning.",
                      ),
                    ),
                  );
                }),

                // TRANSLATE
                _ActionItem(Icons.translate, 'Translate', onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => TranslateScreen()));
                }),

                // SCHEDULE
                _ActionItem(Icons.schedule, 'Schedule', onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ScheduleScreen()));
                }),

                // HISTORY
                _ActionItem(Icons.history, 'History', onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => HistoryScreen()));
                }),

                // PROFILE
                _ActionItem(Icons.person, 'Profile', onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ProfileScreen()));
                }),
              ],
            ),

            const SizedBox(height: 20),

            // ===== AI BADGE =====
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Row(
                children: [
                  Icon(Icons.psychology, color: _green),
                  SizedBox(width: 10),
                  Text(
                    'AI Assistant Active',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // ===== FAB =====
      floatingActionButton: FloatingActionButton(
        backgroundColor: _green,
        onPressed: _creatingMeeting ? null : _createMeeting,
        child: const Icon(Icons.video_call),
      ),
    );
  }
}

// ================= SMALL WIDGETS =================

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        width: 100,
        height: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const _ActionItem(this.icon, this.title, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            child: Icon(icon, color: Colors.green),
          ),
          const SizedBox(height: 8),
          Text(title),
        ],
      ),
    );
  }
}*/



import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'meeting/meeting_repo.dart';
import 'meeting/meeting_video_screen.dart';

// ✅ ALL SCREENS IMPORT
import 'chatbot_screen.dart';
import 'summary_screen.dart';
import 'translate_screen.dart';
import 'schedule_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  static const _green = Color(0xFF3FA534);

  final _repo = MeetingRepo(FirebaseFirestore.instance);

  bool _creatingMeeting = false;

  // ================= CREATE MEETING =================
  Future<void> _createMeeting() async {
    if (_creatingMeeting) return;

    setState(() => _creatingMeeting = true);

    try {
      final meetingId = await _repo.createMeeting();

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MeetingVideoScreen(
            meetingId: meetingId,
            isHost: true,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create meeting: $e')),
      );
    } finally {
      setState(() => _creatingMeeting = false);
    }
  }

  // ================= JOIN MEETING =================
  void _showJoinDialog() {
    final codeCtrl = TextEditingController();
    String? dialogError;
    bool joining = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              title: const Text('Join Meeting'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeCtrl,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'Meeting Code',
                      errorText: dialogError,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                  ),
                  onPressed: joining
                      ? null
                      : () async {
                          final code =
                              codeCtrl.text.trim().toUpperCase();

                          if (code.length != 6) {
                            setDlgState(() =>
                                dialogError = 'Enter valid code');
                            return;
                          }

                          setDlgState(() {
                            joining = true;
                            dialogError = null;
                          });

                          try {
                            final meetingId =
                                await _repo.findMeetingByCode(code);

                            await _repo.joinMeeting(
                              meetingId,
                              displayName: FirebaseAuth
                                      .instance.currentUser?.displayName ??
                                  'Guest',
                            );

                            Navigator.pop(ctx);

                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MeetingVideoScreen(
                                  meetingId: meetingId,
                                  isHost: false,
                                ),
                              ),
                            );
                          } catch (e) {
                            setDlgState(() {
                              joining = false;
                              dialogError = e.toString();
                            });
                          }
                        },
                  child: joining
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Join'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      // ===== APP BAR =====
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'ConvoBridge',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: _green),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),

      // ===== BODY =====
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ===== GREEN CARD =====
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Smart Meeting Hub',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'AI summaries • Live translation • Smart captions',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              _creatingMeeting ? null : _createMeeting,
                          child: _creatingMeeting
                              ? const CircularProgressIndicator()
                              : const Text('Create Meeting'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _showJoinDialog,
                          child: const Text('Join'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ===== STATS =====
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                _StatCard('32', 'Meetings'),
                _StatCard('21h', 'Time Saved'),
                _StatCard('98%', 'Accuracy'),
              ],
            ),

            const SizedBox(height: 25),

            const Text(
              'Quick Actions',
              style:
                  TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            // ===== GRID =====
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [

                // AI CHAT
                _ActionItem(Icons.smart_toy, 'AI Chat', onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ChatbotScreen()));
                }),

                // SUMMARY
                _ActionItem(Icons.description, 'Summary', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SummaryScreen(
                        title: "Meeting",
                        duration: "30 min",
                        participants: ["Ali", "Sara"],
                        transcript:
                            "This meeting discussed app development and planning.",
                      ),
                    ),
                  );
                }),

                // TRANSLATE
                _ActionItem(Icons.translate, 'Translate', onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => TranslateScreen()));
                }),

                // SCHEDULE
                _ActionItem(Icons.schedule, 'Schedule', onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ScheduleScreen()));
                }),

                // HISTORY
                _ActionItem(Icons.history, 'History', onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => HistoryScreen()));
                }),

                // PROFILE
                _ActionItem(Icons.person, 'Profile', onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ProfileScreen()));
                }),
              ],
            ),

            const SizedBox(height: 20),

            // ===== AI BADGE =====
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Row(
                children: [
                  Icon(Icons.psychology, color: _green),
                  SizedBox(width: 10),
                  Text(
                    'AI Assistant Active',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // ===== FAB =====
      floatingActionButton: FloatingActionButton(
        backgroundColor: _green,
        onPressed: _creatingMeeting ? null : _createMeeting,
        child: const Icon(Icons.video_call),
      ),
    );
  }
}

// ================= SMALL WIDGETS =================

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        width: 100,
        height: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const _ActionItem(this.icon, this.title, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            child: Icon(icon, color: Colors.green),
          ),
          const SizedBox(height: 8),
          Text(title),
        ],
      ),
    );
  }
}

