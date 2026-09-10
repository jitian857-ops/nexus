import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/theme.dart';
import '../../cloud/cloud_models.dart';
import '../../cloud/friend_models.dart';
import '../../cloud/nexus_cloud.dart';
import '../../data/app_store.dart';
import '../../widgets/friend_avatar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ui_bits.dart';
import 'friend_qr_scan_page.dart';

class FriendAddPage extends StatefulWidget {
  const FriendAddPage({super.key});

  @override
  State<FriendAddPage> createState() => _FriendAddPageState();
}

class _FriendAddPageState extends State<FriendAddPage> {
  var _loading = true;
  var _error = '';
  FriendProfile? _me;
  var _incoming = <FriendRequestItem>[];
  var _outgoing = <FriendRequestItem>[];
  var _friends = <FriendProfile>[];
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
      final incoming = await _loadList(cloud.incomingFriendRequests);
      final outgoing = await _loadList(cloud.outgoingFriendRequests);
      final friends = await _loadList(cloud.listFriends);
      if (!mounted) return;
      setState(() {
        _me = me;
        _incoming = incoming;
        _outgoing = outgoing;
        _friends = friends;
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

  Future<List<T>> _loadList<T>(Future<List<T>> Function() load) async {
    try {
      return await load();
    } catch (_) {
      return <T>[];
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
                  child: Text('フレンドを追加', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
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
                      textCapitalization: TextCapitalization.characters,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'フレンドコード',
                        hintText: '8桁（ハイフンや空白は自動で除きます）',
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: cloud.busy
                          ? null
                          : () async {
                              try {
                                final found = await cloud.lookupFriend(_search.text);
                                if (!context.mounted) return;
                                setState(() => _found = found);
                                if (found == null) {
                                  showNexusToast(context, '見つかりませんでした');
                                }
                              } catch (error) {
                                if (!context.mounted) return;
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
                          if (!context.mounted) return;
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
                  FriendAvatar(name: friend.displayName, photoUrl: friend.photoUrl, radius: 28),
                  const SizedBox(height: 12),
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
