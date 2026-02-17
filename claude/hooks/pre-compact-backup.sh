#!/bin/sh
# pre-compact-backup.sh - compact 前の自動バックアップ
#
# 責務:
#   - PROGRESS.md のスナップショット保存
#   - transcript から直近のユーザーリクエスト・変更ファイルを抽出
#   - .claude/checkpoints/ に保存
#
# 発動: PreCompact (auto|manual)
# 依存: jaq or jq, perl

set -eu

if [ -t 0 ]; then
    exit 0
fi

INPUT=$(cat)

JQ=$(command -v jaq || command -v jq || echo "jq")

TRANSCRIPT_PATH=$(echo "$INPUT" | $JQ -r '.transcript_path // ""' 2>/dev/null || echo "")
CWD=$(echo "$INPUT" | $JQ -r '.cwd // ""' 2>/dev/null || echo "")
TRIGGER=$(echo "$INPUT" | $JQ -r '.trigger // "unknown"' 2>/dev/null || echo "unknown")

CHECKPOINT_DIR="${CWD}/.claude/checkpoints"
PROGRESS_FILE="${CWD}/.claude/progress.md"
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')

mkdir -p "$CHECKPOINT_DIR"

# --- 1. PROGRESS.md スナップショット ---
if [ -f "$PROGRESS_FILE" ]; then
    cp "$PROGRESS_FILE" "${CHECKPOINT_DIR}/progress-${TIMESTAMP}.md"
fi

# --- 2. transcript からサマリー抽出 ---
SUMMARY_FILE="${CHECKPOINT_DIR}/pre-compact-${TIMESTAMP}.md"

{
    echo "# Pre-Compact Backup"
    echo ""
    echo "- **Timestamp:** $(date '+%Y-%m-%d %H:%M:%S')"
    echo "- **Trigger:** ${TRIGGER}"
    echo "- **Branch:** $(cd "$CWD" && git branch --show-current 2>/dev/null || echo 'N/A')"
    echo ""

    # 直近のユーザーリクエスト抽出
    if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
        echo "## User Requests (recent)"
        echo ""
        tail -500 "$TRANSCRIPT_PATH" | perl -MJSON::PP -ne '
            chomp;
            eval {
                my $d = decode_json($_);
                return unless $d->{message} && $d->{message}{role};
                if ($d->{message}{role} eq "user") {
                    my $content = $d->{message}{content};
                    if (ref $content eq "ARRAY") {
                        for my $block (@$content) {
                            if (ref $block eq "HASH" && ($block->{type} // "") eq "text") {
                                my $text = $block->{text} // "";
                                $text =~ s/\n/ /g;
                                $text = substr($text, 0, 200);
                                print "- $text\n";
                            }
                        }
                    } elsif (!ref $content) {
                        my $text = $content;
                        $text =~ s/\n/ /g;
                        $text = substr($text, 0, 200);
                        print "- $text\n";
                    }
                }
            };
        ' 2>/dev/null || echo "- (transcript parse failed)"
        echo ""
    fi

    # git 変更ファイル一覧
    echo "## Recent Changes"
    echo ""
    if cd "$CWD" 2>/dev/null && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "### Uncommitted"
        git diff --name-only 2>/dev/null | head -20 | sed 's/^/- /'
        git diff --cached --name-only 2>/dev/null | head -20 | sed 's/^/- (staged) /'
        echo ""
        echo "### Recent Commits"
        git log --oneline -10 2>/dev/null | sed 's/^/- /'
    else
        echo "- (not a git repo)"
    fi
    echo ""

    # PROGRESS.md の内容も含める
    if [ -f "$PROGRESS_FILE" ]; then
        echo "## PROGRESS.md (at compact time)"
        echo ""
        cat "$PROGRESS_FILE"
    fi
} > "$SUMMARY_FILE"

# latest.md も更新
cp "$SUMMARY_FILE" "${CHECKPOINT_DIR}/latest.md"

exit 0
