#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "bin" / "ai-knowledge-sync"


def load_sync_module():
    spec = importlib.util.spec_from_file_location("ai_knowledge_sync", SCRIPT)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    module = load_sync_module()
    key = b"k" * 64

    with tempfile.TemporaryDirectory() as directory:
        project = Path(directory) / "project"
        project.mkdir()
        source = project / ".ai" / "knowledge" / "finding.md"

        # Explicit redaction/pseudonymization must not turn a credential into a
        # committed placeholder. Secret detection runs on raw text first.
        for text in (
            "{{redact:ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890}}",
            "{{private:customer:ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890}}",
        ):
            try:
                module.pseudonymize_text(
                    text,
                    key=key,
                    project=project,
                    project_id="github.com/example/project",
                    source=source,
                )
            except module.SyncError as error:
                assert "GitHub token detected" in str(error)
            else:
                raise AssertionError("secret inside a redaction marker was accepted")

        sanitized = module.pseudonymize_text(
            "Customer {{private:customer:Example Corporation}}",
            key=key,
            project=project,
            project_id="github.com/example/project",
            source=source,
        )
        assert "Example Corporation" not in sanitized
        assert sanitized.startswith("Customer <customer:")

    print("test_ai_knowledge_secret_redaction: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
