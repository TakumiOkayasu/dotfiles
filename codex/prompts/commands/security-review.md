---
name: security-review
summary: security-only で差分または指定ファイルをレビューする
profile: review
skills:
  - security-review
---

# security-review

$ARGUMENTS

## Purpose

対象をセキュリティ観点だけでレビューする。保守性・性能・style-only 指摘は扱わない。

## Scope

- 認証 / 認可漏れ
- secrets / token / API key 露出
- SQL / command injection
- XSS / HTML injection
- SSRF
- path traversal
- unsafe deserialization
- CORS / CSRF
- input validation
- cryptography misuse
- TOCTOU

## Method

1. 対象差分と入力境界を読む。
2. attacker-controlled input がどこから入り、どこへ到達するかを追跡する。
3. exploit scenario が書ける指摘だけ出す。
4. すべての指摘に最小修正案を付ける。

## Output

```text
## 判定: BLOCK|WARN|PASS

### [Critical|Warning|Suggestion] [security] <カテゴリ>
- file:line — <要約>
- exploit scenario: <攻撃成立条件>
- evidence: <実コード根拠>
- fix: <修正案>
```
