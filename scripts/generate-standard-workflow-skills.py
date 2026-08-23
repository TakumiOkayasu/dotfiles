#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from codex_asset_manifest import load_asset_manifest

ASSET_MANIFEST_PATH = Path(__file__).with_name("claude-command-map.json")


ASSET_MANIFEST = load_asset_manifest(ASSET_MANIFEST_PATH)
CLAUDE_COMMAND_REFERENCES = {
    mapping.skill: mapping.source.as_posix() for mapping in ASSET_MANIFEST.commands
}

WORKFLOWS: dict[str, tuple[str, str, str]] = {
    "feat": (
        "Feature implementation, new behavior, or product change. Use for 'implement', 'add', 'create', 'feat', UI/API changes. Do not use for pure bug fixes or explanation-only tasks.",
        "Feature Implementation",
        """## Goal\nImplement a feature with minimal scope and risk-gated TDD.\n\n## Steps\n\n1. Read and apply only the rules applicable to this task. If a required rule cannot be read, report the blocker before editing.\n2. Classify risk:\n   - small: <=50 changed lines, no DB/API/dependency/auth/secrets changes\n   - normal: existing architecture, limited files\n   - high-risk: DB schema, public API, auth, secrets, dependency changes, destructive data, 100+ changed lines, unclear requirements\n3. For high-risk tasks, present a short plan and use `premise-questioning` / `feature-pruning` only when the trigger actually applies.\n4. For new modules/classes, use `interface-first-design` before code.\n5. Use `tdd` for behavior changes: test list -> RED -> GREEN -> REFACTOR.\n6. Keep diffs minimal. Do not add unrelated cleanup.\n7. Run project-defined test/lint/build when available.\n\n## Output\n- Risk classification\n- Changed files\n- Tests/checks run\n- Unverified risks\n- Follow-up candidates\n""",
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
        "Select and apply only the markdown rules relevant to the current task. Use when task or project instructions require rules, applicable rules are unclear, or a rules guard requests reactivation.",
        "Rules Required",
        """## Goal\nEnsure applicable markdown rules are read and applied without loading unrelated rules.\n\n## Steps\n1. Locate and read `RULES_CORE.md` and `RULES_INDEX.md` when available.\n2. Use the index and task scope to identify only the relevant detailed rule files.\n3. Read those files before edits or implementation/review conclusions.\n4. If the rules marker is missing, core-only, or stale, run `codex-rules refresh`; the marker proves checksum activation, not model read completion.\n5. Summarize applicable constraints and report conflicts according to the runtime instruction hierarchy.\n\n## Output\n- Rules read and applied\n- Conflicts\n- Task-specific checklist\n""",
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
        """Run `python3 scripts/generate-ai-assets.py --repo .`. It builds the complete pipeline in an isolated tracked-source staging tree, verifies the plugin bundles, and publishes only a complete result under `.generated/ai-assets/`.\n""",
    ),
    "plugin-install": (
        "Install the local dotfile-work Codex plugins into the personal marketplace source.",
        "Plugin Install",
        """Run `./install.sh`, select Codex, then open `/plugins` and enable the core plugin. The installer generates and links the personal plugin source and marketplace. Enable the extra plugin only when needed.\n""",
    ),
}

COMMON = """\n## Common contract\n\n- Plugin-only operation: use `$skill` or `/skills`; no `/prompt:*` or `prompt:*`.\n- Apply mandatory rules before editing, reviewing, testing, or implementation conclusions.\n- Keep diffs minimal and scoped.\n- Report unverified items and skipped checks.\n- Destructive operations, dependency changes, DB/API contract changes, commit, push, deploy, privileged commands, and external writes require explicit user approval.\n"""


def skill_body(name: str, desc: str, title: str, content: str) -> str:
    command_reference = ""
    if name in CLAUDE_COMMAND_REFERENCES:
        command_reference = (
            "\n## Claude command reference\n\n"
            f"- `{CLAUDE_COMMAND_REFERENCES[name]}` から変換された詳細手順は "
            "`references/claude-command.md` を読む。\n"
            "- 内容が競合する場合は、この Codex-native `SKILL.md` と "
            "`Common contract` を優先する。\n"
        )
    normalized_content = re.sub(
        r"(?m)^(#{2,6} .+)\n(?!\n)", r"\1\n\n", content.strip()
    )
    return (
        f"""---\nname: {name}\ndescription: {desc} Front-load this description for Codex implicit matching; explicit invocation via ${name} always works.\n---\n\n# {title}\n\n{normalized_content}\n{command_reference}{COMMON}"""
    ).rstrip() + "\n"


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
        out.write_text(skill_body(name, desc, title, content), encoding="utf-8")
        generated.append(out.relative_to(root).as_posix())
    print(f"generated={len(generated)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
