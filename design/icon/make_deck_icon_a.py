"""Poddeck app icon A "The deck" (Paul, 14 Nov 2026, with the Deck look):
three cards, blue #4C8DFF back-left, red #FF5A45 back-right, and a white
front card with an ink edge and an ink play triangle, on the warm #EEEBE5
tile. Same drawing as appIcon() in design/deck/poddeck-prototype.html.
Run: python3 design/icon/make_deck_icon_a.py  (needs rsvg-convert and Pillow)
Writes icon_deck_a.svg, icon_deck_a.png (1024), the app icon, docs/icon.png
(512) and the badge setting's small preview (IconPreview, 120).
Without rsvg-convert, the same SVG can be screenshotted with Playwright
(Chromium) at each size, as was done for build 154."""
import os, subprocess
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))

# Drawn on a 120 x 120 grid; iOS rounds the corners itself, so the tile is square.
SVG = '''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 120 120">
<rect width="120" height="120" fill="#EEEBE5"/>
<g transform="translate(60 62)">
<rect x="-24" y="-33" width="48" height="64" rx="11" transform="rotate(-14)" fill="#4C8DFF"/>
<rect x="-24" y="-33" width="48" height="64" rx="11" transform="rotate(10)" fill="#FF5A45"/>
<rect x="-24" y="-32" width="48" height="64" rx="11" fill="#FFFFFF" stroke="#1C1B1A" stroke-width="3.5"/>
<path d="M-8 -12v24l19-12z" fill="#1C1B1A"/>
</g>
</svg>
'''

def render(size, out):
    svg_path = os.path.join(HERE, 'icon_deck_a.svg')
    subprocess.run(['rsvg-convert', '-w', str(size), '-h', str(size), svg_path, '-o', out + '.tmp.png'], check=True)
    img = Image.open(out + '.tmp.png').convert('RGB')  # app icons have no transparency
    img.save(out)
    os.remove(out + '.tmp.png')

with open(os.path.join(HERE, 'icon_deck_a.svg'), 'w') as f:
    f.write(SVG)
render(1024, os.path.join(HERE, 'icon_deck_a.png'))
render(1024, os.path.join(ROOT, 'App', 'Assets.xcassets', 'AppIcon.appiconset', 'AppIcon.png'))
render(512, os.path.join(ROOT, 'docs', 'icon.png'))
for root, _, files in os.walk(os.path.join(ROOT, 'App', 'Assets.xcassets')):
    for name in files:
        if name.startswith('IconPreview') and name.endswith('.png'):
            render(120, os.path.join(root, name))
