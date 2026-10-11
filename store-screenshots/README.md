# Store screenshots

Localized Play Store screenshots. The app screens are recreated in plain
HTML/CSS (`html/`), based on the real device captures in
`../real_screenshots/android/`, then dropped into a Pixel 9 Pro frame by
[Telephone](https://sneas.github.io/telephone) with a caption.

```bash
cd store-screenshots
npm install
npx playwright install chromium   # first time only

npm run screenshots               # everything: phone+tablet x dark+light x all locales
npm run screenshots:phone         # or :tablet, :light, :dark (flags combine)
node render.mjs --phone --light de-DE ja-JP   # explicit flags + locales
SCREENS=main,entries npm run screenshots
npm run compare                   # replicas vs real screenshots -> out/compare/*.png
```

Output: `out/<device>/<theme>/<locale>/0N-<screen>.png`, phone 1080x1920,
tablet 1600x2560.

## Layout

| Path | What |
|---|---|
| `html/*.html` | One page per screen: main, listening, entries, settings, feedback. Open directly in a browser (English). Units are Android dp; phone viewport is 411.43 x 914.29, tablet 800 x 1280 (`?w=&h=`). |
| `html/app.css` | Shared styles; colors mirror `lib/presentation/theme/wrait_colors.dart` (dark scheme). |
| `html/app.js` | Optional hooks: `?theme=light`, swaps `[data-i18n]` text from `window.WRAIT_STRINGS`, formats `[data-date]` with `Intl` for `window.WRAIT_LOCALE`. Query params: `?pulse=0..1&progress=0..1&system=1`. |
| `locales/<tag>.json` | Strings, sample entries and captions per language. |
| `render.mjs` | Localized + framed output. |
| `compare.mjs` | Replica next to the real screenshot, for checking fidelity. |

Entry text in the screens is fictional sample content, not from the real
captures.

| Screen | Real capture it was built from |
|---|---|
| main | `…094827.png` (dark), `…174413 (1).png` (light) |
| settings | `…094835.png`, `…174506.png` |
| entries | `…094912.png`, `…174421.png` |
| listening | `…094932.png`, `…094934.png`, `…174436 (1).png` (ring size via `?pulse=`) |
| feedback | `…095625.png`, `…174441.png` |

## Adding a language

Copy `locales/en-US.json` to `locales/<tag>.json` (tag is a BCP 47 locale such
as `fr-FR`) and translate every value, including the 8 `entryN` samples and
`captions`. App strings can be copied from `lib/l10n/app_*.arb` where they exist.

## When the app UI changes

Update the HTML to match, run `npm run compare`, and check it against a fresh
real screenshot. Replace the files in `real_screenshots/android/` to refresh
the reference.

## Tablets

There are no real tablet captures, so the tablet layouts are derived from the
app code: portrait-locked, main column capped at 520dp with the button clamped
to 280dp, entries/settings/feedback full width. Verify against a real tablet
capture when you have one.
