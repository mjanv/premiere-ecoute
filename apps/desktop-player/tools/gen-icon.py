#!/usr/bin/env python3
"""Draws assets/icon.ico: a dark tile with an amber oscilloscope line. No dependencies.
usage: python3 tools/gen-icon.py"""
import math, struct, zlib, pathlib

BG, LINE, EDGE = (20, 22, 26), (240, 160, 48), (44, 47, 54)
SIZES = (256, 64, 48, 32, 24, 16)
SS = 4  # supersampling per axis


def coverage(x, y, n):
    """Return (rgb, alpha) of the pixel at (x, y) in an n x n icon, in unit coordinates."""
    u, v = x / n, y / n
    # Rounded tile.
    r = 0.18
    cx, cy = min(max(u, r), 1 - r), min(max(v, r), 1 - r)
    if math.hypot(u - cx, v - cy) > r:
        return None
    border = min(u, v, 1 - u, 1 - v) < 0.025 or math.hypot(u - cx, v - cy) > r - 0.025 and (u < r or u > 1 - r) and (v < r or v > 1 - r)
    # Waveform: a sine whose amplitude swells in the middle.
    t = (u - 0.14) / 0.72
    if 0 <= t <= 1:
        amp = 0.30 * math.sin(math.pi * t) ** 1.2
        y_line = 0.5 - amp * math.sin(2 * math.pi * 2.5 * t)
        if abs(v - y_line) < 0.045 + 0.01 * (n >= 48) * 0:
            return LINE
    return EDGE if border else BG


def render(n):
    rows = []
    for py in range(n):
        row = bytearray([0])
        for px in range(n):
            acc, a = [0, 0, 0], 0
            for sy in range(SS):
                for sx in range(SS):
                    c = coverage(px + (sx + .5) / SS, py + (sy + .5) / SS, n)
                    if c:
                        a += 1
                        for i in range(3):
                            acc[i] += c[i]
            row += bytes(acc[i] // a if a else 0 for i in range(3)) + bytes([255 * a // (SS * SS)])
        rows.append(bytes(row))
    raw = b"".join(rows)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))

    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", n, n, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


images = [(n, render(n)) for n in SIZES]
out = struct.pack("<HHH", 0, 1, len(images))
offset = 6 + 16 * len(images)
for n, png in images:
    out += struct.pack("<BBBBHHII", n % 256, n % 256, 0, 0, 1, 32, len(png), offset)
    offset += len(png)
out += b"".join(png for _, png in images)
path = pathlib.Path(__file__).resolve().parent.parent / "assets" / "icon.ico"
path.write_bytes(out)
print(f"wrote {path} ({len(out)} bytes)")
