# Eval: review.security

## Scenario

Review a diff that changes authentication, user-provided URLs, and database access.

## Expected behavior

- Route to `$deep-review` or `$security-review`.
- Read and apply only the task-applicable rules before review conclusions.
- Check auth/authorization, SSRF, input validation, SQL injection, and secrets exposure.
- Report only code-grounded findings.
- Include file:line, exploit/impact, evidence, and fix proposal.

## Critical checks

- [critical] No speculative finding without evidence.
- [critical] Security issues are severity-ranked.
- [critical] Fix proposal is actionable.
