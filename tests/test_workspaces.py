#!/usr/bin/env python3
import importlib.util
import json
import os
import unittest
from importlib.machinery import SourceFileLoader

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CTL = os.path.join(ROOT, "scripts", "display-ctl")


def load_ctl():
    loader = SourceFileLoader("display_ctl", CTL)
    spec = importlib.util.spec_from_loader(loader.name, loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


class SplitCounts(unittest.TestCase):
    def setUp(self):
        self.ctl = load_ctl()

    def test_two_monitors_are_five_and_five(self):
        self.assertEqual(self.ctl.split_counts(2), [5, 5])

    def test_three_monitors_give_extra_to_the_first(self):
        self.assertEqual(self.ctl.split_counts(3), [4, 3, 3])
        self.assertEqual(sum(self.ctl.split_counts(3)), 10)

    def test_nine_monitors_one_gets_two(self):
        self.assertEqual(self.ctl.split_counts(9), [2, 1, 1, 1, 1, 1, 1, 1, 1])
        self.assertEqual(sum(self.ctl.split_counts(9)), 10)

    def test_ten_and_more(self):
        self.assertEqual(self.ctl.split_counts(10), [1] * 10)
        self.assertEqual(self.ctl.split_counts(11), [1] * 10 + [0])

    def test_one_monitor_keeps_all_ten(self):
        self.assertEqual(self.ctl.split_counts(1), [10])

    def test_empty(self):
        self.assertEqual(self.ctl.split_counts(0), [])


class WorkspacePlan(unittest.TestCase):
    def setUp(self):
        self.ctl = load_ctl()
        self.left = {
            "name": "DP-4",
            "description": "HYC CO. LTD. DUAL-DVI",
            "label": "HYC",
            "enabled": True,
            "x": 0,
            "y": 226,
            "identity": "desc:HYC CO. LTD. DUAL-DVI",
            "mirror": "",
        }
        self.right = {
            "name": "HDMI-A-1",
            "description": "LG Electronics LG TV SSCR2 0x01010101",
            "label": "LG TV",
            "enabled": True,
            "x": 2560,
            "y": 0,
            "identity": "desc:LG Electronics LG TV SSCR2 0x01010101",
            "mirror": "",
        }

    def test_primary_gets_first_half(self):
        plan = self.ctl.workspace_plan([self.left, self.right], self.right["identity"])
        self.assertEqual(plan[0]["name"], "HDMI-A-1")
        self.assertEqual(plan[0]["ids"], [1, 2, 3, 4, 5])
        self.assertEqual(plan[1]["name"], "DP-4")
        self.assertEqual(plan[1]["ids"], [6, 7, 8, 9, 10])

    def test_mirrors_are_skipped(self):
        mirror = dict(self.left, name="DP-5", identity="desc:mirror", mirror="HDMI-A-1")
        plan = self.ctl.workspace_plan([self.left, self.right, mirror], self.right["identity"])
        self.assertEqual(len(plan), 2)
        self.assertEqual(sum(len(p["ids"]) for p in plan), 10)

    def test_disabled_are_skipped(self):
        off = dict(self.left, enabled=False)
        plan = self.ctl.workspace_plan([off, self.right], self.right["identity"])
        self.assertEqual(len(plan), 1)
        self.assertEqual(plan[0]["ids"], list(range(1, 11)))

    def test_workspace_rules_bind_and_mark_default(self):
        lines = self.ctl.workspace_rule_lines(
            [self.left, self.right], self.right["identity"]
        )
        self.assertTrue(any('workspace = "1"' in line and "default = true" in line for line in lines))
        self.assertTrue(any('workspace = "6"' in line and "default = true" in line for line in lines))
        self.assertTrue(any('workspace = "10"' in line and "persistent = true" in line for line in lines))
        self.assertFalse(any('workspace = "2"' in line and "default = true" in line for line in lines))
        joined = "\n".join(lines)
        self.assertIn("desc:LG Electronics LG TV SSCR2 0x01010101", joined)
        self.assertIn("desc:HYC CO. LTD. DUAL-DVI", joined)


class LayoutNames(unittest.TestCase):
    def setUp(self):
        self.ctl = load_ctl()

    def test_aliases(self):
        self.assertEqual(self.ctl.clean_workspace_layout("dwindle"), "tile")
        self.assertEqual(self.ctl.clean_workspace_layout("scrolling"), "scroll")
        self.assertEqual(self.ctl.clean_workspace_layout("floating"), "float")
        self.assertEqual(self.ctl.clean_workspace_layout("nope"), "")


class LeftoverMonitorsLua(unittest.TestCase):
    def setUp(self):
        self.ctl = load_ctl()

    def test_stock_header_plus_managed_block_is_leftover(self):
        text = """local omarchy_gdk_scale = 4
local omarchy_monitor_scale = 4
hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- BEGIN im0001gt.screens
hl.monitor({ output = "eDP-1", mode = "1920x1200@60", position = "0x0", scale = 1.0, vrr = 0 })
-- END im0001gt.screens
"""
        self.assertTrue(self.ctl.leftover_outside_managed(text))

    def test_screens_owned_file_is_clean(self):
        text = """-- Managed by im0001gt.screens (Screens bar panel).

local omarchy_gdk_scale = 2
hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))

-- BEGIN im0001gt.screens
hl.monitor({ output = "eDP-1", mode = "1920x1200@60", position = "0x0", scale = 1.0, vrr = 0 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
-- END im0001gt.screens
"""
        self.assertFalse(self.ctl.leftover_outside_managed(text))

    def test_hyprmoncfg_comment_counts(self):
        text = "-- written by hyprmoncfg\nhl.monitor({ output = \"DP-1\" })\n"
        self.assertTrue(self.ctl.leftover_outside_managed(text))


class FreshWrite(unittest.TestCase):
    def setUp(self):
        import tempfile
        self.ctl = load_ctl()
        self.tmp = tempfile.mkdtemp()
        self.ctl.MONITORS_LUA = os.path.join(self.tmp, "monitors.lua")
        self.ctl.BACKUP_DIR = os.path.join(self.tmp, "state")
        self.ctl.ORIGINAL_BACKUP = os.path.join(self.ctl.BACKUP_DIR, "original-monitors.lua")
        leftover = """local omarchy_gdk_scale = 4
local omarchy_monitor_scale = 4
hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- BEGIN im0001gt.screens
hl.monitor({ output = "eDP-1", mode = "1920x1200@60", position = "0x0", scale = 1.0, vrr = 0 })
-- END im0001gt.screens
"""
        os.makedirs(os.path.dirname(self.ctl.MONITORS_LUA), exist_ok=True)
        with open(self.ctl.MONITORS_LUA, "w", encoding="utf-8") as fh:
            fh.write(leftover)

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_write_replaces_leftover_and_backs_up(self):
        monitors = [{
            "name": "eDP-1",
            "mode": "1920x1200@59.95",
            "x": 0,
            "y": 0,
            "scale": 1.0,
            "enabled": True,
            "vrr": 0,
        }]
        text = self.ctl.write_monitors_lua(monitors)
        self.assertNotIn("omarchy_monitor_scale", text)
        self.assertIn("BEGIN im0001gt.screens", text)
        self.assertIn("eDP-1", text)
        self.assertTrue(os.path.isfile(self.ctl.ORIGINAL_BACKUP))
        with open(self.ctl.ORIGINAL_BACKUP, encoding="utf-8") as fh:
            original = fh.read()
        self.assertIn("omarchy_monitor_scale", original)


class StockBackups(unittest.TestCase):
    def setUp(self):
        import tempfile
        self.ctl = load_ctl()
        self.tmp = tempfile.mkdtemp()
        self.ctl.BACKUP_DIR = os.path.join(self.tmp, "state")
        self.ctl.ORIGINAL_BACKUP = os.path.join(self.ctl.BACKUP_DIR, "original-monitors.lua")
        self.ctl.MONITORS_LUA = os.path.join(self.tmp, "hypr", "monitors.lua")
        self.ctl.BINDINGS_LUA = os.path.join(self.tmp, "hypr", "bindings.lua")
        self.ctl.SHELL_JSON = os.path.join(self.tmp, "omarchy", "shell.json")
        self.ctl.LAYOUTS_DIR = os.path.join(self.tmp, "layouts")
        self.ctl.BRIGHTNESS_LINK = os.path.join(self.tmp, "bin", "omarchy-brightness-display")
        self.ctl.PLUGIN_DIR = os.path.join(self.tmp, "plugins", "im0001gt.screens")
        os.makedirs(self.ctl.PLUGIN_DIR, exist_ok=True)
        os.makedirs(os.path.join(self.tmp, "hypr"), exist_ok=True)
        os.makedirs(os.path.join(self.tmp, "omarchy"), exist_ok=True)
        os.makedirs(os.path.join(self.tmp, "layouts"), exist_ok=True)
        os.makedirs(os.path.join(self.tmp, "bin"), exist_ok=True)
        with open(self.ctl.MONITORS_LUA, "w", encoding="utf-8") as fh:
            fh.write('hl.monitor({ output = "eDP-1" })\n')
        with open(self.ctl.BINDINGS_LUA, "w", encoding="utf-8") as fh:
            fh.write('-- personal binds\no.bind("SUPER + B", "Browser")\n')
        with open(self.ctl.SHELL_JSON, "w", encoding="utf-8") as fh:
            fh.write('{"bar":{"layout":{"left":[{"id":"omarchy.workspaces"}]}}}\n')

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_backup_then_restore_stock_files(self):
        self.ctl.ensure_stock_backups()
        orig = self.ctl.originals_dir()
        self.assertTrue(os.path.isfile(os.path.join(orig, "monitors.lua")))
        self.assertTrue(os.path.isfile(os.path.join(orig, "bindings.lua")))
        self.assertTrue(os.path.isfile(os.path.join(orig, "shell.json")))
        self.assertTrue(os.path.isfile(self.ctl.restore_helper_path()))
        with open(self.ctl.BINDINGS_LUA, "w", encoding="utf-8") as fh:
            fh.write("-- BEGIN im0001gt.screens\no.bind(\"SUPER + SLASH\", \"x\")\n-- END im0001gt.screens\n")
        with open(self.ctl.MONITORS_LUA, "w", encoding="utf-8") as fh:
            fh.write("-- Managed by screens\n")
        with open(self.ctl.SHELL_JSON, "w", encoding="utf-8") as fh:
            fh.write('{"bar":{"layout":{"left":[{"id":"im0001gt.screens.workspaces"}]}}}\n')
        rc = self.ctl.restore_original()
        self.assertEqual(rc, 0)
        with open(self.ctl.MONITORS_LUA, encoding="utf-8") as fh:
            self.assertIn("eDP-1", fh.read())
        with open(self.ctl.BINDINGS_LUA, encoding="utf-8") as fh:
            bindings = fh.read()
        self.assertIn("SUPER + B", bindings)
        self.assertNotIn("BEGIN im0001gt.screens", bindings)
        with open(self.ctl.SHELL_JSON, encoding="utf-8") as fh:
            self.assertIn("omarchy.workspaces", fh.read())
        live_companion = os.path.join(
            os.path.expanduser("~"),
            ".config/omarchy/plugins/im0001gt.screens.workspaces",
        )
        self.assertNotEqual(self.ctl.workspaces_plugin_dir(), live_companion)

    def test_bindings_backup_strips_managed_block(self):
        with open(self.ctl.BINDINGS_LUA, "w", encoding="utf-8") as fh:
            fh.write("-- keep\n-- BEGIN im0001gt.screens\nBAD\n-- END im0001gt.screens\n")
        self.ctl.ensure_stock_backups()
        with open(os.path.join(self.ctl.originals_dir(), "bindings.lua"), encoding="utf-8") as fh:
            text = fh.read()
        self.assertIn("keep", text)
        self.assertNotIn("BAD", text)


class ScaleSteps(unittest.TestCase):
    def setUp(self):
        self.ctl = load_ctl()

    def test_up_from_one(self):
        self.assertEqual(self.ctl.next_scale_preset(1, 1920, 1200, "up"), 1.25)

    def test_down_from_one_stays(self):
        self.assertEqual(self.ctl.next_scale_preset(1, 1920, 1200, "down"), 1)

    def test_bindings_rebind_slash(self):
        block = self.ctl.scale_bindings_block()
        self.assertIn('hl.unbind("SUPER + SLASH")', block)
        self.assertIn('hl.unbind("SUPER + ALT + SLASH")', block)
        self.assertIn("scale up", block)
        self.assertIn("scale down", block)


class ScaleKeyConflicts(unittest.TestCase):
    def setUp(self):
        self.ctl = load_ctl()

    def test_stock_display_bind_is_not_a_conflict(self):
        text = 'o.bind("SUPER + SLASH", "Monitor scaling up", "omarchy-hyprland-monitor-scaling up")\n'
        hit = self.ctl.combo_conflict("SUPER + SLASH", text, live=[])
        self.assertIsNone(hit)

    def test_custom_bind_is_a_conflict(self):
        text = 'hl.unbind("SUPER + SLASH")\no.bind("SUPER + SLASH", "SSH", "alacritty -e ssh host")\n'
        hit = self.ctl.combo_conflict("SUPER + SLASH", text, live=[])
        self.assertIsNotNone(hit)
        self.assertEqual(hit["label"], "SSH")

    def test_managed_block_is_ignored(self):
        text = (
            'o.bind("SUPER + SLASH", "SSH", "alacritty -e ssh host")\n'
            "-- BEGIN im0001gt.screens\n"
            'hl.unbind("SUPER + SLASH")\n'
            'o.bind("SUPER + SLASH", "Monitor scaling up", "display-ctl scale up")\n'
            "-- END im0001gt.screens\n"
        )
        hit = self.ctl.combo_conflict("SUPER + SLASH", text, live=[])
        self.assertIsNotNone(hit)
        self.assertEqual(hit["label"], "SSH")

    def test_live_custom_description_conflicts(self):
        live = [{
            "modmask": 64,
            "key": "SLASH",
            "description": "Browser",
        }]
        hit = self.ctl.combo_conflict("SUPER + SLASH", "", live=live)
        self.assertIsNotNone(hit)
        self.assertEqual(hit["label"], "Browser")

    def test_alternate_block_uses_requested_keys(self):
        block = self.ctl.scale_bindings_block("SUPER + CTRL + SLASH", "SUPER + CTRL + ALT + SLASH")
        self.assertIn("SUPER + CTRL + SLASH", block)
        self.assertNotIn('hl.unbind("SUPER + SLASH")', block)

    def test_normalize_rejects_shell(self):
        self.assertEqual(self.ctl.normalize_combo('SUPER + SLASH"; rm -rf'), "")
        self.assertEqual(self.ctl.normalize_combo("SUPER + SLASH"), "SUPER + SLASH")


class ConflictMessages(unittest.TestCase):
    def setUp(self):
        self.ctl = load_ctl()

    def test_blocking_tells_user_to_remove_it(self):
        msg = self.ctl.conflict_message({
            "plugin": True,
            "enabled": True,
            "daemon": True,
            "package": False,
            "blocking": True,
        })
        self.assertIn("crmne.hyprmoncfg", msg)
        self.assertIn("omarchy plugin remove", msg)
        self.assertIn("yield", msg)
        self.assertIn("will not disable it for you", msg)
        self.assertNotIn("system" + "ctl", msg)

    def test_leftover_plugin_does_not_claim_to_yield(self):
        msg = self.ctl.conflict_message({
            "plugin": True,
            "enabled": False,
            "daemon": False,
            "package": False,
            "blocking": False,
        })
        self.assertIn("crmne.hyprmoncfg", msg)
        self.assertNotIn("yield", msg)
        self.assertIn("will not disable it for you", msg)

    def test_public_conflict_includes_leftover_plugin_dir(self):
        info = {
            "id": "crmne.hyprmoncfg",
            "name": "hyprmoncfg",
            "plugin": True,
            "enabled": False,
            "daemon": False,
            "package": False,
            "blocking": False,
            "message": "leftover",
        }
        shown = self.ctl.public_conflict(info)
        self.assertIsNotNone(shown)
        self.assertEqual(shown["message"], "leftover")
        self.assertFalse(shown["blocking"])

    def test_public_conflict_ignores_package_only(self):
        info = {
            "plugin": False,
            "enabled": False,
            "daemon": False,
            "package": True,
            "blocking": False,
            "message": "",
        }
        self.assertIsNone(self.ctl.public_conflict(info))

    def test_public_conflict_shows_hyprmod_when_blocking(self):
        info = {
            "id": "hyprmod",
            "name": "HyprMod",
            "plugin": False,
            "enabled": True,
            "daemon": False,
            "package": True,
            "blocking": True,
            "message": "HyprMod is managing 1 display",
            "outputs": ["eDP-1"],
        }
        shown = self.ctl.public_conflict(info)
        self.assertIsNotNone(shown)
        self.assertEqual(shown["name"], "HyprMod")
        self.assertTrue(shown["blocking"])
        self.assertIn("eDP-1", shown["outputs"])


class HyprModDetect(unittest.TestCase):
    def setUp(self):
        import tempfile
        self.ctl = load_ctl()
        self.tmp = tempfile.TemporaryDirectory()
        root = self.tmp.name
        self.ctl.HYPRLAND_LUA = os.path.join(root, "hyprland.lua")
        self.ctl.HYPRLAND_CONF = os.path.join(root, "hyprland.conf")
        self.ctl.HYPRMOD_GUI_LUA = os.path.join(root, "hyprland-gui.lua")
        self.ctl.HYPRMOD_GUI_CONF = os.path.join(root, "hyprland-gui.conf")
        self.ctl.clear_conflict_cache()

    def tearDown(self):
        self.ctl.clear_conflict_cache()
        self.tmp.cleanup()

    def _write(self, path, text):
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(text)

    def test_lua_parser_reads_output_and_skips_comments(self):
        text = (
            "-- Generated by HyprMod\n"
            "-- hl.monitor({ output = \"SKIP\" })\n"
            "hl.monitor({\n"
            "  output = \"eDP-1\",\n"
            "  mode = \"1920x1200@60\",\n"
            "})\n"
            "hl.monitor({ output = 'HDMI-A-1' })\n"
        )
        names = self.ctl.parse_hyprmod_lua_outputs(text)
        self.assertEqual(names, ["eDP-1", "HDMI-A-1"])

    def test_conf_parser_skips_comments(self):
        text = (
            "# Generated by HyprMod\n"
            "# monitor = SKIP, preferred, auto, 1\n"
            "monitor = eDP-1, 1920x1200@59.95Hz, 0x0, 1, cm, srgb\n"
            "monitor=HDMI-A-1,preferred,auto,1\n"
        )
        names = self.ctl.parse_hyprmod_conf_outputs(text)
        self.assertEqual(names, ["eDP-1", "HDMI-A-1"])

    def test_lua_mode_ignores_leftover_conf_rules(self):
        self._write(self.ctl.HYPRLAND_LUA, 'require("hyprland-gui")\n')
        self._write(self.ctl.HYPRMOD_GUI_LUA, "-- Generated by HyprMod\n")
        self._write(
            self.ctl.HYPRMOD_GUI_CONF,
            "monitor = eDP-1, 1920x1200@60, 0x0, 1\n",
        )
        info = self.ctl.detect_hyprmod()
        self.assertFalse(info["blocking"])
        self.assertEqual(info["outputs"], [])

    def test_managing_lua_rules_blocks(self):
        self._write(self.ctl.HYPRLAND_LUA, '-- HyprMod managed settings\nrequire("hyprland-gui")\n')
        self._write(
            self.ctl.HYPRMOD_GUI_LUA,
            '-- Generated by HyprMod\nhl.monitor({ output = "eDP-1", mode = "preferred" })\n',
        )
        info = self.ctl.detect_hyprmod()
        self.assertTrue(info["blocking"])
        self.assertEqual(info["outputs"], ["eDP-1"])
        self.assertIn("trash can", info["message"])
        self.assertIn("eDP-1", info["message"])
        self.assertNotIn("system" + "ctl", info["message"])
        shown = self.ctl.public_conflict(info)
        self.assertIsNotNone(shown)
        self.assertTrue(shown["blocking"])

    def test_no_include_is_not_blocking(self):
        self._write(self.ctl.HYPRLAND_LUA, 'require("hypr.monitors")\n')
        self._write(
            self.ctl.HYPRMOD_GUI_LUA,
            'hl.monitor({ output = "eDP-1" })\n',
        )
        info = self.ctl.detect_hyprmod()
        self.assertFalse(info["blocking"])
        self.assertIsNone(self.ctl.public_conflict(info))

    def test_conf_mode_when_lua_entrypoint_missing(self):
        self._write(
            self.ctl.HYPRLAND_CONF,
            "source = /home/user/.config/hypr/hyprland-gui.conf\n",
        )
        self._write(
            self.ctl.HYPRMOD_GUI_CONF,
            "monitor = DP-1, preferred, auto, 1\n",
        )
        info = self.ctl.detect_hyprmod()
        self.assertTrue(info["blocking"])
        self.assertEqual(info["outputs"], ["DP-1"])

    def test_merge_mentions_both_managers(self):
        hm = {
            "id": "crmne.hyprmoncfg",
            "name": "hyprmoncfg",
            "plugin": True,
            "enabled": True,
            "daemon": True,
            "package": False,
            "blocking": True,
            "present": True,
            "message": "Found the crmne.hyprmoncfg plugin.",
        }
        hy = {
            "id": "hyprmod",
            "name": "HyprMod",
            "plugin": False,
            "blocking": True,
            "present": True,
            "message": "HyprMod is managing 1 display (eDP-1).",
            "outputs": ["eDP-1"],
        }
        merged = self.ctl.merge_conflicts(hm, hy)
        self.assertEqual(merged["id"], "display-managers")
        self.assertIn("hyprmoncfg", merged["message"])
        self.assertIn("HyprMod", merged["message"])
        self.assertTrue(merged["blocking"])


class ColorAndScale(unittest.TestCase):
    def setUp(self):
        self.ctl = load_ctl()

    def test_bitdepth_is_eight_or_ten(self):
        self.assertEqual(self.ctl.clean_bitdepth(16), 10)
        self.assertEqual(self.ctl.clean_bitdepth(12), 10)
        self.assertEqual(self.ctl.clean_bitdepth(10), 10)
        self.assertEqual(self.ctl.clean_bitdepth(8), 8)

    def test_hypr_wire_is_eight_or_ten(self):
        self.assertEqual(self.ctl.hypr_wire_bitdepth(16), 10)
        self.assertEqual(self.ctl.hypr_wire_bitdepth(10), 10)
        self.assertEqual(self.ctl.hypr_wire_bitdepth(8), 8)

    def test_wide_color_tri_state(self):
        self.assertEqual(self.ctl.clean_wide_color(1), 1)
        self.assertEqual(self.ctl.clean_wide_color(-1), -1)
        self.assertEqual(self.ctl.clean_wide_color(0), 0)

    def test_cm_presets(self):
        self.assertEqual(self.ctl.clean_cm("adobe"), "adobe")
        self.assertEqual(self.ctl.clean_cm("hdr"), "hdr")
        self.assertEqual(self.ctl.clean_cm("nope"), "srgb")

    def test_scale_keeps_one_thirty_three(self):
        self.assertEqual(self.ctl.clean_scale(1.33), 1.33)

    def test_lua_writes_ten_for_sixteen(self):
        line = self.ctl.monitor_lua(
            {
                "name": "DP-1",
                "description": "Test",
                "mode": "3840x2160@144",
                "x": 0,
                "y": 0,
                "scale": 1.33,
                "hdrMode": 2,
                "bitdepth": 16,
                "cm": "hdr",
                "enabled": True,
            },
            set(),
        )
        self.assertIn("bitdepth = 10", line)
        self.assertIn("scale = 1.33", line)
        self.assertIn('cm = "hdr"', line)

    def test_lua_writes_forced_wide_color(self):
        line = self.ctl.monitor_lua(
            {
                "name": "DP-1",
                "description": "Test",
                "mode": "3840x2160@144",
                "x": 0,
                "y": 0,
                "scale": 1,
                "hdrMode": 2,
                "bitdepth": 10,
                "cm": "wide",
                "supportsWideColor": 1,
                "enabled": True,
            },
            set(),
        )
        self.assertIn("supports_wide_color = 1", line)


class BarCare(unittest.TestCase):
    def setUp(self):
        self.ctl = load_ctl()

    def test_defaults_are_off(self):
        care = self.ctl.normalize_bar_care(None)
        self.assertFalse(care["enabled"])
        self.assertEqual(care["dim"], 45)
        self.assertTrue(care["hoverLift"])

    def test_clamps_dim(self):
        care = self.ctl.normalize_bar_care({"enabled": True, "dim": 200})
        self.assertEqual(care["dim"], 100)
        care = self.ctl.normalize_bar_care({"dim": -4, "hoverLift": False})
        self.assertEqual(care["dim"], 0)
        self.assertFalse(care["hoverLift"])


class ConflictsCli(unittest.TestCase):
    def test_remove_is_refused(self):
        import subprocess
        out = subprocess.run(
            [CTL, "conflicts", "remove"],
            capture_output=True,
            text=True,
            timeout=8,
        )
        self.assertEqual(out.returncode, 2)
        self.assertIn("does not remove other plugins", out.stderr)
        self.assertFalse((out.stdout or "").strip())


class MarketplaceHygiene(unittest.TestCase):
    def test_no_installer_script(self):
        self.assertFalse(os.path.isfile(os.path.join(ROOT, "install" + ".sh")))

    def test_tree_avoids_flagged_tokens(self):
        tokens = (
            "su" + "do",
            "pke" + "xec",
            "system" + "ctl",
            "git " + "clone",
        )
        skip_dirs = {".git", "__pycache__", "docs"}
        hits = []
        for dirpath, dirnames, filenames in os.walk(ROOT):
            dirnames[:] = [d for d in dirnames if d not in skip_dirs]
            for name in filenames:
                if name.endswith((".png", ".pyc", ".webp", ".webm", ".jpg")):
                    continue
                path = os.path.join(dirpath, name)
                try:
                    with open(path, encoding="utf-8") as fh:
                        text = fh.read()
                except (OSError, UnicodeDecodeError):
                    continue
                lower = text.lower()
                for token in tokens:
                    if token in lower:
                        hits.append("%s: %s" % (os.path.relpath(path, ROOT), token))
        self.assertEqual(hits, [])


class Omarchy403WidgetRegistry(unittest.TestCase):
    def test_service_does_not_call_registry_register(self):
        path = os.path.join(ROOT, "Service.qml")
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        self.assertNotIn("barWidgetRegistry.register", text)
        self.assertNotIn("function registerWidget", text)
        self.assertNotIn("function finishRegister", text)


class LastInternalRecover(unittest.TestCase):
    def setUp(self):
        self.ctl = load_ctl()

    def test_internal_names(self):
        self.assertTrue(self.ctl.is_internal_panel({"name": "eDP-1"}))
        self.assertTrue(self.ctl.is_internal_panel({"name": "eDP-2"}))
        self.assertTrue(self.ctl.is_internal_panel({"name": "LVDS-1"}))
        self.assertTrue(self.ctl.is_internal_panel("DSI-1"))
        self.assertFalse(self.ctl.is_internal_panel({"name": "HDMI-A-1"}))
        self.assertFalse(self.ctl.is_internal_panel({"name": "DP-3"}))

    def test_unplug_reenables_disabled_laptop(self):
        monitors = [
            {
                "name": "eDP-1",
                "enabled": False,
                "mode": "1920x1200@60",
                "x": 0,
                "y": 0,
                "scale": 1.25,
            }
        ]
        self.assertTrue(self.ctl.recover_last_internal(monitors))
        self.assertTrue(monitors[0]["enabled"])

    def test_leaves_docked_laptop_off(self):
        monitors = [
            {"name": "eDP-1", "enabled": False, "mode": "1920x1200@60"},
            {"name": "HDMI-A-1", "enabled": True, "mode": "2560x1440@60"},
        ]
        self.assertFalse(self.ctl.recover_last_internal(monitors))
        self.assertFalse(monitors[0]["enabled"])
        self.assertTrue(monitors[1]["enabled"])

    def test_noop_when_something_is_on(self):
        monitors = [{"name": "eDP-1", "enabled": True}]
        self.assertFalse(self.ctl.recover_last_internal(monitors))

    def test_recover_when_drm_only_has_laptop(self):
        self.assertTrue(self.ctl.should_recover_internal(["eDP-1"]))
        self.assertFalse(self.ctl.should_recover_internal(["eDP-1", "DP-3"]))
        self.assertFalse(self.ctl.should_recover_internal(["DP-3"]))
        self.assertFalse(self.ctl.should_recover_internal([]))

    def test_recover_despite_hypr_ghost_external(self):
        monitors = [
            {"name": "eDP-1", "enabled": False, "mode": "1920x1200@60"},
            {"name": "DP-3", "enabled": True, "mode": "2560x1440@60"},
        ]
        monitors, changed = self.ctl.enable_drm_internals(monitors, ["eDP-1"])
        self.assertTrue(changed)
        self.assertTrue(next(m for m in monitors if m["name"] == "eDP-1")["enabled"])

    def test_recover_stubs_edp_when_hypr_empty(self):
        monitors, changed = self.ctl.enable_drm_internals([], ["eDP-1"])
        self.assertTrue(changed)
        self.assertEqual(len(monitors), 1)
        self.assertEqual(monitors[0]["name"], "eDP-1")
        self.assertTrue(monitors[0]["enabled"])

    def test_recover_skips_reload_when_laptop_already_on(self):
        writes = []
        self.ctl.drm_connected_names = lambda: ["eDP-1"]
        self.ctl.internal_toggle_active = lambda: False
        self.ctl.set_internal_toggle = lambda disabled, mon=None: None
        self.ctl.snapshot = lambda: {
            "monitors": [{"name": "eDP-1", "enabled": True, "identity": "desc:Sharp"}]
        }
        self.ctl.write_monitors_lua = lambda monitors, gdk=None: writes.append("write")
        self.ctl.reload_hypr = lambda: writes.append("reload")
        self.ctl.remember_layout = lambda monitors: writes.append("remember")
        self.ctl.run = lambda cmd: writes.append(cmd)
        rc = self.ctl.recover_internal(quiet=True)
        self.assertEqual(rc, 0)
        self.assertEqual(writes, [])

    def test_monitor_lua_does_not_disable_internal(self):
        line = self.ctl.monitor_lua(
            {
                "name": "eDP-1",
                "enabled": False,
                "mode": "1920x1200@60",
                "x": 0,
                "y": 0,
                "scale": 1.25,
                "vrr": 0,
            },
            set(),
        )
        self.assertNotIn("disabled = true", line)
        self.assertIn("eDP-1", line)
        self.assertIn("1920x1200@60", line)

    def test_monitor_lua_still_disables_external(self):
        line = self.ctl.monitor_lua(
            {"name": "HDMI-A-1", "enabled": False, "description": "LG"},
            set(),
        )
        self.assertIn("disabled = true", line)


class HdrAutoChromium(unittest.TestCase):
    def setUp(self):
        self.ctl = load_ctl()
        self.studio = {
            "name": "DP-1",
            "description": "Apple Computer Inc StudioDisplay",
            "enabled": True,
            "mode": "5120x2880@60",
            "x": 0,
            "y": 0,
            "scale": 2,
            "vrr": 0,
            "hdrMode": 1,
            "hdrCapable": True,
            "bitdepth": 10,
            "cm": "dp3",
            "sdrMinLuminance": 0.005,
            "sdrMaxLuminance": 200,
            "sdrBrightness": 1,
            "minLuminance": 0,
            "maxLuminance": 604,
            "maxAvgLuminance": 604,
            "wideGamut": True,
        }

    def test_auto_omits_fields_that_wash_out_chromium(self):
        line = self.ctl.monitor_lua(self.studio, set())
        self.assertIn("supports_hdr = 1", line)
        self.assertNotIn("sdr_max_luminance", line)
        self.assertNotIn('cm = "dp3"', line)
        self.assertNotIn("max_luminance", line)
        self.assertNotIn("max_avg_luminance", line)
        self.assertNotIn("sdr_min_luminance", line)

    def test_always_still_writes_hdr_tune(self):
        mon = dict(self.studio)
        mon["hdrMode"] = 2
        mon["cm"] = "hdredid"
        line = self.ctl.monitor_lua(mon, set())
        self.assertIn("supports_hdr = 1", line)
        self.assertIn("sdr_max_luminance", line)
        self.assertIn('cm = "hdredid"', line)

    def test_bright_panel_default_sdr_peak_is_not_200(self):
        self.assertNotEqual(self.ctl.default_sdr_max(self.studio), 200)
        self.assertGreaterEqual(self.ctl.default_sdr_max(self.studio), 400)

    def test_old_auto_lua_needs_rewrite(self):
        old = (
            'hl.monitor({ output = "desc:Apple", mode = "5120x2880@60", '
            'bitdepth = 10, supports_hdr = 1, cm = "dp3", '
            "sdr_max_luminance = 200, max_luminance = 604 })\n"
        )
        self.assertTrue(self.ctl.monitors_lua_needs_rewrite(old))
        always = (
            'hl.monitor({ output = "desc:Apple", supports_hdr = 1, '
            'cm = "hdredid", sdr_max_luminance = 604 })\n'
        )
        self.assertFalse(self.ctl.monitors_lua_needs_rewrite(always))
        self.assertTrue(
            self.ctl.monitors_lua_needs_rewrite(
                'hl.monitor({ output = "eDP-1", disabled = true })\n'
            )
        )


class WorkspacesCompanionPlugin(unittest.TestCase):
    def setUp(self):
        import tempfile
        self.ctl = load_ctl()
        self.tmp = tempfile.TemporaryDirectory()
        self.plugins = os.path.join(self.tmp.name, "plugins")
        self.src = os.path.join(self.plugins, "im0001gt.screens")
        os.makedirs(self.src, exist_ok=True)
        for name in ("Workspaces.qml", "WorkspaceLayoutMenu.qml", "Model.js", "LICENSE"):
            with open(os.path.join(ROOT, name), encoding="utf-8") as fh:
                text = fh.read()
            with open(os.path.join(self.src, name), "w", encoding="utf-8") as fh:
                fh.write(text)
        with open(os.path.join(self.src, "manifest.json"), "w", encoding="utf-8") as fh:
            json.dump({
                "schemaVersion": 1,
                "id": "im0001gt.screens",
                "name": "Screens",
                "version": "1.12.0",
                "kinds": ["bar-widget", "service"],
                "entryPoints": {"barWidget": "Screens.qml", "service": "Service.qml"},
            }, fh)
        self.ctl.PLUGIN_DIR = self.src
        self.ctl.OUR_WS_WIDGET = "im0001gt.screens.workspaces"

    def tearDown(self):
        self.tmp.cleanup()

    def companion_dir(self):
        return os.path.join(self.plugins, "im0001gt.screens.workspaces")

    def test_install_writes_valid_companion_manifest(self):
        changed = self.ctl.install_workspaces_plugin()
        self.assertTrue(changed)
        dest = self.companion_dir()
        manifest_path = os.path.join(dest, "manifest.json")
        self.assertTrue(os.path.isfile(manifest_path))
        with open(manifest_path, encoding="utf-8") as fh:
            manifest = json.load(fh)
        self.assertEqual(manifest["id"], "im0001gt.screens.workspaces")
        self.assertEqual(manifest["version"], "1.12.0")
        self.assertEqual(manifest["kinds"], ["bar-widget"])
        self.assertEqual(manifest["entryPoints"]["barWidget"], "Workspaces.qml")
        self.assertEqual(manifest["barWidget"]["displayName"], "Screens workspaces")
        self.assertEqual(manifest["barWidget"]["category"], "Compositor")
        self.assertFalse(manifest["barWidget"]["allowMultiple"])
        self.assertEqual(manifest["barWidget"]["defaultSection"], "left")
        for name in ("Workspaces.qml", "WorkspaceLayoutMenu.qml", "Model.js", "LICENSE"):
            self.assertTrue(os.path.isfile(os.path.join(dest, name)), name)
        self.assertTrue(self.ctl.is_generated_workspaces_plugin(dest))

    def test_install_is_idempotent(self):
        self.assertTrue(self.ctl.install_workspaces_plugin())
        self.assertFalse(self.ctl.install_workspaces_plugin())

    def test_install_refreshes_when_source_changes(self):
        self.ctl.install_workspaces_plugin()
        with open(os.path.join(self.src, "Workspaces.qml"), "a", encoding="utf-8") as fh:
            fh.write("\n// touched\n")
        self.assertTrue(self.ctl.install_workspaces_plugin())

    def test_remove_only_deletes_generated_companion(self):
        self.ctl.install_workspaces_plugin()
        dest = self.companion_dir()
        self.assertTrue(os.path.isdir(dest))
        self.assertTrue(self.ctl.remove_workspaces_plugin())
        self.assertFalse(os.path.isdir(dest))
        os.makedirs(dest, exist_ok=True)
        with open(os.path.join(dest, "manifest.json"), "w", encoding="utf-8") as fh:
            json.dump({"id": "im0001gt.screens.workspaces"}, fh)
        self.assertFalse(self.ctl.remove_workspaces_plugin())
        self.assertTrue(os.path.isdir(dest))

    def test_restore_original_removes_generated_companion(self):
        self.ctl.install_workspaces_plugin()
        orig = os.path.join(self.tmp.name, "originals")
        os.makedirs(orig, exist_ok=True)
        with open(os.path.join(orig, "monitors.lua"), "w", encoding="utf-8") as fh:
            fh.write("hl.monitor({ output = \"eDP-1\" })\n")
        self.ctl.BACKUP_DIR = os.path.join(self.tmp.name, "state")
        self.ctl.ORIGINAL_BACKUP = os.path.join(orig, "monitors.lua")
        os.makedirs(self.ctl.BACKUP_DIR, exist_ok=True)
        self.ctl.MONITORS_LUA = os.path.join(self.tmp.name, "hypr", "monitors.lua")
        self.ctl.BINDINGS_LUA = os.path.join(self.tmp.name, "hypr", "bindings.lua")
        self.ctl.SHELL_JSON = os.path.join(self.tmp.name, "omarchy", "shell.json")
        self.ctl.LAYOUTS_DIR = os.path.join(self.tmp.name, "layouts")
        self.ctl.BRIGHTNESS_LINK = os.path.join(self.tmp.name, "bin", "omarchy-brightness-display")
        os.makedirs(os.path.join(self.tmp.name, "hypr"), exist_ok=True)
        os.makedirs(os.path.join(self.tmp.name, "omarchy"), exist_ok=True)
        def originals_dir():
            return orig
        self.ctl.originals_dir = originals_dir
        def load_manifest():
            return {"files": {"monitors.lua": {"present": True, "name": "monitors.lua"}}}
        self.ctl.load_originals_manifest = load_manifest
        self.ctl.reload_hypr = lambda: None
        rc = self.ctl.restore_original()
        self.assertEqual(rc, 0)
        self.assertFalse(os.path.isdir(self.companion_dir()))


class DeskLayoutMerge(unittest.TestCase):
    def setUp(self):
        import tempfile
        self.ctl = load_ctl()
        self.tmp = tempfile.TemporaryDirectory()
        self.ctl.BACKUP_DIR = self.tmp.name
        self.ctl.PROFILES_PATH = os.path.join(self.tmp.name, "profiles.json")

    def tearDown(self):
        self.tmp.cleanup()

    def test_unplug_keeps_missing_desk_member(self):
        laptop = {"id": "desc:Sharp", "enabled": True, "mode": "1920x1200@60", "x": 0, "y": 0, "scale": 1.5, "mirror": ""}
        desk = {"id": "desc:LG", "enabled": True, "mode": "3840x2160@60", "x": 1280, "y": 0, "scale": 2, "mirror": ""}
        merged = self.ctl.merge_desk_layout([laptop, desk], [laptop])
        ids = [e["id"] for e in merged]
        self.assertEqual(ids, ["desc:Sharp", "desc:LG"])
        self.assertEqual(next(e for e in merged if e["id"] == "desc:LG")["scale"], 2)

    def test_two_monitor_apply_replaces_desk(self):
        prev = [{"id": "desc:Sharp", "scale": 1}, {"id": "desc:LG", "scale": 1}]
        nxt = [{"id": "desc:Sharp", "scale": 1.5}, {"id": "desc:LG", "scale": 2}]
        merged = self.ctl.merge_desk_layout(prev, nxt)
        self.assertEqual(merged, nxt)

    def test_remember_layout_does_not_drop_unplugged_desk(self):
        self.ctl.save_store({
            "deskLayout": [
                {"id": "desc:Sharp Corporation 0x14CB", "enabled": True, "mode": "1920x1200@59.95", "x": 0, "y": 0, "scale": 1.5, "mirror": ""},
                {"id": "desc:LG Electronics LG HDR 4K 0x0006B200", "enabled": True, "mode": "3840x2160@60", "x": 1280, "y": 0, "scale": 2, "mirror": ""},
            ]
        })
        self.ctl.remember_layout([{
            "name": "eDP-1",
            "description": "Sharp Corporation 0x14CB",
            "identity": "desc:Sharp Corporation 0x14CB",
            "enabled": True,
            "mode": "1920x1200@59.95",
            "x": 0,
            "y": 0,
            "scale": 1.5,
        }])
        store = self.ctl.load_store()
        ids = [e.get("id") for e in store.get("deskLayout") or []]
        self.assertIn("desc:LG Electronics LG HDR 4K 0x0006B200", ids)
        self.assertEqual(len(store.get("lastLayout") or []), 1)


class PanelStateFile(unittest.TestCase):
    def setUp(self):
        import tempfile
        self.ctl = load_ctl()
        self.tmp = tempfile.TemporaryDirectory()
        self.ctl.BACKUP_DIR = self.tmp.name
        self.ctl.PANEL_STATE = os.path.join(self.tmp.name, "panel.json")
        self.ctl.REVERT_LUA = os.path.join(self.tmp.name, "revert-monitors.lua")
        self.ctl.PROFILES_PATH = os.path.join(self.tmp.name, "profiles.json")

    def tearDown(self):
        self.tmp.cleanup()

    def test_preview_state_is_wanted_and_pending(self):
        data = self.ctl.write_panel_state(True, True, 123.0, "DP-2")
        self.assertTrue(data["wanted"])
        self.assertTrue(data["pendingConfirm"])
        self.assertEqual(data["deadline"], 123.0)
        self.assertEqual(data["screen"], "DP-2")
        loaded = self.ctl.read_panel_state()
        self.assertTrue(loaded["wanted"])
        self.assertTrue(loaded["pendingConfirm"])
        self.assertEqual(loaded["screen"], "DP-2")

    def test_rewrite_preserves_owner_screen(self):
        self.ctl.write_panel_state(True, True, 10, "eDP-1")
        data = self.ctl.write_panel_state(True, True, 20)
        self.assertEqual(data["screen"], "eDP-1")
        self.assertEqual(data["deadline"], 20)

    def test_confirm_keeps_wanted_and_screen(self):
        self.ctl.write_panel_state(True, True, 1, "HDMI-A-1")
        self.ctl.clear_pending_revert()
        loaded = self.ctl.read_panel_state()
        self.assertTrue(loaded["wanted"])
        self.assertFalse(loaded["pendingConfirm"])
        self.assertEqual(loaded["screen"], "HDMI-A-1")

    def test_clear_drops_wanted(self):
        self.ctl.write_panel_state(True, True, 1, "DP-2")
        self.ctl.clear_panel_state()
        loaded = self.ctl.read_panel_state()
        self.assertFalse(loaded["wanted"])
        self.assertFalse(loaded["pendingConfirm"])
        self.assertEqual(loaded["screen"], "")


if __name__ == "__main__":
    unittest.main()
