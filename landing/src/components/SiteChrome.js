function getNavigationHref(item, content) {
  if (item.page === 'privacy') {
    return content.paths.privacyHref;
  }

  return content.paths.sectionHrefs[item.section];
}

function renderNavigationLinks(content, linkClass = '') {
  return content.navigation
    .map(
      (item) => `
        <a
          class="${linkClass}"
          href="${getNavigationHref(item, content)}"
        >
          ${item.label}
        </a>
      `,
    )
    .join('');
}

export function renderNavbar(content) {
  const mobileNavItems = renderNavigationLinks(
    content,
    'rounded-2xl border border-outline-variant/25 bg-surface-container-low/55 px-4 py-3 text-base font-semibold tracking-tight text-on-surface transition hover:border-primary-container/35 hover:bg-surface-container',
  );
  const localeButtons = content.supportedLocales
    .map(
      (item) => `
        <button
          class="rounded-full px-3 py-1.5 text-[11px] font-bold uppercase tracking-[0.18em] transition-colors ${
            item === content.locale
              ? 'bg-primary-container text-on-primary-container'
              : 'text-on-surface/62 hover:text-on-surface'
          }"
          type="button"
          data-locale-target="${item}"
          aria-pressed="${item === content.locale}"
        >
          ${content.ui.localeLabels[item]}
        </button>
      `,
    )
    .join('');

  return `
    <header class="site-navbar fixed inset-x-0 top-0 z-50" data-navbar>
      <a
        class="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-[60] focus:rounded-full focus:bg-primary-container focus:px-4 focus:py-2 focus:font-label focus:text-sm focus:font-bold focus:uppercase focus:tracking-widest focus:text-on-primary-container"
        href="#main-content"
      >
        ${content.ui.skipToContent}
      </a>
      <nav class="section-shell flex items-center justify-between gap-3 py-3.5 sm:gap-4 sm:py-4" aria-label="Primary">
        <a
          class="flex min-w-0 items-center gap-3 font-headline text-lg font-bold tracking-tight text-on-surface sm:text-2xl"
          href="${content.paths.homeHref}"
          aria-label="${content.ui.homeAria}"
        >
          <img
            src="${content.assets.logoIcon}"
            alt=""
            aria-hidden="true"
            class="h-10 w-10 rounded-full object-contain"
            width="40"
            height="40"
            decoding="async"
          />
          <span class="min-w-0">
            <span class="block truncate">${content.brand.name}</span>
            <span class="block text-[10px] uppercase tracking-[0.18em] text-secondary">
              by ${content.brand.parentName}
            </span>
          </span>
        </a>
        <div class="flex items-center gap-3">
          <a class="cta-primary px-4 py-2.5 text-[11px] sm:px-5 sm:text-xs" href="${content.paths.downloadHref}">
            ${content.ui.mobileHeaderCta}
          </a>
          <button
            class="inline-flex h-11 w-11 items-center justify-center rounded-full border border-outline-variant/40 bg-surface-container-high/70 text-on-surface"
            type="button"
            data-nav-toggle
            aria-expanded="false"
            aria-label="${content.ui.menuLabel}"
            data-nav-open-label="${content.ui.menuLabel}"
            data-nav-close-label="${content.ui.closeMenuLabel}"
          >
            <span class="material-symbols-outlined" aria-hidden="true" data-nav-icon>menu</span>
          </button>
        </div>
      </nav>
      <div class="section-shell hidden pb-4" data-nav-panel>
        <div class="ml-auto w-full max-w-md glass-panel rounded-[26px] border border-outline-variant/30 p-4 shadow-[0_24px_80px_rgba(0,0,0,0.24)]">
          <div class="flex items-center justify-between gap-4">
            <p class="font-label text-xs font-bold uppercase tracking-[0.22em] text-secondary">
              ${content.ui.menuPanelTitle}
            </p>
            <div
              class="flex items-center gap-1 rounded-full border border-outline-variant/30 bg-surface-container-high/45 p-1"
              aria-label="${content.ui.languageLabel}"
            >
              ${localeButtons}
            </div>
          </div>
          <div class="mt-4 flex flex-col gap-3 font-label text-sm text-on-surface">
            ${mobileNavItems}
            <a class="cta-primary mt-1" href="${content.paths.downloadHref}">
              ${content.ui.mobileHeaderCta}
            </a>
          </div>
        </div>
      </div>
    </header>
  `;
}

export function renderFooter(content) {
  return `
    <footer class="border-t border-outline-variant/20 bg-surface-container-lowest/80 py-12">
      <div class="section-shell flex flex-col gap-8 md:flex-row md:items-center md:justify-between">
        <a class="flex items-center gap-3 font-headline text-lg font-bold text-on-surface" href="${content.paths.homeHref}">
          <img
            src="${content.assets.logoIcon}"
            alt=""
            aria-hidden="true"
            class="h-9 w-9 rounded-full object-contain"
            width="36"
            height="36"
            decoding="async"
          />
          <span>${content.brand.name}</span>
        </a>
        <p class="max-w-md text-sm uppercase tracking-[0.18em] text-on-surface/55 text-wrap-anywhere">
          ${content.footer.copyright} ${content.footer.tagline}
        </p>
        <div class="grid grid-cols-2 gap-x-6 gap-y-3 font-label text-sm uppercase tracking-[0.18em] sm:flex sm:flex-wrap">
          <a class="text-on-surface/58 transition hover:text-primary-container" href="${content.links.byteSharkHome}" target="_blank" rel="noreferrer">
            ${content.footer.links.byteShark}
          </a>
          <a class="text-on-surface/58 transition hover:text-primary-container" href="${content.paths.privacyHref}">
            ${content.footer.links.privacy}
          </a>
          <a class="text-on-surface/58 transition hover:text-primary-container" href="${content.links.googlePlay}" target="_blank" rel="noreferrer">
            ${content.footer.links.googlePlay}
          </a>
          <a class="text-on-surface/58 transition hover:text-primary-container" href="${content.links.appStore}" target="_blank" rel="noreferrer">
            ${content.footer.links.appStore}
          </a>
        </div>
      </div>
    </footer>
  `;
}
