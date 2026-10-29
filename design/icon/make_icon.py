"""Draws the Podspot app icon: a sound wave whose outer bars become the ear
cups of a pair of headphones. Run: python3 design/icon/make_icon.py"""
from PIL import Image, ImageDraw
import sys

S = 4  # draw large, then scale down for smooth edges
SIZE = 1024 * S
TERRACOTTA = (173, 82, 48)
OFF_WHITE = (250, 248, 243)

img = Image.new("RGB", (SIZE, SIZE), TERRACOTTA)
d = ImageDraw.Draw(img)

def px(v):
    return int(v * S)

# Headband: the top half of a circle joining the two ear cups.
cx, cy, r, band = 512, 520, 300, 58
d.arc([px(cx - r), px(cy - r), px(cx + r), px(cy + r)], start=180, end=360, fill=OFF_WHITE, width=px(band))

# Ear cups: the tallest bars of the wave, under the ends of the band.
cup_w, cup_top, cup_bottom = 124, 500, 790
for x in (cx - r, cx + r):
    d.rounded_rectangle([px(x - cup_w / 2), px(cup_top), px(x + cup_w / 2), px(cup_bottom)], radius=px(cup_w / 2), fill=OFF_WHITE)

# The sound wave between them, rising towards the cups.
heights = [150, 230, 120, 300, 120, 230, 150]
bar_w, gap = 36, 34
total = len(heights) * bar_w + (len(heights) - 1) * gap
x0 = cx - total / 2
mid = 645
for i, h in enumerate(heights):
    x = x0 + i * (bar_w + gap)
    d.rounded_rectangle([px(x), px(mid - h / 2), px(x + bar_w), px(mid + h / 2)], radius=px(bar_w / 2), fill=OFF_WHITE)

out = img.resize((1024, 1024), Image.LANCZOS)
out.save(sys.argv[1] if len(sys.argv) > 1 else "AppIcon.png")
