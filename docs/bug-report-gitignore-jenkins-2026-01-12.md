# バグ報告: グローバルgitignoreのJENKINS_HOMEセクション問題

**報告日**: 2026-01-12
**重要度**: 高
**影響範囲**: 全リポジトリのgit操作

---

## 概要

`.gitignore.private` (グローバルgitignoreとして使用) にJENKINS_HOMEテンプレートがそのまま含まれており、意図しないファイル無視が発生している。

## 問題のファイル

```sh
~/.gitignore_global -> /Users/yamazaki/prog/dotfile-work/.gitignore.private
```

## 問題の箇所

`.gitignore.private` 1272-1310行目:

```gitignore
### JENKINS_HOME ###
# Learn more about Jenkins and JENKINS_HOME directory for which this file is
# intended.
#  http://jenkins-ci.org/
#  https://wiki.jenkins-ci.org/display/JENKINS/Administering+Jenkins
# ...
# Ignore all JENKINS_HOME except jobs directory, root xml config, and
# .gitignore file.
/*           ← ★問題の行: 全ファイルを無視
!/jobs
!/.gitignore
!/*.xml
# ...
```

## 影響

- `/*` がグローバルに適用され、**全ての新規ファイルがデフォルトで無視される**
- `git add` で `-f` (force) フラグが必要になる
- 新規ファイルが `git status` に表示されない

## 発見経緯

`router` プロジェクトで新規ファイル (`docs/mape-setup-2026-01-12.md`, `scripts/setup-mape.sh`) を作成した際、`git status` に表示されず、`git add -f` が必要だった。

```bash
$ git check-ignore -v docs/mape-setup-2026-01-12.md
/Users/yamazaki/.gitignore_global:1284:/* docs/mape-setup-2026-01-12.md
```

## 根本原因

GitHub gitignore templatesの `JENKINS_HOME.gitignore` は**JENKINS_HOMEディレクトリ専用**であり、グローバルgitignoreに含めるべきではない。このテンプレートは「JENKINS_HOME以下で、jobsと.xmlファイル以外を全て無視する」という設計。

---

## 修正指示

### 対応方法

JENKINS_HOMEセクション全体(1272-1310行目)を削除する。

### 修正コマンド

```bash
# バックアップ作成
cp ~/.gitignore_global ~/.gitignore_global.backup.$(date +%Y%m%d)

# 問題のセクションを削除 (1272-1310行目)
sed -i '' '1272,1310d' /Users/yamazaki/prog/dotfile-work/.gitignore.private

# 削除確認
grep -n "JENKINS_HOME\|^/\*$" ~/.gitignore_global
# → 何も出力されなければOK
```

### 検証方法

```bash
# 任意のリポジトリで新規ファイルを作成
touch /tmp/test-repo/testfile.txt

# git statusに表示されることを確認
cd /tmp/test-repo && git status

# git addに-fが不要であることを確認
git add testfile.txt  # エラーなく追加できればOK
```

---

## 再発防止

グローバルgitignoreに追加するテンプレートは、以下のカテゴリのみとする:

**追加してよいもの**:

- OS固有 (macOS, Linux, Windows)
- エディタ/IDE固有 (Vim, VSCode, JetBrains)
- 言語固有のビルド成果物 (*.pyc, node_modules, etc.)

**追加してはいけないもの**:

- 特定ディレクトリ構造を前提とするもの (JENKINS_HOME, etc.)
- ルートパターン (`/*`, `/特定ディレクトリ`) を含むもの
