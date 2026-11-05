"""Icon options for the "middle ground" look (5 Nov 2026).
Writes middle_A.png ... middle_D.png (1024 px) and middle_options.png."""
from PIL import Image, ImageDraw, ImageFont
import os

S = 1024
SAND, PAPER, INK, OLIVE, DEEP, AMBER = "#E9E3D5", "#F6F2E9", "#1F1D19", "#45543A", "#2F3A27", "#D9A441"
HERE = os.path.dirname(os.path.abspath(__file__))
FONT = "/usr/share/fonts/opentype/inter/Inter-Black.otf"


def wave():
    im = Image.new("RGB", (S, S), OLIVE)
    d = ImageDraw.Draw(im)
    heights = [0.30, 0.52, 0.78, 0.46, 0.92, 0.64, 0.38, 0.70, 0.50]
    n, gap = len(heights), 26
    w = (S - 2 * 150 - gap * (n - 1)) / n
    for i, h in enumerate(heights):
        x = 150 + i * (w + gap)
        hh = h * 600
        colour = AMBER if i == 4 else PAPER
        d.rounded_rectangle([x, S / 2 - hh / 2, x + w, S / 2 + hh / 2], radius=w / 2, fill=colour)
    return im


def cards():
    im = Image.new("RGB", (S, S), SAND)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([110, 640, S - 110, S + 200], radius=110, fill=PAPER)
    d.rounded_rectangle([-40, -300, S + 40, 690], radius=260, fill=OLIVE)
    d.polygon([(420, 250), (420, 520), (650, 385)], fill=PAPER)
    d.rounded_rectangle([250, 760, 770, 800], radius=20, fill="#D6CEBD")
    d.rounded_rectangle([250, 840, 640, 880], radius=20, fill="#D6CEBD")
    return im


def letter():
    im = Image.new("RGB", (S, S), OLIVE)
    big = Image.new("L", (S * 2, S * 2), 0)
    bd = ImageDraw.Draw(big)
    font = ImageFont.truetype(FONT, 1500)
    bd.text((S, S), "P", font=font, fill=255, anchor="mm")
    bbox = big.getbbox()
    glyph = big.crop(bbox)
    gw, gh = glyph.size
    target_h = 640
    glyph = glyph.resize((int(gw * target_h / gh * 0.72), target_h))
    im.paste(PAPER, ((S - glyph.width) // 2 - 20, (S - target_h) // 2), glyph)
    d = ImageDraw.Draw(im)
    d.ellipse([700, 650, 800, 750], fill=AMBER)
    return im


def cassette():
    im = Image.new("RGB", (S, S), SAND)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([120, 250, S - 120, 790], radius=70, fill=OLIVE)
    d.rounded_rectangle([200, 320, S - 200, 600], radius=40, fill=PAPER)
    for cx in (370, S - 370):
        d.ellipse([cx - 90, 370, cx + 90, 550], fill=DEEP)
        d.ellipse([cx - 40, 420, cx + 40, 500], fill=AMBER)
    d.polygon([(260, 790), (330, 680), (S - 330, 680), (S - 260, 790)], fill=DEEP)
    return im


def main():
    options = [("A", "Sound wave", wave()), ("B", "Card over card", cards()), ("C", "Big P", letter()), ("D", "Cassette, recoloured", cassette())]
    tile, pad = 300, 40
    sheet = Image.new("RGB", (pad + len(options) * (tile + pad), tile + 2 * pad + 60), SAND)
    sd = ImageDraw.Draw(sheet)
    label_font = ImageFont.truetype(FONT, 26)
    for i, (key, name, icon) in enumerate(options):
        icon.save(os.path.join(HERE, f"middle_{key}.png"))
        small = icon.resize((tile, tile), Image.LANCZOS)
        mask = Image.new("L", (tile, tile), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, tile, tile], radius=int(tile * 0.225), fill=255)
        x = pad + i * (tile + pad)
        sheet.paste(small, (x, pad), mask)
        sd.text((x + tile / 2, pad + tile + 34), f"{key} · {name}", font=label_font, fill=INK, anchor="mm")
    sheet.save(os.path.join(HERE, "middle_options.png"))


if __name__ == "__main__":
    main()
