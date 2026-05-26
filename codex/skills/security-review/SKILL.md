---
name: security-review
description: 差分・ファイル・設計をセキュリティ観点でレビューする。認証認可、入力検証、secrets、injection、SSRF、path traversal などを対象にする。
---

# Security Review

## Scope

- 認証 / 認可
- secrets / token / API key
- SQL injection
- command injection
- XSS / HTML injection
- SSRF
- path traversal
- unsafe deserialization
- CORS / CSRF
- cryptography misuse
- TOCTOU
- input validation

## Workflow

1. trust boundary を特定する。
2. attacker-controlled input を列挙する。
3. input が sink に到達する経路を読む。
4. exploit scenario が成立するものだけ指摘する。
5. 最小修正案を出す。
6. test / validation 案を添える。

## Severity

| Severity | Condition |
| --- | --- |
| Critical | 認証回避、権限昇格、任意コード実行、secrets 漏洩、データ破壊 |
| Warning | 条件付きで悪用可能、defense-in-depth 不足、入力検証不足 |
| Suggestion | hardening、監査ログ、明確化 |

## Output

```text
### [Critical|Warning|Suggestion] [security] <category>
- file:line — <summary>
- attack path: <source → sink>
- exploit scenario: <conditions>
- evidence: <code evidence>
- fix: <minimal fix>
- validation: <test/check>
```

## Prohibitions

- exploit scenario が書けない推測指摘
- style-only 指摘
- 汎用的な「セキュリティに注意」だけのコメント
