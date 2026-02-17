# セッション復帰

全自動復帰が失敗した場合の手動フォールバック。通常は使用不要。

## 実行手順

1. **PROGRESS.md 確認**
   ```bash
   cat .claude/progress.md
   ```

2. **最終チェックポイント確認**
   ```bash
   cat .claude/checkpoints/latest.md
   ```

3. **git 履歴から文脈復元**
   ```bash
   git log --oneline -20
   git diff --stat
   git log --all --not --remotes --oneline
   ```

4. **PROGRESS.md の git 履歴(破損時)**
   ```bash
   git log -p .claude/progress.md
   ```

5. **状況推測**
   上記の情報を統合して現在の状況を推測し、ユーザーに報告

6. **PROGRESS.md 再構築**
   推測した状況を元に PROGRESS.md を再作成
