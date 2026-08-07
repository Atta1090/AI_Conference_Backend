import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// One participant's recognized speech, carried as **text** (not audio).
///
/// The speaker publishes in their own language; every receiver translates it
/// into the language *they* picked before reading / hearing it.
class Utterance {
  final String id;
  final String speakerUid;
  final String speakerName;
  final String text;
  final String lang;
  final DateTime? createdAt;

  const Utterance({
    required this.id,
    required this.speakerUid,
    required this.speakerName,
    required this.text,
    required this.lang,
    this.createdAt,
  });

  factory Utterance.fromJson(String id, Map<String, dynamic> json) {
    DateTime? createdAt;
    final ts = json['createdAt'];
    if (ts is Timestamp) createdAt = ts.toDate();

    return Utterance(
      id: id,
      speakerUid: (json['speakerUid'] as String?) ?? '',
      speakerName: (json['speakerName'] as String?) ?? 'Speaker',
      text: (json['text'] as String?) ?? '',
      lang: (json['lang'] as String?) ?? 'en',
      createdAt: createdAt,
    );
  }
}

/// Firestore-backed message bus for one room (a meeting or a 1:1 call).
///
/// Rooms live at `meetings/{id}` or `calls/{id}`; utterances go into the
/// `utterances` subcollection underneath, and each participant's chosen
/// language is stored in the room's `participantLangs` map.
class RoomUtterances {
  RoomUtterances({
    required this.collection,
    required this.roomId,
    FirebaseFirestore? db,
  }) : _db = db ?? FirebaseFirestore.instance;

  factory RoomUtterances.meeting(String meetingId, {FirebaseFirestore? db}) =>
      RoomUtterances(collection: 'meetings', roomId: meetingId, db: db);

  factory RoomUtterances.call(String callId, {FirebaseFirestore? db}) =>
      RoomUtterances(collection: 'calls', roomId: callId, db: db);

  final String collection;
  final String roomId;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _room =>
      _db.collection(collection).doc(roomId);

  CollectionReference<Map<String, dynamic>> get _utterances =>
      _room.collection('utterances');

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  String get _myName {
    final me = FirebaseAuth.instance.currentUser;
    final name = (me?.displayName ?? '').trim();
    return name.isEmpty ? 'Speaker' : name;
  }

  /// Tell everyone which language I want to hear/read this room in.
  Future<void> setMyLanguage(String lang) async {
    final uid = _myUid;
    if (uid.isEmpty) return;
    await _room.set({
      'participantLangs': {uid: lang},
      'participantNames': {uid: _myName},
    }, SetOptions(merge: true));
  }

  /// Publish a finished utterance of mine, tagged with the language I spoke.
  Future<void> publish({
    required String text,
    required String lang,
    String? speakerName,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final uid = _myUid;
    if (uid.isEmpty) return;

    final name = (speakerName ?? '').trim();
    // Client timestamp so orderBy works immediately. serverTimestamp() alone
    // leaves createdAt null until the server round-trip, and during that
    // window an orderBy('createdAt') query simply does not see the document
    // — so the other phone never receives the utterance.
    final now = Timestamp.now();
    await _utterances.add({
      'speakerUid': uid,
      'speakerName': name.isEmpty ? _myName : name,
      'text': trimmed,
      'lang': lang,
      'createdAt': now,
      'serverCreatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Live stream of every utterance in this room, oldest first.
  Stream<QuerySnapshot<Map<String, dynamic>>> watch() =>
      _utterances.orderBy('createdAt').snapshots();

  /// The whole conversation as `Name: text` lines — this is what gets fed to
  /// `/summarize` and to the chatbot.
  Future<String> buildTranscript() async {
    final q = await _utterances.orderBy('createdAt').get();
    final lines = <String>[];
    for (final d in q.docs) {
      final u = Utterance.fromJson(d.id, d.data());
      final text = u.text.trim();
      if (text.isEmpty) continue;
      lines.add('${u.speakerName}: $text');
    }
    return lines.join('\n');
  }
}
