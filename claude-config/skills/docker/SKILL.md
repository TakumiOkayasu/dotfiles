---
name: docker
description: Dockerfileやdocker-compose設定を作成する際に使用。
---

# Docker

## トリガー

- Dockerfile作成時
- docker-compose設定時
- コンテナ化検討時
- マルチステージビルド時

## 鉄則

**イメージは小さく、レイヤーは少なく、セキュリティを意識。**

## Dockerfile

```dockerfile
# ⚠️ 具体的なバージョンを指定
FROM node:20-alpine

WORKDIR /app

# 依存関係を先にコピー(キャッシュ効率化)
COPY package*.json ./
RUN npm ci --only=production

# ソースコードをコピー
COPY . .

# 🚫 rootで実行しない
USER node

EXPOSE 3000
CMD ["node", "dist/index.js"]
```

## マルチステージビルド

```dockerfile
# ビルドステージ
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# 本番ステージ(軽量)
FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
USER node
CMD ["node", "dist/index.js"]
```

## docker-compose

```yaml
version: '3.8'
services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
    depends_on:
      - db
  
  db:
    image: postgres:15-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}  # ⚠️ .envから

volumes:
  postgres_data:
```

## .dockerignore

```
node_modules
.git
.env
*.log
dist
coverage
```

## 🚫 禁止事項

```dockerfile
# ❌ latestタグ
FROM node:latest

# ❌ rootユーザー
USER root

# ❌ シークレットをイメージに含める
COPY .env .
```
