class CloudSession {
  const CloudSession({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.occupation,
    required this.emailVerified,
    required this.usesFirebase,
  });

  final String uid;
  final String email;
  final String displayName;
  final String occupation;
  final bool emailVerified;
  final bool usesFirebase;

  CloudSession copyWith({
    String? displayName,
    String? occupation,
    bool? emailVerified,
  }) {
    return CloudSession(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      occupation: occupation ?? this.occupation,
      emailVerified: emailVerified ?? this.emailVerified,
      usesFirebase: usesFirebase,
    );
  }
}

class MailItem {
  const MailItem({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
    this.read = false,
    this.kind = 'notice',
  });

  final String id;
  final String title;
  final String body;
  final DateTime at;
  final bool read;
  final String kind;

  MailItem copyWith({bool? read}) {
    return MailItem(
      id: id,
      title: title,
      body: body,
      at: at,
      read: read ?? this.read,
      kind: kind,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'at': at.toIso8601String(),
        'read': read,
        'kind': kind,
      };

  factory MailItem.fromJson(Map<String, dynamic> json) {
    return MailItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
      read: json['read'] as bool? ?? false,
      kind: json['kind'] as String? ?? 'notice',
    );
  }
}

class VaultRecord {
  const VaultRecord({
    required this.id,
    required this.at,
    required this.reason,
    required this.bytes,
    this.data,
  });

  final String id;
  final DateTime at;
  final String reason;
  final int bytes;
  final Map<String, dynamic>? data;

  Map<String, dynamic> toMetaJson() => {
        'id': id,
        'at': at.toIso8601String(),
        'reason': reason,
        'bytes': bytes,
      };
}

class CloudException implements Exception {
  CloudException(this.message);
  final String message;

  @override
  String toString() => message;
}

String cloudErrorMessage(Object error) {
  if (error is CloudException) return error.message;
  final text = error.toString();
  if (text.contains('email-already-in-use')) return 'このメールアドレスはすでに登録されています';
  if (text.contains('invalid-email')) return 'メールアドレスの形が正しくありません';
  if (text.contains('weak-password')) return 'パスワードは8文字以上にしてください';
  if (text.contains('user-not-found') || text.contains('invalid-credential') || text.contains('wrong-password')) {
    return 'メールアドレスまたはパスワードが違います';
  }
  if (text.contains('too-many-requests')) return '少し待ってからやり直してください';
  if (text.contains('unauthorized-continue-uri') || text.contains('invalid-continue-uri')) {
    return '認証メールのリンク先が許可されていません。Firebase の Authorized domains を確認してください';
  }
  if (text.contains('network')) return '通信できませんでした';
  if (text.contains('requires-recent-login')) return '安全のため、もう一度ログインしてから削除してください';
  return '処理できませんでした';
}
