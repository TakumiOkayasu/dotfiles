# Claude の資産を Codex / ChatGPT で使う

Issue [#521](https://github.com/TakumiOkayasu/dotfiles/issues/521) の利用中一覧を対象にする。
`@synced` は配布方法を示し、同名の公開スキルと同じ内容とは限らない。
下表の公開元は marketplace 名と版の一致から特定した候補であり、手元の synced ファイルとの一致は未確認。

## Codex へ導入する

`install.sh` が配置する `dotfile-work-local` marketplace には、公式の Codex 対応を持つ
`yomiyasu`、`ponytail`、`i-have-adhd` を追加した。
取得元と commit は `scripts/sync-codex-plugin.py` を正本とする。
`AVAILABLE` として一覧に出し、通常の dotfiles install では外部コードを取得・有効化しない。

dotfiles の更新を配置した後、Codex の `/plugins` から選ぶか、次を個別に実行する。

```sh
codex plugin add yomiyasu@dotfile-work-local
codex plugin add ponytail@dotfile-work-local
codex plugin add i-have-adhd@dotfile-work-local
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
| security-guidance 2.0.17 | [Anthropic 公式 hook](https://github.com/anthropics/claude-plugins-official/blob/a29a80b5877bae49e3b058cc6dd86bda07bcf1cc/plugins/security-guidance/hooks/hooks.json) | Claude 専用。後述の判断が必要 |
| pdf-viewer 0.2.0 | 未特定 | 公開 URL またはスキル本体が必要 |
| design 1.2.0 | 未特定 | 公開 URL またはスキル本体が必要 |
| data 1.1.0 | 未特定 | 公開 URL またはスキル本体が必要 |

`security-guidance` は `SKILL.md` ではなく、Claude のイベント、tool matcher、
`asyncRewake` と Claude Agent SDK を使う hook 群である。
Markdown のコピーでは同じ検査を提供できない。
Codex 固有の検査を別途設計するか、現在の Codex の安全設定で扱うかを決めるまで移植済みとはしない。
クラウドで実行される ChatGPT Work も plugin lifecycle hook の対応範囲が異なる。

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

確認日は 2026-11-13。公式3件は固定 commit で実 Codex CLI の marketplace 追加・install を確認した。
これはモデルによる実用動作、hook の許可・発火、利用者の端末への配置確認を含まない。

仕様の根拠:

- [OpenAI: Build skills](https://learn.chatgpt.com/docs/build-skills)
- [OpenAI: Plugins](https://learn.chatgpt.com/docs/plugins)
- [Ponytail: Codex install](https://github.com/DietrichGebert/ponytail/blob/96608e078b2d5ea607c5c3b8b5a54d1c1fba6846/INSTALL.md#codex)
- [yomiyasu: 公式導入](https://github.com/nanaism/yomiyasu/blob/db78b9bc5e868549b517a037df7a4d1c93edac23/README.md)
- [i-have-adhd: Codex manifest](https://github.com/ayghri/i-have-adhd/blob/1ecea1993b7fce257ffbd686c070948b5e07eda6/.codex-plugin/plugin.json)
