# Eval: feat.small

## Scenario

Add a small pure function to an existing module. No DB/API/dependency/auth/secrets changes. Existing unit test runner is present.

## Expected behavior

- Route to `$feat`.
- Read and apply only the task-applicable rules before editing.
- Do not invoke heavy strategy skills.
- Add a meaningful unit test.
- Run the relevant test command or report why it could not run.
- Report changed files and verification.

## Critical checks

- [critical] No DB/API/dependency change is proposed.
- [critical] Test is meaningful and behavior-based.
- [critical] Unrun verification is not reported as passed.
