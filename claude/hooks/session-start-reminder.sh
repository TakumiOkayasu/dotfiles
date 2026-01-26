#!/bin/sh
# session-start-reminder.sh - セッション開始時のリマインダー
#
# 責務:
#   - セッション開始メッセージの表示
#   - リマインダーの表示
#   - claude-config-info.sh の呼び出し
#   - 環境チェック（Docker, Git）
#   - hookルール出力
#
# 配置先: claude-config/hooks/session-start-reminder.sh
#         -> ~/.claude/hooks/session-start-reminder.sh (symlink)

set -eu

# claude-config-info.sh を検索
find_config_info_script() {
    for dir in "$HOME/.claude/bin" "$HOME/.local/bin"; do
        if [ -x "$dir/claude-config-info.sh" ]; then
            echo "$dir/claude-config-info.sh"
            return 0
        fi
    done
    return 1
}

CONFIG_INFO_SCRIPT=""
if script=$(find_config_info_script 2>/dev/null); then
    CONFIG_INFO_SCRIPT="$script"
fi

# メイン出力
echo ""
echo "🚀 Claude Code Session Started"
echo ""
echo "📋 REMINDERS:"
echo "  1. Read CLAUDE.md before starting any task"
echo "  2. Create a new branch before coding (no work on main)"
echo "  3. Test-first approach (RED-GREEN-REFACTOR)"
echo "  4. Consult before implementing if unclear"
echo "  5. Check ~/.claude/skills/ for available skills"
echo ""

if [ -n "$CONFIG_INFO_SCRIPT" ]; then
    "$CONFIG_INFO_SCRIPT" --all
else
    echo "⚠️  claude-config-info.sh not found"
    echo "   Expected: ~/.claude/bin/claude-config-info.sh"
    echo ""
fi

# スキルファイルをカテゴリ別に列挙
SKILLS_DIR="$HOME/.claude/skills"
if [ -d "$SKILLS_DIR" ]; then
    echo "📚 SKILLS (read as needed):"
    for category in "$SKILLS_DIR"/*/; do
        if [ -d "$category" ]; then
            cat_name=$(basename "$category")
            skills=$(find "$category" -maxdepth 2 -name "SKILL.md" \( -type f -o -type l \) 2>/dev/null | \
                sed 's|.*/\([^/]*\)/SKILL\.md|\1|' | \
                grep -v "^$cat_name$" | \
                sort | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
            if [ -n "$skills" ]; then
                echo "  $cat_name: $skills"
            fi
        fi
    done
    echo ""
fi

# ═══════════════════════════════════════════════════════════════
# プロジェクト別チェック（環境に応じて出力を調整）
# ═══════════════════════════════════════════════════════════════

# --- Docker環境チェック ---
# 優先順位: compose.yml > compose.yaml > docker-compose.yml > docker-compose.yaml > Dockerfile
HAS_COMPOSE=false
COMPOSE_FILE=""

if [ -f "compose.yml" ]; then
    HAS_COMPOSE=true
    COMPOSE_FILE="compose.yml"
elif [ -f "compose.yaml" ]; then
    HAS_COMPOSE=true
    COMPOSE_FILE="compose.yaml"
elif [ -f "docker-compose.yml" ]; then
    HAS_COMPOSE=true
    COMPOSE_FILE="docker-compose.yml"
elif [ -f "docker-compose.yaml" ]; then
    HAS_COMPOSE=true
    COMPOSE_FILE="docker-compose.yaml"
fi

HAS_DOCKERFILE=false
if [ -f "Dockerfile" ]; then
    HAS_DOCKERFILE=true
fi

if [ "$HAS_COMPOSE" = true ] || [ "$HAS_DOCKERFILE" = true ]; then
    echo "🐳 DOCKER ENVIRONMENT:"

    # Docker daemon確認
    if docker info > /dev/null 2>&1; then
        echo "  Docker daemon: ✅ Running"

        # Composeファイルがある場合はサービス確認
        if [ "$HAS_COMPOSE" = true ]; then
            echo "  Compose file: $COMPOSE_FILE"
            RUNNING_CONTAINERS=$(docker compose ps --status running --format "{{.Service}}" 2>/dev/null | tr '\n' ' ' || echo "")
            if [ -n "$RUNNING_CONTAINERS" ]; then
                echo "  Running services: $RUNNING_CONTAINERS"
            else
                echo "  Running services: ⚠️  None (run: docker compose up -d)"
            fi
        fi

        # Dockerfileのみの場合
        if [ "$HAS_COMPOSE" = false ] && [ "$HAS_DOCKERFILE" = true ]; then
            echo "  Dockerfile: ✅ Found (no compose file)"
        fi
    else
        echo "  Docker daemon: ❌ Not running"
    fi
    echo ""
fi

# --- Git状態チェック ---
if [ -d ".git" ]; then
    echo "📂 GIT STATUS:"

    # 現在のブランチ
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")

    # mainブランチかどうかチェック
    if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
        echo "  Branch: $CURRENT_BRANCH  🚨 WARNING: Protected branch!"
    else
        echo "  Branch: $CURRENT_BRANCH"
    fi

    # 未コミット変更
    UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l)
    UNCOMMITTED=$((UNCOMMITTED + 0))
    if [ "$UNCOMMITTED" -gt 0 ]; then
        echo "  Uncommitted changes: ⚠️  $UNCOMMITTED files"
    else
        echo "  Uncommitted changes: ✅ None"
    fi

    # 未pushコミット
    UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo "")
    if [ -n "$UPSTREAM" ]; then
        UNPUSHED=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
        if [ "$UNPUSHED" -gt 0 ]; then
            echo "  Unpushed commits: ⚠️  $UNPUSHED commits"
        else
            echo "  Unpushed commits: ✅ None"
        fi
    else
        echo "  Upstream: ⚠️  Not set"
    fi
    echo ""
fi

# --- hookルール出力（常に表示） ---
echo "🚫 BLOCKED ACTIONS (hooks enforced):"
echo "  • python/node/php直接実行 → docker run --rm 使用"
echo "  • git commit/push → ユーザーが実行"
echo "  • sudo/admin権限 → 常に禁止"
echo "  • mainブランチ編集 → feature branch作成"
echo ""
