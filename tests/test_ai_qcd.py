#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "bin" / "ai-qcd"
ROUTES_PATH = ROOT / "common" / "qcd" / "routes.json"
ROUTES = json.loads(ROUTES_PATH.read_text(encoding="utf-8"))["runtimes"]


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
    (project / ".ai" / "state").mkdir(parents=True)
    (project / ".ai" / "manifest.toml").write_text(
        'schema_version = 1\nowner = "dotfile-work"\nproject_id = "local/test"\n',
        encoding="utf-8",
    )
    return project


def candidate(runtime: str, task_class: str, index: int) -> tuple[str, str]:
    entry = ROUTES[runtime][task_class][index]
    return entry["model"], entry["effort"]


def route(
    project: Path,
    runtime: str,
    task_class: str,
    *extra: str,
) -> dict[str, object]:
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
    requested: tuple[str, str],
    effective: tuple[str, str] | None = None,
    quality: str = "pass",
    quota_delta: float | None = None,
    cohort_id: str | None = None,
    scenario_id: str | None = None,
) -> None:
    command = [
        str(SCRIPT),
        "record",
        "--runtime",
        runtime,
        "--task-class",
        task_class,
        "--requested-model",
        requested[0],
        "--requested-effort",
        requested[1],
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
    if effective is not None:
        command.extend(
            ["--effective-model", effective[0], "--effective-effort", effective[1]]
        )
    if quota_delta is not None:
        command.extend(["--quota-delta", str(quota_delta)])
    if cohort_id is not None:
        command.extend(["--cohort-id", cohort_id])
    if scenario_id is not None:
        command.extend(["--scenario-id", scenario_id])
    run(*command, cwd=project)


def record_paired_cohort(
    project: Path,
    *,
    runtime: str,
    task_class: str,
    cohort_id: str,
    routes: tuple[tuple[str, str], tuple[str, str]],
    quota: tuple[float, float],
    fail_second_scenario: str | None = None,
) -> None:
    for scenario_index in range(5):
        scenario_id = f"scenario-{scenario_index}"
        for route_index, selected in enumerate(routes):
            quality = (
                "fail"
                if route_index == 1 and scenario_id == fail_second_scenario
                else "pass"
            )
            record(
                project,
                runtime=runtime,
                task_class=task_class,
                requested=selected,
                effective=selected,
                quality=quality,
                quota_delta=quota[route_index],
                cohort_id=cohort_id,
                scenario_id=scenario_id,
            )


def main() -> int:
    assert SCRIPT.is_file(), SCRIPT
    assert ROUTES_PATH.is_file(), ROUTES_PATH

    with tempfile.TemporaryDirectory() as directory:
        project = write_project(Path(directory))

        bounded_baseline = candidate("codex", "bounded", 0)
        bounded_alt = candidate("codex", "bounded", 1)
        baseline = route(project, "codex", "bounded")
        assert baseline["source"] == "baseline"
        assert (baseline["model"], baseline["effort"]) == bounded_baseline

        # Ordinary production telemetry never changes routing, even when effective
        # model/effort is verified and quality is perfect.
        for _ in range(5):
            record(
                project,
                runtime="codex",
                task_class="bounded",
                requested=bounded_alt,
                effective=bounded_alt,
                quota_delta=0.01,
            )
        telemetry_only = route(project, "codex", "bounded")
        assert telemetry_only["source"] == "baseline"

        # Requested overrides that collapse to one effective route cannot create a
        # paired comparison, protecting against silent runtime inheritance.
        for scenario_index in range(5):
            scenario = f"scenario-{scenario_index}"
            for requested in (bounded_baseline, bounded_alt):
                record(
                    project,
                    runtime="codex",
                    task_class="bounded",
                    requested=requested,
                    effective=bounded_baseline,
                    quota_delta=0.01,
                    cohort_id="collapsed-effective",
                    scenario_id=scenario,
                )
        collapsed = route(
            project, "codex", "bounded", "--cohort-id", "collapsed-effective"
        )
        assert collapsed["source"] == "baseline"

        # Same scenarios, two effective routes, quality gate passed: cheaper route
        # may become the observed winner.
        record_paired_cohort(
            project,
            runtime="codex",
            task_class="bounded",
            cohort_id="paired-1",
            routes=(bounded_baseline, bounded_alt),
            quota=(0.40, 0.10),
        )
        observed = route(project, "codex", "bounded", "--cohort-id", "paired-1")
        assert observed["source"] == "observed-paired"
        assert observed["cohort_id"] == "paired-1"
        assert observed["ranking_metric"] == "median_quota_delta"
        assert (observed["model"], observed["effort"]) == bounded_alt

        # A later malformed cohort with different scenario multisets is ignored;
        # automatic selection keeps the latest valid paired cohort.
        for scenario_index in range(5):
            record(
                project,
                runtime="codex",
                task_class="bounded",
                requested=bounded_baseline,
                effective=bounded_baseline,
                quota_delta=0.50,
                cohort_id="unpaired-later",
                scenario_id=f"base-{scenario_index}",
            )
            record(
                project,
                runtime="codex",
                task_class="bounded",
                requested=bounded_alt,
                effective=bounded_alt,
                quota_delta=0.01,
                cohort_id="unpaired-later",
                scenario_id=f"alt-{scenario_index}",
            )
        latest_valid = route(project, "codex", "bounded")
        assert latest_valid["source"] == "observed-paired"
        assert latest_valid["cohort_id"] == "paired-1"

        # Quality failure disqualifies one route. With fewer than two passing
        # routes there is no controlled winner, regardless of cost.
        reasoning_a = candidate("claude", "reasoning", 0)
        reasoning_b = candidate("claude", "reasoning", 1)
        record_paired_cohort(
            project,
            runtime="claude",
            task_class="reasoning",
            cohort_id="quality-fail",
            routes=(reasoning_a, reasoning_b),
            quota=(0.50, 0.01),
            fail_second_scenario="scenario-2",
        )
        rejected = route(
            project, "claude", "reasoning", "--cohort-id", "quality-fail"
        )
        assert rejected["source"] == "baseline"
        assert (rejected["model"], rejected["effort"]) == reasoning_a

        # Cohort/scenario metadata is atomic.
        bad = run(
            str(SCRIPT),
            "record",
            "--runtime",
            "codex",
            "--task-class",
            "lookup",
            "--requested-model",
            candidate("codex", "lookup", 0)[0],
            "--requested-effort",
            candidate("codex", "lookup", 0)[1],
            "--quality",
            "pass",
            "--cohort-id",
            "broken",
            cwd=project,
            check=False,
        )
        assert bad.returncode != 0
        assert "supplied together" in bad.stderr

    print("test_ai_qcd: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
