# scratch/

試行錯誤用の使い捨てメモ。**コミット対象外** (`.gitignore`)。

詳細規約: `~/.claude/rules/opus-47-policy.md` の「File-System Memory」セクション。

## 用途

- REPL 風メモ
- 没アイデア
- 実験コードのスニペット
- どこに置けばいいか分からない一時メモ

## 用法

- ファイル名は自由 (推奨: `{task-id}.md` で notes と対応)
- 整理不要、捨てる前提
- 残したい内容は notes/ に移動する

## クリーンアップ

30 日以上更新のないファイルは自由に削除可:

```bash
find .claude/scratch -type f -mtime +30 -delete
```
