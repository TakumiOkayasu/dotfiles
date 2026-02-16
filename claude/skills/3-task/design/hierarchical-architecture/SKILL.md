---
name: hierarchical-architecture
description: 階層型アーキテクチャの設計・レビュー時に使用。ピラミッド依存構造、レイヤー分離、命名規則、合成パターンをカバー。設計判断・コードレビュー・リファクタリングの方向性判断に参照。
---

# Hierarchical Architecture

## 📋 実行前チェック(必須)

### このスキルを使うべきか?
- [ ] 階層型アーキテクチャのコードを書く・レビューする?
- [ ] レイヤー間の依存方向を確認する?
- [ ] 管理層・提供層・操作層の設計判断をする?
- [ ] 命名がレイヤーの役割を反映しているか検証する?

### 前提条件
- [ ] 対象コードがどのレイヤーに属するか把握しているか?
- [ ] プロジェクトの命名規則を確認したか?
- [ ] interface-composition-design スキルの内容を把握しているか?

### 禁止事項の確認
- [ ] 同一レイヤーのオブジェクト間で直接参照しようとしていないか?
- [ ] 下位→上位の依存を作ろうとしていないか?
- [ ] 利用者にリソースの生成・破棄を担当させようとしていないか?

---

## トリガー

- 階層型アーキテクチャでの設計・実装時
- レイヤー間の依存関係をレビューする時
- 管理・提供・操作の各層の追加・変更時
- 命名がレイヤーの役割を反映しているかの確認時
- リファクタリングの方向性を判断する時

---

## 🚨 鉄則

**依存は常にピラミッド型。横の参照禁止。上位は指示のみ、実行は下位。**

---

## 1. レイヤー構造

上位→下位の依存のみ許可。逆方向は禁止。

| # | 役割 | 責務 |
| --- | --- | --- |
| 1 | Interface Layer | 契約の定義(単一責任のインターフェース) |
| 2 | 管理層 | 下位の生成・破棄・ライフサイクル管理 |
| 3 | 提供層 | 同種の能力を持つものをグルーピングし提供 |
| 4 | 操作層 | 特定のリソースへのアクセス手段 |
| 5 | サブコンポーネント層(任意) | 操作層内部のドメイン固有オブジェクト |
| 6 | Platform Layer | プラットフォーム固有実装 |

Application Codeは最上位から段階的にアクセスする。

**判断基準:** プロジェクトの命名が異なっていても、実質的に上記の役割分担になっているかを確認する。名前ではなく責務で判断する。

---

## 2. 依存方向の制約(ピラミッド構造)

```text

// ✅ 上下の関係のみ
//
//          Manager
//         ↗      ↖
//   CompA         CompB
//
// AがBの情報を必要とする場合:
//   A → Manager に問い合わせ → Manager が応答(抽象化した情報のみ)

// ❌ 横の関係: 同レベル間で直接アクセス
//   CompA ←→ CompB

```

**保証すること:**

- 依存グラフが循環しない(DAGが保たれる)
- コンポーネントの追加・削除が局所的な変更で済む
- 各コンポーネントは自分の上位だけを知ればよい

---

## 3. 上位層の振る舞い

```text
// ✅ 指示のみ: 制約を伝え、実行は下位に任せる
component.set_boundary(limit)
component.notify_state_change(state)

// ❌ 介入: 下位の内部処理を代行する
component.position = calculate_new_position(component)
component.internal_buffer.resize(new_size)
```

**公平性の原則:** 同レベルの複数コンポーネントには同じ抽象化された情報のみ伝達。特定コンポーネントに他の内部情報を教えない。

---

## 4. 段階的アクセスパターン

上位から下位への段階的なアクセスを基本とする。Method Chainパターンはこの代表的な実現手段。

```text
// 基本(3層): 管理 → 提供 → 操作 → method()
ctx.get_xxx_provider().get_yyy_accessor().write("Hello")

// 階層(4層+): 管理 → 提供 → 操作 → サブコンポーネント → method()
accessor = ctx.get_xxx_provider().get_yyy_accessor()
component = accessor.add_sub_component(config)
component.write("Hello")
```

段階を飛ばしたアクセス(管理層から操作層のメソッドを直接呼ぶ等)は依存方向の制約に違反するため禁止。

---

## 5. インターフェース設計

### 単一責任(ISP)

```text
// ✅ 単一責任
interface Readable  { read(buffer, length) -> size; available() -> bool }
interface Writable  { write(buffer, length) -> size }

// ❌ 複数責任の混在
interface NetworkDevice { connect(); scan(); read() }
```

複数の機能を持つ場合は、複数のインターフェースを実装する。

### 抽象化のポリシー

- **操作(動詞)は抽象化可能** - connect(), read(), write() → インターフェース化
- **構造(データ)は抽象化しない** - 値型は具象型を直接使用

### 入出力の分離

物理的に同一デバイスでも、論理的責務で分離する。

```text
// ✅ 分離する
PumpController     implements Switchable    // 出力
FlowSensorReader   implements Measurable    // 入力

// ❌ 混在させない
SmartPump implements Switchable, Measurable
```

---

## 6. 合成・拡張ルール

### 同一インターフェースによる合成

```text
// ✅ 入力の型 = 出力の型 で合成可能
interface Sendable { send(message) }

EmailSender implements Sendable    // 送信手段(実体)
Logger      implements Sendable    // 加工層(内部にSendableを保持)
Encrypter   implements Sendable    // 加工層(内部にSendableを保持)

// 組み合わせ自由
notifier = Encrypter(Logger(EmailSender(config)))
notifier = Logger(Encrypter(SlackSender(config)))
```

### パラメータ化による汎用化

差異がパラメータだけならサブクラスを作らない。

```text
// ✅ 汎用エンジン + パラメータ
config = [
    { type: "temperature", address: 0x48, interval_ms: 1000 },
    { type: "pressure",    address: 0x77, interval_ms: 500 },
]
engine = SensorEngine(config)

// ❌ パラメータごとにサブクラス
TemperatureSensor1000ms extends Sensor
PressureSensor500ms extends Sensor
```

### 複数インスタンスの識別

同一型のインスタンスが複数ある場合はパラメータで識別する。

```text
// ✅ パラメータで識別
get_serial_accessor(port: uint8)
get_serial_count() -> uint8

// ❌ 同一型の複数getter
get_serial_1_accessor()
get_serial_2_accessor()

```

---

## 7. ライフサイクル管理

- **生成と利用の分離** - ファクトリや上位マネージャが生成。利用者は生成方法を知らない
- **確保と解放はワンセット** - リソースを確保したコードが解放責務を持つ
- **リソース管理の独立性** - リソースの確保・解放はマネージャが自律的に行い、利用者は有無を意識しない

---

## 8. イベントモデル

Pull型を基本とする。各コンポーネントが自律的にイベントキューを確認。

```text
// Pull型: 必要に応じてチェック
update(context) {
    if context.event_queue.has(MY_EVENT_TYPE):
        event = context.event_queue.get(MY_EVENT_TYPE)
        this.handle(event)
}
```

イベントキューは管理層または提供層の一部として保持。ピラミッド構造と整合させる。

---

## 9. 入力の抽象化

3段階の変換。アプリケーションコードはIntentのみに依存。

```text
Raw Input        → ハードウェア生データ(ADC値、GPIO等)
Calibrated Input → キャリブレーション済み正規化データ
Intent           → アプリにとって意味のある操作(移動、選択等)
```

---

## 10. 表示とロジックの分離

状態判断ロジックと出力表現を分離。出力側に判断ロジックを持たせない。

---

## 11. 命名規則

名前はレイヤーでの役割を反映する。プロジェクトごとに具体的な命名規則は異なるが、以下の原則を守る。

### レイヤーと命名の対応

| 役割 | 命名に反映すべきこと | 一例 |
| --- | --- | --- |
| 管理・所有 | ライフサイクル管理者であること | *Context,*Manager |
| 分類・提供 | グルーピングと提供者であること | *Provider,*Registry |
| 操作・接続 | 特定リソースへのアクセス手段であること | *Accessor,*Client, *Adapter |
| ドメイン概念 | そのドメインの標準用語 | BLECharacteristic, HTTPRequest |

### 判断基準

- 命名からレイヤーの役割が読み取れるか?
- 管理層のサフィックスが操作層に使われていないか?(逆も同様)
- サブコンポーネント層にはドメイン標準用語が使われているか?(管理・提供・操作層のサフィックスは不適切)

### Getter命名

```text
// ✅ get_+ 対象 + レイヤーを示すサフィックス
get_connectable_provider()
get_serial_accessor(port)
get_serial_count()

// ❌ 禁止パターン
serial_accessor()            // get_プレフィックスなし
get_serial()                 // レイヤーを示すサフィックスなし
get_serial_1_accessor()      // 同一型の複数getter(パラメータ化すべき)
```

---

## 🚫 禁止事項まとめ

- 同一レイヤー間の直接参照
- 下位→上位への依存
- 上位が下位の内部状態を直接操作
- 特定コンポーネントへの内部情報の漏洩(公平性違反)
- 段階を飛ばしたアクセス
- 複数責任を持つインターフェース
- 入出力の混在(同一クラスにReadとWrite系を混ぜる)
- 利用者によるリソース生成
- 同一型の複数getter(パラメータ化で解決)
- レイヤーの役割が読み取れない命名
- サブコンポーネント層への管理・提供・操作層サフィックスの流用
