import './styles/main.css';

import {
  defaultLocale,
  getPageContent,
  getPageStructuredData,
  supportedLocales,
} from './config/site.js';

const languageStorageKey = 'aphidex-locale';
let navbarScrollBound = false;

function getInitialLocale() {
  try {
    const savedLocale = window.localStorage.getItem(languageStorageKey);
    return supportedLocales.includes(savedLocale) ? savedLocale : defaultLocale;
  } catch {
    return defaultLocale;
  }
}

function syncSeo(pageKey, content) {
  document.title = content.seo.title;
  document.documentElement.lang = content.locale;

  const absoluteOgImage = new URL(content.seo.ogImagePath, content.seo.siteUrl).toString();
  const ogLocale = content.locale === 'es' ? 'es_MX' : 'en_US';
  const metaSelectors = [
    ['meta[name="description"]', content.seo.description, 'content'],
    ['meta[name="author"]', content.brand.owner, 'content'],
    ['meta[name="theme-color"]', '#071518', 'content'],
    ['link[rel="canonical"]', content.seo.pageUrl, 'href'],
    ['meta[property="og:type"]', content.seo.ogType, 'content'],
    ['meta[property="og:site_name"]', content.brand.name, 'content'],
    ['meta[property="og:locale"]', ogLocale, 'content'],
    ['meta[property="og:url"]', content.seo.pageUrl, 'content'],
    ['meta[property="og:title"]', content.seo.title, 'content'],
    ['meta[property="og:description"]', content.seo.description, 'content'],
    ['meta[property="og:image"]', absoluteOgImage, 'content'],
    ['meta[property="og:image:alt"]', content.seo.title, 'content'],
    ['meta[name="twitter:card"]', content.seo.twitterCard, 'content'],
    ['meta[name="twitter:title"]', content.seo.title, 'content'],
    ['meta[name="twitter:description"]', content.seo.description, 'content'],
    ['meta[name="twitter:image"]', absoluteOgImage, 'content'],
    ['meta[name="twitter:image:alt"]', content.seo.title, 'content'],
  ];

  metaSelectors.forEach(([selector, value, attribute]) => {
    const element = document.querySelector(selector);
    if (element) {
      element.setAttribute(attribute, value);
    }
  });

  const structuredDataElement = document.querySelector('#structured-data');
  if (structuredDataElement) {
    structuredDataElement.textContent = JSON.stringify(
      getPageStructuredData(pageKey, content.locale),
      null,
      2,
    );
  }
}

function initNavbarScroll() {
  const updateNavbar = () => {
    const navbar = document.querySelector('[data-navbar]');

    if (!navbar) {
      return;
    }

    navbar.classList.toggle('is-scrolled', window.scrollY > 12);
  };

  updateNavbar();

  if (!navbarScrollBound) {
    window.addEventListener('scroll', updateNavbar, { passive: true });
    navbarScrollBound = true;
  }
}

function initLocaleToggle(mount) {
  const localeButtons = document.querySelectorAll('[data-locale-target]');

  localeButtons.forEach((button) => {
    button.addEventListener('click', () => {
      const nextLocale = button.getAttribute('data-locale-target');

      if (!supportedLocales.includes(nextLocale)) {
        return;
      }

      try {
        window.localStorage.setItem(languageStorageKey, nextLocale);
      } catch {
        // Ignore storage failures and still re-render in-memory.
      }

      mount(nextLocale);
    });
  });
}

function initMobileMenu() {
  const toggle = document.querySelector('[data-nav-toggle]');
  const panel = document.querySelector('[data-nav-panel]');
  const icon = document.querySelector('[data-nav-icon]');

  if (!toggle || !panel) {
    return;
  }

  const navLinks = panel.querySelectorAll('a');
  const openLabel = toggle.getAttribute('data-nav-open-label') ?? 'Open navigation';
  const closeLabel = toggle.getAttribute('data-nav-close-label') ?? 'Close navigation';

  const setOpen = (isOpen) => {
    panel.classList.toggle('hidden', !isOpen);
    toggle.setAttribute('aria-expanded', String(isOpen));
    toggle.setAttribute('aria-label', isOpen ? closeLabel : openLabel);

    if (icon) {
      icon.textContent = isOpen ? 'close' : 'menu';
    }
  };

  toggle.addEventListener('click', () => {
    const isExpanded = toggle.getAttribute('aria-expanded') === 'true';
    setOpen(!isExpanded);
  });

  navLinks.forEach((link) => {
    link.addEventListener('click', () => setOpen(false));
  });
}

export function mountPage({ pageKey, render }) {
  const app = document.querySelector('#app');

  if (!app) {
    return;
  }

  let currentLocale = getInitialLocale();

  const mount = (nextLocale = currentLocale) => {
    currentLocale = nextLocale;
    const content = getPageContent(pageKey, currentLocale);

    app.innerHTML = render(content);
    syncSeo(pageKey, content);
    initNavbarScroll();
    initLocaleToggle(mount);
    initMobileMenu();
  };

  mount();
}
