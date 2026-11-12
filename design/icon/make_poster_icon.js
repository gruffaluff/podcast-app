// Poddeck app icon "W1b Warm white, fine edge" (Paul, 12 Nov 2026, for the
// Native warm look; W1 plus a thin warm-grey edge so the cassette doesn't get
// lost on the tile): a white cassette with spoked reels in an ink window, lifted by a
// soft shadow off the app's warm off-white, with the progress line (olive
// played, amber ad). Before it: "2b olive" (sand cassette on olive with the
// dot print), kept as poster_2b.png / .svg.
// Run: node design/icon/make_poster_icon.js  (uses the pre-installed Playwright)
// Writes icon_w1.svg, icon_w1.png (1024), the app icon and docs/icon.png (512).
const fs = require('fs'), path = require('path');
const { chromium } = require('playwright');
const AMBER = '#D9A441', OLIVE = '#45543A', PAGE = '#F5F2EC', WHITE = '#FFFFFF', INK = '#1C1B19';

function reel(cx, cy, r, col, w) {
  const sp = [0, 120, 240].map(a => { const t = (a - 90) * Math.PI / 180;
    return `M${cx + Math.cos(t) * r * .3} ${cy + Math.sin(t) * r * .3}L${cx + Math.cos(t) * r * .78} ${cy + Math.sin(t) * r * .78}`; }).join('');
  return `<circle cx="${cx}" cy="${cy}" r="${r}" fill="none" stroke="${col}" stroke-width="${w}"/><circle cx="${cx}" cy="${cy}" r="${r * .28}" fill="${col}"/><path d="${sp}" stroke="${col}" stroke-width="${w * .8}" stroke-linecap="round"/>`;
}
function line(x, y, w, h, played, track) {
  const g = h * .45, seg = [[0, .3], [.3, .45], [.45, 1]];
  return seg.map(([a, b], i) => {
    const x0 = x + w * a + (i ? g / 2 : 0), x1 = x + w * b - (i < 2 ? g / 2 : 0);
    const col = i === 0 ? played : i === 1 ? AMBER : track;
    return `<rect x="${x0}" y="${y}" width="${x1 - x0}" height="${h}" rx="${h / 2}" fill="${col}"/>`;
  }).join('');
}
function cassette(x, y, w, body, hole) {
  const h = w * .66, r = w * .1;
  const wx = x + w * .11, wy = y + h * .14, ww = w * .78, wh = h * .45;
  return `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${r}" fill="none" stroke="#CFC6B4" stroke-width="2.4"/>`
    + `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${r}" fill="${body}"/>`
    + `<rect x="${wx}" y="${wy}" width="${ww}" height="${wh}" rx="${wh * .22}" fill="${hole}"/>`
    + reel(x + w * .31, wy + wh / 2, wh * .36, body, wh * .1) + reel(x + w * .69, wy + wh / 2, wh * .36, body, wh * .1)
    + line(x + w * .2, y + h * .72, w * .6, h * .1, OLIVE, 'rgba(0,0,0,.14)');
}
const x = 14, y = 26, w = 72;
const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="1024" height="1024">
<defs><filter id="soft" x="-20%" y="-20%" width="140%" height="160%"><feGaussianBlur stdDeviation="2.2"/></filter></defs>
<rect width="100" height="100" fill="${PAGE}"/>
<rect x="${x}" y="${y + 2.5}" width="${w}" height="${w * .66}" rx="${w * .1}" fill="rgba(60,45,20,.3)" filter="url(#soft)"/>
${cassette(x, y, w, WHITE, INK)}
</svg>`;
const here = __dirname, root = path.join(here, '..', '..');
fs.writeFileSync(path.join(here, 'icon_w1.svg'), svg);
(async () => {
  const b = await chromium.launch();
  for (const [size, out] of [[1024, path.join(here, 'icon_w1.png')], [1024, path.join(root, 'App/Assets.xcassets/AppIcon.appiconset/AppIcon.png')], [512, path.join(root, 'docs/icon.png')]]) {
    const p = await b.newPage({ viewport: { width: size, height: size }, deviceScaleFactor: 1 });
    await p.setContent(`<html><body style="margin:0">${svg.replace('width="1024" height="1024"', `width="${size}" height="${size}"`)}</body></html>`);
    await p.screenshot({ path: out, omitBackground: false });
    await p.close();
  }
  await b.close();
})();
