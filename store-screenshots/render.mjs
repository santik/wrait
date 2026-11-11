// Localized store screenshots: html/*.html screens inside a device frame
// (https://sneas.github.io/telephone) with a caption.
//
//   node render.mjs                       # every device x theme x locale
//   node render.mjs de-DE ja-JP           # selected locales
//   node render.mjs --phone --light       # one device / one theme
//   SCREENS=main,entries node render.mjs
//
// Flags: --phone --tablet (devices), --dark --light (themes); none = all.
// Output: out/<device>/<theme>/<locale>/<locale>_<device>_<theme>_0N-<screen>.png
//         phone 1080x1920, tablet 1600x2560
import { readdir, readFile, mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';
import { chromium } from 'playwright';

const root = path.dirname(fileURLToPath(import.meta.url));

// Viewport sizes are in dp. `frame` is the Telephone element and the device
// width inside the canvas; `slot` is its screen area relative to the frame.
const devices = {
  phone: {
    element: 'pixel-9-pro', script: 'pixel-9-pro.js',
    canvas: [1080, 1920], viewport: [411.43, 914.29], frameWidth: 700,
    caption: { size: 64, top: 70, deviceTop: 26 },
  },
  tablet: {
    element: 'android-tablet', script: 'android-tablet.js',
    canvas: [1600, 2560], viewport: [800, 1280], frameWidth: 1360,
    caption: { size: 92, top: 104, deviceTop: 56 },
  },
};

// `mode` is the Telephone status-bar glyph color (matches the app UI inside the
// device). `head`/`sub` are the headline / subheadline colors, chosen to suit
// the gradient the app set sits on: the uploaded dark-app set sits on warm,
// light gradients (dark text); the light-app set sits on charcoal gradients
// (light text). Per-screen gradient stops live in `backgrounds` below.
const themes = {
  dark: { mode: 'dark', head: '#2C2B27', sub: '#5C5953' },
  light: { mode: 'light', head: '#EDE9E3', sub: '#A8A4A0' },
};

// Subtle per-screen gradient stops, drawn from the Wrait palette (warm creams /
// charcoals) — no off-brand colors. `dark` is the dark-app (uploaded) set on
// warm light gradients so the dark device frame stands out; `light` is the
// light-app set on charcoal gradients. Keyed by screen id.
const backgrounds = {
  'main':      { dark: '#F7F4EF, #E4DDD1', light: '#30302B, #15140F' },
  'listening': { dark: '#F1EBE2, #D3C9B8', light: '#2B302E, #131512' },
  'entries':   { dark: '#F3EEE6, #DAD1C1', light: '#302E2A, #16130F' },
  'languages': { dark: '#EDE7DD, #CEC4B2', light: '#2C302F, #121413' },
  'app-lock':  { dark: '#EAE4DA, #CBC1AF', light: '#2A2926, #121110' },
  'privacy':   { dark: '#F4EFE8, #DDD5C7', light: '#302F2B, #15140F' },
};

// id, html file (+query). 4-slot set (spec 057, revised). `listening` is the
// hero — it shows the app actively recording (more complete than the idle main
// screen, which was dropped as redundant). `app-lock` reuses the settings
// screen with the lock toggle on. The old `privacy` slot (a reworded entries
// screen) was removed as duplicate. main/privacy copy + backgrounds are kept
// for easy re-add but are no longer rendered. settings/feedback are not
// standalone screenshots.
const screens = [
  { id: 'listening', file: 'listening.html?pulse=.7&progress=.85' },
  { id: 'entries', file: 'entries.html' },
  { id: 'languages', file: 'languages.html' },
  { id: 'app-lock', file: 'settings.html?applock=on' },
];

const args = process.argv.slice(2);
const flags = args.filter((a) => a.startsWith('--'));
const wanted = args.filter((a) => !a.startsWith('--'));
const pick = (names, all) => (names.some((n) => flags.includes(`--${n}`))
  ? all.filter((n) => flags.includes(`--${n}`)) : all);
const deviceNames = pick(['phone', 'tablet'], ['phone', 'tablet']);
const themeNames = pick(['dark', 'light'], ['dark', 'light']);
const only = process.env.SCREENS?.split(',');

const available = (await readdir(path.join(root, 'locales')))
  .filter((f) => f.endsWith('.json'))
  .map((f) => f.replace('.json', ''));
const locales = wanted.length ? wanted : available;

const browser = await chromium.launch();
const frameFile = path.join(root, 'out', '_frame.html');
await mkdir(path.dirname(frameFile), { recursive: true });

for (const deviceName of deviceNames) for (const themeName of themeNames) {
  const device = devices[deviceName];
  const theme = themes[themeName];
  const [W, H] = device.canvas;
  const [vw, vh] = device.viewport;
  const telephoneJs = await readFile(
    path.join(root, 'node_modules/@sneas/telephone', device.script), 'utf8');

  for (const tag of locales) {
    const strings = JSON.parse(await readFile(path.join(root, 'locales', `${tag}.json`), 'utf8'));
    const context = await browser.newContext({ viewport: { width: W, height: H } });
    // Runs in the page and in the iframe, before the screen's own scripts.
    await context.addInitScript(({ strings, tag }) => {
      window.WRAIT_STRINGS = strings;
      window.WRAIT_LOCALE = tag;
    }, { strings, tag });
    const page = await context.newPage();
    const outDir = path.join(root, 'out', deviceName, themeName, tag);
    await mkdir(outDir, { recursive: true });

    for (const [i, screen] of screens.entries()) {
      if (only && !only.includes(screen.id)) continue;
      const [name, query = ''] = screen.file.split('?');
      const size = (deviceName === 'phone' ? '' : `&w=${vw}&h=${vh}`) + `&theme=${themeName}`;
      const src = pathToFileURL(path.join(root, 'html', name)).href + `?${query}${size}`;
      const headline = strings.headlines?.[screen.id] ?? '';
      const subheadline = strings.subheadlines?.[screen.id] ?? '';
      const grad = backgrounds[screen.id]?.[themeName] ?? '#F0EDE8, #E6E3DE';
      const headSize = device.caption.size;
      const subSize = Math.round(headSize * 0.5);
      await writeFile(frameFile, `<!doctype html><html lang="${tag}"><head><meta charset="utf-8"><style>
        @import url('../node_modules/@fontsource/roboto/500.css');
        @import url('../node_modules/@fontsource/roboto/700.css');
        @import url('../node_modules/@fontsource/noto-sans-jp/500.css');
        @import url('../node_modules/@fontsource/noto-sans-jp/700.css');
        @import url('../node_modules/@fontsource/noto-sans-kr/500.css');
        @import url('../node_modules/@fontsource/noto-sans-kr/700.css');
        * { box-sizing: border-box; }
        html, body { margin: 0; width: ${W}px; height: ${H}px; overflow: hidden; }
        body { display: flex; flex-direction: column; align-items: center;
               background: linear-gradient(165deg, ${grad});
               font-family: 'Roboto', 'Noto Sans JP', 'Noto Sans KR', 'Noto Sans', sans-serif; }
        h1 { margin: ${device.caption.top}px 70px 0; font-size: ${headSize}px; line-height: 1.12;
             font-weight: 700; letter-spacing: -0.5px; text-align: center; text-wrap: balance; color: ${theme.head}; }
        p.sub { margin: ${Math.round(subSize * 0.5)}px 80px 0; font-size: ${subSize}px; line-height: 1.25;
             font-weight: 500; text-align: center; text-wrap: balance; color: ${theme.sub}; }
        ${device.element} { display: block; width: ${device.frameWidth}px; margin-top: ${device.caption.deviceTop}px; }
        .screen { width: 100%; height: 100%; overflow: hidden; }
        iframe { width: ${vw}px; height: ${vh}px; border: 0; transform-origin: 0 0; display: block; }
      </style></head><body>
        <h1>${headline}</h1>
        ${subheadline ? `<p class="sub">${subheadline}</p>` : ''}
        <${device.element} mode="${theme.mode}"><div class="screen"><iframe id="app" src="${src}"></iframe></div></${device.element}>
      </body></html>`);
      await page.goto(pathToFileURL(frameFile).href);
      await page.addScriptTag({ content: telephoneJs });
      await page.evaluate((vw) => {
        const iframe = document.getElementById('app');
        iframe.style.transform = `scale(${iframe.parentElement.clientWidth / vw})`;
      }, vw);
      const frame = page.frames().find((f) => f !== page.mainFrame());
      await frame.waitForLoadState('load');
      await frame.evaluate(() => document.fonts.ready);
      const file = path.join(
        outDir,
        `${tag}_${deviceName}_${themeName}_${String(i + 1).padStart(2, '0')}-${screen.id}.png`,
      );
      await page.screenshot({ path: file });
      console.log(path.relative(root, file));
    }
    await context.close();
  }
}
await browser.close();
