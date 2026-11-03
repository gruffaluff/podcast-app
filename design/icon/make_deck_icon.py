"""Draws Tape Deck app icon options (grey panel, ink, one orange accent,
dark display with lit segments), to match the app's look.

    python3 design/icon/make_deck_icon.py D out.png        # one option, 1024px
    python3 design/icon/make_deck_icon.py preview out.png  # all side by side
"""
import math
import sys
from PIL import Image, ImageDraw, ImageFont

S = 4  # draw large, then scale down for smooth edges
SIZE = 1024 * S
PANEL = (232, 230, 225)
SURFACE = (244, 243, 239)
EDGE = (201, 198, 190)
INK = (27, 27, 26)
ORANGE = (240, 90, 26)
ORANGE_EDGE = (184, 65, 14)
DISPLAY = (34, 35, 31)
LIT = (230, 237, 215)
TRACK = (58, 60, 53)
AMBER = (255, 176, 0)


def px(v):
    return int(v * S)


def box(d, x0, y0, x1, y1, r, fill):
    d.rounded_rectangle([px(x0), px(y0), px(x1), px(y1)], radius=px(r), fill=fill)


def dot(d, x, y, r, fill):
    d.ellipse([px(x - r), px(y - r), px(x + r), px(y + r)], fill=fill)


def line(d, points, width, fill):
    r = px(width) / 2
    pts = [(px(x), px(y)) for x, y in points]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        steps = max(1, int(math.hypot(x1 - x0, y1 - y0) / (r / 4)))
        for k in range(steps + 1):
            x = x0 + (x1 - x0) * k / steps
            y = y0 + (y1 - y0) * k / steps
            d.ellipse([x - r, y - r, x + r, y + r], fill=fill)


def reel(d, cx, cy, r, ring, hub):
    dot(d, cx, cy, r, ring)
    dot(d, cx, cy, r * 0.62, hub)
    for k in range(6):
        a = k * math.pi / 3
        line(d, [(cx, cy), (cx + r * 0.62 * math.cos(a), cy + r * 0.62 * math.sin(a))], r * 0.16, ring)
    dot(d, cx, cy, r * 0.22, ring)


def option_d(d):
    """Cassette: ink shell, orange label, two reels, on the grey panel."""
    d.rectangle([0, 0, SIZE, SIZE], fill=PANEL)
    box(d, 132, 252 + 14, 892, 772 + 14, 70, EDGE)          # shadow, like a key
    box(d, 132, 252, 892, 772, 70, INK)
    box(d, 196, 306, 828, 420, 22, ORANGE)                   # label strip
    box(d, 252, 470, 772, 660, 95, DISPLAY)                  # tape window
    reel(d, 372, 565, 72, LIT, DISPLAY)
    reel(d, 652, 565, 72, LIT, DISPLAY)
    d.polygon([(px(330), px(772)), (px(372), px(712)), (px(652), px(712)), (px(694), px(772))], fill=(48, 48, 46))


def option_e(d):
    """Level meter: the dark display with a sound wave of lit segments,
    one amber ad segment and an orange status light."""
    d.rectangle([0, 0, SIZE, SIZE], fill=DISPLAY)
    heights = [3, 5, 8, 11, 8, 12, 9, 6, 4, 7, 10, 6, 3]
    n = len(heights)
    seg_h, gap = 30, 12
    for i, h in enumerate(heights):
        x = 168 + i * 54
        for j in range(12):
            y = 760 - j * (seg_h + gap)
            colour = (AMBER if i == 9 else LIT) if j < h else TRACK
            box(d, x, y - seg_h, x + 40, y, 5, colour)
    dot(d, 820, 196, 34, ORANGE)


def option_f(d):
    """Play key: a chunky orange key pressed into the grey panel, with an
    ink play symbol and a strip of lit segments below."""
    d.rectangle([0, 0, SIZE, SIZE], fill=PANEL)
    box(d, 192, 200 + 34, 832, 720 + 34, 110, ORANGE_EDGE)
    box(d, 192, 200, 832, 720, 110, ORANGE)
    d.polygon([(px(440), px(330)), (px(440), px(590)), (px(650), px(460))], fill=INK)
    for i in range(10):
        x = 222 + i * 60
        box(d, x, 820, x + 44, 852, 6, INK if i < 6 else EDGE)


def option_g(d):
    """Your current icon (option C, headband over a sound wave) redrawn in
    Tape Deck colours: ink lines on the grey panel, orange ear cups."""
    d.rectangle([0, 0, SIZE, SIZE], fill=PANEL)
    cx = 512
    wave = []
    for i in range(301):
        t = i / 300
        envelope = math.sin(t * math.pi) ** 2
        wave.append((250 + t * 524, 690 + envelope * 70 * math.sin(t * math.pi * 10)))
    line(d, wave, 30, INK)
    r, cy = 262, 560
    arc = [(cx + r * math.cos(a), cy + r * math.sin(a)) for a in [math.pi + k * math.pi / 200 for k in range(201)]]
    line(d, arc, 46, INK)
    for x in (cx - r, cx + r):
        box(d, x - 56, cy - 30 + 12, x + 56, cy + 190 + 12, 56, ORANGE_EDGE)
        box(d, x - 56, cy - 30, x + 56, cy + 190, 56, ORANGE)


# F (orange play key) was dropped: too close to a well-known video logo.
OPTIONS = {"D": option_d, "E": option_e, "G": option_g}


def draw(option):
    img = Image.new("RGB", (SIZE, SIZE), PANEL)
    OPTIONS[option](ImageDraw.Draw(img))
    return img.resize((1024, 1024), Image.LANCZOS)


def rounded(img, size, background):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0] - 1, img.size[1] - 1], radius=230, fill=255)
    out = Image.new("RGB", img.size, background)
    out.paste(img, (0, 0), mask)
    return out.resize((size, size), Image.LANCZOS)


if __name__ == "__main__":
    which, path = sys.argv[1], sys.argv[2]
    if which == "preview":
        current = Image.open(sys.argv[3]).convert("RGB") if len(sys.argv) > 3 else None
        keys = list(OPTIONS)
        tiles = ([("Now", current)] if current else []) + [(k, draw(k)) for k in keys]
        bg = (200, 197, 190)
        sheet = Image.new("RGB", (len(tiles) * 300 + 40, 360), bg)
        d = ImageDraw.Draw(sheet)
        try:
            font = ImageFont.truetype("DejaVuSansMono-Bold.ttf", 26)
        except OSError:
            font = ImageFont.load_default()
        for i, (key, img) in enumerate(tiles):
            sheet.paste(rounded(img, 240, bg), (40 + i * 300, 30))
            w = d.textlength(key, font=font)
            d.text((40 + i * 300 + 120 - w / 2, 295), key, fill=INK, font=font)
        sheet.save(path)
    else:
        draw(which).save(path)
