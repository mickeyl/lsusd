import csv
import io
import json
import plistlib
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from lsusd import cli, darwin, linux


class LinuxSerialDeviceTests(unittest.TestCase):
    def test_physical_mapping_and_legacy_serial_view(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            usb_bus = root / "bus"
            tty_class = root / "tty"
            usb_bus.mkdir()
            tty_class.mkdir()
            for index, name in enumerate(("usb1", "1-1", "1-2", "1-3"), 1):
                device = root / "devices" / name
                device.mkdir(parents=True)
                attributes = {
                    "idVendor": "1234", "idProduct": "5678",
                    "manufacturer": "Vendor", "product": "Product",
                    "serial": "duplicate", "busnum": "1", "devnum": str(index),
                    "bDeviceClass": "09" if name == "usb1" else "00",
                }
                for key, value in attributes.items():
                    (device / key).write_text(value)
                (usb_bus / name).symlink_to(device)

            for name, parent in (("ttyUSB0", "1-1"), ("ttyUSB1", "1-1"), ("ttyACM0", "1-2")):
                interface = root / "devices" / parent / "interface" / name
                interface.mkdir(parents=True)
                entry = tty_class / name
                entry.mkdir()
                (entry / "device").symlink_to(interface)
            # Non-USB and dangling tty entries must not acquire a USB mapping.
            (tty_class / "ttyS0").mkdir()
            (tty_class / "ttyS0" / "device").symlink_to(root)
            (tty_class / "ttyGone").mkdir()
            (tty_class / "ttyGone" / "device").symlink_to(root / "gone")

            def sysfs_path(value):
                return {
                    "/sys/class/tty": tty_class,
                    "/sys/bus/usb/devices": usb_bus,
                }.get(str(value), Path(value))

            with patch.object(linux, "Path", side_effect=sysfs_path):
                devices = linux.discover_all()
                self.assertEqual([d["device"] for d in devices], [
                    "/dev/ttyUSB0, /dev/ttyUSB1", "/dev/ttyACM0", "?",
                ])
                tree = linux.discover_tree(include_hubs=True)
                self.assertEqual(tree[0]["device"]["device"], "?")
                self.assertEqual([n["device"] for n in tree[0]["children"]], devices)
                legacy = linux.discover()
                self.assertEqual([d["device"] for d in legacy], [
                    "/dev/ttyACM0", "/dev/ttyUSB0", "/dev/ttyUSB1",
                ])
                self.assertTrue(all(set(d) == set(cli.DEVICE_FIELDS) for d in legacy))


class DarwinSerialDeviceTests(unittest.TestCase):
    def test_registry_ancestry_with_duplicate_metadata_and_multiple_ports(self):
        def usb(location, address, **extra):
            return {
                "idVendor": 0x1234, "idProduct": 0x5678,
                "locationID": location, "USB Address": address,
                "bDeviceClass": 0, "USB Serial Number": "duplicate", **extra,
            }

        first = usb(0x01100000, 2)
        second = usb(0x01200000, 3)
        third = usb(0x01300000, 4)
        usb_tree = [usb(0x01000000, 1, bDeviceClass=9, IORegistryEntryChildren=[
            first, second, third,
        ])]
        service_tree = [usb(0x01000000, 1, bDeviceClass=9, IORegistryEntryChildren=[
            {**first, "IORegistryEntryChildren": [{
                "idVendor": 0x1234, "idProduct": 0x5678, "bInterfaceNumber": 0,
                "IORegistryEntryChildren": [
                    {"IOCalloutDevice": "/dev/cu.usbmodem2"},
                    {"IOCalloutDevice": "/dev/cu.usbmodem1"},
                ],
            }]},
            {**second, "IORegistryEntryChildren": [
                {"IOCalloutDevice": "/dev/cu.SLAB_USBtoUART"},
            ]},
            third,
        ]), {"IOCalloutDevice": "/dev/cu.Bluetooth-Incoming-Port"}]

        def ioreg(command, **kwargs):
            plane = command[command.index("-p") + 1]
            return SimpleNamespace(stdout=plistlib.dumps(
                usb_tree if plane == "IOUSB" else service_tree,
            ))

        with patch.object(darwin.subprocess, "run", side_effect=ioreg), patch.object(
            darwin.usb_ids, "lookup", return_value=(None, None),
        ):
            devices = darwin.discover_all()
            self.assertEqual([d["device"] for d in devices], [
                "/dev/cu.usbmodem1, /dev/cu.usbmodem2", "/dev/cu.SLAB_USBtoUART", "?",
            ])
            tree = darwin.discover_tree(include_hubs=True)
            self.assertEqual(tree[0]["device"]["device"], "?")
            self.assertEqual([n["device"] for n in tree[0]["children"]], devices)

    def test_usb_devices_remain_visible_when_serial_registry_is_empty(self):
        node = {"idVendor": 0x1234, "idProduct": 0x5678, "locationID": 0x01100000}
        with patch.object(darwin, "_load_usb_tree", return_value=node), patch.object(
            darwin, "_load_registry_tree", return_value={},
        ), patch.object(darwin.usb_ids, "lookup", return_value=(None, None)):
            self.assertEqual(darwin.discover_all()[0]["device"], "?")


class SerialDeviceOutputTests(unittest.TestCase):
    def setUp(self):
        self.device = {
            "bus": "001", "address": "002", "location": "1.2",
            "device": "/dev/ttyUSB0, /dev/ttyUSB1", "product": "Product",
            "vendor": "Vendor", "serial": "123", "vidpid": "1234:5678",
            "release": "1.00", "speed": "12M",
        }

    def output(self, *args):
        stream = io.StringIO()
        with redirect_stdout(stream):
            cli.print_devices([self.device], cli.parse_args(args))
        return stream.getvalue()

    def test_default_table_replaces_location_with_serial_nodes(self):
        table = self.output()
        self.assertIn("Device Node", table)
        self.assertIn(self.device["device"], table)
        self.assertNotIn("Location", table)

    def test_machine_readable_formats_use_device_instead_of_location(self):
        record = json.loads(self.output("--json"))[0]
        self.assertEqual(record["device"], self.device["device"])
        self.assertNotIn("location", record)
        record = next(csv.DictReader(io.StringIO(self.output("--csv"))))
        self.assertEqual(record["device"], self.device["device"])
        self.assertNotIn("location", record)
        self.assertEqual(self.output("--plain").split("\t")[2], self.device["device"])

    def test_tree_shows_serial_nodes_only_when_available(self):
        tree = cli.format_tree([{"device": self.device, "children": []}])
        self.assertIn(f"device={self.device['device']}", tree)
        self.assertNotIn("loc=", tree)
        self.device["device"] = "?"
        self.assertNotIn("device=", cli.format_tree([{"device": self.device, "children": []}]))

    def test_serial_compatibility_format_is_unchanged(self):
        record = json.loads(self.output("--serial", "--json"))[0]
        self.assertEqual(set(record), set(cli.DEVICE_FIELDS))
        self.assertIn("Device Node", self.output("--serial"))


if __name__ == "__main__":
    unittest.main()
