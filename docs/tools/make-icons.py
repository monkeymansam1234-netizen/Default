#!/usr/bin/env python3
"""Generates the app icons. No image libraries on hand, so this rasterizes
straight to PNG: supersampled coverage per pixel, zlib-deflated scanlines.

    python3 docs/tools/make-icons.py
"""
import math
import struct
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent
SIZES = {"apple-touch-icon.png": 180, "icon-192.png": 192, "icon-512.png": 512}

TOP = (0x2A, 0x25, 0x50)      # night sky, top
BOTTOM = (0x10, 0x10, 0x1E)   # night sky, bottom
MOON = (0xE9, 0xE6, 0xFF)
STAR = (0xC9, 0xC3, 0xFF)

SAMPLES = 3  # per axis


def crescent(x, y):
    """Coverage of a moon: one disc with a second disc bitten out of it."""
    inside = (x - 0.47) ** 2 + (y - 0.50) ** 2 <= 0.30 ** 2
    bitten = (x - 0.62) ** 2 + (y - 0.39) ** 2 <= 0.27 ** 2
    return inside and not bitten


def star(x, y, cx, cy, r):
    """A four-pointed sparkle: a diamond with concave sides."""
    dx, dy = abs(x - cx), abs(y - cy)
    if dx > r or dy > r:
        return False
    # Astroid-ish curve keeps the points sharp at small sizes.
    return (dx / r) ** 0.62 + (dy / r) ** 0.62 <= 1.0


def shade(x, y):
    """Returns (r, g, b) for a point in the unit square."""
    base = tuple(round(TOP[i] + (BOTTOM[i] - TOP[i]) * y) for i in range(3))
    if crescent(x, y):
        return MOON
    if star(x, y, 0.74, 0.70, 0.055) or star(x, y, 0.28, 0.27, 0.038):
        return STAR
    return base


def render(size):
    rows = []
    step = 1.0 / (size * SAMPLES)
    for py in range(size):
        row = bytearray([0])  # PNG filter type 0 for each scanline
        for px in range(size):
            acc = [0, 0, 0]
            for sy in range(SAMPLES):
                for sx in range(SAMPLES):
                    x = (px * SAMPLES + sx + 0.5) * step
                    y = (py * SAMPLES + sy + 0.5) * step
                    c = shade(x, y)
                    for i in range(3):
                        acc[i] += c[i]
            n = SAMPLES * SAMPLES
            row += bytes(round(v / n) for v in acc)
            row.append(255)
        rows.append(bytes(row))
    return b"".join(rows)


def chunk(tag, data):
    return (struct.pack(">I", len(data)) + tag + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))


def write_png(path, size):
    header = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)  # 8-bit RGBA
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", header)
           + chunk(b"IDAT", zlib.compress(render(size), 9))
           + chunk(b"IEND", b""))
    path.write_bytes(png)
    print(f"{path.name}  {size}x{size}  {len(png):,} bytes")


if __name__ == "__main__":
    for name, size in SIZES.items():
        write_png(OUT / name, size)
