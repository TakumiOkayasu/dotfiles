"""A Codex statusline provider using newline-delimited MCP over stdio."""

# Derived from OpenAI Codex, Copyright 2025 OpenAI.
# SPDX-License-Identifier: Apache-2.0
# Upstream: openai/codex@ccf9be8cc458bd6b8336fe84d68d8893f2691a5e
# codex-rs/skills/src/assets/samples/create-statusline/assets/statusline.py
# Changes: fixed usage slots, warning markers, input validation, and error handling.
# See statusline-provider.LICENSE.

from dataclasses import dataclass
import json
import math
import sys
from typing import Literal


WARNING_PERCENT = 80
DANGER_PERCENT = 95
FIVE_HOUR_MINUTES = 300
WEEK_MINUTES = 10080
URI = "ui://dotfiles-statusline/footer"
TOOL = {
    "name": "statusline",
    "title": "Dotfiles usage statusline",
    "description": "Show context, five-hour, and weekly usage in the Codex footer.",
    "inputSchema": {"type": "object", "properties": {}},
    "_meta": {
        "openai/ui": {"entrypoints": [{"type": "statusline", "resourceUri": URI}]}
    },
}


class InvalidParametersError(ValueError):
    pass


class MethodNotFoundError(LookupError):
    pass


@dataclass(frozen=True)
class UsageDisplay:
    """Renderer input: display text and severity, independent of MCP node types."""

    text: str
    severity: Literal["normal", "warning", "danger"]


@dataclass(frozen=True)
class StatuslineDisplay:
    context: UsageDisplay
    five_hour: UsageDisplay
    week: UsageDisplay


def read_object(value: object) -> dict:
    if not isinstance(value, dict):
        raise InvalidParametersError("Expected a JSON object")
    return value


def read_percentage(value: object) -> int | float | None:
    if value is None or type(value) is int:
        return value
    if type(value) is float and math.isfinite(value):
        return value
    raise InvalidParametersError("Expected a finite numeric percentage")


def read_context_percentage(state: dict) -> int | float | None:
    thread = read_object(state.get("thread", {}))
    usage = read_object(thread.get("usage", {}))
    context = read_object(usage.get("context", {}))
    return read_percentage(context.get("used_percentage"))


def read_rate_percentages(state: dict) -> dict[int, int | float | None]:
    account = read_object(state.get("account", {}))
    limits = account.get("rate_limits", [])
    if not isinstance(limits, list):
        raise InvalidParametersError("Expected an array of rate limits")
    windows = {}
    for limit in limits:
        limit = read_object(limit)
        if limit.get("limit_id") != "codex":
            continue
        for name in ("primary_limit", "secondary_limit"):
            window = limit.get(name)
            if window is not None:
                window = read_object(window)
                duration = window.get("window_minutes")
                if duration in (FIVE_HOUR_MINUTES, WEEK_MINUTES):
                    windows[duration] = read_percentage(window.get("used_percent"))
    return windows


def to_usage_display(value: int | float | None) -> UsageDisplay:
    """Convert a validated percentage into display text and warning severity."""
    if value is None:
        return UsageDisplay("–", "normal")
    severity: Literal["normal", "warning", "danger"]
    if value >= DANGER_PERCENT:
        severity = "danger"
    elif value >= WARNING_PERCENT:
        severity = "warning"
    else:
        severity = "normal"
    return UsageDisplay(f"{int(value)}%", severity)


def build_statusline(state: dict) -> StatuslineDisplay:
    windows = read_rate_percentages(state)
    return StatuslineDisplay(
        context=to_usage_display(read_context_percentage(state)),
        five_hour=to_usage_display(windows.get(FIVE_HOUR_MINUTES)),
        week=to_usage_display(windows.get(WEEK_MINUTES)),
    )


def render(display: StatuslineDisplay) -> dict:
    """Translate our display contract into the MCP UI tree."""
    styles = {
        "normal": ("status-metadata", ""),
        "warning": ("yellow", " !"),
        "danger": ("red", " !!"),
    }
    children = []
    for label, usage in (
        ("ctx", display.context), ("5h", display.five_hour), ("week", display.week)
    ):
        if children:
            children.append("|")
        color, marker = styles[usage.severity]
        children.append({
            "type": "text",
            "props": {"color": color},
            "children": [f"{label} {usage.text}{marker}"],
        })
    return {"type": "row", "props": {"gap": 1, "wrap": "wrap"}, "children": children}


def respond(method: str, params: dict) -> dict:
    params = read_object(params)
    if method == "initialize":
        return {
            "protocolVersion": "2025-06-18",
            "capabilities": {"tools": {}, "resources": {}},
            "serverInfo": {"name": "dotfiles-statusline", "version": "1.0"},
        }
    if method == "ping":
        return {}
    if method == "tools/list":
        return {"tools": [TOOL]}
    if method == "tools/call":
        if params.get("name") != TOOL["name"]:
            raise InvalidParametersError("Unknown tool name")
        return {
            "content": [{"type": "text", "text": f"The statusline resource is {URI}."}]
        }
    if method == "resources/list":
        return {
            "resources": [
                {"name": "footer", "uri": URI, "mimeType": "application/json"}
            ]
        }
    if method == "resources/templates/list":
        return {"resourceTemplates": []}
    if method == "resources/read":
        if params.get("uri") != URI:
            raise InvalidParametersError("Unknown resource URI")
        metadata = read_object(params.get("_meta", {}))
        state = read_object(metadata.get("com.openai/codex-statusline-state", {}))
        return {
            "contents": [
                {
                    "uri": URI,
                    "mimeType": "application/json",
                    "text": json.dumps(render(build_statusline(state)), ensure_ascii=False),
                }
            ]
        }
    raise MethodNotFoundError(method)


def main() -> None:
    for line in sys.stdin.buffer:
        reply = {"jsonrpc": "2.0", "id": None}
        try:
            request = json.loads(line)
        except json.JSONDecodeError:
            reply["error"] = {"code": -32700, "message": "Parse error"}
        else:
            if not isinstance(request, dict) or not isinstance(
                request.get("method"), str
            ):
                reply["error"] = {"code": -32600, "message": "Invalid request"}
            elif "id" not in request:
                continue
            else:
                reply["id"] = request["id"]
                try:
                    reply["result"] = respond(request["method"], request.get("params", {}))
                except MethodNotFoundError:
                    reply["error"] = {"code": -32601, "message": "Method not found"}
                except InvalidParametersError:
                    reply["error"] = {"code": -32602, "message": "Invalid parameters"}
        print(json.dumps(reply), flush=True)


if __name__ == "__main__":
    main()
