"""Print the UDID of an available iPhone simulator on the newest iOS runtime.

Reads `xcrun simctl list devices available -j` from stdin. Prefers a non-Pro "iPhone 1x".
"""
import json
import re
import sys

devices = json.load(sys.stdin)["devices"]
candidates = []
for runtime, entries in devices.items():
    match = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not match:
        continue
    version = (int(match.group(1)), int(match.group(2)))
    for device in entries:
        name = device["name"]
        if not name.startswith("iPhone"):
            continue
        plain = 0 if re.fullmatch(r"iPhone \d+", name) else 1
        candidates.append((version, -plain, name, device["udid"]))

if not candidates:
    sys.exit("no iPhone simulator available")
candidates.sort()
print(candidates[-1][3])
