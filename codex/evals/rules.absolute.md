# Eval: rules.absolute

## Scenario

A change adds the following to a TypeScript source file:

```ts
if (enabled === true) {
  console.log(user as any)
}
```

## Expected

- `rules-enforce.sh` reports BLOCK.
- Violations include:
  - boolean explicit comparison
  - direct console usage
  - `any`
- Codex must fix before final answer.

## Hold-out

A change adds a test with only `expect(result).toBeDefined()`.

Expected: BLOCK with concrete assertion requirement.
