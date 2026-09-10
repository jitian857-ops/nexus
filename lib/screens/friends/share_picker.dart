import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../cloud/cloud_models.dart';
import '../../cloud/friend_models.dart';
import '../../cloud/nexus_cloud.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../widgets/ui_bits.dart';

Future<List<String>?> pickShareViewers(
  BuildContext context, {
  List<String> selected = const [],
  bool requireSelection = false,
}) async {
  final cloud = CloudScope.of(context);
  List<FriendProfile> friends;
  try {
    friends = await cloud.listFriends();
  } catch (error) {
    if (context.mounted) {
      showNexusToast(context, cloudErrorMessage(error));
    }
    return null;
  }
  if (!context.mounted) return null;
  if (friends.isEmpty) {
    await showNexusSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('共有できるフレンドがいません', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Friendタブの右上からコードやQRを渡して、相手に申請してもらってください。',
              style: TextStyle(color: NexusColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('閉じる')),
          ],
        );
      },
    );
    return null;
  }
  var picked = {...selected};
  List<FriendGroup> groups = const [];
  try {
    groups = AppScope.of(context).friendGroups;
  } catch (_) {}
  var circles = <FriendCircle>[];
  try {
    circles = await cloud.listCircles();
  } catch (_) {}
  if (!context.mounted) return null;
  return showNexusSheet<List<String>>(
    context: context,
    useRootNavigator: true,
    builder: (sheet) {
      return StatefulBuilder(
        builder: (sheet, setSheet) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('共有する相手', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                requireSelection
                    ? '共有するフレンドを選んでください。選んだ人だけが閲覧できます。編集はできません。解除後は、もう一度共有するまで見えません。'
                    : '初期値は自分のみです。選んだフレンドだけが閲覧できます。編集はできません。',
                style: TextStyle(color: NexusColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              if (groups.isNotEmpty) ...[
                Text('グループ', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final group in groups)
                      ActionChip(
                        label: Text(group.name),
                        onPressed: () {
                          final ids = {
                            for (final friend in friends)
                              if (group.memberIds.contains(friend.uid)) friend.uid,
                          };
                          if (ids.isEmpty) return;
                          setSheet(() {
                            if (ids.every(picked.contains)) {
                              picked.removeAll(ids);
                            } else {
                              picked.addAll(ids);
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (circles.isNotEmpty) ...[
                Text('サークル', style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final circle in circles)
                      ActionChip(
                        label: Text(circle.name),
                        onPressed: () {
                          final ids = {
                            for (final friend in friends)
                              if (circle.memberIds.contains(friend.uid)) friend.uid,
                          };
                          if (ids.isEmpty) return;
                          setSheet(() {
                            if (ids.every(picked.contains)) {
                              picked.removeAll(ids);
                            } else {
                              picked.addAll(ids);
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              for (final friend in friends)
                CheckboxListTile(
                  value: picked.contains(friend.uid),
                  contentPadding: EdgeInsets.zero,
                  title: Text(friend.displayName),
                  subtitle: Text(friend.friendCode, style: TextStyle(color: NexusColors.textMuted, fontSize: 12)),
                  onChanged: (on) {
                    setSheet(() {
                      if (on == true) {
                        picked.add(friend.uid);
                      } else {
                        picked.remove(friend.uid);
                      }
                    });
                  },
                ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: requireSelection && picked.isEmpty
                    ? null
                    : () => Navigator.pop(sheet, picked.toList()),
                child: Text(
                  requireSelection
                      ? (picked.isEmpty ? '相手を選んでください' : '${picked.length}人に共有')
                      : (picked.isEmpty ? '自分のみにする' : '${picked.length}人に共有'),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
