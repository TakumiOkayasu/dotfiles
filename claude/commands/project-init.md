# プロジェクト初期化

Claude Code用のプロジェクトテンプレートを配置する。

## 引数

$ARGUMENTS に言語名が渡されます。

## 実行手順

### Step 1: 利用可能な言語を検出

Glob ツールで `~/.claude/templates/lang/*.md` を検索し、ファイル名 (拡張子除く) を利用可能な言語リストとする。

### Step 2: 引数の検証

| 条件 | 動作 |
|------|------|
| `$ARGUMENTS` が空 | 利用可能な言語一覧を表示して終了 |
| 完全一致あり | Step 3 へ進む |
| エイリアス一致あり | 対応する言語名に自動変換して Step 3 へ進む |
| 部分一致・類似あり | 候補をサジェスト表示し、ユーザーに確認 |
| 該当なし | エラー表示 + 利用可能な言語一覧を表示して終了 |

**言語一覧の表示順** (使用頻度順):

1. java, cpp, typescript, python, go, c, swift
2. php-cakephp, php-laravel, dart, kotlin
3. その他 (アルファベット順)

**エイリアス → 自動変換** (確認なしで直接変換):

| 入力 | 変換先 |
|------|--------|
| `py`, `python3` | python |
| `ts`, `node`, `js` | typescript |
| `c++` | cpp |
| `cake`, `cakephp` | php-cakephp |
| `laravel` | php-laravel |
| `rs` | rust |
| `c#`, `dotnet`, `.net` | csharp |
| `rb`, `rails` | ruby |
| `kt`, `android` | kotlin |
| `ios` | swift |
| `flutter` | dart |

### Step 3: テンプレート読み取りと配置

1. Glob ツールで以下のテンプレートファイルを検索:
   - `~/.claude/templates/rules/common/*.md`
   - `~/.claude/templates/rules/<lang>/*.md`
   - `~/.claude/templates/lang/<lang>.md`
   - `~/.claude/templates/progress.md`

   **注意**: これらはシンボリックリンク。Glob/Read ツールはシンボリックリンクを透過的に読める。

2. 見つかったテンプレートを Read ツールで全て読み取る。

3. 読み取った内容を Write ツールでプロジェクトに配置:
   - `~/.claude/templates/rules/common/<file>` → `.claude/rules/<file>`
   - `~/.claude/templates/rules/<lang>/<file>` → `.claude/rules/<file>`
   - `~/.claude/templates/lang/<lang>.md` → `CLAUDE.md`
   - `~/.claude/templates/progress.md` → `.claude/progress.md`

4. 既存ファイルがある場合はユーザーに上書き確認してから実行する。

### 完了後

配置したファイルの一覧を表示する。
