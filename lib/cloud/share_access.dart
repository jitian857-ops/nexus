/// F02 の共有閲覧判定。ACL削除の成功だけを失効条件にしない。
///
/// 旧ACLの移行案（本番適用しない）:
/// 1. コピー環境で `share_acl` を列挙し、docId != item_id + '_' + viewer_id の行を隔離する。
/// 2. `created_at` が無い ACL / friendship は、コピー上でのみ ISO 時刻を補完して検証する。
/// 3. 解除済み・ブロック済み・deleted_at 付きの共有は、受信者の読取対象から外す。
/// 4. 再フレンド後に `acl.created_at < friendship.created_at` の行は復活させず、明示再共有が必要。
/// 5. 本番の一括書き換え・削除は行わない。
class ShareAccess {
  ShareAccess._();

  static String aclId(String itemId, String viewerId) => '${itemId}_$viewerId';

  static bool aclMatches({
    required String docId,
    required String itemId,
    required String viewerId,
  }) {
    return itemId.isNotEmpty &&
        viewerId.isNotEmpty &&
        docId == aclId(itemId, viewerId);
  }

  /// フレンド再成立だけでは、以前の ACL を復活させない。
  static bool grantSurvivesRefriend({
    required DateTime? aclGrantedAt,
    required DateTime? friendshipStartedAt,
  }) {
    if (friendshipStartedAt == null) return true;
    if (aclGrantedAt == null) return false;
    return !aclGrantedAt.isBefore(friendshipStartedAt);
  }

  static bool ownerImmutable({
    required String existingOwnerId,
    required String requestedOwnerId,
  }) {
    return existingOwnerId.isNotEmpty && existingOwnerId == requestedOwnerId;
  }

  static bool viewerCanRead({
    required String viewerId,
    required String ownerId,
    required bool deleted,
    required String aclDocId,
    required String aclItemId,
    required String aclViewerId,
    required bool friends,
    required bool blocked,
    required DateTime? aclGrantedAt,
    required DateTime? friendshipStartedAt,
  }) {
    if (viewerId.isEmpty || viewerId == ownerId) return false;
    if (deleted) return false;
    if (!aclMatches(docId: aclDocId, itemId: aclItemId, viewerId: aclViewerId)) {
      return false;
    }
    if (aclViewerId != viewerId) return false;
    if (!friends || blocked) return false;
    return grantSurvivesRefriend(
      aclGrantedAt: aclGrantedAt,
      friendshipStartedAt: friendshipStartedAt,
    );
  }
}
