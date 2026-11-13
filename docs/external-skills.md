# Claude の資産を Codex / ChatGPT で使う

Issue [#521](https://github.com/TakumiOkayasu/dotfiles/issues/521) の利用中一覧を対象にする。
`@synced` は配布方法を示し、同名の公開スキルと同じ内容とは限らない。
下表の公開元は marketplace 名と版の一致から特定した候補であり、手元の synced ファイルとの一致は未確認。

## Codex へ導入する

`install.sh` が配置する `dotfile-work-local` marketplace には、公式の Codex 対応を持つ
`yomiyasu`、`ponytail`、`i-have-adhd` と、Codex の Claude 互換loaderで読める
Anthropic 公式の `design`、`data`、`pdf-viewer` を追加した。
hook型の `security-guidance` も公式のportable対応版を選択できる。ただし下記の機能差がある。
取得元と commit は `scripts/sync-codex-plugin.py` を正本とする。
`AVAILABLE` として一覧に出し、通常の dotfiles install では外部コードを取得・有効化しない。

dotfiles の更新を配置した後、Codex の `/plugins` から選ぶか、次を個別に実行する。

```sh
codex plugin add yomiyasu@dotfile-work-local
codex plugin add ponytail@dotfile-work-local
codex plugin add i-have-adhd@dotfile-work-local
codex plugin add design@dotfile-work-local
codex plugin add data@dotfile-work-local
codex plugin add pdf-viewer@dotfile-work-local
codex plugin add security-guidance@dotfile-work-local
```

Ponytail の lifecycle hook は `/hooks` で内容を確認して許可する。
有効化後の新しいセッションで、実際に一覧へ現れた名前を使って起動する。
`i-have-adhd` の明示起動方針など、上流の metadata は変更しない。

Kuu の4種は `dotfile-work-codex-extra` に Codex 向けの手順を同梱する。
Claude の専用 tool 名は現在の tool contract に従う操作へ置き換え、元の反復と終了条件を維持する。
`fix-ci` は対象差分を確認し、commit / push は明示された許可範囲で行う。
Claude 側へ同名スキルを重複配置しない。
上流の GPL-3.0 ライセンス、出典、変更記録を各スキルに保持する。

## 利用中一覧との対応

| 名前 / 一覧の版 | 公開元 | 対応 |
| --- | --- | --- |
| yomiyasu 3.1.0 | [nanaism/yomiyasu](https://github.com/nanaism/yomiyasu) | 公式配布を marketplace から選択 |
| ponytail 5.3.3 | [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) | 公式 Codex plugin を選択 |
| i-have-adhd 0.4.1 | [ayghri/i-have-adhd](https://github.com/ayghri/i-have-adhd) | 公式 Codex plugin を選択 |
| dig 3.0.1 | [Kuu marketplace](https://github.com/fumiya-kume/claude-code/blob/923a30e9f22bcc3860a5a844845e8ae9b0b1121b/.claude-plugin/marketplace.json) | Codex extra skill |
| fix-ci 1.0.1 | 同上 | Codex extra skill。外部書き込みは許可範囲を確認 |
| decomposition 1.1.1 | 同上 | Codex extra skill |
| deslop 1.0.1 | 同上 | Codex extra skill |
| security-guidance 2.0.17 | [Anthropic 公式 hook](https://github.com/anthropics/claude-plugins-official/tree/f75f5b25ae94f4332be4ff5f18435741d2589bdb/plugins/security-guidance) | portable対応2.0.20を選択可能。検査対象に機能差あり |
| pdf-viewer 0.2.0 | [Anthropic 公式](https://github.com/anthropics/knowledge-work-plugins/tree/02717ef04446b6ef5aa4b8af15bb536d79f42ed0/pdf-viewer) | 公式配布を選択。viewer / MCP の要件あり |
| design 1.2.0 | [Anthropic 公式](https://github.com/anthropics/knowledge-work-plugins/tree/02717ef04446b6ef5aa4b8af15bb536d79f42ed0/design) | 公式配布を選択。7 skillsをloaderで確認 |
| data 1.1.0 | [Anthropic 公式](https://github.com/anthropics/knowledge-work-plugins/tree/02717ef04446b6ef5aa4b8af15bb536d79f42ed0/data) | 公式配布を選択。10 skillsをloaderで確認 |

`design` / `data` の `.mcp.json` には、接続先URLが空の雛形と認証が必要なサービスがある。
必要な接続先を個別に設定する。スキルの検出成功は、各サービスへの接続成功を意味しない。

`pdf-viewer` は `view-pdf` と4つのcommandを持ち、Codexはcommandもskillへ変換して検出する。
表示と注釈には `@modelcontextprotocol/server-pdf` と iframe viewer を扱えるホストが必要。
PDFサーバを起動しないskill単体のコピーでは、この機能は動かない。
上流 `.mcp.json` の `npx` はnpm版を固定していないため、Git commit固定はサーバ版の固定を含まない。
実サーバ導入時には対象版・integrity・lockを確認し、未設定のまま再現可能と扱わない。
この変更ではサーバの起動、PDF表示、注釈、署名操作は検証していない。

`security-guidance` は `SKILL.md` ではなくhook群である。
公式版はCodexからの `PLUGIN_ROOT` を検出してportableなJSONを返す。
隔離環境で2.0.20の導入と、LLM検査を無効にしたsynthetic hook入力を確認した。
ただし上流のパターン検査は `Write` / `Edit` 等の入力を対象とし、Codexの
`apply_patch` 入力では同じ危険パターンを検出しない。
導入成功を全編集経路の検査成功と扱わず、既存のCodex安全hookを維持する。
`Stop` / commit / push時のLLM検査はClaude Code / Agent SDKの認証と実行環境を使い、
設定に応じてAnthropic APIやgatewayも利用する。既定で有効なため、実行前にこの経路を確認する。
`ENABLE_CODE_SECURITY_REVIEW=0` でLLM検査を無効にできる。この検証ではSDK、モデル、APIを呼んでいない。
クラウドで実行されるChatGPT Workのplugin lifecycle hookは対応範囲が異なり、
ローカルCodexへの導入で同じhookがChatGPTでも動くとはしない。

## ChatGPT で使う

Codex CLI のローカル配置は、ChatGPT アカウントへのインストールとは別に管理する。
ChatGPT の plugin 一覧で公開配布を確認できる場合は、その配布元から導入する。
個人スキルとして取り込む場合は、公式配布または本リポジトリの対象スキルフォルダを指定して
ChatGPT Work にインストールを依頼する。`SKILL.md` だけでなく参照文書、script、license も含める。
`~/.claude/plugins` 全体には runtime 設定もあるため、対象のスキルフォルダを選ぶ。

Kuu の port は `codex/skills/{dig,fix-ci,decomposition,deslop}/` を使う。
Ponytail をスキル単体で取り込んだ場合、Codex plugin の自動起動やモード切り替え hook まで
インストールされたことにはならない。
この変更では利用者の ChatGPT アカウントや実端末の plugin を変更していない。

## 無効化中の項目

Issue に併記された disabled 項目は自動で有効化しない。
スキル以外のものは、それぞれのホストが対応する仕組みで導入する。

| 種別 | 一覧の項目 | 確認元 |
| --- | --- | --- |
| Skill | claude-code-setup、frontend-design、skill-creator | [Anthropic 公式](https://github.com/anthropics/claude-plugins-official/tree/main/plugins) |
| Skill / command | claude-md-management | 同上 |
| Skill / agent / hook | claude-security | 同上 |
| Agent | code-simplifier | 同上 |
| Command | commit-commands | 同上 |
| Command / agent | feature-dev、pr-review-toolkit | 同上 |
| MCP | github、playwright | 同上 |
| LSP | gopls-lsp、php-lsp、typescript-lsp | 同上 |
| LSP | intelephense | [boostvolt/claude-code-lsps](https://github.com/boostvolt/claude-code-lsps) |
| Claude から Codex への委譲 | codex@openai-codex | [openai/codex-plugin-cc](https://github.com/openai/codex-plugin-cc) |
| Skill / MCP、Codex 対応あり | cloudflare | [Cloudflare 公式](https://github.com/cloudflare/skills/tree/b052c32bab7dd493513260228a36c88294f343f1) |

## 更新と検証

外部 plugin の更新時は正本の固定 commit を変更し、生成 pipeline と隔離した
`CODEX_HOME` での install を再確認する。上流の `main` や `latest` へ自動追従させない。

確認日は 2026-11-13。スキルを含む公式6件は固定 commit で実 Codex CLI の install と
app-server `skills/list` による検出を確認した。loaderのエラーは0件。
hook型の公式1件も実Codex CLIの導入を確認し、上記の機能差をsynthetic入力で検証した。
これはモデルによる実用動作、MCP接続、hook の許可・発火、利用者の端末への配置確認を含まない。

仕様の根拠:

- [OpenAI: Build skills](https://learn.chatgpt.com/docs/build-skills)
- [OpenAI: Plugins](https://learn.chatgpt.com/docs/plugins)
- [Ponytail: Codex install](https://github.com/DietrichGebert/ponytail/blob/96608e078b2d5ea607c5c3b8b5a54d1c1fba6846/INSTALL.md#codex)
- [yomiyasu: 公式導入](https://github.com/nanaism/yomiyasu/blob/db78b9bc5e868549b517a037df7a4d1c93edac23/README.md)
- [i-have-adhd: Codex manifest](https://github.com/ayghri/i-have-adhd/blob/1ecea1993b7fce257ffbd686c070948b5e07eda6/.codex-plugin/plugin.json)
- [OpenAI: Claude互換marketplaceとgit-subdir](https://learn.chatgpt.com/docs/enterprise/plugin-management#supported-formats)
- [Anthropic: 公式marketplace](https://github.com/anthropics/knowledge-work-plugins/blob/02717ef04446b6ef5aa4b8af15bb536d79f42ed0/.claude-plugin/marketplace.json)
