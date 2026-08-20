#!/usr/bin/env python3
import importlib.util
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


if __name__ == "__main__":
    unittest.main()
