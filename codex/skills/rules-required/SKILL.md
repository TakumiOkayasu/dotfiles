---
name: rules-required
description: Use when rules, coding conventions, implementation policy, architecture invariants, or safety constraints may affect the task. Checks that Codex rules are available without printing full rule contents. Do not use to dump rules unless explicitly requested.
---

# Rules Required

Use this skill when rules may affect editing, reviewing, testing, or implementation conclusions.

## Quiet mode policy

Do not print full rules into the user-visible transcript unless the user explicitly asks for the rule text.

Default behavior:

1. Confirm that rules exist.
2. Summarize only the rule names and the specific constraints relevant to the current task.
3. Before editing, rely on `rules-guard.sh` to verify that the rules marker checksum is current.
4. If the guard blocks because the marker is missing or stale, start a new turn or run the quiet marker refresh hook, then continue.

## Required checks

- Determine the task category: implementation / bug fix / review / refactor / test / investigation.
- Identify applicable rule files by name.
- Apply the relevant constraints silently.
- Report only conflicts, blockers, and verification risks.

## Output format

```text
Rules:
- applied: <rule file names only>
- conflicts: <none or concise description>
- risk: <none or concise description>
```

## Do not

- Do not paste `RULES_BUNDLE.md` or full rule file contents.
- Do not produce hook-style context dumps.
- Do not use custom `/prompt:*` commands.
