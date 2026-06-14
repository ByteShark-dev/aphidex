import { renderFooter, renderNavbar } from './SiteChrome.js';

function renderHero(content) {
  const { hero, screenshots } = content.page;
  const previewItems = screenshots.items.slice(0, 2);

  return `
    <section id="home" class="relative overflow-hidden pt-28 sm:pt-32">
      <div aria-hidden="true" class="hero-grid absolute inset-0 opacity-[0.16]"></div>
      <div aria-hidden="true" class="absolute left-1/2 top-10 h-[28rem] w-[28rem] -translate-x-1/2 rounded-full radial-ring blur-3xl"></div>
      <div class="section-shell relative grid gap-10 pb-20 pt-10 lg:grid-cols-[minmax(0,1.05fr)_minmax(320px,0.95fr)] lg:items-center lg:pb-24">
        <div class="min-w-0 space-y-7">
          <span class="eyebrow">${hero.eyebrow}</span>
          <h1 class="max-w-4xl font-headline text-[clamp(3.1rem,11vw,5rem)] font-bold leading-[0.92] tracking-tight text-on-surface sm:text-6xl">
            ${hero.title}
          </h1>
          <p class="max-w-2xl text-xl font-semibold leading-8 text-on-surface sm:text-2xl">
            ${hero.description}
          </p>
          <p class="max-w-3xl text-lg leading-8 text-on-surface-variant sm:text-xl">
            ${hero.subtext}
          </p>
          <div id="downloads" class="flex flex-wrap gap-4">
            <a
              class="store-badge"
              href="${content.links.googlePlay}"
              target="_blank"
              rel="noreferrer"
            >
              <img
                src="${content.assets.playBadge}"
                alt="${hero.primaryCta}"
                class="h-auto w-full"
                width="220"
                height="66"
                decoding="async"
              />
            </a>
            <a
              class="store-badge"
              href="${content.links.appStore}"
              target="_blank"
              rel="noreferrer"
            >
              <img
                src="${content.assets.appStoreBadge}"
                alt="${hero.secondaryCta}"
                class="h-auto w-full"
                width="220"
                height="66"
                decoding="async"
              />
            </a>
          </div>
          <p class="text-sm font-semibold uppercase tracking-[0.18em] text-secondary">${hero.storeNote}</p>
          <div class="flex flex-wrap gap-2">
            ${hero.badges.map((badge) => `<span class="signal-chip">${badge}</span>`).join('')}
          </div>
        </div>
        <aside class="glass-panel min-w-0 overflow-hidden rounded-[30px] border border-outline-variant/30 p-6 sm:p-7 shadow-[0_24px_90px_rgba(0,0,0,0.28)]">
          <div class="flex items-start justify-between gap-6">
            <div class="min-w-0">
              <p class="font-label text-xs uppercase tracking-[0.22em] text-accent">${content.brand.parentName}</p>
              <h2 class="mt-3 text-2xl font-bold text-on-surface">${hero.sideTitle}</h2>
            </div>
            <img
              src="${content.assets.logoIcon}"
              alt="${content.brand.name} icon"
              class="h-16 w-16 rounded-[22px] object-contain"
              width="64"
              height="64"
              decoding="async"
            />
          </div>
          <p class="mt-5 max-w-sm text-base leading-7 text-on-surface-variant">
            ${hero.sideBody}
          </p>
          <div class="mt-8 grid gap-4 sm:grid-cols-2">
            ${previewItems
              .map(
                (item) => `
                  <figure class="phone-frame">
                    <img
                      src="${item.src}"
                      alt="${item.alt}"
                      class="h-auto w-full"
                      loading="lazy"
                      decoding="async"
                    />
                  </figure>
                `,
              )
              .join('')}
          </div>
        </aside>
      </div>
    </section>
  `;
}

function renderFeatures(content) {
  const { features } = content.page;

  return `
    <section id="features" class="scroll-mt-28 py-24 sm:py-28">
      <div class="section-shell">
        <div class="mb-12 space-y-5">
          <span class="eyebrow">${features.title}</span>
          <h2 class="section-title">${features.title}</h2>
          <p class="section-copy">${features.intro}</p>
        </div>
        <div class="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
          ${features.items
            .map(
              (item) => `
                <article class="info-card">
                  <div class="mb-5 inline-flex h-12 w-12 items-center justify-center rounded-2xl bg-primary-container/15 text-primary-container">
                    <span class="material-symbols-outlined" aria-hidden="true">${item.icon}</span>
                  </div>
                  <h3 class="text-xl font-bold text-on-surface">${item.title}</h3>
                  <p class="mt-3 text-sm leading-7 text-on-surface-variant">${item.body}</p>
                </article>
              `,
            )
            .join('')}
        </div>
      </div>
    </section>
  `;
}

function renderPlatforms(content) {
  const { platforms } = content.page;

  return `
    <section id="platforms" class="scroll-mt-28 bg-surface-container-lowest/50 py-24 sm:py-28">
      <div class="section-shell">
        <div class="mb-12 space-y-5">
          <span class="eyebrow">${platforms.title}</span>
          <h2 class="section-title">${platforms.title}</h2>
          <p class="section-copy">${platforms.intro}</p>
        </div>
        <div class="grid gap-5 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)_minmax(0,1.15fr)]">
          ${platforms.items
            .map(
              (item) => `
                <article class="info-card">
                  <div class="mb-5 inline-flex h-12 w-12 items-center justify-center rounded-2xl bg-accent/15 text-accent">
                    <span class="material-symbols-outlined" aria-hidden="true">${item.icon}</span>
                  </div>
                  <h3 class="text-xl font-bold text-on-surface">${item.title}</h3>
                  <p class="mt-3 text-sm leading-7 text-on-surface-variant">${item.body}</p>
                </article>
              `,
            )
            .join('')}
          <article class="glass-panel rounded-[26px] border border-outline-variant/28 p-6">
            <span class="signal-chip">${platforms.compatibilityTitle}</span>
            <p class="mt-5 text-lg font-semibold text-on-surface">${platforms.compatibilityTitle}</p>
            <p class="mt-3 text-sm leading-7 text-on-surface-variant">${platforms.compatibilityBody}</p>
          </article>
        </div>
      </div>
    </section>
  `;
}

function renderMetrics(content) {
  const { metrics } = content.page;

  return `
    <section id="metrics" class="scroll-mt-28 py-24 sm:py-28">
      <div class="section-shell">
        <div class="mb-12 space-y-5">
          <span class="eyebrow">${metrics.title}</span>
          <h2 class="section-title">${metrics.title}</h2>
          <p class="section-copy">${metrics.intro}</p>
        </div>
        <div class="grid gap-5 md:grid-cols-3">
          ${metrics.items
            .map(
              (item) => `
                <article class="info-card">
                  <p class="metric-value">${item.value}</p>
                  <p class="mt-2 font-label text-xs uppercase tracking-[0.22em] text-secondary">${item.label}</p>
                  <p class="mt-4 text-sm leading-7 text-on-surface-variant">${item.body}</p>
                </article>
              `,
            )
            .join('')}
        </div>
      </div>
    </section>
  `;
}

function renderScreenshots(content) {
  const { screenshots } = content.page;
  const items = screenshots.items.length
    ? screenshots.items
    : Array.from({ length: 3 }, (_, index) => ({
        src: content.assets.ogImage,
        alt: `${content.brand.name} placeholder screenshot ${index + 1}`,
        caption: 'Placeholder listo para reemplazar por una captura real.',
      }));

  return `
    <section id="screenshots" class="scroll-mt-28 bg-surface-container-lowest/50 py-24 sm:py-28">
      <div class="section-shell">
        <div class="mb-12 space-y-5">
          <span class="eyebrow">${screenshots.title}</span>
          <h2 class="section-title">${screenshots.title}</h2>
          <p class="section-copy">${screenshots.intro}</p>
        </div>
        <div class="grid gap-6 lg:grid-cols-3">
          ${items
            .map(
              (item) => `
                <figure class="phone-frame">
                  <img
                    src="${item.src}"
                    alt="${item.alt}"
                    class="h-auto w-full"
                    loading="lazy"
                    decoding="async"
                  />
                  <figcaption class="border-t border-outline-variant/25 p-5 text-sm text-on-surface-variant">
                    ${item.caption}
                  </figcaption>
                </figure>
              `,
            )
            .join('')}
        </div>
      </div>
    </section>
  `;
}

function renderLanguages(content) {
  const { languages } = content.page;

  return `
    <section id="languages" class="scroll-mt-28 py-24 sm:py-28">
      <div class="section-shell">
        <div class="mb-12 space-y-5">
          <span class="eyebrow">${languages.title}</span>
          <h2 class="section-title">${languages.title}</h2>
          <p class="section-copy">${languages.intro}</p>
        </div>
        <div class="grid gap-5 md:grid-cols-3">
          ${languages.items
            .map(
              (item) => `
                <article class="info-card">
                  <span class="signal-chip">${item.label}</span>
                  <p class="mt-5 text-sm leading-7 text-on-surface-variant">${item.body}</p>
                </article>
              `,
            )
            .join('')}
        </div>
      </div>
    </section>
  `;
}

function renderLegal(content) {
  const { legal } = content.page;

  return `
    <section id="legal" class="scroll-mt-28 pb-24 pt-4 sm:pb-28">
      <div class="section-shell">
        <div class="rounded-[28px] border border-outline-variant/30 bg-surface-container-low/80 p-6 text-sm leading-7 text-on-surface-variant">
          <span class="font-label text-xs uppercase tracking-[0.2em] text-secondary">${legal.title}</span>
          <p class="mt-4">${legal.body}</p>
        </div>
      </div>
    </section>
  `;
}

export function renderLandingPage(content) {
  return `
    ${renderNavbar(content)}
    <main id="main-content">
      ${renderHero(content)}
      ${renderFeatures(content)}
      ${renderPlatforms(content)}
      ${renderMetrics(content)}
      ${renderScreenshots(content)}
      ${renderLanguages(content)}
      ${renderLegal(content)}
    </main>
    ${renderFooter(content)}
  `;
}
