"""Draws the Podspot app icon options. Each is a sound wave turning into
headphones, off-white on terracotta.

    python3 design/icon/make_icon.py A out.png   # one option
    python3 design/icon/make_icon.py preview out.png  # all options side by side
"""
import math
import sys
from PIL import Image, ImageDraw

S = 4  # draw large, then scale down for smooth edges
SIZE = 1024 * S
TERRACOTTA = (173, 82, 48)
OFF_WHITE = (250, 248, 243)


def px(v):
    return v * S


def thick_polyline(d, points, width):
    """A smooth line with round joins and ends."""
    # Stamp round dots closely along the path: perfectly smooth edges.
    r = px(width) / 2
    pts = [(px(x), px(y)) for x, y in points]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        steps = max(1, int(math.hypot(x1 - x0, y1 - y0) / (r / 4)))
        for k in range(steps + 1):
            x = x0 + (x1 - x0) * k / steps
            y = y0 + (y1 - y0) * k / steps
            d.ellipse([x - r, y - r, x + r, y + r], fill=OFF_WHITE)


def option_a(d):
    """The headband itself is a sound wave: it ripples most at the top,
    smoothing out as it reaches the ear cups."""
    cx, cy, r = 512, 560, 300
    points = []
    steps = 400
    for i in range(steps + 1):
        t = i / steps                       # 0 at left cup, 1 at right cup
        angle = math.pi + t * math.pi       # left → over the top → right
        ripple = math.sin(t * math.pi) ** 1.5 * 20 * math.sin(t * math.pi * 16)
        rr = r + ripple
        points.append((cx + rr * math.cos(angle), cy + rr * math.sin(angle)))
    thick_polyline(d, points, 46)
    for x in (cx - r, cx + r):
        d.rounded_rectangle([px(x - 62), px(cy - 40), px(x + 62), px(cy + 250)], radius=px(62), fill=OFF_WHITE)


def option_b(d):
    """Sound-wave bars stand around an arc to form the headband, tallest at
    the top, shrinking into the ear cups."""
    cx, cy, r = 512, 580, 300
    count = 15
    for i in range(count):
        t = i / (count - 1)
        angle = math.pi + 0.12 + t * (math.pi - 0.24)
        length = 40 + 120 * math.sin(t * math.pi) ** 1.5 * (0.75 + 0.25 * math.cos(t * math.pi * 6))
        x, y = cx + r * math.cos(angle), cy + r * math.sin(angle)
        dx, dy = math.cos(angle), math.sin(angle)
        a = (x - dx * length / 2, y - dy * length / 2)
        b = (x + dx * length / 2, y + dy * length / 2)
        thick_polyline(d, [a, b], 30)
    for x in (cx - r, cx + r):
        d.rounded_rectangle([px(x - 64), px(cy - 30), px(x + 64), px(cy + 230)], radius=px(64), fill=OFF_WHITE)


def option_c(d):
    """A single line: flat, then a burst of sound, then it lifts up and over
    into a headband and lands as two ear cups (a 'spot' of sound)."""
    cx = 512
    # The wave along the bottom.
    wave = []
    for i in range(301):
        t = i / 300
        x = 250 + t * 524
        envelope = math.sin(t * math.pi) ** 2
        y = 690 + envelope * 70 * math.sin(t * math.pi * 10)
        wave.append((x, y))
    thick_polyline(d, wave, 30)
    # Headband arc above.
    r, cy = 262, 560
    arc = [(cx + r * math.cos(a), cy + r * math.sin(a)) for a in [math.pi + k * math.pi / 200 for k in range(201)]]
    thick_polyline(d, arc, 46)
    for x in (cx - r, cx + r):
        d.rounded_rectangle([px(x - 56), px(cy - 30), px(x + 56), px(cy + 190)], radius=px(56), fill=OFF_WHITE)


OPTIONS = {"A": option_a, "B": option_b, "C": option_c}


def draw(option):
    img = Image.new("RGB", (SIZE, SIZE), TERRACOTTA)
    OPTIONS[option](ImageDraw.Draw(img))
    return img.resize((1024, 1024), Image.LANCZOS)


def rounded(img, size):
    """How it looks on the home screen (iOS rounds the corners)."""
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0] - 1, img.size[1] - 1], radius=230, fill=255)
    out = Image.new("RGB", img.size, OFF_WHITE)
    out.paste(img, (0, 0), mask)
    return out.resize((size, size), Image.LANCZOS)


if __name__ == "__main__":
    which, path = sys.argv[1], sys.argv[2]
    if which == "preview":
        tiles = [rounded(draw(k), 300) for k in OPTIONS]
        sheet = Image.new("RGB", (len(tiles) * 340 + 40, 380), OFF_WHITE)
        d = ImageDraw.Draw(sheet)
        for i, (key, tile) in enumerate(zip(OPTIONS, tiles)):
            sheet.paste(tile, (40 + i * 340, 20))
            d.text((40 + i * 340 + 145, 335), key, fill=(31, 30, 27))
        sheet.save(path)
    else:
        draw(which).save(path)
