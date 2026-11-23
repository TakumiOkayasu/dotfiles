"""Verify usage acquisition, display conversion, rendering, and the MCP stdio contract."""

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
spec = importlib.util.spec_from_file_location("statusline_provider", PROVIDER)
assert spec is not None and spec.loader is not None
provider = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = provider
spec.loader.exec_module(provider)


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


def assert_slots(
    test: unittest.TestCase,
    tree: dict,
    labels: tuple[str, str, str],
    colors: tuple[str, str, str] = ("status-metadata",) * 3,
) -> None:
    test.assertEqual(tree["type"], "row")
    test.assertEqual(tree["props"]["gap"], 1)
    test.assertEqual(tree["props"]["wrap"], "wrap")
    test.assertEqual(len(tree["children"]), 5)
    test.assertEqual(tree["children"][1::2], ["|", "|"])
    for node, label, color in zip(tree["children"][::2], labels, colors, strict=True):
        test.assertEqual(node["type"], "text")
        for child in node["children"]:
            test.assertIsInstance(child, str)
            test.assertNotIn("\x1b", child)
        actual = "".join(node["children"])
        test.assertEqual(actual, label)
        test.assertEqual(node["props"]["color"], color, actual)


class TestUsageReading(unittest.TestCase):
    def test_context_uses_received_percentage_without_recalculating_tokens(self) -> None:
        """ctx の取得が受信した使用率をそのまま返すテスト。

        希望する結果: tokens から算出した56%ではなく、受信した42を返す。
        実際の結果: ctx だけを含む snapshot に対する取得関数の戻り値を比較する。
        """
        state = {"thread": {"usage": {"context": {
            "used_tokens": 56000, "context_window_size": 100000, "used_percentage": 42,
        }}}}
        self.assertEqual(provider.read_context_percentage(state), 42)

    def test_windows_are_selected_by_duration_not_position(self) -> None:
        """primary と secondary が逆でも期間から使用率を取得するテスト。

        希望する結果: 300分は18、10080分は27として返す。
        実際の結果: 使用枠だけの snapshot に対する取得関数の戻り値を比較する。
        """
        state = {"account": {"rate_limits": [{
            "limit_id": "codex",
            "primary_limit": {"window_minutes": 10080, "used_percent": 27},
            "secondary_limit": {"window_minutes": 300, "used_percent": 18},
        }]}}
        self.assertEqual(provider.read_rate_percentages(state), {300: 18, 10080: 27})

    def test_other_limits_do_not_supply_codex_values(self) -> None:
        """別製品の使用枠を Codex の枠に混ぜないテスト。

        希望する結果: codex がなければ空、あれば codex の18・27を返す。
        実際の結果: 別製品だけの場合と、codex の前後に別製品がある場合を比較する。
        条件: 公式の配列型を使った合成入力。別製品が届く実機動作は未確認。
        """
        other = {"limit_id": "other-product", "primary_limit": {
            "window_minutes": 300, "used_percent": 99,
        }}
        codex = {"limit_id": "codex",
                 "primary_limit": {"window_minutes": 300, "used_percent": 18},
                 "secondary_limit": {"window_minutes": 10080, "used_percent": 27}}
        for limits, expected in (
            ([other], {}),
            ([other, codex, other], {300: 18, 10080: 27}),
        ):
            with self.subTest(limits=limits):
                actual = provider.read_rate_percentages({"account": {"rate_limits": limits}})
                self.assertEqual(actual, expected)

    def test_unknown_durations_do_not_guess_from_position(self) -> None:
        """不明な期間を5時間・週と推測しないテスト。

        希望する結果: 期間が null または1440分なら、対象の使用枠を返さない。
        実際の結果: 取得関数が空の結果を返すことを確認する。
        """
        state = {"account": {"rate_limits": [{
            "limit_id": "codex",
            "primary_limit": {"window_minutes": None, "used_percent": 18},
            "secondary_limit": {"window_minutes": 1440, "used_percent": 27},
        }]}}
        self.assertEqual(provider.read_rate_percentages(state), {})


class TestUsageDisplay(unittest.TestCase):
    def test_missing_and_zero_are_distinct(self) -> None:
        """欠損と取得済みの0を異なる表示値へ変換するテスト。

        希望する結果: None は「–」、0は「0%」。どちらも通常の警告段階。
        実際の結果: 変換関数の戻り値を、手で構築した表示契約と比較する。
        """
        for value, text in ((None, "–"), (0, "0%")):
            with self.subTest(value=value):
                self.assertEqual(provider.to_usage_display(value),
                                 provider.UsageDisplay(text, "normal"))

    def test_warning_boundaries_fractional_usage_and_over_limit(self) -> None:
        """使用率の小数・警告境界・100%超過を表示契約へ変換するテスト。

        希望する結果: 小数を切り捨て、80でwarning、95でdanger。125%も保持する。
        実際の結果: 各数値から得た表示文字列と警告段階を、表の期待値と比較する。
        """
        for value, text, severity in (
            (79, "79%", "normal"),
            (79.9, "79%", "normal"),
            (80, "80%", "warning"),
            (94, "94%", "warning"),
            (94.9, "94%", "warning"),
            (95, "95%", "danger"),
            (100, "100%", "danger"),
            (125, "125%", "danger"),
        ):
            with self.subTest(value=value):
                self.assertEqual(provider.to_usage_display(value),
                                 provider.UsageDisplay(text, severity))


class TestStatuslineRendering(unittest.TestCase):
    def test_builds_the_display_contract_from_context_and_rate_limits(self) -> None:
        """二つの取得経路から自前の表示契約を組み立てるテスト。

        希望する結果: ctx・5h・week の各値が通常・警告・危険の段階とともに対応する。
        実際の結果: snapshot の変換結果を、3枠を持つ表示契約と比較する。
        """
        actual = provider.build_statusline(snapshot(42, 80, 95))
        self.assertEqual(actual, provider.StatuslineDisplay(
            context=provider.UsageDisplay("42%", "normal"),
            five_hour=provider.UsageDisplay("80%", "warning"),
            week=provider.UsageDisplay("95%", "danger"),
        ))

    def test_missing_values_keep_their_contract_slots(self) -> None:
        """公式 snapshot の欠損でも表示契約の3枠を保つテスト。

        希望する結果: 欠損した枠だけ「–」とし、取得できた0や他の値を残す。
        実際の結果: 各 snapshot の変換結果を、表から構築した表示契約と比較する。
        条件: ctx の省略、null の使用枠、空の使用枠一覧を入力する。
        """
        empty_usage = snapshot()
        empty_usage["thread"]["usage"]["context"] = {}
        empty_usage["account"]["rate_limits"] = []
        for name, state, expected in (
            ("all missing", snapshot(None, None, None), ("–", "–", "–")),
            ("empty usage", empty_usage, ("–", "–", "–")),
            ("null windows", snapshot(42, None, None), ("42%", "–", "–")),
            ("missing ctx", snapshot(ctx=None), ("–", "18%", "27%")),
            ("missing 5h", snapshot(five_hour=None), ("42%", "–", "27%")),
            ("missing week", snapshot(weekly=None), ("42%", "18%", "–")),
            ("known zero", snapshot(0, 0, 0), ("0%", "0%", "0%")),
        ):
            with self.subTest(case=name):
                actual = provider.build_statusline(state)
                self.assertEqual(actual, provider.StatuslineDisplay(
                    *(provider.UsageDisplay(text, "normal") for text in expected)
                ))

    def test_renderer_uses_only_display_text_and_severity(self) -> None:
        """自前の表示契約だけで固定ラベル・順序・色・記号を描画するテスト。

        希望する結果: ctx・5h・week の順で文字列を保ち、warning は黄と !、danger は赤と !!。
        実際の結果: snapshot を渡さずに得た UI tree の文字列・色・区切りを比較する。
        条件: 任意の表示文字列を渡し、描画側が数値の解釈や警告の再判定をしないことを確認する。
        """
        display = provider.StatuslineDisplay(
            context=provider.UsageDisplay("context text", "normal"),
            five_hour=provider.UsageDisplay("short window", "warning"),
            week=provider.UsageDisplay("long window", "danger"),
        )
        actual = provider.render(display)
        assert_slots(self, actual, ("ctx context text", "5h short window !", "week long window !!"),
                     ("status-metadata", "yellow", "red"))


class TestCodexStatuslineProvider(unittest.TestCase):
    def setUp(self) -> None:
        self.host = FakeCodexHost()
        self.addCleanup(self.host.close)
        self.host.discover()

    def test_normal_snapshot_keeps_ctx_five_hour_weekly_order(self) -> None:
        """ctx・5h・週枠を使用率のまま固定順に表示するテスト。

        希望する結果: ctx 42% | 5h 18% | week 27%、3枠とも通常色。
        実際の結果: resources/read から受け取った各枠の文字列と色を比較する。
        条件: tokens から算出した56%を使わず、受信した ctx 42%を使う。
        """
        actual = self.host.read(snapshot())
        assert_slots(self, actual, ("ctx 42%", "5h 18%", "week 27%"))

    def test_open_session_replies_to_each_snapshot_without_stale_values(self) -> None:
        """EOF 前の逐次応答と、別スレッドへの表示更新を確認するテスト。

        希望する結果: 同じプロセスが要求ごとに応答し、以前の値や警告を残さない。
        実際の結果: stdin を開いたまま各応答を受けて、次の snapshot を送る。
        条件: 通常値→別スレッドの警告値→0→欠損。5秒は停止検出用の上限。
        """
        other_thread = snapshot(95, 80, 95)
        other_thread["thread"]["id"] = "other-synthetic-thread"
        for state, expected, colors in (
            (snapshot(), ("ctx 42%", "5h 18%", "week 27%"), ("status-metadata",) * 3),
            (other_thread, ("ctx 95% !!", "5h 80% !", "week 95% !!"),
             ("red", "yellow", "red")),
            (snapshot(0, 0, 0), ("ctx 0%", "5h 0%", "week 0%"),
             ("status-metadata",) * 3),
            (snapshot(None, None, None), ("ctx –", "5h –", "week –"),
             ("status-metadata",) * 3),
        ):
            actual = self.host.read(state)
            assert_slots(self, actual, expected, colors)

    def test_missing_state_metadata_keeps_all_slots(self) -> None:
        """snapshot が渡されない読み取りでも3枠を残すテスト。

        希望する結果: ctx・5h・週をすべて「–」と通常色で返す。
        実際の結果: metadata の省略・空・空 snapshot に対する応答を比較する。
        """
        for fields in ({}, {"_meta": {}}, {"_meta": {STATE_META: {}}}):
            with self.subTest(fields=fields):
                reply = self.host.request("resources/read", params={"uri": self.host.uri, **fields})
                actual = self.host.tree(reply)
                assert_slots(self, actual, ("ctx –", "5h –", "week –"))

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
        条件: ctx・5h・週の使用率へ文字列と bool を入れる。bool を0%・1%として受理しない。
        """
        for value in ("42", False, True):
            context = snapshot()
            five_hour = snapshot()
            weekly = snapshot()
            context["thread"]["usage"]["context"]["used_percentage"] = value
            five_hour["account"]["rate_limits"][0]["primary_limit"]["used_percent"] = value
            weekly["account"]["rate_limits"][0]["secondary_limit"]["used_percent"] = value
            for slot, state in (("ctx", context), ("5h", five_hour), ("week", weekly)):
                with self.subTest(slot=slot, value=value):
                    actual = self.host.request("resources/read", params={
                        "uri": self.host.uri, "_meta": {STATE_META: state},
                    })
                    self.assertNotIn("result", actual)
                    self.assertEqual(actual["error"]["code"], -32602)
                    assert_slots(self, self.host.read(snapshot()), ("ctx 42%", "5h 18%", "week 27%"))



class TestCodexStatuslineFailures(unittest.TestCase):
    def test_renderer_defects_are_not_reported_as_invalid_requests(self) -> None:
        """描画の内部例外を呼び出し側の入力エラーへ変換しないテスト。

        希望する結果: 正しい要求で発生した内部例外は伝播し、誤った MCP エラーを返さない。
        実際の結果: main から伝播する例外と stdout を比較する。
        条件: 自前の表示契約を受け取る render だけを故障する fake に置き換える。
        """
        wire = json.dumps({
            "jsonrpc": "2.0", "id": 1, "method": "resources/read",
            "params": {"uri": provider.URI, "_meta": {STATE_META: snapshot()}},
        }).encode() + b"\n"
        for failure in (
            KeyError("renderer defect"),
            TypeError("renderer defect"),
            ValueError("renderer defect"),
            AttributeError("renderer defect"),
            json.JSONDecodeError("renderer defect", "", 0),
        ):
            with self.subTest(exception=type(failure).__name__):
                def broken_render(display: provider.StatuslineDisplay) -> dict:
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
