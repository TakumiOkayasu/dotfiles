---
name: file-storage
description: ファイルアップロード、S3、ファイルシステム操作を扱う際に使用。
---

# File & Storage

## 🚨 鉄則

**ユーザーアップロードは信用しない。検証必須。**

## アップロード検証

```typescript
// ⚠️ 必須チェック
const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const MAX_SIZE = 5 * 1024 * 1024; // 5MB

function validateUpload(file: File) {
  // MIMEタイプ(⚠️ 拡張子だけで判断しない)
  if (!ALLOWED_TYPES.includes(file.mimetype)) {
    throw new Error('Invalid file type');
  }
  
  // サイズ
  if (file.size > MAX_SIZE) {
    throw new Error('File too large');
  }
}
```

## ファイル名

```typescript
// 🚫 ユーザー入力をそのまま使わない
const safeName = `${uuid()}-${Date.now()}${path.extname(file.name)}`;

// ❌ 危険
const name = file.originalname;  // ../../../etc/passwd
```

## S3アップロード

```typescript
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';

const s3 = new S3Client({ region: 'ap-northeast-1' });

await s3.send(new PutObjectCommand({
  Bucket: process.env.S3_BUCKET,
  Key: `uploads/${userId}/${safeName}`,
  Body: buffer,
  ContentType: file.mimetype,
}));
```

## 署名付きURL

```typescript
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

// ⚠️ 有効期限を短く
const url = await getSignedUrl(s3, command, { expiresIn: 3600 });
```

## 🚫 禁止事項

```
❌ アップロードファイルを実行可能にする
❌ パス操作でディレクトリトラバーサル許可
❌ 無制限のファイルサイズ
❌ 拡張子だけでファイルタイプ判定
```
