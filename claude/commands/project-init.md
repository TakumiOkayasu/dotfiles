# プロジェクト初期化

Claude Code用のプロジェクトテンプレートを配置する。

## 引数

$ARGUMENTS に言語名が渡されます。

## 対応言語

python, typescript, cpp, go, php-laravel, php-cakephp

## 実行手順

### 引数なしの場合 ($ARGUMENTS が空)

対応言語の一覧を表示して終了。

### 言語が指定された場合

1. `$ARGUMENTS` が対応言語リスト (python, typescript, cpp, go, php-laravel, php-cakephp) に完全一致するか検証。一致しなければエラー表示して終了。
2. `~/.claude/templates/lang/<lang>.md` が存在するか確認。なければエラー表示して終了。

2. 以下のテンプレートファイルを読み取る:
   - `~/.claude/templates/rules/common/` 内の全 `.md` ファイル
   - `~/.claude/templates/rules/<lang>/` 内の全 `.md` ファイル
   - `~/.claude/templates/lang/<lang>.md`

3. `.claude/rules/` ディレクトリにルールファイルを Write:
   - common ルール → `.claude/rules/<filename>`
   - 言語別ルール → `.claude/rules/<filename>`

4. `CLAUDE.md` を Write (テンプレートの内容をそのまま配置)

5. `.claude/progress.md` を `~/.claude/templates/progress.md` から Write

### 既存ファイルがある場合

CLAUDE.md や `.claude/rules/` 内のファイルが既に存在する場合は、ユーザーに上書きするか確認してから実行する。

### 完了後

配置したファイルの一覧を表示する。
