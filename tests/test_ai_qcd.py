#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "bin" / "ai-qcd"


def run(*args: str, cwd: Path | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        [*args], cwd=cwd, text=True, capture_output=True, check=False
    )
    if check and result.returncode != 0:
        raise AssertionError(
            f"command failed ({result.returncode}): {' '.join(args)}\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )
    return result


def write_project(root: Path) -> Path:
    project = root / "project"
    state = project / ".ai" / "state"
    state.mkdir(parents=True)
    (project / ".ai" / "manifest.toml").write_text(
        'schema_version = 1\nowner = "dotfile-work"\nproject_id = "local/test"\n',
        encoding="utf-8",
    )
    return project


def route(project: Path, runtime: str, task_class: str, *extra: str) -> dict[str, object]:
    result = run(
        str(SCRIPT),
        "route",
        "--runtime",
        runtime,
        "--task-class",
        task_class,
        "--json",
        *extra,
        cwd=project,
    )
    return json.loads(result.stdout)


def record(
    project: Path,
    *,
    runtime: str,
    task_class: str,
    model: str,
    effort: str,
    quality: str = "pass",
    quota_delta: float | None = None,
    verified: bool = True,
) -> None:
    command = [
        str(SCRIPT),
        "record",
        "--runtime",
        runtime,
        "--task-class",
        task_class,
        "--requested-model",
        model,
        "--requested-effort",
        effort,
        "--quality",
        quality,
        "--duration-ms",
        "1000",
        "--input-tokens",
        "1000",
        "--cached-input-tokens",
        "900",
        "--output-tokens",
        "100",
    ]
    if verified:
        command.extend(
            ["--effective-model", model, "--effective-effort", effort]
        )
    if quota_delta is not None:
        command.extend(["--quota-delta", str(quota_delta)])
    run(*command, cwd=project)


def main() -> int:
    assert SCRIPT.is_file(), SCRIPT

    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        project = write_project(root)

        baseline = route(project, "codex", "bounded")
        assert baseline["source"] == "baseline"
        assert baseline["model"] == "gpt-5.6-terra"
        assert baseline["effort"] == "medium"

        # Provisional observations without verified effective config never train routing.
        for _ in range(5):
            record(
                project,
                runtime="codex",
                task_class="bounded",
                model="gpt-5.6-luna",
                effort="medium",
                verified=False,
                quota_delta=0.1,
            )
        provisional = route(project, "codex", "bounded")
        assert provisional["source"] == "baseline"

        # A cheaper verified route can win only after the sample and quality gates pass.
        for _ in range(5):
            record(
                project,
                runtime="codex",
                task_class="bounded",
                model="gpt-5.6-luna",
                effort="medium",
                quota_delta=0.1,
            )
        observed = route(project, "codex", "bounded")
        assert observed["source"] == "observed"
        assert observed["model"] == "gpt-5.6-luna"
        assert observed["effort"] == "medium"

        # Quality failure disqualifies a route at the default 100% pass-rate gate.
        for _ in range(4):
            record(
                project,
                runtime="claude",
                task_class="reasoning",
                model="sonnet",
                effort="medium",
                quota_delta=0.01,
            )
        record(
            project,
            runtime="claude",
            task_class="reasoning",
            model="sonnet",
            effort="medium",
            quality="fail",
            quota_delta=0.01,
        )
        rejected = route(project, "claude", "reasoning")
        assert rejected["source"] == "baseline"
        assert rejected["model"] == "sonnet"
        assert rejected["effort"] == "xhigh"

        # Quota delta is preferred over token/latency proxies when available.
        for model, quota in (("sonnet", 0.2), ("opus", 0.4)):
            for _ in range(5):
                record(
                    project,
                    runtime="claude",
                    task_class="bounded",
                    model=model,
                    effort="high",
                    quota_delta=quota,
                )
        winner = route(project, "claude", "bounded")
        assert winner["source"] == "observed"
        assert winner["model"] == "sonnet"

        bad = run(
            str(SCRIPT),
            "record",
            "--runtime",
            "codex",
            "--task-class",
            "lookup",
            "--requested-model",
            "gpt-5.6-luna",
            "--requested-effort",
            "medium",
            "--effective-model",
            "gpt-5.6-luna",
            "--quality",
            "pass",
            cwd=project,
            check=False,
        )
        assert bad.returncode != 0
        assert "supplied together" in bad.stderr

    print("test_ai_qcd: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
