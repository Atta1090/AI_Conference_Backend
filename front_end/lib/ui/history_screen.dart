import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'chatbot_screen.dart';
import 'summary_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF39A935),
        elevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: uid == null
          ? _emptyState('Sign in to see your meeting history.')
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('sessions')
                  .where('participantUid', isEqualTo: uid)
                  .orderBy('updatedAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return _emptyState(
                    'Could not load history. If this is the first run, create a Firestore index for sessions (participantUid + updatedAt).',
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs
                    .where((d) =>
                        ((d.data()['transcript'] as String?) ?? '')
                            .trim()
                            .isNotEmpty)
                    .toList();
                if (docs.isEmpty) return _emptyState();

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final transcript =
                        (data['transcript'] as String?)?.trim() ?? '';
                    final title = data['meetingId'] != null
                        ? 'Meeting'
                        : (data['callId'] != null ? 'Call' : 'Session');
                    final preview = transcript.length > 120
                        ? '${transcript.substring(0, 120)}…'
                        : transcript;
                    final updated = data['updatedAt'];
                    String dateLabel = '';
                    if (updated is Timestamp) {
                      final dt = updated.toDate();
                      dateLabel =
                          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                    }
                    final lang =
                        '${data['srcLang'] ?? 'en'} → ${data['tgtLang'] ?? 'en'}';
                    // Re-open the summary/chatbot in the language this session
                    // was held in, not always English.
                    final sessionLang =
                        (data['srcLang'] as String?)?.trim().isNotEmpty == true
                            ? (data['srcLang'] as String).trim()
                            : 'en';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 3)
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF222222),
                                ),
                              ),
                              Text(
                                dateLabel,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14, color: Color(0xFF555555)),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.language,
                                  size: 18, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                lang,
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.grey),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SummaryScreen(
                                        title: title,
                                        transcript: transcript,
                                        language: sessionLang,
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Summary'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatbotScreen(
                                        transcript: transcript,
                                        language: sessionLang,
                                        meetingId:
                                            data['meetingId'] as String?,
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Ask AI'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _emptyState([String? message]) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          const Text(
            'No History Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF444444),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              message ??
                  'Your meeting and call transcripts will appear here after you end a session.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF777777)),
            ),
          ),
        ],
      ),
    );
  }
}
