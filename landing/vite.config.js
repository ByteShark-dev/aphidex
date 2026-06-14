import { resolve } from 'node:path';

import { defineConfig } from 'vite';

import {
  getPageSeo,
  getPageStructuredData,
  getStaticLocale,
  siteConfig,
} from './src/config/site.js';

function getPageKeyFromContext(context) {
  const filename = context?.filename?.replaceAll('\\', '/');
  const path = context?.path?.replaceAll('\\', '/');

  if (filename?.endsWith('/privacy/index.html') || path?.includes('/privacy/')) {
    return 'privacy';
  }

  return 'home';
}

function buildMetaTokens(pageKey) {
  const locale = getStaticLocale(pageKey);
  const seo = getPageSeo(pageKey, locale);
  const structuredData = JSON.stringify(getPageStructuredData(pageKey, locale), null, 2);
  const ogImage = new URL(seo.ogImagePath, seo.siteUrl).toString();
  const ogLocale = locale === 'es' ? 'es_MX' : 'en_US';

  return {
    '%PAGE_TITLE%': seo.title,
    '%PAGE_DESCRIPTION%': seo.description,
    '%PAGE_URL%': seo.pageUrl,
    '%PAGE_OG_IMAGE%': ogImage,
    '%SITE_NAME%': siteConfig.brand.name,
    '%PAGE_AUTHOR%': siteConfig.brand.owner,
    '%OG_TYPE%': seo.ogType,
    '%PAGE_LOCALE%': ogLocale,
    '%TWITTER_CARD%': seo.twitterCard,
    '%STRUCTURED_DATA%': structuredData,
  };
}

export default defineConfig({
  base: './',
  build: {
    rollupOptions: {
      input: {
        main: resolve(__dirname, 'index.html'),
        privacy: resolve(__dirname, 'privacy/index.html'),
      },
    },
  },
  plugins: [
    {
      name: 'aphidex-meta',
      transformIndexHtml(html, context) {
        const pageKey = getPageKeyFromContext(context);
        const metaTokens = buildMetaTokens(pageKey);

        return Object.entries(metaTokens).reduce(
          (output, [token, value]) => output.replaceAll(token, value),
          html,
        );
      },
    },
  ],
});
