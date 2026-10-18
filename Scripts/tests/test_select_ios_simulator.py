"""Fixture tests for CI destination discovery (no simulator required)."""
import importlib.util
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location(
    "selector", Path(__file__).parents[1] / "select_ios_simulator.py"
)
selector = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(selector)


class SimulatorSelectionTests(unittest.TestCase):
    def test_selects_newest_available_iphone_on_supported_runtime(self):
        runtimes = {"runtimes": [
            {"identifier": "com.apple.CoreSimulator.SimRuntime.iOS-16-4", "version": "16.4", "isAvailable": True},
            {"identifier": "com.apple.CoreSimulator.SimRuntime.iOS-26-2", "version": "26.2", "isAvailable": True},
            {"identifier": "com.apple.CoreSimulator.SimRuntime.iOS-27-0", "version": "27.0", "isAvailable": False},
        ]}
        devices = {"devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-16-4": [{"name": "iPhone 14", "udid": "com.apple.CoreSimulator.SimRuntime.iOS-16-4", "isAvailable": True}],
            "com.apple.CoreSimulator.SimRuntime.iOS-26-2": [
                {"name": "iPad Pro", "udid": "ipad", "isAvailable": True},
                {"name": "iPhone missing", "udid": "missing", "isAvailable": False},
                {"name": "iPhone 17", "udid": "chosen", "isAvailable": True},
            ],
            "com.apple.CoreSimulator.SimRuntime.iOS-27-0": [{"name": "iPhone 18", "udid": "com.apple.CoreSimulator.SimRuntime.iOS-27-0", "isAvailable": True}],
        }}
        self.assertEqual(selector.select_destination(runtimes, devices), "chosen")

    def test_compares_versions_numerically_and_ignores_other_platforms(self):
        runtimes = {"runtimes": [
            {"identifier": "com.apple.CoreSimulator.SimRuntime.iOS-18-9", "version": "18.9", "isAvailable": True},
            {"identifier": "com.apple.CoreSimulator.SimRuntime.iOS-18-10", "version": "18.10", "isAvailable": True},
            {"identifier": "com.apple.CoreSimulator.SimRuntime.tvOS-99-0", "version": "99.0", "isAvailable": True},
        ]}
        devices = {"devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-18-9": [{"name": "iPhone A", "udid": "nine", "isAvailable": True}],
            "com.apple.CoreSimulator.SimRuntime.iOS-18-10": [{"name": "iPhone B", "udid": "ten", "isAvailable": True}],
            "com.apple.CoreSimulator.SimRuntime.tvOS-99-0": [{"name": "iPhone misleading name", "udid": "com.apple.CoreSimulator.SimRuntime.tvOS-99-0", "isAvailable": True}],
        }}
        self.assertEqual(selector.select_destination(runtimes, devices), "ten")

    def test_fails_clearly_without_supported_iphone(self):
        with self.assertRaisesRegex(ValueError, "iPhone.*iOS 18"):
            selector.select_destination({"runtimes": []}, {"devices": {}})


if __name__ == "__main__":
    unittest.main()
