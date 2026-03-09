#!/usr/bin/env python3
"""ghostty-migrate テスト"""

import importlib.machinery
import importlib.util
import json
import plistlib
import subprocess
import sys
import unittest
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent.parent
SCRIPT_PATH = SCRIPT_DIR / "bin" / "ghostty-migrate"

# スクリプトをモジュールとして読み込み (拡張子なしのため loader を明示指定)
_loader = importlib.machinery.SourceFileLoader("ghostty_migrate", str(SCRIPT_PATH))
_spec = importlib.util.spec_from_file_location(
    "ghostty_migrate", SCRIPT_PATH, loader=_loader
)
assert _spec is not None, f"Failed to create spec for {SCRIPT_PATH}"
_mod = importlib.util.module_from_spec(_spec)
sys.modules["ghostty_migrate"] = _mod
assert _spec.loader is not None, "spec.loader is None"
_spec.loader.exec_module(_mod)
gm = _mod


# --- テストフィクスチャ ---


def _make_ns_color(r, g, b):
    """NSColor NSKeyedArchiver データを生成"""
    return plistlib.dumps(
        {
            "$archiver": "NSKeyedArchiver",
            "$version": 100000,
            "$top": {"root": plistlib.UID(1)},
            "$objects": [
                "$null",
                {
                    "$class": plistlib.UID(2),
                    "NSRGB": f"{r} {g} {b}".encode("ascii"),
                    "NSColorSpace": 1,
                },
                {"$classname": "NSColor", "$classes": ["NSColor", "NSObject"]},
            ],
        },
        fmt=plistlib.FMT_BINARY,
    )


def _make_ns_font(name, size):
    """NSFont NSKeyedArchiver データを生成"""
    return plistlib.dumps(
        {
            "$archiver": "NSKeyedArchiver",
            "$version": 100000,
            "$top": {"root": plistlib.UID(1)},
            "$objects": [
                "$null",
                {
                    "$class": plistlib.UID(3),
                    "NSName": plistlib.UID(2),
                    "NSSize": float(size),
                    "NSfFlags": 16,
                },
                name,
                {"$classname": "NSFont", "$classes": ["NSFont", "NSObject"]},
            ],
        },
        fmt=plistlib.FMT_BINARY,
    )


def _make_test_plist():
    """テスト用 plist を生成"""
    return {
        "Default Window Settings": "TestProfile",
        "Window Settings": {
            "TestProfile": {
                "Font": _make_ns_font("SFMono-Regular", 14.0),
                "BackgroundColor": _make_ns_color(0.0, 0.0, 0.0),
                "TextColor": _make_ns_color(1.0, 1.0, 1.0),
                "CursorType": 2,
                "CursorBlink": True,
                "SelectionColor": _make_ns_color(0.2, 0.4, 0.6),
                "ANSIBlackColor": _make_ns_color(0.0, 0.0, 0.0),
                "ANSIRedColor": _make_ns_color(1.0, 0.0, 0.0),
                "ANSIGreenColor": _make_ns_color(0.0, 1.0, 0.0),
            },
            "OtherProfile": {
                "Font": _make_ns_font("Menlo-Regular", 12.0),
            },
        },
    }


# --- NSKeyedArchiver パーサーテスト ---


class TestParseNsColor(unittest.TestCase):
    def test_black(self):
        self.assertEqual(gm.parse_ns_color(_make_ns_color(0.0, 0.0, 0.0)), (0.0, 0.0, 0.0))

    def test_white(self):
        self.assertEqual(gm.parse_ns_color(_make_ns_color(1.0, 1.0, 1.0)), (1.0, 1.0, 1.0))

    def test_rgb(self):
        self.assertEqual(gm.parse_ns_color(_make_ns_color(0.2, 0.4, 0.6)), (0.2, 0.4, 0.6))

    def test_rgba_ignores_alpha(self):
        """NSRGB に4値 (RGBA) が含まれる場合、アルファを無視する"""
        archive = {
            "$archiver": "NSKeyedArchiver",
            "$version": 100000,
            "$top": {"root": plistlib.UID(1)},
            "$objects": [
                "$null",
                {
                    "$class": plistlib.UID(2),
                    "NSRGB": b"0.5 0.5 0.5 1",
                    "NSColorSpace": 1,
                },
                {"$classname": "NSColor", "$classes": ["NSColor", "NSObject"]},
            ],
        }
        data = plistlib.dumps(archive, fmt=plistlib.FMT_BINARY)
        self.assertEqual(gm.parse_ns_color(data), (0.5, 0.5, 0.5))

    def test_invalid_data(self):
        self.assertIsNone(gm.parse_ns_color(b"invalid"))

    def test_empty_data(self):
        self.assertIsNone(gm.parse_ns_color(b""))


class TestParseNsFont(unittest.TestCase):
    def test_sfmono(self):
        self.assertEqual(
            gm.parse_ns_font(_make_ns_font("SFMono-Regular", 14.0)),
            ("SFMono-Regular", 14.0),
        )

    def test_menlo(self):
        self.assertEqual(
            gm.parse_ns_font(_make_ns_font("Menlo-Regular", 12.0)),
            ("Menlo-Regular", 12.0),
        )

    def test_invalid_data(self):
        self.assertIsNone(gm.parse_ns_font(b"invalid"))

    def test_empty_data(self):
        self.assertIsNone(gm.parse_ns_font(b""))


# --- 変換ユーティリティテスト ---


class TestRgbToHex(unittest.TestCase):
    def test_black(self):
        self.assertEqual(gm.rgb_to_hex(0, 0, 0), "#000000")

    def test_white(self):
        self.assertEqual(gm.rgb_to_hex(1, 1, 1), "#ffffff")

    def test_red(self):
        self.assertEqual(gm.rgb_to_hex(1, 0, 0), "#ff0000")

    def test_gray(self):
        self.assertEqual(gm.rgb_to_hex(0.5, 0.5, 0.5), "#808080")

    def test_mixed(self):
        self.assertEqual(gm.rgb_to_hex(0.2, 0.4, 0.6), "#336699")


class TestPsToFamily(unittest.TestCase):
    def test_sfmono(self):
        self.assertEqual(gm.ps_to_family("SFMono-Regular"), "SF Mono")

    def test_sfmono_terminal(self):
        self.assertEqual(gm.ps_to_family("SFMonoTerminal-Bold"), "SF Mono")

    def test_menlo(self):
        self.assertEqual(gm.ps_to_family("Menlo-Regular"), "Menlo")

    def test_monaco(self):
        self.assertEqual(gm.ps_to_family("Monaco"), "Monaco")

    def test_firacode(self):
        self.assertEqual(gm.ps_to_family("FiraCode-Retina"), "Fira Code")


# --- プロファイル・色取得テスト ---


class TestGetColorHex(unittest.TestCase):
    def setUp(self):
        self.profile = _make_test_plist()["Window Settings"]["TestProfile"]

    def test_background(self):
        self.assertEqual(gm.get_color_hex(self.profile, "BackgroundColor"), "#000000")

    def test_foreground(self):
        self.assertEqual(gm.get_color_hex(self.profile, "TextColor"), "#ffffff")

    def test_selection(self):
        self.assertEqual(gm.get_color_hex(self.profile, "SelectionColor"), "#336699")

    def test_missing_key(self):
        self.assertIsNone(gm.get_color_hex(self.profile, "NonExistentColor"))

    def test_non_bytes_value(self):
        self.assertIsNone(gm.get_color_hex({"Foo": "string_value"}, "Foo"))


class TestProfileAccess(unittest.TestCase):
    def setUp(self):
        self.plist = _make_test_plist()

    def test_default_profile_name(self):
        self.assertEqual(self.plist.get("Default Window Settings"), "TestProfile")

    def test_other_profile_font(self):
        other = self.plist["Window Settings"]["OtherProfile"]
        self.assertEqual(gm.parse_ns_font(other["Font"]), ("Menlo-Regular", 12.0))

    def test_missing_profile(self):
        self.assertIsNone(self.plist["Window Settings"].get("NoSuchProfile"))


# --- 出力生成テスト ---


class TestGenerateGhostty(unittest.TestCase):
    def setUp(self):
        self.profile = _make_test_plist()["Window Settings"]["TestProfile"]
        self.output = gm.generate_ghostty(self.profile, "TestProfile")

    def test_header(self):
        self.assertIn("migrated from Terminal.app profile: TestProfile", self.output)

    def test_font(self):
        self.assertIn("font-family = SF Mono", self.output)
        self.assertIn("font-size = 14", self.output)

    def test_colors(self):
        self.assertIn("background = #000000", self.output)
        self.assertIn("foreground = #ffffff", self.output)

    def test_cursor(self):
        self.assertIn("cursor-style = bar", self.output)
        self.assertIn("cursor-style-blink = true", self.output)

    def test_selection(self):
        self.assertIn("selection-background = #336699", self.output)

    def test_palette(self):
        self.assertIn("palette = 0=#000000", self.output)
        self.assertIn("palette = 1=#ff0000", self.output)
        self.assertIn("palette = 2=#00ff00", self.output)


class TestGenerateVscode(unittest.TestCase):
    def setUp(self):
        self.profile = _make_test_plist()["Window Settings"]["TestProfile"]
        self.output = gm.generate_vscode(self.profile, "TestProfile")

    def test_valid_json(self):
        json_lines = [line for line in self.output.split("\n") if not line.startswith("//")]
        config = json.loads("\n".join(json_lines))
        self.assertIsInstance(config, dict)

    def test_font(self):
        self.assertIn('"terminal.integrated.fontFamily": "SF Mono"', self.output)
        self.assertIn('"terminal.integrated.fontSize": 14', self.output)

    def test_cursor_bar_to_line(self):
        self.assertIn('"terminal.integrated.cursorStyle": "line"', self.output)

    def test_color_customizations(self):
        json_lines = [line for line in self.output.split("\n") if not line.startswith("//")]
        config = json.loads("\n".join(json_lines))
        colors = config.get("workbench.colorCustomizations", {})
        self.assertEqual(colors.get("terminal.background"), "#000000")
        self.assertEqual(colors.get("terminal.foreground"), "#ffffff")
        self.assertEqual(colors.get("terminal.ansiBlack"), "#000000")
        self.assertEqual(colors.get("terminal.ansiRed"), "#ff0000")


# --- エッジケーステスト ---


class TestCursorMapFallback(unittest.TestCase):
    def test_unknown_cursor_type(self):
        output = gm.generate_ghostty({"CursorType": 99}, "test")
        self.assertIn("cursor-style = block", output)

    def test_missing_cursor_type(self):
        output = gm.generate_ghostty({}, "test")
        self.assertIn("cursor-style = block", output)


class TestEmptyProfile(unittest.TestCase):
    def test_ghostty_minimal(self):
        output = gm.generate_ghostty({}, "Empty")
        self.assertIn("cursor-style = block", output)
        self.assertNotIn("font-family", output)
        self.assertNotIn("background", output)

    def test_vscode_minimal(self):
        output = gm.generate_vscode({}, "Empty")
        json_lines = [line for line in output.split("\n") if not line.startswith("//")]
        config = json.loads("\n".join(json_lines))
        self.assertIn("terminal.integrated.cursorStyle", config)
        self.assertNotIn("workbench.colorCustomizations", config)

    def test_vscode_no_cursor_blinking_when_false(self):
        output = gm.generate_vscode({"CursorBlink": False}, "test")
        json_lines = [line for line in output.split("\n") if not line.startswith("//")]
        config = json.loads("\n".join(json_lines))
        self.assertNotIn("terminal.integrated.cursorBlinking", config)


# --- CLI テスト ---


class TestCli(unittest.TestCase):
    def test_help_contains_usage(self):
        result = subprocess.run(
            [sys.executable, str(SCRIPT_PATH), "--help"],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0)
        self.assertIn("使い方", result.stdout)

    def test_help_contains_vscode(self):
        result = subprocess.run(
            [sys.executable, str(SCRIPT_PATH), "--help"],
            capture_output=True,
            text=True,
        )
        self.assertIn("--vscode", result.stdout)

    def test_unknown_option(self):
        result = subprocess.run(
            [sys.executable, str(SCRIPT_PATH), "--unknown"],
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
