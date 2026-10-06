import '../cloud/friend_models.dart';
import '../cloud/nexus_cloud.dart';
import '../core/format.dart';
import '../data/app_store.dart';
import '../data/models.dart';
import '../widgets/nexus_nav_bar.dart';
import 'voice_intent.dart';

class VoiceDispatcher {
  VoiceDispatcher(this.store, {this.cloud});

  final AppStore store;
  final NexusCloud? cloud;

  Future<VoiceDispatchResult> dispatch(VoiceIntent intent) async {
    switch (intent) {
      case VoiceUnknown():
        return VoiceDispatchResult.fail(intent.hint);
      case NavigateTabIntent(:final tabIndex):
        store.goTo(tabIndex);
        return VoiceDispatchResult.ok(message: '画面を開きました', tabIndex: tabIndex);
      case CreateScheduleIntent():
        store.addSchedule(
          title: intent.title.trim().isEmpty ? '予定' : intent.title.trim(),
          startAt: intent.startAt,
          endAt: intent.endAt,
          allDay: intent.allDay,
          note: intent.note,
        );
        store.goTo(NexusTab.life);
        return VoiceDispatchResult.ok(message: store.lastToast, tabIndex: NexusTab.life);
      case CreateSpendIntent():
        return _spend(intent);
      case CreateIncomeIntent():
        final use = nextUseMonth(intent.depositedAt);
        store.addIncome(
          name: intent.name.trim().isEmpty ? '収入' : intent.name.trim(),
          amount: intent.amount,
          depositedAt: dateOnly(intent.depositedAt),
          useYear: use.year,
          useMonth: use.month,
        );
        store.goTo(NexusTab.money);
        return VoiceDispatchResult.ok(message: store.lastToast, tabIndex: NexusTab.money);
      case StartTimerIntent():
        return _startTimer(intent);
      case PauseTimerIntent():
        store.pauseTimer();
        return VoiceDispatchResult.ok(message: 'タイマーを一時停止しました', tabIndex: NexusTab.study);
      case FinishTimerIntent():
        store.finishTimer();
        store.goTo(NexusTab.study);
        return VoiceDispatchResult.ok(message: store.lastToast, tabIndex: NexusTab.study);
      case ToggleHabitIntent():
        if (intent.habitId == null || intent.habitId!.isEmpty) {
          return const VoiceDispatchResult.fail('習慣が見つかりません');
        }
        if (intent.alreadyDone) {
          return const VoiceDispatchResult.fail('すでに記録されています');
        }
        store.toggleHabit(intent.habitId!, dateOnly(DateTime.now()));
        store.goTo(NexusTab.life);
        return VoiceDispatchResult.ok(message: store.lastToast, tabIndex: NexusTab.life);
      case CheckInIntent():
        store.setCheckIn(
          mood: intent.mood == 0 ? (store.mood == 0 ? 3 : store.mood) : intent.mood,
          energy: intent.energy == 0 ? (store.energy == 0 ? 3 : store.energy) : intent.energy,
          tags: intent.tags,
          diary: intent.diary,
        );
        store.goTo(NexusTab.life);
        return VoiceDispatchResult.ok(
          message: store.lastToast.isEmpty ? '今日を記録しました' : store.lastToast,
          tabIndex: NexusTab.life,
        );
      case SetDiaryIntent():
        store.setDiary(intent.text);
        store.goTo(NexusTab.life);
        return VoiceDispatchResult.ok(message: '日記を保存しました', tabIndex: NexusTab.life);
      case ShareItemIntent():
        return _share(intent);
      case CreateAssignmentIntent():
        final subjectId = intent.subjectId ??
            (store.visibleSubjects.isEmpty ? null : store.visibleSubjects.first.id);
        if (subjectId == null) {
          return const VoiceDispatchResult.fail('先に教科を追加してください');
        }
        store.addAssignment(
          subjectId: subjectId,
          title: intent.title.trim().isEmpty ? '提出物' : intent.title.trim(),
          dueAt: intent.dueAt,
        );
        store.goTo(NexusTab.study);
        return VoiceDispatchResult.ok(message: store.lastToast, tabIndex: NexusTab.study);
      case CreateExamIntent():
        store.addExam(
          title: intent.title.trim().isEmpty ? '試験' : intent.title.trim(),
          examAt: intent.examAt,
        );
        store.goTo(NexusTab.study);
        return VoiceDispatchResult.ok(message: store.lastToast, tabIndex: NexusTab.study);
    }
  }

  VoiceDispatchResult _spend(CreateSpendIntent intent) {
    final boxes = store.visibleBoxes;
    if (boxes.isEmpty) {
      return const VoiceDispatchResult.fail('先にボックスを作ってください');
    }
    final boxId = intent.boxId ?? (boxes.length == 1 ? boxes.first.id : null);
    if (boxId == null) {
      return const VoiceDispatchResult.fail('どのボックスに入れるか選んでください');
    }
    final box = store.boxById(boxId);
    if (box == null) {
      return const VoiceDispatchResult.fail('ボックスが見つかりません');
    }
    var kind = intent.kind ?? MoneyCardKind.spend;
    if (box.isSavings && intent.kind == null) {
      return const VoiceDispatchResult.fail('預けるか出すかを選んでください');
    }
    if (intent.amount <= 0) {
      return const VoiceDispatchResult.fail('金額を確認してください');
    }
    store.addMoneyCard(
      boxId: boxId,
      title: intent.title.trim().isEmpty ? '支出' : intent.title.trim(),
      amount: intent.amount,
      at: dateOnly(intent.at),
      memo: intent.memo,
      kind: kind,
    );
    store.goTo(NexusTab.money);
    return VoiceDispatchResult.ok(message: store.lastToast, tabIndex: NexusTab.money);
  }

  VoiceDispatchResult _startTimer(StartTimerIntent intent) {
    if (intent.minutes > 0) {
      store.setTimerMinutes(intent.minutes);
    }
    final subjectId = intent.subjectId ?? store.selectedTimerSubjectId;
    if (subjectId == null) {
      return const VoiceDispatchResult.fail('先に教科を追加してください');
    }
    store.setTimerSubject(subjectId);
    store.startTimer();
    if (!store.timerRunning) {
      return const VoiceDispatchResult.fail('タイマーを開始できませんでした');
    }
    store.goTo(NexusTab.study);
    return VoiceDispatchResult.ok(message: 'タイマーを開始しました', tabIndex: NexusTab.study);
  }

  Future<VoiceDispatchResult> _share(ShareItemIntent intent) async {
    final cloud = this.cloud;
    if (cloud == null || !cloud.isSignedIn || cloud.isGuest) {
      return const VoiceDispatchResult.fail('共有するにはログインが必要です');
    }
    if (intent.viewerId.trim().isEmpty) {
      return const VoiceDispatchResult.fail('共有する相手が見つかりません。表示名と完全に一致する名前を言ってください');
    }

    if (intent.kind == SharedKind.diary) {
      final body = store.diary.trim();
      final images = store.diaryImages[dateKey(store.lifeDate)] ?? const <String>[];
      if (body.isEmpty && images.isEmpty) {
        return const VoiceDispatchResult.fail('共有する日記がありません');
      }
      await cloud.shareItem(
        type: SharedKind.diary,
        sourceLocalId: dateKey(store.lifeDate),
        payload: {
          'title': '${store.lifeDate.month}月${store.lifeDate.day}日の日記',
          'body': body,
          'images': images,
          'occurred_at': store.lifeDate.toIso8601String(),
        },
        viewerIds: [intent.viewerId],
      );
      store.goTo(NexusTab.friends);
      return VoiceDispatchResult.ok(
        message: '${intent.viewerName}に日記を共有しました',
        tabIndex: NexusTab.friends,
      );
    }

    final item = _scheduleForShare(intent);
    if (item == null) {
      return const VoiceDispatchResult.fail('共有する予定がありません');
    }
    await cloud.shareItem(
      type: SharedKind.schedule,
      sourceLocalId: item.id,
      payload: {
        'title': item.title,
        'start_at': item.startAt.toIso8601String(),
        'end_at': item.endAt?.toIso8601String(),
        'all_day': item.allDay,
        'memo': item.note,
        'note': item.note,
        'tags': item.tags,
      },
      viewerIds: [intent.viewerId],
    );
    store.goTo(NexusTab.friends);
    return VoiceDispatchResult.ok(
      message: '${intent.viewerName}に「${item.title}」を共有しました',
      tabIndex: NexusTab.friends,
    );
  }

  ScheduleItem? _scheduleForShare(ShareItemIntent intent) {
    if (intent.sourceLocalId.isNotEmpty) {
      for (final item in store.schedules) {
        if (item.id == intent.sourceLocalId) return item;
      }
    }
    if (store.schedules.isEmpty) return null;
    return store.schedules.last;
  }
}
