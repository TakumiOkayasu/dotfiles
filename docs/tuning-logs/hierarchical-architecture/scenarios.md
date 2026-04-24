# hierarchical-architecture シナリオカタログ

## 隣接 rule / skill との境界

| 隣接 | 境界 |
|---|---|
| `oop-composition-over-inheritance` | OOP は**設計判断の原則** (パラメータ増・継承増の回避)。HA は**依存方向の強制** (上位→下位のみ)。重複領域 (L69-74 合成・拡張節) は両方適用、両 rule が同じ結論を出す |
| `coding-conventions` L186-213 (命名規則) | CC は変数・関数レベルの命名、HA はクラス/モジュールの**レイヤーサフィックス** (`*Manager`, `*Provider`, `*Accessor` 等)。直交 |
| `coding-conventions` L215-221 (SOLID) | SOLID の「依存性逆転」は HA の「上位→下位依存のみ」を抽象的に表現。HA はレイヤー表という具体化を提供 |
| `interface-first-design` skill | HA の「インターフェースを定義する」(L22) は IFD に明示委譲。IFD は発動時の実装順序、HA は常時のレイヤー構造 |

## baseline シナリオ (3 本、中央値 1 + edge 2)

### A (中央値): Web API バックエンドに「週次レポート生成機能」を追加

**状況**: Python の Web API (FastAPI + SQLAlchemy) に「週次の売上レポートを CSV で生成してメール送信する」機能を追加する。API エンドポイント `POST /reports/weekly` が叩かれたら、DB から注文データを取得 → CSV 整形 → 管理者宛にメール送信。どのレイヤーに何を配置するか設計してほしい。

**要件チェックリスト**:
1. [critical] エンドポイントハンドラ (API 入口) を**管理層相当** (ルーティング・リクエスト受付) に配置し、ビジネスロジックをそこに書かないと明示する
2. [critical] DB アクセス (注文取得)・CSV 生成・メール送信を**それぞれ独立した操作層クラス** (`OrderAccessor` / `CsvWriter` / `MailClient` 等、`*Accessor` or `*Client` サフィックス) に分離する
3. 提供層 (`ReportProvider` or `WeeklyReportService` など) を間に挟み、操作層 3 クラスを合成 (コンストラクタ注入) する
4. 依存方向は Handler → Provider → 各 Accessor/Client の一方向のみで、横参照 (例: `CsvWriter` → `MailClient` 直接呼び出し) を禁止する
5. インターフェース (`Readable` / `Writable` 的な単一責任契約) を先に定義して DI することに触れる
6. 命名サフィックスが各レイヤーの役割を読み取れるものになっているか確認する指摘

### B (edge, 横参照リファクタ): 既存コードで同レイヤー間直接参照

**状況**: 「既存のコードレビューで `UserService.notify_order_confirmation()` が内部で `OrderRepository.get_latest_order()` を直接呼び出している。`UserService` も `OrderRepository` も同じ操作層 (`*Service`, `*Repository`)。これは横参照で禁止とあるが、どうリファクタすべきか」

```python
class UserService:
    def __init__(self, user_repo: UserRepository) -> None:
        self._user_repo = user_repo

    def notify_order_confirmation(self, user_id: int) -> None:
        user = self._user_repo.get(user_id)
        # ↓ 同レイヤーの OrderRepository を直接参照しているのが問題
        order = OrderRepository().get_latest_order(user_id)
        send_email(user.email, f"注文 {order.id} を確認しました")
```

**要件チェックリスト**:
1. [critical] `UserService` と `OrderRepository` が**同一レイヤー (操作層) 間の横参照**であることを指摘する
2. [critical] **上位の提供層** (`NotificationProvider` / `OrderNotificationService` 等) を作り、そこに `UserService`・`OrderAccessor`・`MailClient` を合成する形で依存方向を一方向にするよう提案する
3. `UserService` 内で `OrderRepository()` を直接 new しているのは「利用者によるリソース生成」(L127) 違反でもあると指摘する (DI / コンストラクタ注入推奨)
4. 上位から両者を呼び出す形にすることで、`UserService` が `OrderRepository` を知らなくて済む (疎結合) と説明する
5. 「段階飛ばし」「下位→上位依存」等、別種の禁止パターンと混同させず**横参照** (同レイヤー) であることを正しく特定する

### C (edge, 命名判定の曖昧): `DatabaseConnectionHolder` は管理層 / 提供層 どちらか

**状況**: 既存コードで `DatabaseConnectionHolder` というクラスがある。内部で接続プール (`ConnectionPool`) を保持し、各リクエストに接続を払い出し、終了時にクローズする。この命名はレイヤー規則的にどうレビューすべきか、判定根拠を示してほしい。命名を変えるならどのサフィックスが適切か。

**要件チェックリスト**:
1. [critical] 「下位コンポーネント (接続プール) の**ライフサイクルを持つ**」ことから**管理層** (`*Manager` / `*Context`) が適切と判定する
2. [critical] `*Holder` はレイヤー役割が読み取れない命名であり、**禁止事項 L128「レイヤー役割が読み取れない命名」に該当**と指摘する
3. 命名変更案として `DatabaseConnectionManager` または `DatabaseContext` 等、管理層サフィックスを提示する
4. 提供層 (`*Provider` / `*Registry`) との違い (同種能力の**束**を提供するか、特定リソースの**ライフサイクル**を管理するか) を判定根拠として説明する
5. 操作層 (`*Accessor` / `*Client`) は特定リソースへの**アクセス**を担うもので、ライフサイクル管理とは別と指摘する

## hold-out シナリオ (D、誤発動回避)

### D: 単一ファイル CLI スクリプト (100-200 行) への 6 レイヤー強制を避ける

**状況**: 「ローカル CSV を受け取って空行除去 + 列名リネームをして別ファイルに書き出すワンショット CLI (スクリプト 1 ファイル 100 行程度、個人作業用) を書いてほしい。引数で入力ファイルパスと出力ファイルパスを受け取る」

**要件チェックリスト**:
1. [critical] 6 レイヤー (Interface / 管理 / 提供 / 操作 / サブ / Platform) の**すべてを強制適用しない**。単一ファイル 100 行程度のスクリプトに 6 層構造は過剰
2. [critical] **関数分割 (main / parse_args / load_csv / transform / save_csv 等) 程度で十分**と判定する。不必要な `*Manager` / `*Provider` / `*Accessor` クラス階層を導入しない
3. 将来「同じ変換を複数スクリプトで使い回したい」「Web API から呼ばれる」等の**再利用・合成要求**が出たら、そのとき操作層クラスへ切り出す判断を示す (YAGNI)
4. 「横参照禁止」「段階飛ばし禁止」等の原則は**クラス階層が存在する前提**であり、関数のみのスクリプトでは**適用対象外**であると言及 (過剰発動を防ぐ判断)
5. `Raw Input → Calibrated Input → Intent` (L94) の 3 段変換も、単純スクリプトでは **argparse の結果を直接使ってよい** と判断できる

## 共通の dispatch プロンプト要件

- 対象 rule 本文 (`claude/rules/hierarchical-architecture.md`) を Read で読ませる
- 他 rule / skill の auto-load は避ける (対象 rule 優先参照)
- empirical-prompt-tuning「subagent 起動契約」節のレポート構造で返答
- `[critical]` 項目が全 ○ のときのみ成功
