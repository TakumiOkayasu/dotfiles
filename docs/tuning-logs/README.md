# Tuning Logs

`empirical-prompt-tuning` skill で各スキルをチューニングした際の評価ログ置き場。

- 手法: [`claude/skills/empirical-prompt-tuning/SKILL.md`](../../claude/skills/empirical-prompt-tuning/SKILL.md)
- 全体計画: `~/.claude/plans/empirical-prompt-tuning-skill-atomic-wadler.md`

## 配置が `claude/` 外である理由

`install.sh` は `git ls-files claude/` で `claude/` 配下の tracked ファイルを `~/.claude/` にシンボリックリンクする。チューニングログを `claude/skills/<name>/tuning/` に置くと `~/.claude/skills/<name>/tuning/` に配布され、将来の subagent が skill autoload でログを読み込んでバイアス汚染する恐れがある（empirical-prompt-tuning「同一 subagent 使い回し禁止」と同精神）。

`docs/` 配下なら `install.sh` が拾わないため、リポジトリ資産として保持しつつ `~/.claude/` を汚さない。

## ディレクトリ構造

```
docs/tuning-logs/
├── README.md                  # 本ファイル
├── trigger-overlap.md         # 全スキルの description 重なり語表（Phase 0 成果物）
└── <skill-name>/
    ├── scenarios.md           # baseline 3 本 + hold-out 1 本。iter 中は変更禁止
    ├── iter-0.md              # description/body 整合チェック（静的、dispatch なし）
    ├── iter-1.md              # baseline 評価（3 シナリオ並列 dispatch）
    ├── iter-2.md              # 1 テーマ修正後の再評価
    └── iter-N.md              # 連続2（重要スキル3）クリアまで
```

## `scenarios.md` フォーマット

```markdown
# <skill-name> シナリオカタログ

## Baseline シナリオ

### シナリオA（中央値）
- **状況**: <1 段落>
- **要件チェックリスト**（○/×/部分的で判定、[critical] は最低1つ必須）:
  1. [critical] <最低ライン>
  2. <通常項目>
  ...

### シナリオB（edge 1）
...

### シナリオC（edge 2）
...

## Hold-out シナリオ（収束判定時のみ使用）

### シナリオD
...
```

## `iter-N.md` フォーマット

empirical-prompt-tuning「提示フォーマット」節準拠。

```markdown
# iter N — <skill-name>

## 変更点（前回差分）
- <修正内容 1 行>

## 実行結果（シナリオ別）
| シナリオ | 成功/失敗 | 精度 | steps | duration | retries |
|---|---|---|---|---|---|
| A | ○ | 90% | 4 | 20s | 0 |
| B | × | 60% | 9 | 41s | 2 |

## 不明瞭点（今回新出）
- シナリオ B: [critical] 項目 N が × — <落ちた理由 1 行>
- シナリオ B: <その他の指摘>

## 裁量補完（今回新出）
- シナリオ B: <補完内容>

## empirical-prompt-tuning 側の曖昧点
（対象 skill ではなく empirical-prompt-tuning 自身の記述で subagent が詰まった箇所があれば記録。Phase 4 の入力になる）

## 次の修正案
- <最小修正 1 行>

## 収束判定
- 連続 X 回クリア / 停止条件まであと Y 回
- hold-out 結果（最終 iter のみ）: 直近平均から -N pt
```

## 運用ルール

| ルール | 理由 |
|---|---|
| シナリオは iter 開始後に変更しない | チューニングが「シナリオ側を簡単にする」方向に走るのを防ぐ |
| subagent は iter ごとに新規 dispatch | 前回の改善を学習したエージェントは評価に使えない |
| 1 iter = 1 テーマ修正 | 何が効いたか追えなくなるのを防ぐ（関連微修正はまとめて OK） |
| `[critical]` タグ最低1つ | 成功判定が vacuous になるのを防ぐ |
| hold-out は収束判定時のみ使用 | 過適合チェック用。途中 iter で使うと「見えてしまう」 |
| subagent 起動時に他 skill auto-load を禁止 | 対象 skill 以外の recipe で動かれると評価が成立しない |
| 対象が配布パッケージ（例: qa-nightmare + `checklists/`）なら全ファイル参照指示 | SKILL.md 単独評価だと false positive |

## 収束判定（empirical-prompt-tuning L128-133）

連続 2 イテレーション（重要スキルは連続 3）で **全て** 満たす:

- 新規不明瞭点 0
- 精度の前回比改善 +3pt 以下
- ステップ数の前回比変動 ±10% 以内
- duration の前回比変動 ±15% 以内
- hold-out シナリオで直近平均から -15pt 以内
