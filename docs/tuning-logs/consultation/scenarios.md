# consultation シナリオカタログ

empirical-prompt-tuning でチューニングするための評価シナリオ。**iter 開始後は変更しない**。

- 対象スキル: `claude/skills/consultation/SKILL.md`
- description: 「実装中に判断が必要になった時、技術選定・設計相談が必要な時に使用。相談テンプレートで構造化された問題提示を強制。」
- 収束目標: **連続2** イテレーション（典型スキル）

## 隣接スキルとの境界（iter 0 整合確認の焦点）

| スキル | 対比 |
|---|---|
| interface-first-design | iface-first = **設計手順の駆動**（疑似コード→interface→クラス→TDD）、consultation = **判断の相談**（AとBで迷っている） |
| systematic-debugging | sd = バグの**原因分析**（Phase 1-4）、consultation = **技術選定・設計の迷い**。仮説確立後の「修正方針AかBか」は consultation 発動余地あり |
| failure-logging | failure-logging = 失敗**記録**（再発防止DB）、consultation = 迷い**相談**（方針決定） |
| tdd | tdd = テスト駆動**実装**、consultation = 実装**前**の判断 |

## Baseline シナリオ

### シナリオA（中央値: 技術選定、前提条件クリア、2案まで絞り込み済）

**状況**:
ユーザー「JWT のリフレッシュトークン保存場所で迷ってる。localStorage に保存するか httpOnly Cookie にするか、XSS と CSRF のトレードオフで決めきれない。

試したこと:
1. localStorage 実装 → XSS ライブラリ混入時に漏洩リスク（OWASP Top 10 A03:2021 を参照）
2. httpOnly Cookie 実装 → CSRF 対策で SameSite=Strict にしたら OAuth リダイレクト後のセッションが切れた

エラーログ: `SameSite=Strict cookie rejected on cross-site redirect`
公式ドキュメント: RFC 6265bis / OWASP Cheat Sheet Session Management を確認済

制約: B2C アプリ、年間MAU 50万、PCI DSS スコープ外。どうすべき?」

**要件チェックリスト**:
1. [critical] **consultation スキルを発動し、Phase 1-4 を順守**（Phase 1 言語化 → Phase 2 テンプレ → Phase 3 送信 → Phase 4 反映）
2. [critical] **Phase 2 テンプレ 6 セクションを全て埋める**（省略不可、SKILL.md L46-68）
3. 前提条件チェックリスト 4項目の充足を明示的に確認する（SKILL.md L26-30）
4. トリガー条件の該当項目（技術選定が必要、複数案を比較検討済み）を明示する
5. 「1. 何が起きているか」に現在のタスク/ブランチ/現象を事実ベースで記載
6. 「3. なぜその問題が発生したのか」で「なぜ?」3-5回の根本原因を展開
7. 「5. 判断が必要な点」を「AとBのどちらを使うべきか」形式で具体化

### シナリオB（edge: interface-first-design との境界、設計相談の発動判定）

**状況**:
ユーザー「新しい `NotificationManager` クラスを設計したい。メール / Slack / SMS を扱う。設計相談したい。依存関係をどう整理すべきか」

**要件チェックリスト**:
1. [critical] **consultation を単独では発動しない、または interface-first-design との関係を明示**（description「技術選定・設計相談」と iface-first「interface設計・依存関係整理・責務分割」が隣接）
2. [critical] **前提条件（AとBで迷っているレベルまで絞り込み）を確認し、未充足なら差し戻す**（SKILL.md L27）
3. interface-first-design への委譲、または併用の提案を出す（疑似コード → interface → クラスの手順がある旨）
4. 「AとBで迷っている」レベルに絞り込めていない旨を指摘
5. 絞り込み質問を提示する（例: 「メール/Slack/SMS の共通抽象は? 非同期戦略は? エラー時フォールバックは?」）
6. 前提条件未充足の場合は発動せず、ユーザー差し戻しの形式で返す

### シナリオC（edge: 前提条件未充足、何も試していない）

**状況**:
ユーザー「React の状態管理で Redux と Zustand どっち使うべき? 決めたい」

（補足情報: 実装はまだ開始していない。公式ドキュメントも未読）

**要件チェックリスト**:
1. [critical] **前提条件（少なくとも1つ以上の解決策を試した / 公式ドキュメント確認済）未充足で発動しない**（SKILL.md L28-30）
2. [critical] **発動しない場合の判定基準（L19「まだ何も試していない / 公式ドキュメント未確認」）を明示的に適用**
3. 前提条件チェックリスト4項目のうちどれが未充足かを列挙する
4. 次にやるべきステップを提示する（各公式ドキュメント確認、最小 PoC 実装、具体ユースケースの列挙など）
5. 「漠然とした質問」が禁止事項（L113）に該当することに言及する
6. 絞り込みができた段階で consultation に戻る旨のガイドを示す

## Hold-out シナリオ（収束判定時のみ使用）

### シナリオD（漠然質問 = 発動すべきでない、systematic-debugging 領域との混同）

**状況**:
ユーザー「API が 500 エラー返してる。どうすればいい?」

（補足情報なし。試したこと・エラーログ・再現手順・仮説すべて未提示）

**要件チェックリスト**:
1. [critical] **consultation を発動しない**（L19「エラーメッセージ未確認」+ 禁止事項 L111「何も試さずに相談」「エラーメッセージを記録せずに相談」「漠然とした質問」に該当）
2. [critical] **systematic-debugging への誘導または情報収集のヒアリングを優先**（バグの原因分析は sd スキルの領域）
3. 発動しない判断根拠（トリガー未該当 + 前提条件未充足 + 禁止事項該当）を明示する
4. ユーザーが次に提示すべき情報（エラーログ原文、再現手順、試したこと、仮説）を列挙する
5. 情報収集後に systematic-debugging → 仮説確立後に方針選定で consultation の順序を提示

## 運用メモ

- シナリオ A は「技術選定・前提条件クリア」の理想ケース。テンプレ全埋めが中核
- シナリオ B は interface-first-design との境界を突く edge。発動判定の精度
- シナリオ C は「前提条件未充足」での発動抑止。禁止事項の積極活用
- シナリオ D は hold-out として、**発動すべきでない場面での誤発動回避**（systematic-debugging との混同、情報不足での発動）を試す
