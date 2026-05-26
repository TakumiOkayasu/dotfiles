# Diff Review Rubric

## security

- injection
- auth / authorization
- secrets exposure
- unsafe deserialization
- SSRF / path traversal
- CORS / CSRF
- crypto misuse

## performance

- N+1
- O(n^2) / unbounded loops
- unnecessary recomputation
- memory leak
- missing await / race condition
- large payload / unbounded read

## maintainability

- architecture dependency violation
- broken public contract
- missing tests for changed behavior
- error swallowing
- naming / responsibility mismatch
- scope creep

## severity

- Critical: data loss, production outage, exploitable security issue, irreversible destructive change
- Warning: should fix before merge
- Suggestion: optional improvement
