import '../widgets/nexus_nav_bar.dart';

enum TutorialTab { home, study, life, money }

class TutorialSlide {
  const TutorialSlide({
    required this.asset,
    required this.title,
    required this.body,
  });

  final String asset;
  final String title;
  final String body;
}

class TutorialDeck {
  const TutorialDeck({
    required this.tab,
    required this.slides,
  });

  final TutorialTab tab;
  final List<TutorialSlide> slides;

  static TutorialTab? forIndex(int index) {
    return switch (index) {
      NexusTab.home => TutorialTab.home,
      NexusTab.study => TutorialTab.study,
      NexusTab.life => TutorialTab.life,
      NexusTab.money => TutorialTab.money,
      _ => null,
    };
  }

  static TutorialDeck of(TutorialTab tab) {
    return switch (tab) {
      TutorialTab.home => home,
      TutorialTab.study => study,
      TutorialTab.life => life,
      TutorialTab.money => money,
    };
  }

  static const home = TutorialDeck(
    tab: TutorialTab.home,
    slides: [
      TutorialSlide(
        asset: 'assets/tutorial/home_01.png',
        title: 'Homeは今日の窓口',
        body: '登録やゲストで入ると、まずここが開きます。今日の予定・学習の残り・残高を、各タブと同じ計算で見ます。',
      ),
      TutorialSlide(
        asset: 'assets/tutorial/home_02.png',
        title: '日付・予定・記念日',
        body: '日付を変えると、その日の予定と名言・記念日が入れ替わります。ゲストの記録は、あとからログインしても自動では移りません。',
      ),
    ],
  );

  static const study = TutorialDeck(
    tab: TutorialTab.study,
    slides: [
      TutorialSlide(
        asset: 'assets/tutorial/study_01.png',
        title: '学習の記録',
        body: '先に教科を追加してから「学習を追加」します。教科がまだなくても、その場で作れます。',
      ),
      TutorialSlide(
        asset: 'assets/tutorial/study_02.png',
        title: 'タイマーと復習',
        body: '集中タイマーで計測できます。提出物や問題から、1日後と5日後の復習カードが付きます。',
      ),
    ],
  );

  static const life = TutorialDeck(
    tab: TutorialTab.life,
    slides: [
      TutorialSlide(
        asset: 'assets/tutorial/life_01.png',
        title: 'カレンダーと予定',
        body: '日付を選んで予定を追加します。共有する相手を選ばない限り、予定は自分だけです。',
      ),
      TutorialSlide(
        asset: 'assets/tutorial/life_02.png',
        title: '共有は閲覧のみ',
        body: '予定だけ、選んだフレンドが閲覧できます。編集のやりとりはありません。日記は非公開が既定で、習慣に点数や診断は出しません。',
      ),
    ],
  );

  static const money = TutorialDeck(
    tab: TutorialTab.money,
    slides: [
      TutorialSlide(
        asset: 'assets/tutorial/money_01.png',
        title: 'Moneyは今月の残高',
        body: '大きな数字は、収入から支出を引いた残高です。未記録と0は別です。',
      ),
      TutorialSlide(
        asset: 'assets/tutorial/money_02.png',
        title: 'ボックスとカード',
        body: '先に収入を残し、ボックスへ分け、カードが支出の記録です。記録の閲覧と削除は、課金の有無では止まりません。',
      ),
    ],
  );
}
