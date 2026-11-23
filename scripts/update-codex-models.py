"""Propose same-family Codex model updates from an official release catalog."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import tomllib
import urllib.request

MODEL_ID = re.compile(r"gpt-(\d+(?:\.\d+)*)-([a-z][a-z0-9-]*)")
RELEASE_API = "https://api.github.com/repos/openai/codex/releases/latest"
CATALOG_PATH = "codex-rs/models-manager/models.json"
MAX_RESPONSE_BYTES = 8 * 1024 * 1024


def version(value: str) -> tuple[int, ...]:
    if not isinstance(value, str) or not re.fullmatch(r"\d+(?:\.\d+)*", value):
        raise ValueError(f"Invalid version: {value!r}")
    return tuple(int(part) for part in value.split("."))


def read_json(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=30) as response:
        payload = response.read(MAX_RESPONSE_BYTES + 1)
    if len(payload) > MAX_RESPONSE_BYTES:
        raise ValueError("Upstream response exceeds the size limit")
    result = json.loads(payload)
    if not isinstance(result, dict):
        raise ValueError("Expected a JSON object")
    return result


def fetch_catalog() -> tuple[dict, str, str]:
    """Read the catalog at the latest stable release, never the development branch."""
    release = read_json(RELEASE_API)
    tag = release.get("tag_name", "")
    if (release.get("draft") is not False or release.get("prerelease") is not False
            or not re.fullmatch(r"rust-v\d+\.\d+\.\d+", tag)):
        raise ValueError("Expected a stable Codex release")
    source = f"https://raw.githubusercontent.com/openai/codex/{tag}/{CATALOG_PATH}"
    return read_json(source), tag.removeprefix("rust-v"), source


def catalog_models(catalog: dict) -> list[dict]:
    models = catalog.get("models")
    if not isinstance(models, list) or not models:
        raise ValueError("Catalog must contain a nonempty models list")
    seen = set()
    for model in models:
        if not isinstance(model, dict):
            raise ValueError("Invalid catalog entry")
        slug = model.get("slug")
        if not isinstance(slug, str) or slug in seen:
            raise ValueError("Catalog model IDs must be unique strings")
        seen.add(slug)
        if model.get("visibility") not in ("list", "hide"):
            raise ValueError(f"Missing catalog visibility: {slug}")
        plans = model.get("available_in_plans")
        levels = model.get("supported_reasoning_levels")
        if not isinstance(plans, list) or not all(isinstance(p, str) for p in plans):
            raise ValueError(f"Missing ChatGPT plan availability: {slug}")
        if (not isinstance(levels, list) or not levels
                or not all(isinstance(level, dict) and isinstance(level.get("effort"), str)
                           for level in levels)):
            raise ValueError(f"Missing reasoning efforts: {slug}")
        version(model.get("minimal_client_version"))
    return models


def replacement(current: str, effort: str, models: list[dict],
                plan: str, cli_version: str) -> str:
    match = MODEL_ID.fullmatch(current)
    if match is None:
        raise ValueError(f"Unsupported model ID {current!r}; select an exact Codex model ID")
    current_entry = next((model for model in models if model["slug"] == current), None)
    if (current_entry is not None
            and version(current_entry["minimal_client_version"]) > version(cli_version)):
        raise ValueError(
            f"{current} requires Codex CLI >= {current_entry['minimal_client_version']} "
            f"(selected {cli_version})"
        )
    candidates = []
    for model in models:
        candidate = MODEL_ID.fullmatch(model["slug"])
        if (candidate is not None and candidate[2] == match[2]
                and model["visibility"] == "list"
                and plan in model["available_in_plans"]
                and version(model["minimal_client_version"]) <= version(cli_version)):
            candidates.append(model)
    if not candidates:
        raise ValueError(f"No compatible {match[2]} model for plan {plan} / CLI {cli_version}")
    newest = max(candidates, key=lambda model: version(MODEL_ID.fullmatch(model["slug"])[1]))
    if version(MODEL_ID.fullmatch(newest["slug"])[1]) < version(match[1]):
        return current
    if effort not in {level["effort"] for level in newest["supported_reasoning_levels"]}:
        raise ValueError(f"{newest['slug']} does not support reasoning effort {effort!r}")
    return newest["slug"]


def replace_assignment(text: str, setting: tuple[str, ...], current: str, target: str) -> str:
    # Parsing each candidate prefix rejects matches inside multiline instructions.
    pattern = re.compile(
        rf"^([ \t]*{setting[-1]}[ \t]*=[ \t]*)(['\"]){re.escape(current)}\2", re.MULTILINE
    )
    for match in pattern.finditer(text):
        try:
            prefix = tomllib.loads(text[:match.end()])
        except tomllib.TOMLDecodeError:
            continue
        parent = prefix
        for key in setting[:-1]:
            parent = parent.get(key, {})
        if parent.get(setting[-1]) == current:
            start = match.start() + len(match[1]) + 1
            return text[:start] + target + text[start + len(current):]
    raise ValueError(f"Cannot locate the TOML assignment: {'.'.join(setting)}")


def plan_updates(repo: Path, catalog: dict, plan: str, cli_version: str) -> dict[Path, str]:
    """Validate every source first and return proposed contents without writing files."""
    models = catalog_models(catalog)
    version(cli_version)
    codex = repo / "codex"
    files = [codex / "config.toml.template", *sorted(codex.glob("*.config.toml")),
             *sorted((codex / "agents").glob("*.toml"))]
    updates = {}
    for path in files:
        if path.is_symlink():
            raise ValueError(f"Expected a canonical regular source file: {path}")
        original = path.read_text(encoding="utf-8")
        config = tomllib.loads(original)
        settings = [(("model",), config["model"], config["model_reasoning_effort"])]
        agents = config.get("agents", {})
        if "default_subagent_model" in agents:
            settings.append((("agents", "default_subagent_model"),
                             agents["default_subagent_model"],
                             agents["default_subagent_reasoning_effort"]))
        updated = original
        for setting, current, effort in settings:
            target = replacement(current, effort, models, plan, cli_version)
            if current != target:
                updated = replace_assignment(updated, setting, current, target)
        if updated != original:
            tomllib.loads(updated)
            updates[path] = updated
    return updates


def render_report(repo: Path, updates: dict[Path, str], catalog: dict,
                  plan: str, cli_version: str, source: str) -> str:
    lines = [
        "HUMAN_REVIEW_REQUIRED", "",
        f"Catalog: {source}", f"Catalog CLI baseline: {cli_version}",
        f"ChatGPT plan filter: {plan}", "",
    ]
    selected = set()
    for path, updated in updates.items():
        before = tomllib.loads(path.read_text(encoding="utf-8"))
        after = tomllib.loads(updated)
        pairs = [(before["model"], after["model"])]
        if "default_subagent_model" in after.get("agents", {}):
            pairs.append((before["agents"]["default_subagent_model"],
                          after["agents"]["default_subagent_model"]))
        for current, target in pairs:
            if current != target:
                selected.add(target)
                lines.append(f"- {path.relative_to(repo)}: `{current}` -> `{target}`")
    minimums = [m["minimal_client_version"] for m in catalog["models"] if m["slug"] in selected]
    if minimums:
        lines += ["", f"Required Codex CLI: >= {max(minimums, key=version)}."]
    lines += [
        "", "Review and merge manually after checking /model with the target account.",
        "The public release catalog is a snapshot; workspace access can differ.",
        "Existing ~/.codex/config.toml is generated only once and must be updated separately.",
        "No inference request is made. Model access on the target account is unverified.",
        "The workflow validates generated assets and installer regressions before opening a PR.",
        "GITHUB_TOKEN-created PRs require approval to run PR CI; select Approve workflows to run.",
    ]
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--catalog", type=Path, help="Offline official catalog JSON")
    parser.add_argument("--cli-version", help="Client compatibility baseline")
    parser.add_argument("--plan", required=True, help="Exact ChatGPT catalog plan ID")
    parser.add_argument("--write", action="store_true", help="Apply the validated plan")
    args = parser.parse_args(argv)
    if args.catalog:
        if not args.cli_version:
            parser.error("--catalog requires --cli-version")
        catalog = json.loads(args.catalog.read_text(encoding="utf-8"))
        cli_version, source = args.cli_version, args.catalog.name
    else:
        catalog, released_version, source = fetch_catalog()
        cli_version = args.cli_version or released_version
    updates = plan_updates(args.repo, catalog, args.plan, cli_version)
    report = render_report(args.repo, updates, catalog, args.plan, cli_version, source)
    if args.write:
        for path, content in updates.items():
            path.write_text(content, encoding="utf-8")
    print(report, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
