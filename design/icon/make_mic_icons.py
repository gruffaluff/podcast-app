"""Reel-to-reel combined with a microphone (Paul, 5 Nov 2026, after E).
Writes mic_I.png ... mic_L.png and mic_options.png (with E for comparison)."""
from PIL import Image, ImageDraw, ImageFont
import os
from make_tape_icons import reel, S, SAND, PAPER, INK, OLIVE, DEEP, AMBER, FONT, HERE


def mic(d, cx, top, w, h, body=PAPER, grille=DEEP, stand=PAPER, stem=120, yoke=True):
    """A studio microphone: capsule head with grille slots, yoke, stem."""
    d.rounded_rectangle([cx - w / 2, top, cx + w / 2, top + h], radius=w / 2, fill=body)
    for k in range(1, 5):
        y = top + h * 0.12 + k * h * 0.13
        d.rounded_rectangle([cx - w * 0.3, y, cx + w * 0.3, y + h * 0.045], radius=h * 0.02, fill=grille)
    if yoke:
        lw = int(w * 0.12)
        d.arc([cx - w * 0.78, top + h * 0.25, cx + w * 0.78, top + h * 1.12], 0, 180, fill=stand, width=lw)
        y0 = top + h * 1.12
    else:
        y0 = top + h
    d.rectangle([cx - w * 0.07, y0 - 4, cx + w * 0.07, y0 + stem], fill=stand)
    return y0 + stem


def tape_into_mic():
    """I: two reels on top, the tape runs down into a mic standing between them."""
    im = Image.new("RGB", (S, S), OLIVE)
    d = ImageDraw.Draw(im)
    d.line([(250, 470), (512, 600), (774, 470)], fill=INK, width=14, joint="curve")
    reel(d, 250, 330, 170, holes=OLIVE, hub=PAPER, tape=DEEP)
    reel(d, 774, 330, 170, holes=OLIVE, hub=PAPER, tape=DEEP)
    bottom = mic(d, 512, 480, 150, 250, body=AMBER, grille=INK, stand=PAPER, stem=60)
    d.rounded_rectangle([400, bottom, 624, bottom + 34], radius=17, fill=PAPER)
    return im


def reel_head_mic():
    """J: a big studio mic whose head is a tape reel."""
    im = Image.new("RGB", (S, S), OLIVE)
    d = ImageDraw.Draw(im)
    cx, cy, r = 512, 400, 230
    # Yoke round the reel, then stem and base.
    d.arc([cx - r - 50, cy - 40, cx + r + 50, cy + r + 70], 0, 180, fill=PAPER, width=34)
    d.rectangle([cx - 18, cy + r + 50, cx + 18, 820], fill=PAPER)
    d.rounded_rectangle([cx - 150, 800, cx + 150, 846], radius=23, fill=INK)
    reel(d, cx, cy, r, body=PAPER, hub=DEEP, holes=SAND, tape="#5A6B4C")
    return im


def mic_between_reels():
    """K: reel-to-reel deck panel with a mic as the record head."""
    im = Image.new("RGB", (S, S), OLIVE)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([80, 130, S - 80, 894], radius=90, fill=INK)
    d.line([(300, 560), (420, 690), (604, 690), (724, 560)], fill=AMBER, width=12, joint="curve")
    reel(d, 300, 400, 160, body=PAPER, hub=AMBER, holes=INK, tape=DEEP)
    reel(d, 724, 400, 160, body=PAPER, hub=AMBER, holes=INK, tape=DEEP)
    mic(d, 512, 600, 96, 170, body=PAPER, grille=INK, stand=PAPER, stem=40, yoke=False)
    d.rounded_rectangle([440, 810, 584, 836], radius=13, fill=PAPER)
    return im


def mic_with_reel_ear():
    """L: a bold microphone, one small reel spinning beside it like a sound."""
    im = Image.new("RGB", (S, S), DEEP)
    d = ImageDraw.Draw(im)
    bottom = mic(d, 420, 170, 280, 440, body=PAPER, grille=DEEP, stand=PAPER, stem=110)
    d.rounded_rectangle([260, bottom, 580, bottom + 48], radius=24, fill=PAPER)
    d.line([(580, 360), (700, 520)], fill=AMBER, width=14)
    reel(d, 760, 600, 150, body=AMBER, hub=PAPER, holes=DEEP, tape=OLIVE)
    return im


def main():
    options = [("E", "Reel-to-reel", Image.open(os.path.join(HERE, "tape_E.png")).convert("RGB")),
               ("I", "Tape into mic", tape_into_mic()), ("J", "Reel mic", reel_head_mic()),
               ("K", "Deck with mic", mic_between_reels()), ("L", "Mic + reel", mic_with_reel_ear())]
    tile, pad = 260, 36
    sheet = Image.new("RGB", (pad + len(options) * (tile + pad), tile + 2 * pad + 56), SAND)
    sd = ImageDraw.Draw(sheet)
    font = ImageFont.truetype(FONT, 22)
    for i, (key, name, icon) in enumerate(options):
        if key != "E":
            icon.save(os.path.join(HERE, f"mic_{key}.png"))
        small = icon.resize((tile, tile), Image.LANCZOS)
        mask = Image.new("L", (tile, tile), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, tile, tile], radius=int(tile * 0.225), fill=255)
        x = pad + i * (tile + pad)
        sheet.paste(small, (x, pad), mask)
        sd.text((x + tile / 2, pad + tile + 30), f"{key} · {name}", font=font, fill=INK, anchor="mm")
    sheet.save(os.path.join(HERE, "mic_options.png"))


if __name__ == "__main__":
    main()
