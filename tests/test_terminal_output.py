import io
import json
import re
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch

from lsusd import cli


ANSI_STYLE = re.compile(r"\033\[[0-9;]*m")


class TerminalOutputTests(unittest.TestCase):
    def setUp(self):
        self.device = {
            "bus": "001", "address": "002", "device": "/dev/ttyUSB0",
            "product": "USB Adapter", "vendor": "?", "serial": "?",
            "vidpid": "1234:5678", "release": "?", "speed": "480M",
        }

    def output(self, *args, tty=False, env=None):
        stream = io.StringIO()
        with redirect_stdout(stream), patch.object(stream, "isatty", return_value=tty), patch.dict(
            cli.os.environ, {"TERM": "xterm-256color", **(env or {})}, clear=True,
        ):
            cli.print_devices([self.device], cli.parse_args(args))
        return stream.getvalue()

    def test_table_uses_em_dash_including_usb_serial(self):
        for args in ((), ("--serial",)):
            with self.subTest(args=args):
                output = self.output(*args)
                self.assertNotIn("?", output)
                self.assertEqual(output.count("—"), 3)
                self.assertNotIn("\033", output)
        self.assertEqual(self.device["serial"], "?")

    def test_color_keeps_table_alignment_and_emphasizes_device_nodes(self):
        for args in ((), ("--serial",)):
            with self.subTest(args=args):
                colored = self.output(*args, tty=True)
                self.assertIn("\033[32m/dev/ttyUSB0\033[0m", colored)
                self.assertIn("\033[2m—\033[0m", colored)
                self.assertEqual(ANSI_STYLE.sub("", colored), self.output(*args))

    def test_color_opt_out_and_dumb_terminals(self):
        for env in ({"NO_COLOR": "1"}, {"TERM": "dumb"}):
            with self.subTest(env=env):
                self.assertNotIn("\033", self.output(tty=True, env=env))

    def test_speed_tiers_have_distinct_colors(self):
        for speed, code in (("10G", "35"), ("480M", "36"), ("12M", "33")):
            with self.subTest(speed=speed):
                self.device["speed"] = speed
                self.assertIn(f"\033[{code}m{speed}\033[0m", self.output(tty=True))

    def test_data_formats_preserve_unknown_values_without_styles_even_in_tty(self):
        for flag in ("--plain", "--csv", "--json"):
            for serial in ((), ("--serial",)):
                with self.subTest(flag=flag, serial=serial):
                    output = self.output(*serial, flag, tty=True)
                    self.assertIn("?", output)
                    self.assertNotIn("—", output)
                    self.assertNotIn("\033", output)
        self.assertEqual(json.loads(self.output("--json", tty=True))[0]["serial"], "?")

    def test_tree_uses_the_same_styles_and_unknown_placeholder(self):
        tree = [{"device": self.device, "children": []}]
        plain = cli.format_tree(tree)
        colored = cli.format_tree(tree, color=True)
        self.assertIn("release=—", plain)
        self.assertNotIn("?", plain)
        self.assertIn("\033[32m/dev/ttyUSB0\033[0m", colored)
        self.assertEqual(ANSI_STYLE.sub("", colored), plain)

    def test_live_watch_uses_em_dash_and_colors_removal_events(self):
        stream = io.StringIO()
        event = {"action": "remove", **self.device}

        def events(initial="events"):
            self.assertEqual(initial, "snapshot")
            yield {"action": "snapshot", "devices": [self.device]}
            yield event

        with redirect_stdout(stream), patch.object(stream, "isatty", return_value=True), patch.dict(
            cli.os.environ, {"TERM": "xterm-256color"}, clear=True,
        ):
            cli.watch_devices(events, cli.parse_args(["--watch"]))
        self.assertIn("\033[2m—\033[0m", stream.getvalue())
        self.assertIn("\033[31mremove\033[0m", stream.getvalue())
        self.assertNotIn("?", stream.getvalue())

    def test_watch_log_uses_em_dash_but_data_events_keep_question_mark(self):
        event = {"action": "present", **self.device}
        self.assertIn("serial='—'", cli.format_watch_line(event))
        self.assertNotIn("?", cli.format_watch_line(event))
        self.assertIn("?", cli.format_watch_plain(event))


if __name__ == "__main__":
    unittest.main()
