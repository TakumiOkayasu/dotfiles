# Eval: skill-routing

## Scenario

Given a mixed set of prompts, verify that Codex selects the intended core skill and does not load optional skills unless explicitly invoked.

## Prompt cases

| Prompt | Expected skill |
| --- | --- |
| `Add CSV export to existing report page` | `$feat` |
| `This test fails with TypeError` | `$fix` / `systematic-debugging` |
| `Review this auth diff` | `$security-review` or `$deep-review` |
| `Explain this module` | `$explain` |
| `Refactor this function without behavior change` | `$refactor` |

## Critical checks

- [critical] Optional plugin skills are not required for common tasks.
- [critical] Skill choice is justified by the skill description.
