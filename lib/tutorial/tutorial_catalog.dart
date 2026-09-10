import '../widgets/nexus_nav_bar.dart';

enum TutorialTab { home, study, life, money, friends, settings }

class TutorialSlide {
  const TutorialSlide({
    required this.asset,
    required this.label,
  });

  final String asset;
  final String label;
}

class TutorialDeck {
  const TutorialDeck({
    required this.tab,
    required this.slides,
  });

  final TutorialTab tab;
  final List<TutorialSlide> slides;

  String get finishLabel => tab == TutorialTab.settings ? '完了' : 'はじめる';

  static TutorialTab? forIndex(int index) {
    return switch (index) {
      NexusTab.home => TutorialTab.home,
      NexusTab.study => TutorialTab.study,
      NexusTab.life => TutorialTab.life,
      NexusTab.money => TutorialTab.money,
      NexusTab.friends => TutorialTab.friends,
      _ => null,
    };
  }

  static TutorialDeck of(TutorialTab tab) {
    return switch (tab) {
      TutorialTab.home => home,
      TutorialTab.study => study,
      TutorialTab.life => life,
      TutorialTab.money => money,
      TutorialTab.friends => friends,
      TutorialTab.settings => settings,
    };
  }

  static const home = TutorialDeck(
    tab: TutorialTab.home,
    slides: [
      TutorialSlide(
        asset: 'assets/tutorial/home_01.jpg',
        label: 'ネグモだよ！まずは今日の予定をひとつ追加してみよう！',
      ),
      TutorialSlide(
        asset: 'assets/tutorial/home_02.jpg',
        label: '学習を記録すると、目標までの残り時間と今週のグラフに反映されるよ！',
      ),
      TutorialSlide(
        asset: 'assets/tutorial/home_03.jpg',
        label: '下のタブから移動できるよ！勉強はStudy、予定はLife、お金の管理はMoneyへ！',
      ),
    ],
  );

  static const study = TutorialDeck(
    tab: TutorialTab.study,
    slides: [
      TutorialSlide(
        asset: 'assets/tutorial/study_01.jpg',
        label: 'Studyは学習を記録する場所！まずは『教科を追加』から自分の教科を作ろう！',
      ),
      TutorialSlide(
        asset: 'assets/tutorial/study_02.jpg',
        label: '教科名を入力して、好きなアイコンと色を選ぼう。最後に『追加』を押してね！',
      ),
      TutorialSlide(
        asset: 'assets/tutorial/study_03.jpg',
        label: '教科・日付・勉強時間を確認！集中度も選んで、「記録する」を押そう！',
      ),
      TutorialSlide(
        asset: 'assets/tutorial/study_04.jpg',
        label: '30分の記録が反映されたね！今週と累計、教科ごとの時間を見比べてみよう！',
      ),
      TutorialSlide(
        asset: 'assets/tutorial/study_05.jpg',
        label: '提出物は期限とセットで！教科・提出物名・期限を選んで、『追加』で登録しよう！',
      ),
    ],
  );

  static const life = TutorialDeck(
    tab: TutorialTab.life,
    slides: [
      TutorialSlide(
        asset: 'assets/tutorial/life_01.jpg',
        label: 'カレンダーで日付を選ぶと、その日の予定を確認できるよ！左右の矢印で月も変えられるよ。',
      ),
      TutorialSlide(
        asset: 'assets/tutorial/life_02.jpg',
        label: 'タイトルと開始・終了を入力！時間を決めない予定は『終日』を使ってね。',
      ),
      TutorialSlide(
        asset: 'assets/tutorial/life_03.jpg',
        label: '予定が一覧に追加されたね！日付と時間が合っているか確認。今日の予定はHomeにも出るよ！',
      ),
      TutorialSlide(
        asset: 'assets/tutorial/life_04.jpg',
        label: '続けたい習慣をひとつ作ろう！名前・アイコン・色を決めて、『追加』で登録できるよ。',
      ),
      TutorialSlide(
        asset: 'assets/tutorial/life_05.jpg',
        label: '共有したい予定は『フレンドに共有』から相手を選ぼう！選ばなければ自分だけの予定だよ。',
      ),
    ],
  );

  static const money = TutorialDeck(
    tab: TutorialTab.money,
    slides: [
      TutorialSlide(
        asset: 'assets/tutorial/money_01.jpg',
        label: 'まずは収入を登録しよう！入金日と『何月分として使うか』をそれぞれ確認して保存してね。',
      ),
      TutorialSlide(
        asset: 'assets/tutorial/money_02.jpg',
        label: '使うお金は予算ボックス。貯めるお金は貯蓄ボックス！貯蓄の残高は翌月へ持ち越すよ。',
      ),
      TutorialSlide(
        asset: 'assets/tutorial/money_03.jpg',
        label: 'ボックス名と月間予算を決めよう！アイコンや色も選んだら、『作成』で準備完了だよ。',
      ),
      TutorialSlide(
        asset: 'assets/tutorial/money_04.jpg',
        label: '支出はカードに記録しよう！入れるボックス・金額・日付を確認して『保存』を押してね。',
      ),
      TutorialSlide(
        asset: 'assets/tutorial/money_05.jpg',
        label: '買い物の前に残り予算を確認！「今日使える額」「今週使える額」も切り替えて見てみよう！',
      ),
    ],
  );

  static const friends = TutorialDeck(
    tab: TutorialTab.friends,
    slides: [
      TutorialSlide(
        asset: 'assets/tutorial/settings_01.jpg',
        label: '友だちの日記や予定、グループ、思い出はここに集まるよ。右上からフレンドを追加できるよ。',
      ),
    ],
  );

  static const settings = TutorialDeck(
    tab: TutorialTab.settings,
    slides: [
      TutorialSlide(
        asset: 'assets/tutorial/settings_01.jpg',
        label: 'ここで自分好みに設定しよう！テーマやプロフィールを変えられるよ。',
      ),
    ],
  );
}
