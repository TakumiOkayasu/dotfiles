"""Exercise the provider with a fake Codex host over the real stdio boundary."""

# Derived from OpenAI Codex, Copyright 2025 OpenAI.
# SPDX-License-Identifier: Apache-2.0
# Upstream: openai/codex@ccf9be8cc458bd6b8336fe84d68d8893f2691a5e
# codex-rs/skills/tests/test_statusline_starter.py
# Changes: fake host and fixed usage-slot, warning, and protocol assertions.
# See ../codex/bin/statusline-provider.LICENSE.

from __future__ import annotations

from contextlib import redirect_stdout
import importlib.util
import io
import json
import os
from pathlib import Path
from queue import Empty, Queue
import subprocess
import sys
from threading import Thread
import unittest
from unittest.mock import patch


PROVIDER = Path(__file__).resolve().parents[1] / "codex/bin/statusline-provider.py"
STATE_META = "com.openai/codex-statusline-state"


class FakeCodexHost:
    """Keep stdin open and wait for each response before sending the next request."""

    def __init__(self) -> None:
        self.process = subprocess.Popen(
            [sys.executable, str(PROVIDER)],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            encoding="utf-8",
            env={**os.environ, "PYTHONIOENCODING": "ascii"},
        )
        self.replies: Queue[str] = Queue()
        self.reader = Thread(target=self.collect_replies, daemon=True)
        self.reader.start()
        self.request_id = 0

    def collect_replies(self) -> None:
        for line in self.process.stdout:
            self.replies.put(line)
        self.replies.put("")

    def close(self) -> None:
        self.process.stdin.close()
        try:
            self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait()
            raise AssertionError("Provider did not exit after EOF")
        finally:
            self.reader.join(timeout=5)
            stderr = self.process.stderr.read()
            self.process.stdout.close()
            self.process.stderr.close()
        assert self.process.returncode == 0, stderr
        assert stderr == "", stderr
        while not self.replies.empty():
            extra = self.replies.get_nowait()
            assert extra == "", f"Unexpected extra stdout: {extra!r}"

    def send(self, message: dict) -> None:
        self.send_wire(json.dumps({"jsonrpc": "2.0", **message}, ensure_ascii=False))

    def send_wire(self, line: str) -> None:
        self.process.stdin.write(line + "\n")
        self.process.stdin.flush()

    def receive(self) -> dict:
        try:
            line = self.replies.get(timeout=5)
        except Empty as error:
            raise AssertionError("No response within 5 seconds while stdin is open") from error
        assert line, "Provider closed stdout before responding"
        reply = json.loads(line)
        assert reply["jsonrpc"] == "2.0", reply
        return reply

    def request(self, method: str, **fields: object) -> dict:
        self.request_id += 1
        self.send({"id": self.request_id, "method": method, **fields})
        reply = self.receive()
        assert reply["id"] == self.request_id, reply
        return reply

    def discover(self) -> None:
        initialized = self.request("initialize", params={
            "protocolVersion": "2025-06-18",
            "capabilities": {},
            "clientInfo": {"name": "fake-codex-host", "version": "1.0"},
        })
        assert initialized["result"]["protocolVersion"] == "2025-06-18"
        assert {"tools", "resources"} <= initialized["result"]["capabilities"].keys()
        self.send({"method": "notifications/initialized"})
        listed = self.request("tools/list")
        (tool,) = listed["result"]["tools"]
        assert tool["name"] == "statusline"
        (entry,) = tool["_meta"]["openai/ui"]["entrypoints"]
        assert entry["type"] == "statusline"
        assert entry["resourceUri"].startswith("ui://")
        self.uri = entry["resourceUri"]

    def tree(self, reply: dict) -> dict:
        (resource,) = reply["result"]["contents"]
        assert resource["uri"] == self.uri
        assert resource["mimeType"] == "application/json"
        return json.loads(resource["text"])

    def read(self, state: dict) -> dict:
        return self.tree(self.request("resources/read", params={
            "uri": self.uri,
            "_meta": {STATE_META: state},
        }))


def snapshot(
    ctx: int | None = 42,
    five_hour: float | None = 18,
    weekly: float | None = 27,
) -> dict:
    context = {"used_tokens": 56000, "context_window_size": 100000}
    if ctx is not None:
        context["used_percentage"] = ctx
    return {
        "app": {"cli_version": "0.171.0", "display_mode": "standard"},
        "config": {"statusline_items": []},
        "thread": {
            "id": "synthetic-thread",
            "name": None,
            "agent": {"state": "ready"},
            "model": {"display_name": "Synthetic model", "provider": "openai"},
            "workspace": {"cwd": "/synthetic"},
            "usage": {"context": context},
        },
        "account": {
            "rate_limits": [{
                "limit_id": "codex",
                "limit_name": None,
                "primary_limit": None if five_hour is None else {
                    "used_percent": five_hour,
                    "window_minutes": 300,
                    "resets_at": None,
                },
                "secondary_limit": None if weekly is None else {
                    "used_percent": weekly,
                    "window_minutes": 10080,
                    "resets_at": None,
                },
            }],
        },
    }


class TestCodexStatuslineProvider(unittest.TestCase):
    def setUp(self) -> None:
        self.host = FakeCodexHost()
        self.addCleanup(self.host.close)
        self.host.discover()

    def assert_slots(
        self,
        tree: dict,
        labels: tuple[str, str, str],
        colors: tuple[str, str, str] = ("status-metadata",) * 3,
    ) -> None:
        self.assertEqual(tree["type"], "row")
        self.assertEqual(tree["props"]["gap"], 1)
        self.assertEqual(tree["props"]["wrap"], "wrap")
        self.assertEqual(len(tree["children"]), 5)
        self.assertEqual(tree["children"][1::2], ["|", "|"])
        for node, label, color in zip(tree["children"][::2], labels, colors, strict=True):
            self.assertEqual(node["type"], "text")
            for child in node["children"]:
                self.assertIsInstance(child, str)
                self.assertNotIn("\x1b", child)
            actual = "".join(node["children"])
            self.assertEqual(actual, label)
            self.assertEqual(node["props"]["color"], color, actual)

    def test_normal_snapshot_keeps_ctx_five_hour_weekly_order(self) -> None:
        """ctx・5h・週枠を使用率のまま固定順に表示するテスト。

        希望する結果: ctx 42% | 5h 18% | 週 27%、3枠とも通常色。
        実際の結果: resources/read から受け取った各枠の文字列と色を比較する。
        条件: tokens から算出した56%を使わず、受信した ctx 42%を使う。
        """
        actual = self.host.read(snapshot())
        self.assert_slots(actual, ("ctx 42%", "5h 18%", "週 27%"))

    def test_missing_values_keep_their_slots(self) -> None:
        """公式 snapshot の欠損で枠を消さないテスト。

        希望する結果: 欠損した枠だけ「–」となり、他の値と3枠の順序を保つ。
        実際の結果: 各欠損ケースへの応答を、表の期待文字列と通常色に照合する。
        条件: ctx の省略、null の使用枠、空の使用枠一覧を入力する。
        """
        empty_usage = snapshot()
        empty_usage["thread"]["usage"]["context"] = {}
        empty_usage["account"]["rate_limits"] = []
        for name, state, expected in (
            ("all missing", snapshot(None, None, None), ("ctx –", "5h –", "週 –")),
            ("empty usage", empty_usage, ("ctx –", "5h –", "週 –")),
            ("null windows", snapshot(42, None, None), ("ctx 42%", "5h –", "週 –")),
            ("missing ctx", snapshot(ctx=None), ("ctx –", "5h 18%", "週 27%")),
            ("missing 5h", snapshot(five_hour=None), ("ctx 42%", "5h –", "週 27%")),
            ("missing week", snapshot(weekly=None), ("ctx 42%", "5h 18%", "週 –")),
        ):
            with self.subTest(case=name):
                actual = self.host.read(state)
                self.assert_slots(actual, expected)

    def test_zero_is_a_known_usage(self) -> None:
        """使用率0と欠損を区別するテスト。

        希望する結果: 3枠とも「0%」と通常色で表示し、「–」に置き換えない。
        実際の結果: 0を送った read の文字列と色を比較する。
        """
        actual = self.host.read(snapshot(0, 0, 0))
        self.assert_slots(actual, ("ctx 0%", "5h 0%", "週 0%"))

    def test_open_session_replies_to_each_snapshot_without_stale_values(self) -> None:
        """EOF 前の逐次応答と、別スレッドへの表示更新を確認するテスト。

        希望する結果: 同じプロセスが要求ごとに応答し、以前の値や警告を残さない。
        実際の結果: stdin を開いたまま各応答を受けて、次の snapshot を送る。
        条件: 通常値→別スレッドの警告値→欠損。5秒は停止検出用の上限。
        """
        other_thread = snapshot(12, 80, 95)
        other_thread["thread"]["id"] = "other-synthetic-thread"
        for state, expected, colors in (
            (snapshot(), ("ctx 42%", "5h 18%", "週 27%"), ("status-metadata",) * 3),
            (other_thread, ("ctx 12%", "5h 80% !", "週 95% !!"),
             ("status-metadata", "yellow", "red")),
            (snapshot(None, None, None), ("ctx –", "5h –", "週 –"),
             ("status-metadata",) * 3),
        ):
            actual = self.host.read(state)
            self.assert_slots(actual, expected, colors)

    def test_context_warning_boundaries(self) -> None:
        """ctx の80%・95%境界で色と警告記号が変わるテスト。

        希望する結果: 79%まで通常、80%以上は黄と !、95%以上は赤と !!。
        実際の結果: 整数の ctx に対する文字列・色と、他の2枠の通常表示を比較する。
        """
        for value, expected, color in (
            (79, "ctx 79%", "status-metadata"),
            (80, "ctx 80% !", "yellow"),
            (94, "ctx 94% !", "yellow"),
            (95, "ctx 95% !!", "red"),
            (100, "ctx 100% !!", "red"),
        ):
            with self.subTest(ctx=value):
                actual = self.host.read(snapshot(ctx=value))
                self.assert_slots(actual, (expected, "5h 18%", "週 27%"),
                                  (color, "status-metadata", "status-metadata"))

    def test_rate_limit_warning_boundaries_and_fractional_usage(self) -> None:
        """使用枠の小数・警告境界・100%超過を表示するテスト。

        希望する結果: 小数を切り捨て、80%で黄と !、95%で赤と !!。125%も保持する。
        実際の結果: 5h・週枠の応答文字列と色を、表の期待値に照合する。
        """
        for value, five_hour, weekly, color in (
            (79.9, "5h 79%", "週 79%", "status-metadata"),
            (80, "5h 80% !", "週 80% !", "yellow"),
            (94.9, "5h 94% !", "週 94% !", "yellow"),
            (95, "5h 95% !!", "週 95% !!", "red"),
            (100, "5h 100% !!", "週 100% !!", "red"),
            (125, "5h 125% !!", "週 125% !!", "red"),
        ):
            with self.subTest(used_percent=value):
                actual = self.host.read(snapshot(42, value, value))
                self.assert_slots(actual, ("ctx 42%", five_hour, weekly),
                                  ("status-metadata", color, color))

    def test_windows_are_selected_by_duration_not_position(self) -> None:
        """primary と secondary が逆でも期間から枠を選ぶテスト。

        希望する結果: primary が週でも「5h 18% | 週 27%」の対応を保つ。
        実際の結果: 2枠を入れ替えた snapshot への応答を比較する。
        """
        state = snapshot()
        limit = state["account"]["rate_limits"][0]
        limit["primary_limit"], limit["secondary_limit"] = (
            limit["secondary_limit"], limit["primary_limit"]
        )
        actual = self.host.read(state)
        self.assert_slots(actual, ("ctx 42%", "5h 18%", "週 27%"))

    def test_other_limits_do_not_supply_codex_values(self) -> None:
        """別製品の使用枠を Codex の枠に混ぜないテスト。

        希望する結果: codex がなければ「–」、あれば codex の18%・27%を使う。
        実際の結果: 別製品だけの場合と、codex の前後に別製品がある場合を比較する。
        条件: 公式の配列型を使った合成入力。別製品が届く実機動作は未確認。
        """
        other = snapshot(42, 99, 98)["account"]["rate_limits"][0]
        other["limit_id"] = "other-product"
        for limits, expected in (
            ([other], ("ctx 42%", "5h –", "週 –")),
            ([other, *snapshot()["account"]["rate_limits"], other],
             ("ctx 42%", "5h 18%", "週 27%")),
        ):
            with self.subTest(limits=limits):
                state = snapshot()
                state["account"]["rate_limits"] = limits
                actual = self.host.read(state)
                self.assert_slots(actual, expected)

    def test_unknown_durations_do_not_guess_from_position(self) -> None:
        """不明な期間を5時間・週と推測しないテスト。

        希望する結果: 期間が null または1440分なら、5h・週をどちらも「–」にする。
        実際の結果: primary・secondary にその期間を入れた応答を比較する。
        """
        state = snapshot()
        limit = state["account"]["rate_limits"][0]
        limit["primary_limit"]["window_minutes"] = None
        limit["secondary_limit"]["window_minutes"] = 1440
        actual = self.host.read(state)
        self.assert_slots(actual, ("ctx 42%", "5h –", "週 –"))

    def test_missing_state_metadata_keeps_all_slots(self) -> None:
        """snapshot が渡されない読み取りでも3枠を残すテスト。

        希望する結果: ctx・5h・週をすべて「–」と通常色で返す。
        実際の結果: metadata の省略・空・空 snapshot に対する応答を比較する。
        """
        for fields in ({}, {"_meta": {}}, {"_meta": {STATE_META: {}}}):
            with self.subTest(fields=fields):
                reply = self.host.request("resources/read", params={"uri": self.host.uri, **fields})
                actual = self.host.tree(reply)
                self.assert_slots(actual, ("ctx –", "5h –", "週 –"))

    def test_resource_listing_and_tool_call_use_the_advertised_uri(self) -> None:
        """provider が広告した URI を resource と tool で共有するテスト。

        希望する結果: resource 一覧と tool 応答に同じ URI があり、MIME は application/json。
        実際の結果: 初期化済みセッションの各応答を、tools/list で取得した URI と比較する。
        """
        resources = self.host.request("resources/list")
        templates = self.host.request("resources/templates/list")
        tool = self.host.request("tools/call", params={"name": "statusline"})
        (resource,) = resources["result"]["resources"]
        self.assertEqual(resource["uri"], self.host.uri)
        self.assertEqual(resource["mimeType"], "application/json")
        self.assertEqual(templates["result"]["resourceTemplates"], [])
        (content,) = tool["result"]["content"]
        self.assertEqual(content["type"], "text")
        self.assertIn(self.host.uri, content["text"])

    def test_invalid_requests_return_mcp_errors_and_preserve_the_process(self) -> None:
        """不正要求を拒否し、同じセッションの次の要求へ応答するテスト。

        希望する結果: 未知の method は -32601、不正パラメータは -32602、その後の ping は成功。
        実際の結果: 各応答の error.code と、最後の ping の result を比較する。
        """
        for method, fields, expected in (
            ("unknown", {}, -32601),
            ("resources/read", {"params": {"uri": "ui://unknown"}}, -32602),
            ("tools/call", {"params": {"name": "unknown"}}, -32602),
            ("resources/read", {"params": None}, -32602),
            ("resources/read", {"params": {"uri": self.host.uri, "_meta": {STATE_META: []}}}, -32602),
        ):
            with self.subTest(method=method, fields=fields):
                actual = self.host.request(method, **fields)
                self.assertNotIn("result", actual)
                self.assertEqual(actual["error"]["code"], expected)
        actual = self.host.request("ping")
        self.assertEqual(actual["result"], {})

    def test_invalid_json_and_request_shape_have_protocol_errors(self) -> None:
        """JSON と request の構造が壊れていても後続要求へ応答するテスト。

        希望する結果: 不正 JSON は -32700、不正な request は -32600、その後の ping は成功。
        実際の結果: 生の各入力への error.code・id と、最後の ping の result を比較する。
        """
        for wire, expected in (
            ("not json", -32700),
            ("[]", -32600),
            ('{"jsonrpc":"2.0","method":42}', -32600),
        ):
            with self.subTest(wire=wire):
                self.host.send_wire(wire)
                actual = self.host.receive()
                self.assertIsNone(actual["id"])
                self.assertNotIn("result", actual)
                self.assertEqual(actual["error"]["code"], expected)
        actual = self.host.request("ping")
        self.assertEqual(actual["result"], {})

    def test_invalid_usage_is_rejected_without_ending_the_session(self) -> None:
        """数値でない使用率を欠損扱いにせず拒否するテスト。

        希望する結果: -32602 を返し、同じセッションの次の正常な read に応答する。
        実際の結果: 不正入力への error.code と、続く read の3枠を比較する。
        条件: 公式 snapshot の数値フィールドへ文字列を入れる。
        """
        state = snapshot()
        state["thread"]["usage"]["context"]["used_percentage"] = "42"
        actual = self.host.request("resources/read", params={
            "uri": self.host.uri, "_meta": {STATE_META: state},
        })
        self.assertNotIn("result", actual)
        self.assertEqual(actual["error"]["code"], -32602)
        self.assert_slots(self.host.read(snapshot()), ("ctx 42%", "5h 18%", "週 27%"))


class TestCodexStatuslineFailures(unittest.TestCase):
    def test_renderer_defects_are_not_reported_as_invalid_requests(self) -> None:
        """描画の内部例外を呼び出し側の入力エラーへ変換しないテスト。

        希望する結果: 正しい要求で発生した内部例外は伝播し、誤った MCP エラーを返さない。
        実際の結果: main から伝播する例外と stdout を比較する。
        条件: 公式サンプルの render 境界だけを故障する fake に置き換える。
        """
        spec = importlib.util.spec_from_file_location("statusline_provider", PROVIDER)
        assert spec is not None and spec.loader is not None
        provider = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(provider)
        wire = json.dumps({
            "jsonrpc": "2.0", "id": 1, "method": "resources/read",
            "params": {"uri": provider.URI, "_meta": {STATE_META: snapshot()}},
        }).encode() + b"\n"
        for failure in (KeyError("renderer defect"), TypeError("renderer defect")):
            with self.subTest(exception=type(failure).__name__):
                def broken_render(state: dict) -> dict:
                    raise failure

                with io.TextIOWrapper(io.BytesIO(wire)) as incoming, io.StringIO() as outgoing:
                    with (
                        patch.object(provider, "render", broken_render),
                        patch.object(sys, "stdin", incoming),
                        redirect_stdout(outgoing),
                    ):
                        with self.assertRaises(type(failure)) as raised:
                            provider.main()
                    self.assertIs(raised.exception, failure)
                    self.assertEqual(outgoing.getvalue(), "")


if __name__ == "__main__":
    unittest.main()
