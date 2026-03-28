# Hierarchical Architecture

**依存は常にピラミッド型。横の参照禁止。上位は指示のみ、実行は下位。**

## レイヤー構造 (上位→下位の依存のみ許可)

| # | 役割 | 責務 |
|---|------|------|
| 1 | Interface | 契約の定義 (単一責任) |
| 2 | 管理層 | 下位の生成・破棄・ライフサイクル |
| 3 | 提供層 | 同種能力のグルーピング |
| 4 | 操作層 | 特定リソースへのアクセス |
| 5 | サブコンポーネント (任意) | ドメイン固有オブジェクト |
| 6 | Platform | プラットフォーム固有実装 |

## ピラミッド依存

- A→B必要時: A→Manager問い合わせ→抽象情報で応答
- 横参照 (A←→B) 禁止
- 段階飛ばしアクセス禁止
- 上位は指示のみ。下位の内部操作代行は禁止
- 同レベルには同じ抽象化情報のみ伝達 (公平性)

## インターフェース設計

- 単一責任: `Readable { read() }` + `Writable { write() }` (混在NG)
- 操作は抽象化可能 / データは具象型を直接使用
- 入出力は分離: 物理的に同一でも論理的責務で分ける

## 合成・拡張

- 同一IF合成: `Encrypter(Logger(EmailSender(config)))` — 組み合わせ自由
- パラメータ化: 差異がパラメータだけならサブクラス不要
- 合成 > 継承: 深い継承禁止。コンストラクタ注入で合成
- DI: インターフェースに依存。具象クラス直接依存禁止

## 入力の抽象化

Raw Input → Calibrated Input → Intent。アプリケーションコードはIntentのみに依存。

## ライフサイクル・イベント

- 生成と利用の分離 / 確保と解放はワンセット
- リソース管理の独立性: マネージャが自律的に確保・解放
- Pull型イベント基本

## 命名規則

| 役割 | サフィックス例 | 具体例 |
|------|---------------|--------|
| 管理 | *Context, *Manager | `ConnectionManager`, `AppContext` |
| 提供 | *Provider, *Registry | `ConfigProvider`, `HandlerRegistry` |
| 操作 | *Accessor, *Client | `DatabaseAccessor`, `HttpClient` |

## 使用例

### ✅ 正しい依存方向

```
Controller (管理層)
  └─ UserProvider (提供層)
       └─ UserAccessor (操作層)
            └─ PostgresClient (Platform)
```

### ❌ 禁止パターン

```
# 横参照
UserAccessor → OrderAccessor  # NG: 同レイヤー直接参照

# 段階飛ばし
Controller → PostgresClient   # NG: 管理層がPlatform直接参照

# 下位→上位
UserAccessor → Controller     # NG: 逆依存
```

## 禁止事項

- 同一レイヤー間直接参照 / 下位→上位依存 / 段階飛ばし
- 複数責任IF / 入出力混在 / 深い継承 / 具象依存
- 利用者によるリソース生成 / 公平性違反
- レイヤー役割が読み取れない命名
