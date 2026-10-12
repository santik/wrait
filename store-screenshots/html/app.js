// Optional page hooks; every screen reads fine as plain HTML without this.
//   window.WRAIT_STRINGS  { key: text }  replaces [data-i18n="key"] text
//   window.WRAIT_LOCALE   'de-DE'        formats [data-date="ISO"] with Intl
//   ?pulse=0..1 &progress=0..1 &system=1 tweak the listening/preview state
//   ?theme=light selects the light scheme (dark is the default)
//   ?w=800&h=1280 lays the screen out for another viewport size (dp)
(() => {
  const strings = window.WRAIT_STRINGS || {};
  const locale = window.WRAIT_LOCALE;
  const query = new URLSearchParams(location.search);

  for (const el of document.querySelectorAll('[data-i18n]')) {
    const value = strings[el.dataset.i18n];
    if (value != null) el.textContent = value;
  }

  if (locale) {
    document.documentElement.lang = locale;
    const day = new Intl.DateTimeFormat(locale, { weekday: 'short', year: 'numeric', month: 'numeric', day: 'numeric' });
    const time = new Intl.DateTimeFormat(locale, { hour: 'numeric', minute: '2-digit' });
    for (const el of document.querySelectorAll('[data-date]')) {
      const d = new Date(el.dataset.date);
      el.textContent = `${day.format(d)} · ${time.format(d)}`;
    }
  }

  for (const name of ['w', 'h']) {
    if (query.has(name)) document.documentElement.style.setProperty(`--${name}`, `${query.get(name)}px`);
  }
  for (const name of ['pulse', 'progress']) {
    if (query.has(name)) document.documentElement.style.setProperty(`--${name}`, query.get(name));
  }
  if (query.get('theme') === 'light') document.documentElement.dataset.theme = 'light';
  if (query.has('system')) document.body.classList.add('system');
})();
