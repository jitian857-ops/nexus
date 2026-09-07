import 'dart:math';

enum SharedKind { diary, schedule }

enum FriendRequestStatus { pending, accepted, rejected, cancelled }

class FriendProfile {
  const FriendProfile({
    required this.uid,
    required this.displayName,
    required this.friendCode,
    this.occupation = '',
  });

  final String uid;
  final String displayName;
  final String friendCode;
  final String occupation;

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        'friendCode': friendCode,
        'occupation': occupation,
      };

  factory FriendProfile.fromJson(Map<String, dynamic> json) {
    return FriendProfile(
      uid: json['uid'] as String? ?? json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? json['display_name'] as String? ?? '',
      friendCode: json['friendCode'] as String? ?? json['friend_code'] as String? ?? '',
      occupation: json['occupation'] as String? ?? '',
    );
  }
}

class FriendRequestItem {
  const FriendRequestItem({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    this.sender,
    this.receiver,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final FriendRequestStatus status;
  final DateTime createdAt;
  final FriendProfile? sender;
  final FriendProfile? receiver;

  bool get isPending => status == FriendRequestStatus.pending;
}

class SharedItem {
  const SharedItem({
    required this.id,
    required this.ownerId,
    required this.type,
    required this.sourceLocalId,
    required this.payload,
    required this.updatedAt,
    this.deletedAt,
    this.owner,
    this.viewerIds = const [],
  });

  final String id;
  final String ownerId;
  final SharedKind type;
  final String sourceLocalId;
  final Map<String, dynamic> payload;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final FriendProfile? owner;
  final List<String> viewerIds;

  String get title => payload['title'] as String? ?? '';

  String get body => payload['body'] as String? ?? payload['note'] as String? ?? '';
}

class FriendNotice {
  const FriendNotice({
    required this.id,
    required this.userId,
    required this.type,
    required this.actorId,
    this.targetId,
    this.readAt,
    required this.createdAt,
    this.actor,
  });

  final String id;
  final String userId;
  final String type;
  final String actorId;
  final String? targetId;
  final DateTime? readAt;
  final DateTime createdAt;
  final FriendProfile? actor;

  bool get read => readAt != null;
}

String generateFriendCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();
  return String.fromCharCodes(
    Iterable.generate(8, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
  );
}

String normalizeFriendQuery(String raw) {
  return raw.trim().replaceAll(' ', '').toUpperCase();
}

const kFriendQrPrefix = 'NEXUS.FRIEND:';

String friendQrPayload(String friendCode) => '$kFriendQrPrefix${normalizeFriendQuery(friendCode)}';

String? friendCodeFromScan(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final upper = text.toUpperCase().replaceAll(' ', '');
  const prefixes = ['NEXUS.FRIEND:', 'NEXUS:FRIEND:', 'NEXUS-FRIEND:'];
  for (final prefix in prefixes) {
    if (upper.startsWith(prefix)) {
      final code = normalizeFriendQuery(upper.substring(prefix.length));
      return code.isEmpty ? null : code;
    }
  }
  final uri = Uri.tryParse(text);
  if (uri != null && uri.hasQuery) {
    final c = uri.queryParameters['c'] ?? uri.queryParameters['code'];
    if (c != null && c.trim().isNotEmpty) return normalizeFriendQuery(c);
  }
  final compact = normalizeFriendQuery(text);
  if (RegExp(r'^[A-Z0-9]{8}$').hasMatch(compact)) return compact;
  return null;
}

SharedKind sharedKindFrom(String raw) {
  return raw == 'schedule' ? SharedKind.schedule : SharedKind.diary;
}

FriendRequestStatus requestStatusFrom(String raw) {
  return switch (raw) {
    'accepted' => FriendRequestStatus.accepted,
    'rejected' => FriendRequestStatus.rejected,
    'cancelled' => FriendRequestStatus.cancelled,
    _ => FriendRequestStatus.pending,
  };
}
