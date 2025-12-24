---
name: interface-composition-design
description: クラス設計やアーキテクチャリファクタリング時に使用。継承より合成を推奨。
---

# Interface-based Design

## 鉄則

**実装を隠し、インターフェースのみ公開。合成で拡張。**

## 判断基準

### 1. パラメータ爆発していないか?

```typescript
// ❌ パラメータ追加し続ける
process(data, useA: boolean, useB: boolean, useC: boolean, ...)

// ✅ 実装クラスを追加
interface Processor { process(data): Result }
class ProcessorA implements Processor {}
class ProcessorB implements Processor {} // 新規追加
```

### 2. 新機能で既存コード変更が必要か?

```typescript
// ❌ 分岐を追加
if (type === 'new') { ... } // 既存コード変更

// ✅ 新クラス追加のみ
class NewHandler implements Handler {} // 既存コード変更なし
```

### 3. 単一責任か?

```typescript
// ❌ 複数責任
class UserManager { 
  validate() {}
  save() {}
  sendEmail() {}
}

// ✅ 単一責任
class UserValidator {}
class UserRepository {}
class EmailSender {}
```

## アンチパターン

```typescript
// ❌ instanceof / typeof による分岐
if (obj instanceof TypeA) { ... }

// ❌ Manager / Helper / Util クラス
class DataHelper {} // 何のデータ?

// ❌ 継承の深いヒエラルキー
class A extends B extends C extends D
```

## 実装ポイント

- インターフェースは薄く(必要最小限のメソッド)
- 依存は外部から注入(コンストラクタ)
- 内部実装は完全に隠蔽
