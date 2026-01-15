# /research - 軽い検索 (Perplexity API)

Perplexity sonarモデルでWeb検索を行い、最新情報を取得する。

## 使い方

```
/research <検索内容>
/research          # 引数なし: 使い方を表示
```

## 実行手順

### 1. 環境判定とAPIキー取得

```bash
# OS判定
if grep -qi microsoft /proc/version 2>/dev/null; then
  # WSL
  API_KEY=$(pass show "api/wsl/perplexity-deepresearch")
else
  # Windows (Git Bash等) or その他
  API_KEY=$(wsl pass show "api/win/perplexity-deepresearch")
fi
```

### 2. API呼び出し

```bash
QUERY="$1"

RESPONSE=$(curl -s https://api.perplexity.ai/chat/completions \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg q "$QUERY" '{
    model: "sonar",
    messages: [{role: "user", content: $q}]
  }')")
```

### 3. 結果出力

```bash
# 回答を出力
echo "$RESPONSE" | jq -r '.choices[0].message.content'

# 引用元を出力 (あれば)
CITATIONS=$(echo "$RESPONSE" | jq -r '.citations[]? // empty' 2>/dev/null)
if [[ -n "$CITATIONS" ]]; then
  echo ""
  echo "[引用元]"
  echo "$CITATIONS" | while read -r url; do
    echo "  - $url"
  done
fi

# Usage表示
INPUT_TOKENS=$(echo "$RESPONSE" | jq -r '.usage.prompt_tokens // 0')
OUTPUT_TOKENS=$(echo "$RESPONSE" | jq -r '.usage.completion_tokens // 0')

# コスト計算 (sonar: $1/1M input, $1/1M output + request fee ~$0.005)
COST=$(echo "scale=4; ($INPUT_TOKENS + $OUTPUT_TOKENS) / 1000000 + 0.005" | bc)

echo ""
echo "[Usage] input: ${INPUT_TOKENS} tokens, output: ${OUTPUT_TOKENS} tokens, cost: ~\$${COST}"
```

### 4. 引数なしの場合

引数がない場合は使い方を表示:

```
research - 軽い検索コマンド

Usage:
  /research <検索内容>

Example:
  /research "TypeScript 5.4 新機能"
  /research "Rust 2024 edition の変更点"

Backend: Perplexity API (sonar)
Cost: ~$0.005-0.02/回

深い調査が必要な場合は /deepresearch を使用してください。
```

## エラーハンドリング

- APIキー取得失敗 → passの設定を確認するよう促す
- API呼び出し失敗 → HTTPステータスコードとエラーメッセージを表示
- レート制限 → 少し待ってから再試行するよう促す

## 注意事項

- 軽い検索・最新情報の確認に使用
- 徹底調査が必要な場合は `/deepresearch` を使用
- 引用元が返される場合があるので、情報の信頼性確認に活用
