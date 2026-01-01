---
name: internationalization
description: i18nやタイムゾーン処理を実装する際に使用。
---

# Internationalization

## トリガー

- 多言語対応時
- 日付・数値フォーマット時
- タイムゾーン処理時
- RTL言語対応時

## 鉄則

**最初から国際化を意識。後付けは困難。**

## テキスト外部化

```typescript
// ❌
const msg = 'ユーザーが見つかりません';

// ✅
const msg = t('errors.userNotFound');
const greeting = t('greeting', { name });
```

## 翻訳ファイル

```json
// locales/ja/common.json
{
  "greeting": "こんにちは、{{name}}さん",
  "errors": { "userNotFound": "ユーザーが見つかりません" }
}
```

## 複数形

```json
// 英語
{ "items": "{{count}} item", "items_plural": "{{count}} items" }

// 日本語(複数形なし)
{ "items": "{{count}}個" }
```

## 日付・数値

```typescript
// Intl API
new Intl.DateTimeFormat('ja-JP').format(date);
// → "2024/1/15"

new Intl.NumberFormat('ja-JP', {
  style: 'currency', currency: 'JPY'
}).format(1234);
// → "￥1,234"
```

## タイムゾーン

```
サーバー: UTC保存
API: ISO 8601 ("2024-01-15T10:30:00Z")
クライアント: ユーザーのTZで表示
```

```typescript
const userTz = Intl.DateTimeFormat().resolvedOptions().timeZone;
```

## RTL言語

```css
/* 論理プロパティ */
margin-inline-start: 1rem;  /* 左/右ではなく開始側 */
```

```html
<html dir="rtl" lang="ar">
```
