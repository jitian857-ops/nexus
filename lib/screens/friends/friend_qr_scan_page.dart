import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../cloud/cloud_models.dart';
import '../../cloud/friend_models.dart';
import '../../cloud/nexus_cloud.dart';
import '../../widgets/ui_bits.dart';

Future<bool> openFriendQrScan(BuildContext context) async {
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => const FriendQrScanPage()),
  );
  return result == true;
}

class FriendQrScanPage extends StatefulWidget {
  const FriendQrScanPage({super.key});

  @override
  State<FriendQrScanPage> createState() => _FriendQrScanPageState();
}

class _FriendQrScanPageState extends State<FriendQrScanPage> {
  final _paste = TextEditingController();
  var _busy = false;
  var _handled = '';

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  Future<void> _applyRaw(String raw) async {
    final code = friendCodeFromScan(raw);
    if (code == null || code.isEmpty) {
      if (mounted) showNexusToast(context, 'フレンドのQRではありません');
      return;
    }
    if (_busy || _handled == code) return;
    setState(() {
      _busy = true;
      _handled = code;
    });
    final cloud = CloudScope.of(context);
    try {
      final found = await cloud.lookupFriend(code);
      if (!mounted) return;
      if (found == null) {
        showNexusToast(context, '見つかりませんでした');
        setState(() {
          _busy = false;
          _handled = '';
        });
        return;
      }
      final send = await showNexusSheet<bool>(
        context: context,
        useRootNavigator: true,
        builder: (sheet) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('この人に申請しますか？', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(found.displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              Text(
                found.occupation.isEmpty ? found.friendCode : '${found.occupation}  ·  ${found.friendCode}',
                style: TextStyle(color: NexusColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(sheet, true),
                child: const Text('申請する'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(sheet, false),
                child: const Text('やめる'),
              ),
            ],
          );
        },
      );
      if (!mounted) return;
      if (send != true) {
        setState(() {
          _busy = false;
          _handled = '';
        });
        return;
      }
      await cloud.sendFriendRequest(found.uid);
      if (!mounted) return;
      showNexusToast(context, '申請しました');
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      showNexusToast(context, cloudErrorMessage(error));
      setState(() {
        _busy = false;
        _handled = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
                const Expanded(
                  child: Text(
                    'QRを読み取る',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            Expanded(
              child: NexusMotion.inWidgetTest
                  ? const Center(
                      child: Text('カメラはテストでは使いません', style: TextStyle(color: Colors.white70)),
                    )
                  : MobileScanner(
                      onDetect: (capture) {
                        if (_busy) return;
                        for (final barcode in capture.barcodes) {
                          final value = barcode.rawValue;
                          if (value == null || value.isEmpty) continue;
                          _applyRaw(value);
                          break;
                        }
                      },
                      errorBuilder: (context, error) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'カメラを開けませんでした。下の欄にコードを貼ってください。',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.86), height: 1.4),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              color: NexusColors.background,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '相手のフレンドQRを枠に入れるか、コードを貼ってください',
                    style: TextStyle(color: NexusColors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _paste,
                    enabled: !_busy,
                    style: TextStyle(color: NexusColors.text),
                    decoration: const InputDecoration(labelText: 'フレンドコード'),
                    onSubmitted: _applyRaw,
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy ? null : () => _applyRaw(_paste.text),
                    child: Text(_busy ? '処理中...' : 'このコードで探す'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
