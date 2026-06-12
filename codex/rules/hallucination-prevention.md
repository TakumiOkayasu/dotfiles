# Hallucination Prevention

<!-- codex-port: managed; source=claude/rules/hallucination-prevention.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `claude/rules/hallucination-prevention.md`.
- Codex skills are packaged into `plugins/dotfile-work-codex` or `plugins/dotfile-work-codex-extra`; `install.sh` should not duplicate them into `${HOME}/.agents/skills` in plugin-only mode.
- Global and project rules live under `${HOME}/.codex/rules/*.md`; do not assume they are automatically loaded unless the rules-inject hook injected them into context.
- Claude slash-command references should be invoked through Codex plugin/local skills such as `@feat`, `@fix`, `@deep-review`, or `/skills`. Do not use custom `/prompt:*` commands.
- Subagent usage must follow `${HOME}/.codex/SUBAGENTS.md` and the current Codex tool contract.

「たぶん正しい」で出力しない。不確実なものは不確実と明示する。

## 基本

- 確認済みの情報のみを回答に含める
- 不確実な箇所は `[要確認: <理由>]` マーカーで明示する
- パッケージ・API・引数・戻り値の型・コマンドオプション・設定ファイル名・環境変数名は、公式レジストリ / 公式リファレンスで実在を確認してから使う
- 出典の信頼性は 公式ドキュメント > 査読済み論文 > その他 の順で評価する

## URL の扱い

- 公知の公式ドメイン root とパス断片 (例: `nodejs.org`, `docs.github.com/en/rest/pulls/comments`) は、パッケージ名・API 名と同格の参照先として提示してよい
- フルパス URL (`https://...`) を提示する場合は `[要確認: 実在確認推奨]` を付ける
- WebFetch / 実行ログで実在確認できない URL は提示しない
- コマンド引数中の REST API パス (例: `gh api repos/{owner}/{repo}/pulls/{n}/comments`) はコマンド仕様の一部として扱い、この制限の対象外とする

## 不確実な場合の対処

既定は `[要確認: <理由>]` を付けて出力する。誤情報が致命的、明確な代替が存在する、訂正が必要などのケースでは次を行う:

- 確認できないものは出力しない
- 確実に存在する代替案を提示する
- ユーザーが自分で確認できる手順を案内する
- 間違いに気づいたら影響範囲を説明し、即訂正する


## Codex rule loading

This rule must be treated as mandatory whenever it is injected by `rules-inject.sh` or explicitly read from `${HOME}/.codex/rules/*.md`. If this rule conflicts with a nearer project rule, follow the nearer project rule and report the conflict.
