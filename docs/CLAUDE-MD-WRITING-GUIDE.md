# 効果的な CLAUDE.md の書き方

## CLAUDE.md とは

CLAUDE.mdは、Claude Codeがプロジェクトで作業する際に**常に読み込まれる**設定ファイルです。プロジェクトのルールや規約を伝えることで、一貫性のある高品質なアウトプットを得られます。

## 配置場所

```text
プロジェクトルート/
├── CLAUDE.md          # プロジェクト設定(常に読み込まれる)
└── .claude/
    └── skills/        # タスク固有のスキル(必要時のみ読み込まれる)
        ├── skill-a/
        │   └── SKILL.md
        └── skill-b/
            └── SKILL.md
```

## CLAUDE.md と SKILL.md の使い分け

| | CLAUDE.md | SKILL.md |
| --- | ----------- | ---------- |
| **読み込み** | 常に | 必要なときのみ |
| **内容** | 全体ルール、規約 | 特定タスクの手順 |
| **長さ** | 短く(〜200行目安) | 詳細可(〜500行) |
| **例** | 命名規則、gitルール | TDD手順、セキュリティチェック |

### 判断基準

```markdown
Q: すべてのタスクで適用したい?
  YES → CLAUDE.md
  NO  → SKILL.md

Q: 詳細な手順が必要?
  YES → SKILL.md
  NO  → CLAUDE.md

Q: コンテキストを節約したい?
  YES → SKILL.mdに分離
```

## 構成のベストプラクティス

### 1. 最も重要なルールを最初に

```markdown
# ⚠️ 絶対ルール

- git commit/pushは禁止(ユーザーのみ実行可能)
- テストコードを勝手に変更しない
- 機密情報をログに出力しない
```

Claudeは長いプロンプトの最初と最後を重視する傾向があります。

### 2. 具体的に書く

```markdown
# ❌ 曖昧
コードは読みやすく書いてください。

# ✅ 具体的
- 関数は30行以内
- ネストは3階層まで
- 変数名は意図を表す(例: `userCount` not `n`)
```

### 3. 例を示す

```markdown
# 命名規則

## 良い例
- `fetchUserById()`
- `calculateTotalPrice()`
- `isValidEmail()`

## 悪い例
- `getData()` → 何のデータ?
- `process()` → 何を処理?
- `doSomething()` → 意味不明
```

### 4. 禁止事項は明確に

```markdown
# 禁止事項

**絶対禁止**(例外なし):
- `git commit`, `git push`
- テストコードの変更

**原則禁止**(要相談):
- `any`型の使用
- `console.log`の残留
```

## 推奨セクション

```markdown
# プロジェクト名

## 必須ルール
(最重要。必ず守るべきこと)

## 技術スタック
(言語、フレームワーク、ツール)

## 命名規則
(ファイル、変数、関数等)

## コーディング規約
(スタイル、パターン)

## 作業フロー
(ブランチ戦略、コミット規約)

## 禁止事項
(やってはいけないこと)

## スキル参照
(詳細手順へのリンク)
```

## 長さの目安

```markdown
理想: 100〜200行
最大: 300行程度

それ以上 → SKILL.mdに分離を検討
```

**理由**: コンテキストウィンドウは共有リソース。CLAUDE.mdが長すぎると、実際のタスクに使える容量が減る。

## アンチパターン

### 1. 長すぎる

```markdown
# ❌ 500行以上のCLAUDE.md
→ 重要でない部分はSKILL.mdに分離
```

### 2. 曖昧すぎる

```markdown
# ❌ 
良いコードを書いてください。

# ✅
- 関数は単一責任
- 副作用を避ける
- 純粋関数を優先
```

### 3. 矛盾がある

```markdown
# ❌ 
## ルールA
変数名はcamelCaseで

## ルールB(別の場所)
変数名はsnake_caseで
→ どっち?
```

### 4. 更新されていない

```markdown
# ❌
古いライブラリ名やバージョンが記載されている
→ 定期的にレビュー・更新する
```

## テンプレート

```markdown
# [プロジェクト名]

## 必須ルール

1. **git操作**: commit/pushは禁止(ユーザーのみ)
2. **テスト**: テストコードを変更する前に確認
3. **言語**: 日本語で応答(コードコメントは英語)

## 技術スタック

- 言語: TypeScript 5.x
- フレームワーク: Next.js 14
- テスト: Vitest
- パッケージ管理: pnpm

## コーディング規約

### 命名
- ファイル: kebab-case (`user-service.ts`)
- 変数/関数: camelCase
- 型/クラス: PascalCase
- 定数: SCREAMING_SNAKE_CASE

### 禁止
- `any`型
- `console.log`の残留
- マジックナンバー

## ブランチ戦略

- 機能追加: `feat/機能名`
- バグ修正: `fix/内容`
- mainから作成し、mainにマージ

## 完了報告

タスク完了時: `{タスク名}が完了しました.`

## スキル参照

詳細な手順は以下を参照:
- テスト駆動開発 → `.claude/skills/test-driven-development/`
- デバッグ → `.claude/skills/systematic-debugging/`
- セキュリティ → `.claude/skills/security-review/`
```

## SKILL.md との連携

CLAUDE.mdからSKILL.mdを参照することで、必要な時だけ詳細を読み込ませる:

```markdown
## スキル参照

特定のタスクには以下のスキルを参照:

| タスク | スキル |
| -------- | -------- |
| 機能実装 | `.claude/skills/test-driven-development/` |
| バグ修正 | `.claude/skills/systematic-debugging/` |
| PR作成 | `.claude/skills/code-review/` |
```

## 効果測定

CLAUDE.mdが効果的かどうかを確認:

```markdown
✅ 効果的な兆候:
- 一貫したコードスタイル
- ルール違反が減少
- 確認の質問が減少
- 期待通りの出力

❌ 改善が必要な兆候:
- 同じ指摘を繰り返す
- ルールが無視される
- 矛盾した出力
- 「これはどうすれば?」が多い
```

## メンテナンス

```markdown
## 定期レビュー(月1回程度)

- [ ] 古くなった情報はないか
- [ ] 矛盾するルールはないか
- [ ] 追加すべきルールはないか
- [ ] SKILL.mdに分離すべき内容はないか
- [ ] チームメンバーからのフィードバック
```

## よくある質問

### Q: CLAUDE.mdとSKILL.mdは同時に使える?

はい。CLAUDE.mdは常に読み込まれ、SKILL.mdは関連するタスクのときに追加で読み込まれます。

### Q: SKILL.mdの読み込みはどうやって指示する?

Claude Codeはタスクの内容からSKILL.mdの`description`を見て自動的に判断します。または明示的に「TDDスキルを使って」と指示できます。

### Q: チーム共有のCLAUDE.mdはどこに置く?

プロジェクトルートに置いてGitで管理します。個人設定は`~/.claude/CLAUDE.md`に置けます。

### Q: 機密情報を書いても大丈夫?

CLAUDE.mdはGitにコミットされることが多いので、機密情報は書かないでください。環境変数や別のシークレット管理を使用してください。

## 参考: 公式ドキュメント

- [Claude Code Skills](https://docs.anthropic.com/en/docs/claude-code/skills)
- [Memory and CLAUDE.md](https://docs.anthropic.com/en/docs/claude-code/memory)

---

## まとめ

1. **短く保つ**: 200行以内を目標
2. **重要なことを最初に**: 絶対ルールをトップに
3. **具体的に書く**: 例を示す
4. **詳細はSKILL.mdへ**: 必要時のみ読み込まれる
5. **定期的に更新**: 古い情報は害になる
