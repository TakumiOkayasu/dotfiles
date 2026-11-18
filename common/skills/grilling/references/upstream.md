# 上流と変更内容

本skillは Matt Pocock の grilling を日本語向けに改変したものである。

- Repository: https://github.com/mattpocock/skills
- 固定commit: `5863806dd4e15c63174bee4e7515a4256792ecfa`
- 原文: https://github.com/mattpocock/skills/blob/5863806dd4e15c63174bee4e7515a4256792ecfa/skills/productivity/grilling/SKILL.md
- ライセンス原文: https://github.com/mattpocock/skills/blob/5863806dd4e15c63174bee4e7515a4256792ecfa/LICENSE

判断を分岐として扱い、前提が決まった独立質問をラウンドごとにまとめ、人間の回答で次の質問を決める手順を保持した。
各質問の推奨回答、はいで推奨案を採用する形式、事実はエージェントが調査し判断は人間へ聞く分担、最後の共有理解の確認も保持した。

日本語の途中経過/質問/最終確認の形式、回答の有効範囲、欠落を点検する品質基準、subagentを利用できない場合の調査方法を追加した。
共有理解の確認と作業の実行許可を分離し、通常の実装中に自動起動しないようにした。
特定のモデル/CLI/有料契約には依存しない。

## MIT License

```text
MIT License

Copyright (c) 2026 Matt Pocock

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
