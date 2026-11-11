// Contract checks for the redesigned store screenshots (spec 057).
//   node scripts/validate-locales.mjs            # checks locales + out/phone/dark
//   node scripts/validate-locales.mjs --theme light
//
// Verifies, with no external deps:
//   - every locale JSON has headlines + subheadlines for exactly the 6 screen ids
//   - every headline is <= 8 words (CJK locales checked by character length)
//   - the rendered phone PNGs: exactly 6 per locale, named 01-main..06-privacy,
//     each 1080x1920 and < 1 MB
import { readdir, readFile, stat } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const argv = process.argv;
const theme = argv.includes('--theme') ? argv[argv.indexOf('--theme') + 1] : 'dark';
const device = argv.includes('--device') ? argv[argv.indexOf('--device') + 1] : 'phone';
const DIMS = { phone: [1080, 1920], tablet: [1600, 2560] };
const [EXP_W, EXP_H] = DIMS[device] ?? DIMS.phone;

// Active render set (spec 057, revised to 4). Retired ids (main, privacy) may
// still have copy in the locale files — that's allowed, just not rendered.
const SCREENS = ['listening', 'entries', 'languages', 'app-lock'];
const MAX_WORDS = 8;      // non-CJK headlines
const MAX_CJK_CHARS = 16; // CJK headlines (no word spaces)
const CJK = new Set(['ja-JP', 'ko-KR', 'zh-CN', 'zh-TW']);
const MAX_BYTES = 1024 * 1024;

const problems = [];
const fail = (m) => problems.push(m);

// PNG IHDR: width at byte offset 16, height at 20 (big-endian).
async function pngSize(file) {
  const buf = await readFile(file);
  if (buf.length < 24 || buf.readUInt32BE(0) !== 0x89504e47) return null;
  return { w: buf.readUInt32BE(16), h: buf.readUInt32BE(20) };
}

const tags = (await readdir(path.join(root, 'locales')))
  .filter((f) => f.endsWith('.json')).map((f) => f.replace('.json', ''));

// --- locale strings ---
for (const tag of tags) {
  const j = JSON.parse(await readFile(path.join(root, 'locales', `${tag}.json`), 'utf8'));
  if ('captions' in j) fail(`${tag}: stale "captions" key still present`);
  for (const map of ['headlines', 'subheadlines']) {
    if (!j[map]) { fail(`${tag}: missing "${map}"`); continue; }
    for (const id of SCREENS) if (!(id in j[map])) fail(`${tag}.${map}: missing id "${id}"`);
    // Extra ids (e.g. retired main/privacy) are allowed — only active ids are required.
  }
  for (const id of SCREENS) {
    const h = j.headlines?.[id];
    if (!h) continue;
    if (CJK.has(tag)) {
      if ([...h].length > MAX_CJK_CHARS) fail(`${tag}.headlines.${id}: ${[...h].length} chars > ${MAX_CJK_CHARS} (CJK)`);
    } else {
      const words = h.trim().split(/\s+/).length;
      if (words > MAX_WORDS) fail(`${tag}.headlines.${id}: ${words} words > ${MAX_WORDS} ("${h}")`);
    }
  }
}

// --- rendered phone output ---
let checkedImgs = 0;
for (const tag of tags) {
  const dir = path.join(root, 'out', device, theme, tag);
  let files;
  try { files = (await readdir(dir)).filter((f) => f.endsWith('.png')); }
  catch { fail(`${tag}: no output dir out/${device}/${theme}/${tag}`); continue; }
  const expected = SCREENS.map((id, i) => `${tag}_${device}_${theme}_${String(i + 1).padStart(2, '0')}-${id}.png`);
  if (files.length !== SCREENS.length) fail(`${tag}: ${files.length} PNGs, expected ${SCREENS.length} — [${files.sort().join(', ')}]`);
  for (const name of expected) {
    const file = path.join(dir, name);
    let s; try { s = await stat(file); } catch { fail(`${tag}: missing ${name}`); continue; }
    if (s.size > MAX_BYTES) fail(`${name}: ${(s.size / 1024 / 1024).toFixed(2)} MB > 1 MB`);
    const dim = await pngSize(file);
    if (!dim) fail(`${name}: not a PNG`);
    else if (dim.w !== EXP_W || dim.h !== EXP_H) fail(`${name}: ${dim.w}x${dim.h}, expected ${EXP_W}x${EXP_H}`);
    else checkedImgs++;
  }
}

if (problems.length) {
  console.error(`✗ ${problems.length} problem(s):`);
  for (const p of problems) console.error('  - ' + p);
  process.exit(1);
}
console.log(`✓ ${tags.length} locales: headlines/subheadlines complete, all ≤ ${MAX_WORDS} words (CJK by char length)`);
const first = `01-${SCREENS[0]}`, last = `${String(SCREENS.length).padStart(2, '0')}-${SCREENS.at(-1)}`;
console.log(`✓ ${checkedImgs} ${device}/${theme} PNGs: exactly ${SCREENS.length} per locale, ${first}…${last}, all ${EXP_W}x${EXP_H}, all < 1 MB`);
