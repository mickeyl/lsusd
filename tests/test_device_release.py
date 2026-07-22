import tempfile
import unittest
from pathlib import Path

from lsusd.linux import _usb_device_row
from lsusd.metadata import format_bcd_device_release


class DeviceReleaseTests(unittest.TestCase):
    def test_formats_bcd_device_release(self):
        self.assertEqual(format_bcd_device_release(0x1234), "12.34")
        self.assertEqual(format_bcd_device_release(0x0060), "0.60")

    def test_missing_or_invalid_release_is_unknown(self):
        self.assertEqual(format_bcd_device_release(None), "?")
        self.assertEqual(format_bcd_device_release(0x10000), "?")


class LinuxReleaseTests(unittest.TestCase):
    def test_reads_kernel_formatted_bcd_device_release(self):
        with tempfile.TemporaryDirectory() as directory:
            device = Path(directory)
            attributes = {
                "idVendor": "1234",
                "idProduct": "5678",
                "busnum": "1",
                "devnum": "2",
                "bcdDevice": "12.34",
            }
            for name, value in attributes.items():
                (device / name).write_text(value)

            self.assertEqual(_usb_device_row(device)["release"], "12.34")


if __name__ == "__main__":
    unittest.main()
