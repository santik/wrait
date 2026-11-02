// Renders each html/*.html at the real device size (1080x2400) with the
// system bars shown, next to the matching real screenshot, so the replicas
// can be checked by eye.   node compare.mjs   ->  out/compare/<screen>.png
import { mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';
import { chromium } from 'playwright';

const root = path.dirname(fileURLToPath(import.meta.url));
const real = path.join(root, '..', 'real_screenshots', 'android');
const outDir = path.join(root, 'out', 'compare');

// theme -> screen id -> [html file + query, real screenshot]
const pairs = {
  dark: {
    main: ['main.html', 'Screenshot_20261011-094827.png'],
    settings: ['settings.html', 'Screenshot_20261011-094835.png'],
    entries: ['entries.html', 'Screenshot_20261011-094912.png'],
    'listening-wide': ['listening.html?pulse=1&progress=.88', 'Screenshot_20261011-094932.png'],
    listening: ['listening.html?pulse=0&progress=.9', 'Screenshot_20261011-094934.png'],
    feedback: ['feedback.html', 'Screenshot_20261011-095625.png'],
  },
  light: {
    main: ['main.html', 'Screenshot_20261011-174413 (1).png'],
    settings: ['settings.html', 'Screenshot_20261011-174506.png'],
    entries: ['entries.html', 'Screenshot_20261011-174421.png'],
    'listening-wide': ['listening.html?pulse=1&progress=.88', 'Screenshot_20261011-174436 (1).png'],
    feedback: ['feedback.html', 'Screenshot_20261011-174441.png'],
  },
};

await mkdir(outDir, { recursive: true });
const browser = await chromium.launch();
const DSF = 1080 / 411.43;
const page = await browser.newPage({ viewport: { width: 412, height: 915 }, deviceScaleFactor: DSF });
const sheet = await browser.newPage({ viewport: { width: 1080, height: 1200 } });

for (const [theme, set] of Object.entries(pairs)) for (const [id0, [file, realFile]] of Object.entries(set)) {
  const id = `${theme}-${id0}`;
  const [name, query = ''] = file.split('?');
  await page.goto(pathToFileURL(path.join(root, 'html', name)).href + `?${query}&system=1&theme=${theme}`);
  await page.evaluate(() => document.fonts.ready);
  const replica = path.join(outDir, `${id}-replica.png`);
  await page.screenshot({ path: replica, clip: { x: 0, y: 0, width: 411.43, height: 914.29 } });

  const html = `<body style="margin:0;display:flex;gap:0;background:#444">
    <img src="${pathToFileURL(path.join(real, realFile)).href}" width="540">
    <img src="${pathToFileURL(replica).href}" width="540"></body>`;
  await writeFile(path.join(outDir, `${id}.html`), html);
  await sheet.goto(pathToFileURL(path.join(outDir, `${id}.html`)).href);
  await sheet.screenshot({ path: path.join(outDir, `${id}.png`), clip: { x: 0, y: 0, width: 1080, height: 1200 } });
  console.log(id);
}
await browser.close();
