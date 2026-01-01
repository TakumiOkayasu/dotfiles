---
name: email
description: メール送信、テンプレート、通知機能を実装する際に使用。
---

# Email

## トリガー

- メール送信機能実装時
- メールテンプレート作成時
- 通知システム構築時
- SMTP設定時

## 鉄則

**本番で誤送信しない仕組みを作る。テスト環境は隔離。**

## 基本設定

```typescript
import nodemailer from 'nodemailer';

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: 587,
  secure: false,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,  // 🚫 ハードコード禁止
  },
});
```

## メール送信

```typescript
await transporter.sendMail({
  from: '"App Name" <noreply@example.com>',
  to: user.email,
  subject: 'Welcome!',
  text: 'Plain text version',  // ⚠️ テキスト版も用意
  html: '<h1>Welcome!</h1>',
});
```

## ⚠️ 本番誤送信防止

```typescript
// 開発環境では送信先を制限
function getSafeRecipient(email: string): string {
  if (process.env.NODE_ENV === 'production') {
    return email;
  }
  // ⚠️ 開発環境では自分宛に
  console.log(`[DEV] Would send to: ${email}`);
  return process.env.DEV_EMAIL || 'dev@example.com';
}
```

## テンプレート

```typescript
// Handlebarsなどを使用
import Handlebars from 'handlebars';

const template = Handlebars.compile(`
  <h1>Hello, {{name}}!</h1>
  <p>Your order #{{orderId}} has been confirmed.</p>
`);

const html = template({ name: 'John', orderId: '12345' });
```

## 🚫 禁止事項

```
❌ ユーザー入力をそのままHTMLに(XSS)
❌ 開発環境で本番メールサーバー使用
❌ 送信エラーを無視
❌ 大量送信をループで(キュー使用)
```

## 大量送信

```typescript
// ⚠️ キューを使用
await emailQueue.add('send', {
  to: user.email,
  template: 'welcome',
  data: { name: user.name }
});
```
