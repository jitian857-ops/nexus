# 未接続の設計ドラフト

このフォルダは、現行アプリやテストから参照されていない実装案の保管場所です。機能の廃止ではありません。元ファイルの内容をバイト単位で保持し、Dartの解析・コンパイル対象と区別するため `.dart.txt` としています。

| 保存ファイル | 元パス |
|---|---|
| snapshot.dart.txt | lib/data/snapshot.dart |
| report_builder.dart.txt | lib/domain/report_builder.dart |
| report_vault_page.dart.txt | lib/screens/reports/report_vault_page.dart |

## 分離の根拠

2026-10-27、基準コミット `55d1af1e1567ec0dd8822f7d1139ca8b57741f69` で確認:

- `NexusSnapshot` は定義のみで呼び出されていません。現在の保存・クラウド同期は `AppStore.toCloudMap()` を使っています。
- `ReportVaultPage` / `ReportPrintPage` への外部の画面遷移やルートはありません。
- `ReportBuilder` の参照元は未接続の `report_vault_page.dart` のみです。
- `kLifeActivityTags` は他ファイルから参照されていません。
- ドラフトが必要とする `DayCheckIn`、`BoxAllocation`、`StoredReport`、保存API等は現行モデルにありません。

この状態で `lib/` に置くと未実装の型・メソッドへの27件の解析エラーが出ます。一方、通常の起動・保存・画面はこれらのファイルを読み込んでおらず、分離による現行の画面や保存形式の変更はありません。

## 再開するとき

1. レポート機能やスナップショット統合を行う範囲・画面導線・保存互換性を決めます。
2. 必要なモデル、保存と削除API、既存データからの移行を実装し、回帰テストを作ります。現行の `AppStore.toCloudMap()` と二重管理にしないでください。
3. 元のパスへ戻す際は、既に同名ファイルが再作成されていないか確認して差分を統合します。
4. 現行の `GlassCard`、空状態表示、トースト、テーマのAPIと整合させます。
5. 実際のルートから接続し、静的解析、全テスト、Webビルド、保存・復元・レポート表示を確認します。

解析除外ルールや `ignore` でエラーを隠す方式は採用していません。完成済み機能として宣伝しないでください。
