# Claude 資産を Codex 配布物へ変換するための対応表

| 出典 | 目的 | 具体対象 | 役割 | 前後関係 | 初出定義 | 候補語 |
| --- | --- | --- | --- | --- | --- | --- |
| `claude/commands/*.md` | Claude command の詳細手順を Codex から参照可能にする | Codex-native skill が必要時に読む変換済み command 本文 | 記録 | Claude command → Codex skill reference → plugin bundle | command reference とは、Codex-native skill の入口を上書きせずに保持する Claude command 由来の詳細手順を指す | command reference |
| `claude/skills/*/SKILL.md` | Claude skill の更新を Codex の runtime contract に合わせる | frontmatter、本文内の path、skill 呼び出し、subagent 契約 | 手段 | Claude skill → Codex skill source → core/extra plugin | skill port とは、Claude skill の意図を保ちながら Codex 固有の配置と呼び出しへ変換する処理を指す | skill port |
| `claude/skills/semantic-generation/SKILL.md` | 対象文書を書く前に指示対象と役割を固定する | 対応表を本文より先に保存し、その表に基づいて本文を書く手順 | 手段 | 対応表の保存 → hash 記録 → 本文生成 | ユーザーが指定した skill 名をそのまま使う | semantic-generation |
| `claude/rules/referent-before-label.md` | 対応表を先に作る順序を rules injection で常時適用する | 対象文書の適用条件、3 禁則、skill が使えない場合の予備動作 | 開始条件 | rule injection → skill 発火または予備動作 → 対象文書生成 | ユーザーが指定した rule 名をそのまま使う | referent-before-label |
| `codex/skills` と `codex/rules` | Codex source と plugin bundle の内容差を検出する | skill の全ファイルと rule の全ファイル | 記録 | source 生成 → plugin 同期 → verifier | content sync とは、source と配布先のファイル集合および内容が一致している状態を指す | content sync |
