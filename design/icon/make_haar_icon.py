"""Poddeck app icon "P1 Cassette in the haar" (Paul, 13 Nov 2026, for the
Haar look): Poddeck's cassette in deep blue, half lost behind two bands of
fog, on a misty grey tile. Mock-ups: https://claude.ai/artifact/MyaR1XmhaAy6Vf17WGv2i7
(board "Poddeck icons in the Haar look").
Run: python3 design/icon/make_haar_icon.py  (needs rsvg-convert and Pillow)
Writes icon_p1.svg, icon_p1.png (1024), the app icon, docs/icon.png (512)
and the badge setting's small preview (IconPreview, 120)."""
import os, subprocess
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
DEEP, MIST = '#2B4766', '#D6DCE0'

# Drawn on a 100 x 100 grid; iOS rounds the corners itself, so the tile is square.
SVG = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 100 100">
<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#E1E5E7"/><stop offset="1" stop-color="#BCC6CD"/></linearGradient>
<filter id="soft" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="0.6"/></filter></defs>
<rect width="100" height="100" fill="url(#g)"/>
<rect x="14" y="24" width="72" height="50" rx="10" fill="{DEEP}"/>
<rect x="24" y="33" width="52" height="20" rx="6" fill="{MIST}"/>
<circle cx="38" cy="43" r="6" fill="{DEEP}"/><circle cx="62" cy="43" r="6" fill="{DEEP}"/>
<rect x="38" y="41" width="24" height="4" fill="{DEEP}"/>
<g filter="url(#soft)">
<rect x="8" y="56" width="58" height="7" rx="3.5" fill="#FFFFFF" fill-opacity="0.92"/>
<rect x="36" y="68" width="56" height="7" rx="3.5" fill="#FFFFFF" fill-opacity="0.72"/>
</g>
</svg>
'''

def render(size, out):
    svg_path = os.path.join(HERE, 'icon_p1.svg')
    subprocess.run(['rsvg-convert', '-w', str(size), '-h', str(size), svg_path, '-o', out + '.tmp.png'], check=True)
    img = Image.open(out + '.tmp.png').convert('RGB')  # app icons have no transparency
    img.save(out)
    os.remove(out + '.tmp.png')

with open(os.path.join(HERE, 'icon_p1.svg'), 'w') as f:
    f.write(SVG)
render(1024, os.path.join(HERE, 'icon_p1.png'))
render(1024, os.path.join(ROOT, 'App', 'Assets.xcassets', 'AppIcon.appiconset', 'AppIcon.png'))
render(512, os.path.join(ROOT, 'docs', 'icon.png'))
for root, _, files in os.walk(os.path.join(ROOT, 'App', 'Assets.xcassets')):
    for name in files:
        if name.startswith('IconPreview') and name.endswith('.png'):
            render(120, os.path.join(root, name))
print('done')
