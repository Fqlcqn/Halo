#!/usr/bin/env python3
"""Read-only reference executable inspection. Never used by the rebuilt app."""
import argparse
import re
import struct
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("start", nargs="?", default="0")
parser.add_argument("end", nargs="?", default="0xffffffffffffffff")
parser.add_argument("--save", action="store_true")
args = parser.parse_args()
binary = ROOT.parent / "Latest/Halo.app/Contents/MacOS/Halo"
listing = subprocess.check_output(["otool", "-tvV", str(binary)], text=True)
listing = subprocess.check_output(["xcrun", "swift-demangle"], input=listing, text=True)
registers = {}
lines = []
for line in listing.splitlines():
    match = re.match(r"([0-9a-f]{16})\s+(.*)", line)
    if match:
        address, instruction = int(match[1], 16), match[2]
        move = re.match(r"(mov|movk)\s+([xw]\d+), #(-?0x[0-9a-f]+)(?:, lsl #(\d+))?", instruction)
        if move:
            op, reg, immediate, shift = move.groups()
            value, shift = int(immediate, 16), int(shift or 0)
            old = registers.get(reg, 0) if op == "movk" else 0
            registers[reg] = ((old & ~(0xffff << shift)) | ((value & 0xffff) << shift)) if op == "movk" else value & ((1 << 64)-1)
        floating = re.match(r"fmov\s+d\d+, (x\d+)", instruction)
        if floating and floating[1] in registers:
            value = struct.unpack("<d", struct.pack("<Q", registers[floating[1]]))[0]
            line += f"  // double {value:.12g}"
        if not int(args.start, 0) <= address < int(args.end, 0):
            continue
    lines.append(line)
if args.save:
    target = ROOT / "Reference/disassembly.txt"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text("\n".join(lines) + "\n")
    print(target)
else:
    print("\n".join(lines))
