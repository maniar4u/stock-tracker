#!/usr/bin/env python3
"""Print an available iPhone UDID from the selected Xcode's simctl inventory."""
import json
import subprocess
import sys


def select_destination(runtimes, devices):
    candidates = []
    for runtime in runtimes["runtimes"]:
        if not runtime.get("isAvailable", False) or ".iOS-" not in runtime["identifier"]:
            continue
        version = tuple(int(part) for part in runtime["version"].split("."))
        if version < (18,):
            continue
        for device in devices["devices"].get(runtime["identifier"], []):
            if device.get("isAvailable", False) and device["name"].startswith("iPhone"):
                candidates.append((version, device["name"], device["udid"]))
    if not candidates:
        raise ValueError("No available iPhone simulator with iOS 18 or later; install a runtime in Xcode.")
    return max(candidates)[2]


def main():
    def inventory(kind):
        return json.loads(subprocess.check_output(["xcrun", "simctl", "list", kind, "--json"]))

    try:
        print(select_destination(inventory("runtimes"), inventory("devices")))
    except (ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(f"Simulator selection failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
