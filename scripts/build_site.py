#!/usr/bin/env python3
"""Makes the public website (docs/index.html, served by GitHub Pages at
poddeck.uk) from website/poddeck.html, the same file published as the
claude.ai page. Edit website/poddeck.html, then run this script.

The claude.ai page is wrapped in its own <html>/<head>/<body> when it is
published; a normal web host needs them in the file, plus a favicon and
the preview card details that link previews (iMessage, WhatsApp) read.
"""
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "website" / "poddeck.html"
OUT = ROOT / "docs" / "index.html"
SITE = "https://poddeck.uk"

page = SOURCE.read_text(encoding="utf-8")
title_end = page.index("</title>") + len("</title>")
head_bits, body = page[:title_end], page[title_end:]

# Everything before the first <style> or element that belongs in <head>.
style_at = body.index("<style>")
style_end = body.index("</style>") + len("</style>")
head_extra = body[:style_end]
body = body[style_end:]

head = f"""<!doctype html>
<html lang="en-GB">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
{head_bits}
<link rel="icon" type="image/png" href="icon.png">
<link rel="apple-touch-icon" href="icon.png">
<link rel="canonical" href="{SITE}/">
<meta property="og:type" content="website">
<meta property="og:url" content="{SITE}/">
<meta property="og:title" content="Poddeck: a podcast app you run, not rent">
<meta property="og:description" content="Transcripts, ad skipping, smart speed and a queue that keeps every show in order, all on your iPhone. No subscription, no account, no ads.">
<meta property="og:image" content="{SITE}/icon.png">
<meta name="twitter:card" content="summary">
<meta name="theme-color" content="#E9E3D5">
{head_extra}
<style>
:root {{ padding-top: env(safe-area-inset-top, 0px); padding-bottom: env(safe-area-inset-bottom, 0px); }}
body {{ margin: 0; }}
img {{ max-width: 100%; }}
[hidden] {{ display: none !important; }}
</style>
</head>
<body>
"""
OUT.write_text(head + body.strip() + "\n</body>\n</html>\n", encoding="utf-8")
# Screenshots used by the page (website/shots → docs/shots).
shots = ROOT / "website" / "shots"
if shots.is_dir():
    shutil.copytree(shots, ROOT / "docs" / "shots", dirs_exist_ok=True)
print(f"Wrote {OUT.relative_to(ROOT)} from {SOURCE.relative_to(ROOT)}")
