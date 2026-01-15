# /deepresearch - 徹底調査 (Perplexity API)

Perplexity sonar-deep-researchモデルで徹底的なWeb調査を行う。

## 使い方

```
/deepresearch <調査内容>
/deepresearch          # 引数なし: 使い方を表示
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

echo "[INFO] Deep Research実行中... (数分かかる場合があります)" >&2

RESPONSE=$(curl -s https://api.perplexity.ai/chat/completions \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg q "$QUERY" '{
    model: "sonar-deep-research",
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
CITATION_TOKENS=$(echo "$RESPONSE" | jq -r '.usage.citation_tokens // 0')
REASONING_TOKENS=$(echo "$RESPONSE" | jq -r '.usage.reasoning_tokens // 0')
SEARCH_QUERIES=$(echo "$RESPONSE" | jq -r '.usage.search_queries // 0')

# コスト計算 (Deep Research: 複合的)
# input: $2/1M, output: $8/1M, citation: $2/1M, reasoning: $3/1M, search: $5/1K
COST=$(echo "scale=4; \
  $INPUT_TOKENS * 2 / 1000000 + \
  $OUTPUT_TOKENS * 8 / 1000000 + \
  $CITATION_TOKENS * 2 / 1000000 + \
  $REASONING_TOKENS * 3 / 1000000 + \
  $SEARCH_QUERIES * 5 / 1000" | bc)

echo ""
echo "[Usage] input: ${INPUT_TOKENS}, output: ${OUTPUT_TOKENS}, citation: ${CITATION_TOKENS}, reasoning: ${REASONING_TOKENS}, searches: ${SEARCH_QUERIES}"
echo "[Cost] ~\$${COST}"
```

### 4. 引数なしの場合

引数がない場合は使い方を表示:

```
deepresearch - 徹底調査コマンド

Usage:
  /deepresearch <調査内容>

Example:
  /deepresearch "2024年のKubernetesセキュリティベストプラクティス"
  /deepresearch "Rust vs Go パフォーマンス比較 2024"

Backend: Perplexity API (sonar-deep-research)
Cost: ~$0.40-1.30/回

注意: Deep Researchは時間がかかります (数分)
軽い検索には /research を使用してください。
```

## エラーハンドリング

- APIキー取得失敗 → passの設定を確認するよう促す
- API呼び出し失敗 → HTTPステータスコードとエラーメッセージを表示
- レート制限 → 少し待ってから再試行するよう促す
- タイムアウト → Deep Researchは時間がかかるため、待つよう促す

## 注意事項

- 徹底的な調査が必要な場合に使用
- 時間がかかる (数分)
- コストが高い (~$0.40-1.30/回)
- 軽い検索には `/research` を使用
- 複数の引用元を元に包括的なレポートを生成
