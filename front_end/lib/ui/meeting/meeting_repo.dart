import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../../services/room_utterances.dart';
import '../../services/transcript_entry.dart';

/// Firestore mein ek meeting document ka model
class MeetingDoc {
  final String id;
  final String hostUid;
  final String meetingCode; // 6-char human-readable code e.g. "AB12CD"
  final String channelName; // Agora channel name
  final String status; // 'waiting' | 'active' | 'ended'
  final List<String> participantUids;

  /// uid -> display name
  final Map<String, String> participantNames;

  /// uid -> preferred ISO language code ('en' | 'ur' | 'ar' | 'hi').
  /// Each participant hears/reads the meeting in their own language.
  final Map<String, String> participantLangs;

  final DateTime? createdAt;

  const MeetingDoc({
    required this.id,
    required this.hostUid,
    required this.meetingCode,
    required this.channelName,
    required this.status,
    required this.participantUids,
    this.participantNames = const {},
    this.participantLangs = const {},
    this.createdAt,
  });

  factory MeetingDoc.fromJson(String id, Map<String, dynamic> json) {
    final participants = (json['participantUids'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [];

    DateTime? createdAt;
    final ts = json['createdAt'];
    if (ts != null && ts is Timestamp) {
      createdAt = ts.toDate();
    }

    return MeetingDoc(
      id: id,
      hostUid: (json['hostUid'] as String?) ?? '',
      meetingCode: (json['meetingCode'] as String?) ?? '',
      channelName: (json['channelName'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'waiting',
      participantUids: participants,
      participantNames: _stringMap(json['participantNames']),
      participantLangs: _stringMap(json['participantLangs']),
      createdAt: createdAt,
    );
  }

  static Map<String, String> _stringMap(dynamic raw) {
    if (raw is! Map) return const {};
    return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
  }
}

/// Meeting ke liye saare Firestore operations
class MeetingRepo {
  MeetingRepo(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _meetings =>
      _db.collection('meetings');

  // ── Meeting banana ──────────────────────────────────────────────────

  /// Naya meeting create karta hai aur meetingId return karta hai
  Future<String> createMeeting({String? myLang}) async {
    final me = FirebaseAuth.instance.currentUser!;
    final meetingId = const Uuid().v4();

    // 6 character readable code generate karo (e.g. "A3B9XZ")
    final code = _generateCode(meetingId);
    final channelName = 'meeting_$meetingId';
    final name = (me.displayName ?? 'Host').trim();

    await _meetings.doc(meetingId).set({
      'hostUid': me.uid,
      'meetingCode': code,
      'channelName': channelName,
      'status': 'waiting',
      'participantUids': [me.uid],
      'participantNames': {me.uid: name.isEmpty ? 'Host' : name},
      'participantLangs': {me.uid: myLang ?? 'en'},
      'createdAt': FieldValue.serverTimestamp(),
    });

    return meetingId;
  }

  // ── Code se meeting join karna ──────────────────────────────────────

  /// Meeting code se meetingId dhundh ke return karta hai.
  /// Agar nahi mila ya ended hai to exception throw karta hai.
  Future<String> findMeetingByCode(String code) async {
    final q = await _meetings
        .where('meetingCode', isEqualTo: code.trim().toUpperCase())
        .where('status', whereIn: ['waiting', 'active'])
        .limit(1)
        .get();

    if (q.docs.isEmpty) {
      throw StateError('No active meeting found for code "$code".');
    }
    return q.docs.first.id;
  }

  /// Current user ko participantUids mein add karta hai.
  /// Optional [displayName] is stored for guest / profile display.
  Future<void> joinMeeting(
    String meetingId, {
    String? displayName,
    String? myLang,
  }) async {
    final me = FirebaseAuth.instance.currentUser!;
    final name = (displayName ?? me.displayName ?? 'Guest').trim();
    await _meetings.doc(meetingId).update({
      'participantUids': FieldValue.arrayUnion([me.uid]),
      'participantNames.${me.uid}': name.isEmpty ? 'Guest' : name,
      if (myLang != null) 'participantLangs.${me.uid}': myLang,
      'status': 'active',
    });
  }

  /// Anonymous Firebase user + display name for guest join (FR-3).
  Future<User> ensureGuestUser(String displayName) async {
    final existing = FirebaseAuth.instance.currentUser;
    if (existing != null) {
      if (displayName.trim().isNotEmpty) {
        await existing.updateDisplayName(displayName.trim());
      }
      return existing;
    }
    final cred = await FirebaseAuth.instance.signInAnonymously();
    final user = cred.user!;
    if (displayName.trim().isNotEmpty) {
      await user.updateDisplayName(displayName.trim());
    }
    return user;
  }

  // ── Per-participant language ────────────────────────────────────────

  /// Meri preferred language meeting doc mein likho, taake baaki
  /// participants jaan sakein ke mujhe kis language mein sunna hai.
  Future<void> setMyLanguage(String meetingId, String lang) =>
      bus(meetingId).setMyLanguage(lang);

  // ── Utterance bus ───────────────────────────────────────────────────

  /// Is meeting ka text bus (publish / watch / transcript).
  RoomUtterances bus(String meetingId) =>
      RoomUtterances.meeting(meetingId, db: _db);

  /// Poori meeting ka transcript (har speaker ki line, original language mein).
  /// Summarization aur chatbot isi transcript par kaam karte hain.
  Future<String> buildTranscript(String meetingId) =>
      bus(meetingId).buildTranscript();

  /// Wahi transcript, magar har line ke saath uski language bhi — mixed
  /// language meeting ko summarize karne se pehle normalise karne ke liye.
  Future<List<TranscriptEntry>> buildTranscriptEntries(String meetingId) =>
      bus(meetingId).buildTranscriptEntries();

  // ── Status update ───────────────────────────────────────────────────

  Future<void> startMeeting(String meetingId) async {
    await _meetings.doc(meetingId).update({'status': 'active'});
  }

  Future<void> endMeeting(String meetingId) async {
    await _meetings.doc(meetingId).update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Watch ───────────────────────────────────────────────────────────

  Stream<MeetingDoc> watchMeeting(String meetingId) {
    return _meetings.doc(meetingId).snapshots().map((snap) {
      final data = snap.data() ?? const <String, dynamic>{};
      return MeetingDoc.fromJson(snap.id, data);
    });
  }

  // ── Helper ─────────────────────────────────────────────────────────

  String _generateCode(String uuid) {
    // UUID ke pehle 6 hex characters lo, uppercase karo
    final hex = uuid.replaceAll('-', '').toUpperCase();
    return hex.substring(0, 6);
  }
}
