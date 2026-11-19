import 'package:flutter/material.dart';
import '../data/app_store.dart';

/// Stays visible above routes and sheets until both save destinations succeed.
class SaveStatusBanner extends StatelessWidget {
  const SaveStatusBanner({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (!store.hasUnsavedChanges) return const SizedBox.shrink();
        return Material(
          color: Theme.of(context).colorScheme.errorContainer,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        store.saveFailed
                            ? '変更を保存できませんでした。画面を閉じずに再試行してください。'
                            : '変更を保存中です。画面を閉じないでください。',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                  if (store.saveFailed)
                    TextButton(
                      onPressed: store.retrySave,
                      child: const Text('再試行'),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
