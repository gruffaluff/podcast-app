"""More tape icons after Paul liked D (5 Nov 2026): reel-to-reel and
cassette variations. Writes tape_E.png ... tape_H.png and tape_options.png
(with D from make_middle_icons.py for comparison)."""
from PIL import Image, ImageDraw, ImageFont
import math, os

S = 1024
SAND, PAPER, INK, OLIVE, DEEP, AMBER, LINE = "#E9E3D5", "#F6F2E9", "#1F1D19", "#45543A", "#2F3A27", "#D9A441", "#D6CEBD"
HERE = os.path.dirname(os.path.abspath(__file__))
FONT = "/usr/share/fonts/opentype/inter/Inter-Black.otf"


def reel(d, cx, cy, r, body=PAPER, hub=OLIVE, holes=DEEP, tape=None):
    if tape:
        d.ellipse([cx - r * 0.82, cy - r * 0.82, cx + r * 0.82, cy + r * 0.82], fill=tape)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=body, width=int(r * 0.09))
    for k in range(3):
        a = math.radians(90 + k * 120)
        hx, hy = cx + math.cos(a) * r * 0.52, cy - math.sin(a) * r * 0.52
        d.ellipse([hx - r * 0.2, hy - r * 0.2, hx + r * 0.2, hy + r * 0.2], fill=holes)
    d.ellipse([cx - r * 0.22, cy - r * 0.22, cx + r * 0.22, cy + r * 0.22], fill=hub)
    d.ellipse([cx - r * 0.08, cy - r * 0.08, cx + r * 0.08, cy + r * 0.08], fill=AMBER)


def reel_to_reel():
    im = Image.new("RGB", (S, S), OLIVE)
    d = ImageDraw.Draw(im)
    # Tape path between the two big reels, over the head.
    d.line([(290, 600), (512, 800), (734, 600)], fill=INK, width=14, joint="curve")
    d.rounded_rectangle([457, 770, 567, 840], radius=14, fill=AMBER)
    reel(d, 290, 400, 200, holes=OLIVE, hub=PAPER, tape=DEEP)
    reel(d, 734, 400, 200, holes=OLIVE, hub=PAPER, tape=DEEP)
    return im


def single_reel():
    im = Image.new("RGB", (S, S), SAND)
    d = ImageDraw.Draw(im)
    d.ellipse([112, 112, 912, 912], fill=OLIVE)
    reel(d, 512, 512, 330, body=PAPER, hub=DEEP, holes=SAND, tape="#5A6B4C")
    # Tape leaving the reel.
    d.polygon([(512, 842), (1024, 842), (1024, 870), (512, 870)], fill=INK)
    return im


def cassette_tilt():
    im = Image.new("RGB", (S, S), OLIVE)
    shell = Image.new("RGBA", (860, 560), (0, 0, 0, 0))
    d = ImageDraw.Draw(shell)
    d.rounded_rectangle([0, 0, 860, 560], radius=60, fill=SAND)
    d.rounded_rectangle([60, 60, 800, 330], radius=34, fill=PAPER)
    d.rectangle([60, 60, 800, 110], fill=AMBER)
    for cx in (250, 610):
        d.ellipse([cx - 80, 140, cx + 80, 300], fill=DEEP)
        d.ellipse([cx - 32, 188, cx + 32, 252], fill=SAND)
    d.polygon([(150, 560), (220, 430), (640, 430), (710, 560)], fill=LINE)
    shell = shell.rotate(-12, resample=Image.BICUBIC, expand=True)
    im.paste(shell, ((S - shell.width) // 2, (S - shell.height) // 2), shell)
    return im


def cassette_label():
    im = Image.new("RGB", (S, S), SAND)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([90, 230, S - 90, 810], radius=80, fill=INK)
    d.rounded_rectangle([160, 290, S - 160, 590], radius=40, fill=OLIVE)
    d.rounded_rectangle([160, 290, S - 160, 360], radius=40, fill=AMBER)
    d.rectangle([160, 330, S - 160, 360], fill=AMBER)
    d.rounded_rectangle([300, 420, S - 300, 540], radius=60, fill=DEEP)
    for cx in (370, S - 370):
        d.ellipse([cx - 52, 428, cx + 52, 532], fill=PAPER)
        d.ellipse([cx - 20, 460, cx + 20, 500], fill=DEEP)
    d.polygon([(250, 810), (320, 680), (S - 320, 680), (S - 250, 810)], fill="#3A3833")
    return im


def main():
    options = [("D", "Cassette (first pick)", Image.open(os.path.join(HERE, "middle_D.png")).convert("RGB")),
               ("E", "Reel-to-reel", reel_to_reel()), ("F", "Big reel", single_reel()),
               ("G", "Tilted cassette", cassette_tilt()), ("H", "Ink cassette", cassette_label())]
    tile, pad = 260, 36
    sheet = Image.new("RGB", (pad + len(options) * (tile + pad), tile + 2 * pad + 56), SAND)
    sd = ImageDraw.Draw(sheet)
    label_font = ImageFont.truetype(FONT, 22)
    for i, (key, name, icon) in enumerate(options):
        if key != "D":
            icon.save(os.path.join(HERE, f"tape_{key}.png"))
        small = icon.resize((tile, tile), Image.LANCZOS)
        mask = Image.new("L", (tile, tile), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, tile, tile], radius=int(tile * 0.225), fill=255)
        x = pad + i * (tile + pad)
        sheet.paste(small, (x, pad), mask)
        sd.text((x + tile / 2, pad + tile + 30), f"{key} · {name}", font=label_font, fill=INK, anchor="mm")
    sheet.save(os.path.join(HERE, "tape_options.png"))


if __name__ == "__main__":
    main()
