#!/bin/sh
# methodology-skill-reminder.sh - 方針検証 skill 発動リマインド (UserPromptSubmit)
#
# 責務:
#   - ユーザーの入力が premise-questioning / feature-pruning の発動条件キーワードを
#     含む場合に reminder を注入する
#   - 発動条件は ~/.codex/AGENTS.md 「着手前の方針検証 (2 段階)」と整合させる
#
# 配置先: codex/hooks/methodology-skill-reminder.sh

[ "${CODEX_METHODOLOGY_SKILL_REMINDER_MODE:-}" = "quiet" ] && exit 0

# === 設定: 二重発火回避対象コマンド ===
# command md 側で発動するため hook 側はスキップ
# 素の "/xxx" 形式と <command-name>/xxx</command-name> タグ形式の両方に対応
SKIP_COMMANDS="feat fix code-review"

# === 設定: 否定文除外パターン (発動キーワードを含むが意図と逆の文章) ===
# 「機能多すぎないか?」のような反語形 (= 発動すべき) を除外しないため、
# 動詞の否定 (~しない / ~は要らない) のみ対象とする
NEGATION_PATTERNS="リファクタしない リファクタリングしない レビューしない レビューは要らない"

# === 設定: premise-questioning 発動キーワード (戦略レベル) ===
# 単純キーワード (空白を含まない)
PREMISE_KEYWORDS="新機能 新規実装 アーキテクチャ 設計レビュー 方針確認 方針レビュー \
外部依存 ライブラリ追加 SDK追加 依存追加 依存削除 \
スキーマ変更 マイグレーション 公開API API契約 \
リファクタリング リファクタ 構造改善"

# === 設定: feature-pruning 発動キーワード (戦術レベル) ===
PRUNING_KEYWORDS="機能多すぎ 機能要らない これ要る 要らない機能 \
機能削減 機能整理 UI整理 画面削減 エンドポイント削減 \
機能リスト"

# === 設定: レビュー系キーワード (premise / pruning 両方発火) ===
REVIEW_KEYWORDS="コードレビュー レビューして"

# === 関数: 任意のキーワードリストに 1 つでもマッチしたら 0 (true) を返す ===
contains_any() {
    _prompt="$1"
    shift
    for _kw in "$@"; do
        case "$_prompt" in
            *"$_kw"*) return 0 ;;
        esac
    done
    return 1
}

# === メイン処理 ===

# stdin がない場合はスキップ
if [ -t 0 ]; then
    exit 0
fi

INPUT=$(cat)

# jaq優先、jqフォールバック
JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")
if [ -z "$JQ" ]; then
    exit 0
fi

PROMPT=$(printf '%s\n' "$INPUT" | "$JQ" -r '.prompt // ""' 2>/dev/null) || PROMPT=""

if [ -z "$PROMPT" ]; then
    exit 0
fi

# スキップ判定: 二重発火回避対象コマンド経由
for cmd in $SKIP_COMMANDS; do
    case "$PROMPT" in
        "/$cmd"*|*"<command-name>/$cmd</command-name>"*)
            exit 0
            ;;
    esac
done

# スキップ判定: 否定文
# shellcheck disable=SC2086
if contains_any "$PROMPT" $NEGATION_PATTERNS; then
    exit 0
fi

# キーワード判定
PREMISE_HIT=0
PRUNING_HIT=0

# shellcheck disable=SC2086
contains_any "$PROMPT" $PREMISE_KEYWORDS && PREMISE_HIT=1

# DB スキーマ系の複合キーワード (空白含むため別扱い)
case "$PROMPT" in
    *DB*スキーマ*|*"API I/F"*) PREMISE_HIT=1 ;;
esac

# shellcheck disable=SC2086
contains_any "$PROMPT" $PRUNING_KEYWORDS && PRUNING_HIT=1

# エンドポイント複数の複合キーワード
case "$PROMPT" in
    *複数*エンドポイント*|*エンドポイント*複数*) PRUNING_HIT=1 ;;
esac

# レビュー系は両方発火
# shellcheck disable=SC2086
if contains_any "$PROMPT" $REVIEW_KEYWORDS; then
    PREMISE_HIT=1
    PRUNING_HIT=1
fi

if [ "$PREMISE_HIT" -eq 0 ] && [ "$PRUNING_HIT" -eq 0 ]; then
    exit 0
fi

cat <<'HEADER'
🎯 [方針検証 skill 発動チェック]
入力に方針検証が必要な可能性のあるキーワードを検知しました。
~/.codex/AGENTS.md 「着手前の方針検証 (2 段階)」と照合して必要なら skill を起動してください。
HEADER

if [ "$PREMISE_HIT" -eq 1 ]; then
    cat <<'PREMISE'

📌 premise-questioning (戦略レベル) 発動条件:
    - [ ] 100 行以上の変更
    - [ ] 外部依存 (ライブラリ / API / SDK) の追加・削除
    - [ ] DB スキーマ / 公開 API I/F 変更
    - [ ] バグ修正で根本原因に手を入れる
    - [ ] 「設計レビューして」「方針確認して」と要求された
    → いずれかに該当する場合は ~/.agents/skills/premise-questioning/SKILL.md を起動
PREMISE
fi

if [ "$PRUNING_HIT" -eq 1 ]; then
    cat <<'PRUNING'

📌 feature-pruning (戦術レベル) 発動条件:
    - [ ] UI 機能リスト 5 個以上
    - [ ] API エンドポイント複数新設
    - [ ] DB テーブル 5 列以上新設
    - [ ] 既存画面 / API の削減レビュー
    - [ ] 「機能多すぎないか」「これ要るか」と要求された
    → いずれかに該当する場合は ~/.agents/skills/feature-pruning/SKILL.md を起動
PRUNING
fi

cat <<'FOOTER'

❌ 該当しない場合は `methodology-skill: skipped (理由: ...)` を 1 行明示してスキップ可
FOOTER

exit 0
