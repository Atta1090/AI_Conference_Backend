import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../ui/call/call_models.dart';

class CallsRepo {
  CallsRepo(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  Future<String> _getUserLang(String uid) async {
    final snap = await _userDoc(uid).get();
    final lang = snap.data()?['defaultLang'] as String?;
    return (lang == null || lang.isEmpty) ? 'en' : lang;
  }

  /// Creates an audio call document (existing behaviour).
  Future<String> startCall({required String calleeUid}) =>
      _startCallDoc(calleeUid: calleeUid, callType: 'audio');

  /// Creates a video call document.
  Future<String> startVideoCall({required String calleeUid}) =>
      _startCallDoc(calleeUid: calleeUid, callType: 'video');

  Future<String> _startCallDoc({
    required String calleeUid,
    required String callType,
  }) async {
    final me = FirebaseAuth.instance.currentUser!;
    final callerLang = await _getUserLang(me.uid);
    final calleeLang = await _getUserLang(calleeUid);

    final callId = const Uuid().v4();
    final channelName = 'call_$callId';

    await _db.collection('calls').doc(callId).set({
      'callerUid': me.uid,
      'calleeUid': calleeUid,
      'status': 'ringing',
      'channelName': channelName,
      'callType': callType,
      'callerLang': callerLang,
      'calleeLang': calleeLang,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return callId;
  }

  Stream<CallDoc> watchCall(String callId) {
    return _db.collection('calls').doc(callId).snapshots().map((snap) {
      final data = snap.data() ?? const <String, dynamic>{};
      return CallDoc.fromJson(snap.id, data);
    });
  }

  Future<void> acceptCall(String callId) async {
    await _db.collection('calls').doc(callId).set(
      {'status': 'accepted', 'acceptedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Future<void> endCall(String callId) async {
    await _db.collection('calls').doc(callId).set(
      {'status': 'ended', 'endedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }
}