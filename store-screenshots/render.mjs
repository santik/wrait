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
    canvas: [1080, 1920], viewport: [411.43, 914.29], frameWidth: 740,
    caption: { size: 68, top: 90 },
  },
  tablet: {
    element: 'android-tablet', script: 'android-tablet.js',
    canvas: [1600, 2560], viewport: [800, 1280], frameWidth: 1360,
    caption: { size: 92, top: 120 },
  },
};

// `mode` is the Telephone status-bar text color; the others style the canvas.
const themes = {
  dark: { mode: 'dark', canvas: '#0F0F0D', caption: '#EDE9E3' },
  light: { mode: 'light', canvas: '#F0EDE8', caption: '#2C2B27' },
};

// id, html file (+query)
const screens = [
  { id: 'main', file: 'main.html' },
  { id: 'listening', file: 'listening.html?pulse=.7&progress=.85' },
  { id: 'entries', file: 'entries.html' },
  { id: 'settings', file: 'settings.html' },
  { id: 'feedback', file: 'feedback.html' },
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
      const caption = strings.captions?.[screen.id] ?? '';
      await writeFile(frameFile, `<!doctype html><html lang="${tag}"><head><meta charset="utf-8"><style>
        * { box-sizing: border-box; }
        html, body { margin: 0; width: ${W}px; height: ${H}px; }
        body { display: flex; flex-direction: column; align-items: center; background: ${theme.canvas};
               font-family: Roboto, -apple-system, 'Noto Sans', sans-serif; }
        h1 { margin: ${device.caption.top}px 70px 0; font-size: ${device.caption.size}px; line-height: 1.15;
             font-weight: 700; text-align: center; text-wrap: balance; color: ${theme.caption}; }
        ${device.element} { display: block; width: ${device.frameWidth}px; margin-top: ${deviceName === 'phone' ? 44 : 70}px; }
        .screen { width: 100%; height: 100%; overflow: hidden; }
        iframe { width: ${vw}px; height: ${vh}px; border: 0; transform-origin: 0 0; display: block; }
      </style></head><body>
        <h1>${caption}</h1>
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
