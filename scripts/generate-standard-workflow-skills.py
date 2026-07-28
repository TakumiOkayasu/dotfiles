#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shutil
from datetime import datetime, timedelta, timezone
from pathlib import Path

JST = timezone(timedelta(hours=9), "JST")

WORKFLOWS: dict[str, tuple[str, str, str]] = {
    "feat": (
        "Feature implementation, new behavior, or product change. Use for 'implement', 'add', 'create', 'feat', UI/API changes. Do not use for pure bug fixes or explanation-only tasks.",
        "Feature Implementation",
        """## Goal\nImplement a feature with minimal scope and risk-gated TDD.\n\n## Steps\n\n1. Apply mandatory rules. If full rules are not injected, stop before editing.\n2. Classify risk:\n   - small: <=50 changed lines, no DB/API/dependency/auth/secrets changes\n   - normal: existing architecture, limited files\n   - high-risk: DB schema, public API, auth, secrets, dependency changes, destructive data, 100+ changed lines, unclear requirements\n3. For high-risk tasks, present a short plan and use `premise-questioning` / `feature-pruning` only when the trigger actually applies.\n4. For new modules/classes, use `interface-first-design` before code.\n5. Use `tdd` for behavior changes: test list -> RED -> GREEN -> REFACTOR.\n6. Keep diffs minimal. Do not add unrelated cleanup.\n7. Run project-defined test/lint/build when available.\n\n## Output\n- Risk classification\n- Changed files\n- Tests/checks run\n- Unverified risks\n- Follow-up candidates\n""",
    ),
    "fix": (
        "Bug fixing, failing tests, runtime errors, unexpected behavior, regression repair. First reproduce and identify root cause. Do not use for new features.",
        "Bug Fix",
        """## Goal\nFix a bug by proving the failure, identifying root cause, and adding regression protection.\n\n## Steps\n\n1. Apply mandatory rules.\n2. Record symptom, expected behavior, actual behavior, and environment.\n3. Reproduce. If runtime reproduction is unavailable, enter static trace mode and clearly mark reproduction as unavailable.\n4. Use `systematic-debugging`: boundary trace -> root cause -> hypothesis validation.\n5. Add or update a regression test before the patch when feasible.\n6. Patch the root cause with minimal diff. Avoid symptom-only fixes.\n7. Run relevant tests/checks.\n\n## Output\n- Reproduction status\n- Root cause\n- Fix summary\n- Regression test\n- Verification\n- Unverified risks\n""",
    ),
    "review": (
        "Code review for a diff, file, PR, or implementation result. Use for 'review', 'check', 'inspect'. Escalate to deep-review for high-risk diffs.",
        "Code Review",
        """## Goal\nReview real code evidence only.\n\n## Steps\n\n1. Apply mandatory rules.\n2. Identify target: explicit path/commit/diff, otherwise `git diff HEAD`.\n3. Escalate to `deep-review` if auth, secrets, DB/API contracts, concurrency, payments, or large diff are involved.\n4. Report only issues grounded in code.\n5. Every finding must include file:line, evidence, impact, and fix proposal.\n\n## Output\n- PASS / WARN / BLOCK\n- Findings ordered by severity\n- Fix proposals\n- Checks not performed\n""",
    ),
    "deep-review": (
        "High-risk or multi-file code review using security, performance, and maintainability perspectives. Use for 'deep review', large diffs, auth/secrets/DB/API, or release gates.",
        "Deep Review",
        """## Goal\nRun a multi-perspective review and synthesize into one severity-ordered result.\n\n## Steps\n\n1. Apply mandatory rules and read target diff.\n2. Split review by perspective: security, performance, maintainability. Use subagents only if available and useful; otherwise use parent-session sections.\n3. Security: auth, authorization, input validation, secrets, SQL/command injection, XSS, SSRF, path traversal, unsafe deserialization, CSRF/CORS.\n4. Performance: N+1, O(n^2), unnecessary recomputation, memory/resource leak, concurrency/race/await issues.\n5. Maintainability: architecture invariants, dependency direction, public contract breakage, test quality, scope creep.\n6. Synthesize duplicates and sort Critical -> Warning -> Suggestion.\n\n## Output\n- `## 判定: BLOCK|WARN|PASS`\n- Counts by severity and perspective\n- Findings with file:line, evidence, fix proposal\n""",
    ),
    "security-review": (
        "Security-only review for auth, authorization, secrets, input validation, injection, XSS, SSRF, path traversal, unsafe deserialization, CORS/CSRF.",
        "Security Review",
        """## Goal\nFind exploitable security issues with evidence and fixes.\n\n## Scope\n- auth / authorization\n- secrets / tokens / credentials\n- input validation and output encoding\n- SQL / command injection\n- XSS / SSRF / path traversal\n- unsafe deserialization / dynamic code execution\n- CORS / CSRF\n\n## Output\n- BLOCK / WARN / PASS\n- file:line\n- exploit scenario\n- evidence\n- fix proposal\n""",
    ),
    "test": (
        "Add or improve tests for existing behavior or new specification. Use for unit/integration test additions. Do not use for CI-only changes.",
        "Test Authoring",
        """## Goal\nAdd meaningful tests that fail for the right reason and protect behavior.\n\n## Steps\n1. Apply mandatory rules.\n2. Inspect existing test runner, layout, naming, and assertions.\n3. Define what behavior each test proves.\n4. Use `tdd` when changing implementation.\n5. Avoid tautological assertions and coverage-only tests.\n6. Run relevant tests or report why not.\n""",
    ),
    "refactor": (
        "Behavior-preserving refactoring, structure cleanup, naming, extraction, duplication removal. Do not use when behavior, public API, or data model changes.",
        "Refactor",
        """## Goal\nImprove structure without changing behavior.\n\n## Steps\n1. Apply mandatory rules.\n2. Confirm existing tests/checks and current behavior.\n3. State scope and invariants.\n4. Make one small structural change at a time.\n5. Run tests after meaningful changes.\n6. If behavior change is needed, stop and reroute to `feat` or `fix`.\n""",
    ),
    "rules-required": (
        "Mandatory rule application before edits, tests, reviews, or implementation conclusions. Use when rules are unclear or before any mutating tool.",
        "Rules Required",
        """## Goal\nEnsure applicable markdown rules are read and applied.\n\n## Steps\n1. Confirm `RULES_CORE.md` and `RULES_INDEX.md` are available.\n2. For implementation/review/test/refactor, require full rule injection before any mutating tool.\n3. Identify relevant rule files for the task.\n4. Summarize applicable constraints.\n5. If rules conflict, follow nearest/project-specific rule and report conflict.\n\n## Output\n- Rules applied\n- Conflicts\n- Task-specific checklist\n""",
    ),
    "codex-handoff": (
        "Create a compact continuation handoff for Codex sessions, compaction, or task transfer.",
        "Codex Handoff",
        """## Output format\n\n```md\n🎯 Context\n- 背景:\n- 制約:\n- 決定:\n\n📌 Tasks\n1. [task] - [purpose] - [notes]\n\n📁 Files\n- 変更:\n- 参考:\n\n✅ Done when\n- ...\n\n⚠️ Risks\n- ...\n```\n""",
    ),
    "implementation-router": (
        "Classify implementation tasks by risk and route to feat, fix, refactor, test, review, or consult.",
        "Implementation Router",
        """## Routing\n- New behavior -> `feat`\n- Bug/failing test/runtime error -> `fix`\n- Behavior-preserving cleanup -> `refactor`\n- Test-only -> `test`\n- Planning/no edit -> `consult`\n- Code review -> `review` / `deep-review`\n\nAlways apply rules first and escalate high-risk tasks.\n""",
    ),
    "plan": (
        "Planning-only mode for 2-3 options and a recommendation. Do not edit files.",
        "Plan",
        """Use `consult`. File edits are forbidden. Output options, comparison, recommendation, and handoff.\n""",
    ),
    "explain": (
        "Explain code structure, data flow, dependencies, and change points. Do not edit files.",
        "Explain",
        """Read relevant files and explain: overview, entry points, data flow, dependencies, risks, and where to change. No edits.\n""",
    ),
    "commit-msg": (
        "Generate Conventional Commits message proposals from staged diff. Never run git commit.",
        "Commit Message",
        """Check `git status --short` and `git diff --staged`. If staged diff is empty, stop. Suggest 1-3 Conventional Commits messages. Do not commit.\n""",
    ),
    "plugin-sync": (
        "Synchronize codex assets into the local plugin bundle and verify plugin packaging.",
        "Plugin Sync",
        """Run `python3 scripts/apply-codex-performance-profile.py --repo .`, then `python3 scripts/sync-codex-plugin.py --repo . --clean`, then `python3 scripts/verify-codex-plugin.py --repo .`.\n""",
    ),
    "plugin-install": (
        "Install the local dotfile-work Codex plugins into the personal marketplace source.",
        "Plugin Install",
        """Run `python3 scripts/install-codex-plugin-personal.py --repo .`. Then restart Codex, open `/plugins`, install/enable core plugin, and trust hooks. Enable extra plugin only when needed.\n""",
    ),
}

COMMON = """\n## Common contract\n\n- Plugin-only operation: use `$skill` / `@skill` or `/skills`; no `/prompt:*` or `prompt:*`.\n- Apply mandatory rules before editing, reviewing, testing, or implementation conclusions.\n- Keep diffs minimal and scoped.\n- Report unverified items and skipped checks.\n- Destructive operations, dependency changes, DB/API contract changes, commit, push, deploy, privileged commands, and external writes require explicit user approval.\n"""


def generated_at_jst() -> str:
    return f"{datetime.now(JST).isoformat(timespec='seconds')} JST"


def skill_body(name: str, desc: str, title: str, content: str) -> str:
    return f"""---\nname: {name}\ndescription: {desc} Front-load this description for Codex implicit matching; explicit invocation via ${name} always works.\n---\n\n# {title}\n\n{content.strip()}\n{COMMON}\n"""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=".")
    ap.add_argument("--overwrite", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    root = Path(args.repo).resolve()
    outdir = root / "codex" / "skills"
    outdir.mkdir(parents=True, exist_ok=True)
    generated: list[str] = []
    for name, (desc, title, content) in sorted(WORKFLOWS.items()):
        out = outdir / name / "SKILL.md"
        if args.dry_run:
            print(f"would generate {out.relative_to(root)}")
            continue
        out.parent.mkdir(parents=True, exist_ok=True)
        if out.exists() and not args.overwrite:
            print(f"skip existing {out.relative_to(root)}")
            continue
        bak = out.with_name("SKILL.md.pre-performance-profile.bak")
        if out.exists() and not bak.exists():
            shutil.copy2(out, bak)
        out.write_text(skill_body(name, desc, title, content), encoding="utf-8")
        generated.append(out.relative_to(root).as_posix())
    if not args.dry_run:
        (outdir / "PLUGIN_ONLY_WORKFLOWS.md").write_text(
            "# Plugin-only workflow skills\n\n"
            "Generated optimized core @skill workflow entrypoints. Legacy prompt compatibility is intentionally not generated.\n\n"
            f"Generated at: {generated_at_jst()}\n\n"
            + "\n".join(f"- `{p}`" for p in generated) + "\n",
            encoding="utf-8",
        )
    print(f"generated={len(generated)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
