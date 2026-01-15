# /bounce - 壁打ち (Anthropic API)

別のClaude Sonnetインスタンスに壁打ちして、アイデアや設計の相談を行う。

## 使い方

```
/bounce <質問内容>
/bounce          # 引数なし: 使い方を表示
```

## 実行手順

### 1. 環境判定とAPIキー取得

```bash
# OS判定
if grep -qi microsoft /proc/version 2>/dev/null; then
  # WSL
  API_KEY=$(pass show "api/wsl/anthropic-brainstorming")
else
  # Windows (Git Bash等) or その他
  API_KEY=$(wsl pass show "api/win/anthropic-brainstorming")
fi
```

### 2. API呼び出し

**リクエスト形式:**

```bash
QUERY="$1"

RESPONSE=$(curl -s https://api.anthropic.com/v1/messages \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: ${API_KEY}" \
  -H "anthropic-version: 2023-06-01" \
  -d "$(jq -n --arg q "$QUERY" '{
    model: "claude-sonnet-4-5-20250929",
    max_tokens: 8192,
    messages: [{role: "user", content: $q}]
  }')")
```

**リクエストボディ構造:**

```json
{
  "model": "claude-sonnet-4-5-20250929",
  "max_tokens": 8192,
  "messages": [
    {
      "role": "user",
      "content": "<質問内容>"
    }
  ]
}
```

### 3. レスポンス形式

**成功時のレスポンス構造:**

```json
{
  "id": "msg_...",
  "type": "message",
  "role": "assistant",
  "content": [
    {
      "type": "text",
      "text": "<回答内容>"
    }
  ],
  "model": "claude-sonnet-4-5-20250929",
  "stop_reason": "end_turn",
  "usage": {
    "input_tokens": 100,
    "output_tokens": 500
  }
}
```

**主要フィールド:**

| フィールド | 説明 |
|-----------|------|
| `id` | メッセージID (msg_で始まる) |
| `content[0].text` | 回答テキスト |
| `stop_reason` | 終了理由 (`end_turn`, `max_tokens`, `stop_sequence`) |
| `usage.input_tokens` | 入力トークン数 |
| `usage.output_tokens` | 出力トークン数 |

### 4. 結果出力

```bash
# 回答を出力
echo "$RESPONSE" | jq -r '.content[0].text'

# Usage表示
INPUT_TOKENS=$(echo "$RESPONSE" | jq -r '.usage.input_tokens')
OUTPUT_TOKENS=$(echo "$RESPONSE" | jq -r '.usage.output_tokens')

# コスト計算 (Sonnet 4.5: $3/1M input, $15/1M output)
COST=$(echo "scale=4; ($INPUT_TOKENS * 3 + $OUTPUT_TOKENS * 15) / 1000000" | bc)

echo ""
echo "[Usage] input: ${INPUT_TOKENS} tokens, output: ${OUTPUT_TOKENS} tokens, cost: ~\$${COST}"
```

### 5. 引数なしの場合

引数がない場合は使い方を表示:

```
bounce - 壁打ちコマンド

Usage:
  /bounce <質問内容>

Example:
  /bounce "この設計パターンについてどう思う?"
  /bounce "Rustで非同期処理を実装する際のベストプラクティスは?"

Backend: Anthropic API (Claude Sonnet)
Cost: ~$0.01-0.05/回
```

## エラーハンドリング

- APIキー取得失敗 → passの設定を確認するよう促す
- API呼び出し失敗 → HTTPステータスコードとエラーメッセージを表示
- レート制限 → 少し待ってから再試行するよう促す

## 注意事項

- このコマンドはClaude Codeが自動的に呼び出すことを想定
- 複雑な設計判断や、セカンドオピニオンが必要な場合に使用
- 人間(ユーザー)も直接呼び出し可能
