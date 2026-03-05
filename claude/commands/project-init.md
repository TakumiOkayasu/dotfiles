# プロジェクト初期化

Claude Code用のプロジェクトテンプレートを配置する。

## 引数

$ARGUMENTS に言語名が渡されます。

## 実行手順

### Step 1: 言語の決定

#### 引数ありの場合

| 条件 | 動作 |
|------|------|
| エイリアス一致あり | 対応する言語名に自動変換して Step 2 へ |
| `~/.claude/templates/lang/<入力>.md` が存在 | Step 2 へ |
| 部分一致・類似あり | 候補をサジェスト表示し、ユーザーに確認 |
| 該当なし | エラー表示 + 利用可能な言語一覧を表示して終了 |

#### 引数なしの場合: プロジェクト自動検出

Glob ツールでカレントディレクトリの設定ファイルを検索し、言語を推定する。

| 検出ファイル | 推定言語 |
|-------------|---------|
| `pyproject.toml`, `setup.py`, `requirements.txt` | python |
| `package.json`, `tsconfig.json` | typescript |
| `go.mod` | go |
| `Cargo.toml` | rust |
| `composer.json` + `config/app.php` | php-laravel |
| `composer.json` + `config/app_local.php` | php-cakephp |
| `composer.json` (上記以外) | php-laravel |
| `build.gradle`, `build.gradle.kts`, `pom.xml` | java |
| `*.kt` + (`build.gradle` or `build.gradle.kts`) | kotlin |
| `Package.swift`, `*.xcodeproj` | swift |
| `pubspec.yaml` | dart |
| `Gemfile` | ruby |
| `*.csproj`, `*.sln` | csharp |
| `Makefile` + `*.c` (`.cpp` なし) | c |
| `CMakeLists.txt`, `Makefile` + `*.cpp` | cpp |

- 1件検出 → 「<lang> として初期化しますか？」と確認して Step 2 へ
- 複数検出 → 候補を表示してユーザーに選択させる
- 0件検出 → 利用可能な言語一覧を表示して終了

#### エイリアス一覧

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

#### 言語一覧の表示順 (固定)

1. java, cpp, typescript, python, go, c, swift
2. php-cakephp, php-laravel, dart, kotlin
3. rust, ruby, csharp

### Step 2: テンプレート読み取りと配置

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
