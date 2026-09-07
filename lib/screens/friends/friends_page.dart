import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/theme.dart';
import '../../cloud/cloud_models.dart';
import '../../cloud/friend_models.dart';
import '../../cloud/nexus_cloud.dart';
import '../../data/app_store.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_bits.dart';
import 'friend_group_page.dart';
import 'friend_qr_scan_page.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  var _loading = true;
  var _error = '';
  FriendProfile? _me;
  var _incoming = <FriendRequestItem>[];
  var _outgoing = <FriendRequestItem>[];
  var _friends = <FriendProfile>[];
  var _shared = <SharedItem>[];
  final _search = TextEditingController();
  FriendProfile? _found;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final cloud = CloudScope.of(context);
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final me = await cloud.ensureFriendCode();
      final incoming = await cloud.incomingFriendRequests();
      final outgoing = await cloud.outgoingFriendRequests();
      final friends = await cloud.listFriends();
      final shared = await cloud.listSharedWithMe();
      if (!mounted) return;
      setState(() {
        _me = me;
        _incoming = incoming;
        _outgoing = outgoing;
        _friends = friends;
        _shared = shared;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = cloudErrorMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _run(Future<void> Function() task) async {
    try {
      await task();
      await _reload();
    } catch (error) {
      if (!mounted) return;
      showNexusToast(context, cloudErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cloud = CloudScope.of(context);
    return Scaffold(
      backgroundColor: NexusColors.background,
      body: PageScaffold(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: NexusColors.text),
                ),
                const Expanded(
                  child: Text('フレンド', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  onPressed: _loading ? null : _reload,
                  icon: Icon(Icons.refresh_rounded, color: NexusColors.cyan),
                ),
              ],
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Text(_error, style: TextStyle(color: NexusColors.expense)),
                    const SizedBox(height: 8),
                    OutlinedButton(onPressed: _reload, child: const Text('再試行')),
                  ],
                ),
              )
            else ...[
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('あなたのフレンドコード', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _me?.friendCode ?? '',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1.4),
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            final code = _me?.friendCode ?? '';
                            await Clipboard.setData(ClipboardData(text: code));
                            if (context.mounted) showNexusToast(context, 'コードをコピーしました');
                          },
                          icon: Icon(Icons.copy_rounded, color: NexusColors.cyan),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () async {
                        final ok = await showNexusSheet<bool>(
                          context: context,
                          useRootNavigator: true,
                          builder: (sheet) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text('コードを再発行しますか？', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 8),
                                Text('今のコードは使えなくなります。', style: TextStyle(color: NexusColors.textSecondary)),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: () => Navigator.pop(sheet, true),
                                  child: const Text('再発行'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(sheet, false),
                                  child: const Text('やめる'),
                                ),
                              ],
                            );
                          },
                        );
                        if (ok == true) await _run(() => cloud.ensureFriendCode(regenerate: true));
                      },
                      child: const Text('コードを再発行'),
                    ),
                    if ((_me?.friendCode ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: QrImageView(
                            data: friendQrPayload(_me!.friendCode),
                            size: 168,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          'このQRを相手に読み取ってもらうと申請できます',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: NexusColors.textMuted, fontSize: 11),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final sent = await openFriendQrScan(context);
                        if (sent) await _reload();
                      },
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                      label: const Text('QRを読み取って追加'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('フレンドを探す', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _search,
                      style: TextStyle(color: NexusColors.text),
                      decoration: const InputDecoration(labelText: 'フレンドコードまたはユーザーID'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: cloud.busy
                          ? null
                          : () async {
                              try {
                                final found = await cloud.lookupFriend(_search.text);
                                if (!mounted) return;
                                setState(() => _found = found);
                                if (found == null) {
                                  showNexusToast(context, '見つかりませんでした');
                                }
                              } catch (error) {
                                if (!mounted) return;
                                showNexusToast(context, cloudErrorMessage(error));
                              }
                            },
                      child: const Text('検索'),
                    ),
                    if (_found != null) ...[
                      const SizedBox(height: 10),
                      Text(_found!.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        _found!.occupation.isEmpty ? _found!.friendCode : '${_found!.occupation}  ·  ${_found!.friendCode}',
                        style: TextStyle(color: NexusColors.textMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => _run(() async {
                          await cloud.sendFriendRequest(_found!.uid);
                          if (!mounted) return;
                          setState(() => _found = null);
                          _search.clear();
                          showNexusToast(context, '申請しました');
                        }),
                        child: const Text('申請する'),
                      ),
                    ],
                  ],
                ),
              ),
              if (_friends.isEmpty && _incoming.isEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'コードを相手に渡すと、フレンド申請できます。メールアドレスでは探せません。',
                  style: TextStyle(color: NexusColors.textMuted, height: 1.4),
                ),
              ],
              if (_incoming.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('届いた申請', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
                const SizedBox(height: 8),
                for (final item in _incoming)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.sender?.displayName ?? 'ユーザー', style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              FilledButton(
                                onPressed: () => _run(() => cloud.respondFriendRequest(item.id, accept: true)),
                                child: const Text('承認'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () => _run(() => cloud.respondFriendRequest(item.id, accept: false)),
                                child: const Text('拒否'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              if (_outgoing.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('送った申請', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
                const SizedBox(height: 8),
                for (final item in _outgoing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      child: Row(
                        children: [
                          Expanded(child: Text(item.receiver?.displayName ?? 'ユーザー')),
                          TextButton(
                            onPressed: () => _run(() => cloud.cancelFriendRequest(item.id)),
                            child: const Text('取消'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text('グループ', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const FriendGroupEditPage(),
                        ),
                      );
                      if (mounted) setState(() {});
                    },
                    child: const Text('グループを作る'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (AppScope.of(context).friendGroups.isEmpty)
                Text('まだグループはありません', style: TextStyle(color: NexusColors.textMuted))
              else
                for (final group in AppScope.of(context).friendGroups)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => FriendGroupEditPage(existing: group),
                          ),
                        );
                        if (mounted) setState(() {});
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: GlassCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(group.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(
                                    '${group.memberIds.length}人',
                                    style: TextStyle(color: NexusColors.textMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: NexusColors.textMuted),
                          ],
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: 16),
              Text('フレンド', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
              const SizedBox(height: 8),
              if (_friends.isEmpty)
                Text('まだフレンドはいません', style: TextStyle(color: NexusColors.textMuted))
              else
                for (final friend in _friends)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => FriendDetailPage(friend: friend),
                          ),
                        );
                        await _reload();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: GlassCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(friend.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(friend.friendCode, style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: NexusColors.textMuted),
                          ],
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: 16),
              Text('共有された日記・予定', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                '閲覧のみです。解除やブロックのあと、再フレンドしても自動では戻りません。',
                style: TextStyle(color: NexusColors.textMuted, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 8),
              if (_shared.isEmpty)
                Text('共有された項目はまだありません', style: TextStyle(color: NexusColors.textMuted))
              else
                for (final item in _shared)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.type == SharedKind.diary ? '日記' : '予定',
                            style: TextStyle(color: NexusColors.cyan, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (item.body.isNotEmpty)
                            Text(item.body, style: TextStyle(color: NexusColors.textSecondary, height: 1.4)),
                          const SizedBox(height: 4),
                          Text(
                            '共有元  ${item.owner?.displayName ?? ''}',
                            style: TextStyle(color: NexusColors.textMuted, fontSize: 11),
                          ),
                          if (item.type == SharedKind.schedule)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  final start = DateTime.tryParse(item.payload['start_at'] as String? ?? '');
                                  if (start == null) return;
                                  final end = DateTime.tryParse(item.payload['end_at'] as String? ?? '');
                                  AppScope.of(context).addSchedule(
                                    title: item.title,
                                    startAt: start,
                                    endAt: end,
                                    allDay: item.payload['all_day'] as bool? ?? false,
                                    tags: [
                                      for (final tag in (item.payload['tags'] as List? ?? const []))
                                        if (tag is String) tag,
                                    ],
                                    source: 'shared',
                                  );
                                  showNexusToast(context, '自分の予定に複製しました');
                                },
                                child: const Text('自分用に複製'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class FriendDetailPage extends StatelessWidget {
  const FriendDetailPage({super.key, required this.friend});

  final FriendProfile friend;

  @override
  Widget build(BuildContext context) {
    final cloud = CloudScope.of(context);
    return Scaffold(
      backgroundColor: NexusColors.background,
      body: PageScaffold(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: NexusColors.text),
                ),
                Expanded(
                  child: Text(friend.displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(friend.friendCode, style: TextStyle(color: NexusColors.textMuted)),
                  if (friend.occupation.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(friend.occupation),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final ok = await _confirm(context, 'フレンドを解除しますか？', '相互の共有もすぐに見えなくなります。もう一度共有するまで戻りません。');
                if (!ok || !context.mounted) return;
                await cloud.removeFriend(friend.uid);
                if (context.mounted) {
                  AppScope.of(context).pruneFriendFromGroups(friend.uid);
                  Navigator.pop(context);
                }
              },
              child: const Text('フレンド解除'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                final ok = await _confirm(context, 'ブロックしますか？', '相手からの申請・共有・閲覧を止めます。');
                if (!ok || !context.mounted) return;
                await cloud.blockUser(friend.uid);
                if (context.mounted) {
                  AppScope.of(context).pruneFriendFromGroups(friend.uid);
                  Navigator.pop(context);
                }
              },
              child: Text('ブロック', style: TextStyle(color: NexusColors.expense)),
            ),
            TextButton(
              onPressed: () async {
                final reason = await _askReason(context);
                if (reason == null || reason.isEmpty) return;
                await cloud.reportUser(targetId: friend.uid, reason: reason);
                if (context.mounted) showNexusToast(context, '通報を送りました');
              },
              child: const Text('通報'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> _confirm(BuildContext context, String title, String body) async {
  final ok = await showNexusSheet<bool>(
    context: context,
    useRootNavigator: true,
    builder: (sheet) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(body, style: TextStyle(color: NexusColors.textSecondary, height: 1.4)),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => Navigator.pop(sheet, true), child: const Text('実行')),
          TextButton(onPressed: () => Navigator.pop(sheet, false), child: const Text('やめる')),
        ],
      );
    },
  );
  return ok == true;
}

Future<String?> _askReason(BuildContext context) async {
  final controller = TextEditingController();
  final saved = await showNexusSheet<bool>(
    context: context,
    useRootNavigator: true,
    builder: (sheet) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('通報理由', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: 3,
            style: TextStyle(color: NexusColors.text),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => Navigator.pop(sheet, true), child: const Text('送信')),
        ],
      );
    },
  );
  final text = controller.text.trim();
  controller.dispose();
  if (saved != true) return null;
  return text;
}
