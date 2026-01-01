---
name: websocket-realtime
description: WebSocket、SSE、リアルタイム機能を実装する際に使用。
---

# WebSocket & Real-time

## トリガー

- WebSocket実装時
- SSE(Server-Sent Events)実装時
- リアルタイム通信機能時
- 再接続ロジック設計時

## 鉄則

**接続は切れる前提で設計。再接続ロジック必須。**

## WebSocket (Socket.io)

```typescript
// サーバー
import { Server } from 'socket.io';

const io = new Server(server, {
  cors: { origin: process.env.CLIENT_URL }
});

io.on('connection', (socket) => {
  // ⚠️ 認証確認
  const token = socket.handshake.auth.token;
  if (!verifyToken(token)) {
    socket.disconnect();
    return;
  }
  
  socket.on('message', (data) => {
    // ⚠️ 入力検証
    if (!isValidMessage(data)) return;
    io.emit('message', data);
  });
});
```

```typescript
// クライアント
const socket = io(SERVER_URL, {
  auth: { token },
  reconnection: true,        // ⚠️ 再接続有効
  reconnectionAttempts: 5,
  reconnectionDelay: 1000,
});

socket.on('connect_error', (err) => {
  console.error('Connection failed:', err);
});
```

## Server-Sent Events (SSE)

```typescript
// 一方向通信に最適
app.get('/events', (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  
  const send = (data: any) => {
    res.write(`data: ${JSON.stringify(data)}\n\n`);
  };
  
  // イベント送信
  send({ type: 'connected' });
});
```

## ⚠️ 注意点

```
□ 接続数の上限を設定
□ ハートビートで接続維持確認
□ 認証はハンドシェイク時に
□ メッセージサイズ制限
```

## 🚫 禁止事項

```
❌ 認証なしで接続許可
❌ 受信データを検証なしで使用
❌ 再接続ロジックなし
```
