class CallDoc {
  final String id;
  final String callerUid;
  final String calleeUid;
  final String status; // ringing, accepted, ended
  final String channelName;
  final String callType; // 'audio' | 'video'

  /// Both sides should translate into the receiver's language.
  final String callerLang;
  final String calleeLang;

  const CallDoc({
    required this.id,
    required this.callerUid,
    required this.calleeUid,
    required this.status,
    required this.channelName,
    required this.callType,
    required this.callerLang,
    required this.calleeLang,
  });

  factory CallDoc.fromJson(String id, Map<String, dynamic> json) {
    return CallDoc(
      id: id,
      callerUid: (json['callerUid'] as String?) ?? '',
      calleeUid: (json['calleeUid'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'ringing',
      channelName: (json['channelName'] as String?) ?? '',
      callType: (json['callType'] as String?) ?? 'audio',
      callerLang: (json['callerLang'] as String?) ?? 'en',
      calleeLang: (json['calleeLang'] as String?) ?? 'en',
    );
  }
}