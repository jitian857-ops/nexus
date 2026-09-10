import 'dart:math';

enum SharedKind { diary, schedule }

enum FriendRequestStatus { pending, accepted, rejected, cancelled }

enum ShareStatus { pending, accepted, declined }

class FriendProfile {
  const FriendProfile({
    required this.uid,
    required this.displayName,
    required this.friendCode,
    this.occupation = '',
    this.photoUrl = '',
  });

  final String uid;
  final String displayName;
  final String friendCode;
  final String occupation;
  final String photoUrl;

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        'friendCode': friendCode,
        'occupation': occupation,
        'photoUrl': photoUrl,
      };

  factory FriendProfile.fromJson(Map<String, dynamic> json) {
    return FriendProfile(
      uid: json['uid'] as String? ?? json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? json['display_name'] as String? ?? '',
      friendCode: json['friendCode'] as String? ?? json['friend_code'] as String? ?? '',
      occupation: json['occupation'] as String? ?? '',
      photoUrl: json['photoUrl'] as String? ?? json['photo_url'] as String? ?? '',
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
    this.aclId = '',
    this.shareStatus = ShareStatus.accepted,
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
  final String aclId;
  final ShareStatus shareStatus;

  String get title => payload['title'] as String? ?? '';

  String get body => payload['body'] as String? ?? payload['note'] as String? ?? '';

  List<String> get imageUrls => [
        for (final item in (payload['images'] as List? ?? payload['image_urls'] as List? ?? const []))
          if (item is String && item.isNotEmpty) item,
      ];

  DateTime? get startAt => DateTime.tryParse(payload['start_at'] as String? ?? '');

  DateTime? get endAt => DateTime.tryParse(payload['end_at'] as String? ?? '');

  bool get allDay => payload['all_day'] as bool? ?? false;
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

class ShareReaction {
  const ShareReaction({required this.itemId, required this.uid, required this.emoji});
  final String itemId;
  final String uid;
  final String emoji;
}

class ShareReply {
  const ShareReply({
    required this.id,
    required this.itemId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    this.author,
  });
  final String id;
  final String itemId;
  final String authorId;
  final String body;
  final DateTime createdAt;
  final FriendProfile? author;
}

class FriendCircle {
  const FriendCircle({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.memberIds,
    required this.createdAt,
  });
  final String id;
  final String name;
  final String ownerId;
  final List<String> memberIds;
  final DateTime createdAt;

  FriendCircle copyWith({
    String? name,
    List<String>? memberIds,
  }) {
    return FriendCircle(
      id: id,
      name: name ?? this.name,
      ownerId: ownerId,
      memberIds: memberIds ?? this.memberIds,
      createdAt: createdAt,
    );
  }
}

class CirclePoll {
  const CirclePoll({
    required this.id,
    required this.circleId,
    required this.title,
    required this.options,
    required this.votes,
    required this.createdAt,
  });
  final String id;
  final String circleId;
  final String title;
  final List<String> options;
  final Map<String, int> votes;
  final DateTime createdAt;

  List<int> get counts {
    final list = List<int>.filled(options.length, 0);
    for (final index in votes.values) {
      if (index >= 0 && index < list.length) list[index]++;
    }
    return list;
  }
}

class CircleWant {
  const CircleWant({
    required this.id,
    required this.circleId,
    required this.title,
    required this.done,
    required this.creatorId,
  });
  final String id;
  final String circleId;
  final String title;
  final bool done;
  final String creatorId;
}

class MemoryAlbum {
  const MemoryAlbum({
    required this.id,
    required this.title,
    required this.ownerId,
    required this.participantIds,
    this.circleId,
    required this.createdAt,
  });
  final String id;
  final String title;
  final String ownerId;
  final List<String> participantIds;
  final String? circleId;
  final DateTime createdAt;

  MemoryAlbum copyWith({
    String? title,
    List<String>? participantIds,
    String? circleId,
  }) {
    return MemoryAlbum(
      id: id,
      title: title ?? this.title,
      ownerId: ownerId,
      participantIds: participantIds ?? this.participantIds,
      circleId: circleId ?? this.circleId,
      createdAt: createdAt,
    );
  }
}

class MemoryPhoto {
  const MemoryPhoto({
    required this.id,
    required this.albumId,
    required this.day,
    required this.authorId,
    this.dataB64 = '',
    this.url = '',
    this.mime = 'image/jpeg',
  });
  final String id;
  final String albumId;
  final DateTime day;
  final String authorId;
  final String dataB64;
  final String url;
  final String mime;

  String get src {
    if (url.isNotEmpty) return url;
    if (dataB64.isEmpty) return '';
    return 'data:$mime;base64,$dataB64';
  }
}

class PhotoComment {
  const PhotoComment({
    required this.id,
    required this.photoId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    this.author,
  });
  final String id;
  final String photoId;
  final String authorId;
  final String body;
  final DateTime createdAt;
  final FriendProfile? author;
}

class TalkMessage {
  const TalkMessage({
    required this.id,
    required this.chatId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    this.imageUrl = '',
    this.author,
  });
  final String id;
  final String chatId;
  final String authorId;
  final String body;
  final DateTime createdAt;
  final String imageUrl;
  final FriendProfile? author;
}

String generateFriendCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();
  return String.fromCharCodes(
    Iterable.generate(8, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
  );
}

String normalizeFriendQuery(String raw) {
  final out = StringBuffer();
  for (final rune in raw.trim().runes) {
    var code = rune;
    if (code >= 0xFF21 && code <= 0xFF3A) {
      code = 0x41 + (code - 0xFF21);
    } else if (code >= 0xFF41 && code <= 0xFF5A) {
      code = 0x41 + (code - 0xFF41);
    } else if (code >= 0xFF10 && code <= 0xFF19) {
      code = 0x30 + (code - 0xFF10);
    }
    if (code >= 0x61 && code <= 0x7A) code -= 0x20;
    final ok = (code >= 0x41 && code <= 0x5A) || (code >= 0x30 && code <= 0x39);
    if (ok) out.writeCharCode(code);
  }
  return out.toString();
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
  if (compact.length == 8) return compact;
  return null;
}

ShareStatus shareStatusFrom(String? raw) {
  return switch (raw) {
    'pending' => ShareStatus.pending,
    'declined' => ShareStatus.declined,
    _ => ShareStatus.accepted,
  };
}

String shareStatusForNew(SharedKind type) {
  return type == SharedKind.schedule ? 'pending' : 'accepted';
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
