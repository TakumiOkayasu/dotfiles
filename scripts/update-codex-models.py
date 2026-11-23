"""Prepare Codex model updates from the official catalog."""
from pathlib import Path


def plan_updates(repo: Path, catalog: dict, plan: str, cli_version: str) -> dict[Path, str]:
    return {}


def fetch_catalog() -> tuple[dict, str, str]:
    raise NotImplementedError


def main(argv: list[str] | None = None) -> int:
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
