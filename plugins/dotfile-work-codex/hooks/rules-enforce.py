#!/usr/bin/env python3
"""Deterministic compliance gate for markdown rules.

This scanner enforces the mechanically-checkable subset of codex/rules/*.md.
It intentionally scans changed lines instead of whole legacy files to avoid
blocking unrelated historical violations.

Exit codes:
  0: no blocking violation
  2: blocking violation for Codex hook continuation/blocking
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Sequence

MAX_REPORT_ITEMS = int(os.environ.get("CODEX_RULES_MAX_REPORT_ITEMS", "25"))
STRICT = os.environ.get("CODEX_RULES_STRICT", "1") != "0"
MODE = os.environ.get("CODEX_RULES_ENFORCE_MODE", "block")  # block|warn
ALLOW_DEPENDENCY_CHANGE = os.environ.get("CODEX_RULES_ALLOW_DEPENDENCY_CHANGE", "0") == "1"
ALLOW_RULE_IGNORE = os.environ.get("CODEX_RULES_ALLOW_INLINE_IGNORE", "1") == "1"

CODE_EXTS = {
    ".js", ".jsx", ".ts", ".tsx", ".mjs", ".cjs", ".vue", ".svelte",
    ".py", ".rb", ".php", ".java", ".kt", ".kts", ".go", ".rs", ".cs",
}
JS_EXTS = {".js", ".jsx", ".ts", ".tsx", ".mjs", ".cjs", ".vue", ".svelte"}
TS_EXTS = {".ts", ".tsx", ".vue", ".svelte"}
PY_EXTS = {".py"}
TEST_PATTERNS = re.compile(r"(^|/)(test|tests|__tests__|spec)(/|$)|\.(test|spec)\.[jt]sx?$|_test\.go$|test_.*\.py$")
GENERATED_PATTERNS = re.compile(r"(^|/)(node_modules|vendor|dist|build|coverage|\.git|target|\.next|out|generated|__generated__)(/|$)|\.min\.js$|lock$|package-lock\.json$|pnpm-lock\.yaml$|yarn\.lock$|Cargo\.lock$|poetry\.lock$")

LOOSE_EQUAL_RE = re.compile(r"(?<![=!<>])(?:==|!=)(?!=)")
EXPLICIT_BOOL_RE = re.compile(r"(===|!==)\s*(true|false)\b|\b(true|false)\s*(===|!==)")
ANY_RE = re.compile(r"(?<![A-Za-z0-9_$])(?:any)(?![A-Za-z0-9_$])|:\s*any\b|as\s+any\b|<\s*any\s*>|Array\s*<\s*any\s*>")
PROMISE_CHAIN_RE = re.compile(r"\.(then|catch|finally)\s*\(")
CONSOLE_RE = re.compile(r"\bconsole\.(log|debug|info|warn|error)\s*\(")
PY_PRINT_RE = re.compile(r"(^|[^\w.])print\s*\(")
BROAD_CATCH_RE = re.compile(r"\bcatch\s*\(\s*(Exception|Throwable|Error|\$?e\b|e\b|err\b|error\b)[^)]*\)|\bexcept\s+(Exception|BaseException)\b")
EMPTY_CATCH_RE = re.compile(r"\bcatch\s*\([^)]*\)\s*\{\s*\}|\bexcept\b[^:]*:\s*(pass)?\s*$")
TO_BE_DEFINED_RE = re.compile(r"\.toBeDefined\s*\(\s*\)")
TODO_RE = re.compile(r"\bTODO(?!\(@[^)]+\):)")
COMMENTED_OUT_CODE_RE = re.compile(r"^\s*(//|#)\s*(if|for|while|return|const|let|var|function|class|def|public|private|protected|import|export)\b")
DEPENDENCY_SECTION_RE = re.compile(r'"(dependencies|devDependencies|peerDependencies|optionalDependencies)"\s*:')
DEPENDENCY_LINE_RE = re.compile(r'^\s*"[^"]+"\s*:\s*"[^"]+"\s*,?\s*$')
LATEST_OR_WILDCARD_RE = re.compile(r'"(latest|\*)"')
REDIRECT_MUTATION_RE = re.compile(r"(^|\s)(>|>>|tee\b)")

@dataclass(frozen=True)
class AddedLine:
    path: str
    line_no: int
    text: str
    is_untracked: bool = False

@dataclass(frozen=True)
class Violation:
    rule: str
    path: str
    line_no: int
    message: str
    evidence: str
    severity: str = "BLOCK"


def run(cmd: Sequence[str], cwd: str | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)


def git_root(cwd: str) -> Path | None:
    proc = run(["git", "-C", cwd, "rev-parse", "--show-toplevel"])
    if proc.returncode != 0:
        return None
    root = proc.stdout.strip()
    return Path(root) if root else None


def should_skip(path: str) -> bool:
    return bool(GENERATED_PATTERNS.search(path))


def is_test(path: str) -> bool:
    return bool(TEST_PATTERNS.search(path))


def ext(path: str) -> str:
    return Path(path).suffix.lower()


def is_code(path: str) -> bool:
    return ext(path) in CODE_EXTS or path.endswith((".vue", ".svelte"))


def is_comment_only(line: str, path: str) -> bool:
    s = line.strip()
    if not s:
        return True
    if s.startswith(("//", "#", "*", "/*", "<!--")):
        return True
    return False


def has_ignore(line: str, rule: str | None = None) -> bool:
    if not ALLOW_RULE_IGNORE:
        return False
    marker = "codex-rule-ignore"
    if marker not in line:
        return False
    if rule is None:
        return True
    return rule in line or marker in line


def read_json_stdin() -> dict:
    if sys.stdin.isatty():
        return {}
    raw = sys.stdin.read()
    if not raw.strip():
        return {}
    try:
        return json.loads(raw)
    except Exception:
        return {}


def parse_diff_added_lines(diff_text: str) -> list[AddedLine]:
    lines: list[AddedLine] = []
    current_path: str | None = None
    new_line: int | None = None
    for raw in diff_text.splitlines():
        if raw.startswith("+++ b/"):
            current_path = raw[6:]
            new_line = None
            continue
        if raw.startswith("+++ /"):
            current_path = None
            new_line = None
            continue
        if raw.startswith("@@ "):
            m = re.search(r"\+(\d+)(?:,(\d+))?", raw)
            new_line = int(m.group(1)) if m else None
            continue
        if current_path is None or new_line is None:
            continue
        if raw.startswith("+") and not raw.startswith("+++"):
            text = raw[1:]
            lines.append(AddedLine(current_path, new_line, text, False))
            new_line += 1
        elif raw.startswith("-") and not raw.startswith("---"):
            # deletion: does not advance new file line number
            continue
        else:
            new_line += 1
    return lines


def collect_added_lines(root: Path) -> list[AddedLine]:
    # HEAD includes staged + unstaged. If HEAD is absent, fallback to cached/worktree.
    proc = run(["git", "diff", "--no-ext-diff", "--unified=0", "HEAD", "--"], cwd=str(root))
    if proc.returncode != 0:
        proc = run(["git", "diff", "--no-ext-diff", "--unified=0", "--"], cwd=str(root))
    added = parse_diff_added_lines(proc.stdout)

    untracked = run(["git", "ls-files", "--others", "--exclude-standard"], cwd=str(root))
    for rel in untracked.stdout.splitlines():
        if should_skip(rel):
            continue
        p = root / rel
        if not p.is_file():
            continue
        try:
            data = p.read_text(encoding="utf-8", errors="replace").splitlines()
        except Exception:
            continue
        for idx, text in enumerate(data, 1):
            added.append(AddedLine(rel, idx, text, True))
    return added


def changed_paths(root: Path) -> set[str]:
    out: set[str] = set()
    for cmd in (["git", "diff", "--name-only", "HEAD", "--"], ["git", "ls-files", "--others", "--exclude-standard"]):
        proc = run(cmd, cwd=str(root))
        if proc.returncode == 0:
            out.update(x for x in proc.stdout.splitlines() if x)
    return out


def violation(rule: str, item: AddedLine, message: str, severity: str = "BLOCK") -> Violation:
    evidence = item.text.strip()
    if len(evidence) > 180:
        evidence = evidence[:177] + "..."
    return Violation(rule, item.path, item.line_no, message, evidence, severity)


def scan_added_lines(lines: Iterable[AddedLine]) -> list[Violation]:
    violations: list[Violation] = []
    in_dependency_section: dict[str, bool] = {}
    dep_depth: dict[str, int] = {}

    for item in lines:
        path = item.path
        if should_skip(path):
            continue
        e = ext(path)
        text = item.text
        stripped = text.strip()
        lower_path = path.lower()

        # Allow intentional local escapes only with explicit reason.
        if has_ignore(text):
            # Require a reason after the marker to avoid silent blanket ignores.
            if re.search(r"codex-rule-ignore(?::|\s+-\s+).{8,}", text):
                continue
            violations.append(violation("RULES_CORE", item, "codex-rule-ignore requires a concrete reason."))
            continue

        # package dependency guard
        if path.endswith("package.json"):
            if DEPENDENCY_SECTION_RE.search(text):
                in_dependency_section[path] = True
                dep_depth[path] = text.count("{") - text.count("}")
                continue
            if in_dependency_section.get(path):
                dep_depth[path] = dep_depth.get(path, 0) + text.count("{") - text.count("}")
                if DEPENDENCY_LINE_RE.match(text):
                    if LATEST_OR_WILDCARD_RE.search(text):
                        violations.append(violation("implementation-policy.md", item, "Dependency version must not use latest or wildcard."))
                    elif not ALLOW_DEPENDENCY_CHANGE:
                        violations.append(violation("implementation-policy.md", item, "Dependency changes require explicit approval and audit. Set CODEX_RULES_ALLOW_DEPENDENCY_CHANGE=1 only after approval."))
                if dep_depth.get(path, 0) <= 0:
                    in_dependency_section[path] = False
            continue

        if not is_code(path):
            # Test assertion rule can still apply in non-code snapshots? keep code only.
            continue

        comment_only = is_comment_only(text, path)

        # coding-conventions: strict equality.
        if e in JS_EXTS and not comment_only:
            if LOOSE_EQUAL_RE.search(text):
                violations.append(violation("coding-conventions.md", item, "Use strict equality (`===` / `!==`) or add an explicit codex-rule-ignore reason."))
            if EXPLICIT_BOOL_RE.search(text):
                violations.append(violation("coding-conventions.md", item, "Do not compare booleans with `=== true` / `=== false`; use truthy/falsy form."))
            if e in TS_EXTS and ANY_RE.search(text):
                violations.append(violation("coding-conventions.md", item, "Do not use `any`; use `unknown`, `object`, generics, or a concrete type."))
            if PROMISE_CHAIN_RE.search(text):
                violations.append(violation("coding-conventions.md", item, "Avoid Promise chains; prefer async/await."))
            if CONSOLE_RE.search(text) and not is_test(path):
                violations.append(violation("implementation-policy.md", item, "Do not use console.* directly in production code; use the project logger."))

        if e in PY_EXTS and not comment_only:
            if PY_PRINT_RE.search(text) and not is_test(path) and "/scripts/" not in f"/{path}":
                violations.append(violation("implementation-policy.md", item, "Do not use print() directly in production code; use the project logger."))
            if BROAD_CATCH_RE.search(text):
                violations.append(violation("coding-conventions.md", item, "Avoid broad Exception/BaseException catches unless handling is specific and justified."))
            if EMPTY_CATCH_RE.search(text):
                violations.append(violation("coding-conventions.md", item, "Do not use empty exception handlers or `pass` catches."))

        if not comment_only:
            if BROAD_CATCH_RE.search(text) and e not in PY_EXTS:
                violations.append(violation("coding-conventions.md", item, "Avoid broad catch clauses; catch specific errors or rethrow with context."))
            if EMPTY_CATCH_RE.search(text) and e not in PY_EXTS:
                violations.append(violation("coding-conventions.md", item, "Empty catch block is forbidden."))
            if TODO_RE.search(text):
                violations.append(violation("coding-conventions.md", item, "TODO must use `TODO(@user): content` or the project existing format."))
            if TO_BE_DEFINED_RE.search(text) and is_test(path):
                violations.append(violation("coding-conventions.md", item, "Do not use toBeDefined()-only assertions; assert concrete behavior."))

        if COMMENTED_OUT_CODE_RE.search(text):
            violations.append(violation("coding-conventions.md", item, "Do not add commented-out code; delete it and rely on git history."))

    return violations


def scan_function_length(root: Path, paths: Iterable[str]) -> list[Violation]:
    """Approximate function-length guard for changed JS/TS/Python files.

    This is intentionally conservative: it only reports newly/modified files when
    a simple top-level function shape is obviously longer than the 30-line rule.
    """
    if os.environ.get("CODEX_RULES_CHECK_FUNCTION_LENGTH", "1") == "0":
        return []
    violations: list[Violation] = []
    for rel in sorted(paths):
        if should_skip(rel) or not is_code(rel):
            continue
        p = root / rel
        if not p.is_file():
            continue
        e = ext(rel)
        if e not in JS_EXTS and e not in PY_EXTS:
            continue
        try:
            file_lines = p.read_text(encoding="utf-8", errors="replace").splitlines()
        except Exception:
            continue
        if e in PY_EXTS:
            starts = [(idx, line) for idx, line in enumerate(file_lines, 1) if re.match(r"^\s*def\s+\w+\s*\(", line)]
            for i, (start, line) in enumerate(starts):
                indent = len(line) - len(line.lstrip(" "))
                end = len(file_lines) + 1
                for j in range(start, len(file_lines)):
                    l = file_lines[j]
                    if l.strip() and (len(l) - len(l.lstrip(" "))) <= indent and not l.lstrip().startswith(("#", "@")):
                        end = j + 1
                        break
                length = end - start
                if length > 45:  # hard gate above guideline to reduce false positives
                    violations.append(Violation("coding-conventions.md", rel, start, f"Function appears too long ({length} lines). Split around single responsibilities.", line.strip()))
        else:
            starts = [(idx, line) for idx, line in enumerate(file_lines, 1) if re.search(r"\b(function\s+\w+|const\s+\w+\s*=\s*(async\s*)?\([^)]*\)\s*=>|\w+\s*\([^)]*\)\s*\{)", line)]
            for start, line in starts:
                brace = line.count("{") - line.count("}")
                if brace <= 0:
                    continue
                end = start
                for j in range(start, len(file_lines)):
                    if j + 1 == start:
                        continue
                    brace += file_lines[j].count("{") - file_lines[j].count("}")
                    if brace <= 0:
                        end = j + 1
                        break
                length = end - start + 1 if end >= start else 0
                if length > 45:
                    violations.append(Violation("coding-conventions.md", rel, start, f"Function appears too long ({length} lines). Split around single responsibilities.", line.strip()))
    return violations


def format_report(violations: Sequence[Violation]) -> str:
    header = f"[rules-enforce] BLOCK: {len(violations)} markdown-rule violation(s) detected in changed code."
    body = [header]
    for v in violations[:MAX_REPORT_ITEMS]:
        body.append(f"- {v.rule}: {v.path}:{v.line_no}: {v.message}")
        if v.evidence:
            body.append(f"  evidence: {v.evidence}")
    if len(violations) > MAX_REPORT_ITEMS:
        body.append(f"- ... {len(violations) - MAX_REPORT_ITEMS} more omitted. Fix above first or run `codex/hooks/rules-enforce.sh --report`.")
    body.append("Use a narrower fix, or add `codex-rule-ignore: <specific reason>` only when a project rule explicitly permits an exception.")
    return "\n".join(body)


def main() -> int:
    data = read_json_stdin()
    cwd = data.get("cwd") or os.getcwd()
    hook_event = data.get("hook_event_name") or "manual"
    tool_name = data.get("tool_name") or ""

    # For PreToolUse, do not scan; rules-guard handles read-before-mutate.
    if hook_event == "PreToolUse":
        return 0

    root = git_root(cwd)
    if root is None:
        return 0

    added = collect_added_lines(root)
    if not added:
        return 0

    violations = scan_added_lines(added)
    violations.extend(scan_function_length(root, changed_paths(root)))

    # Deduplicate while preserving order.
    seen: set[tuple[str, str, int, str]] = set()
    unique: list[Violation] = []
    for v in violations:
        key = (v.rule, v.path, v.line_no, v.message)
        if key in seen:
            continue
        seen.add(key)
        unique.append(v)

    if not unique:
        return 0

    report = format_report(unique)
    print(report, file=sys.stderr)
    if MODE == "warn":
        return 0
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
