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


if __name__ == "__main__":
    unittest.main()
