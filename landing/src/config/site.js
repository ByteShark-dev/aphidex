export const defaultLocale = 'es';
export const supportedLocales = ['es', 'en'];

const screenshotFiles = [
  'IMG_20260428_231511.jpg',
  'IMG_20260428_231525.jpg',
  'IMG_20260428_231537.jpg',
];

const localizedContent = {
  es: {
    navigation: [
      { label: 'Funciones', section: 'features' },
      { label: 'Plataformas', section: 'platforms' },
      { label: 'Capturas', section: 'screenshots' },
      { label: 'Privacidad', page: 'privacy' },
    ],
    footer: {
      tagline: 'Companion app no oficial creada por ByteShark',
      links: {
        byteShark: 'ByteShark',
        privacy: 'Politica de privacidad',
        googlePlay: 'Google Play',
        appStore: 'App Store',
      },
    },
    ui: {
      skipToContent: 'Saltar al contenido',
      homeAria: 'Inicio de Aphidex',
      languageLabel: 'Idioma',
      menuLabel: 'Abrir navegacion',
      closeMenuLabel: 'Cerrar navegacion',
      menuPanelTitle: 'Menu',
      mobileHeaderCta: 'Descargar',
      localeLabels: {
        es: 'ES',
        en: 'EN',
      },
    },
    home: {
      seo: {
        title: 'Aphidex | Companion app para Grounded y Grounded 2',
        description:
          'Consulta criaturas, debilidades, resistencias, ataques y datos utiles para Grounded y Grounded 2 desde Aphidex.',
      },
      hero: {
        eyebrow: 'COMPANION APP PARA GROUNDED Y GROUNDED 2',
        title: 'Aphidex',
        description: 'Companion app para Grounded y Grounded 2.',
        subtext:
          'Consulta criaturas, debilidades, resistencias, ataques, comportamiento y datos utiles para jugar mejor.',
        primaryCta: 'Descargar en Google Play',
        secondaryCta: 'Descargar en App Store',
        storeNote: 'Disponible para Android e iOS.',
        badges: ['Android', 'iOS', 'Offline guide', 'ByteShark'],
        sideTitle: 'Referencia rapida para sobrevivir mejor',
        sideBody:
          'Aphidex concentra informacion de combate, filtros por juego y datos de criaturas en una app ligera pensada para consultar en segundos.',
      },
      features: {
        title: 'Funciones',
        intro:
          'La landing se enfoca en lo que el producto resuelve para jugadores que quieren menos busqueda externa y respuestas mas rapidas.',
        items: [
          {
            icon: 'pest_control',
            title: 'Guia de criaturas',
            body: 'Consulta enemigos clave, variantes y referencias utiles para planear mejor cada combate.',
          },
          {
            icon: 'shield',
            title: 'Debilidades y resistencias',
            body: 'Revisa rapido que dano funciona mejor y que tipos conviene evitar antes de pelear.',
          },
          {
            icon: 'ads_click',
            title: 'Ataques y puntos debiles',
            body: 'Ubica ataques relevantes, elementos peligrosos y puntos debiles para optimizar tu estrategia.',
          },
          {
            icon: 'filter_alt',
            title: 'Filtros por juego',
            body: 'Separa contenido de Grounded y Grounded 2 para llegar mas rapido a la informacion correcta.',
          },
          {
            icon: 'trophy',
            title: 'Compatibilidad doble',
            body: 'Pensada para acompanar tanto contenido actual como la evolucion del universo de Grounded 2.',
          },
          {
            icon: 'bolt',
            title: 'Interfaz rapida y ligera',
            body: 'Una experiencia agil, movil y clara para consultar datos utiles sin friccion.',
          },
        ],
      },
      platforms: {
        title: 'Plataformas',
        intro:
          'Aphidex esta disponible como companion app movil para que la referencia vaya contigo mientras juegas.',
        items: [
          {
            icon: 'android',
            title: 'Android',
            body: 'Disponible para descargar desde Google Play con actualizaciones del producto publicado.',
          },
          {
            icon: 'phone_iphone',
            title: 'iOS',
            body: 'Disponible en App Store para llevar la misma guia a iPhone y mantener la experiencia consistente.',
          },
        ],
        compatibilityTitle: 'Compatible con Grounded y Grounded 2',
        compatibilityBody:
          'La estructura del contenido y los filtros de la app estan pensados para convivir con ambos juegos sin mezclar referencias.',
      },
      metrics: {
        title: 'Confianza',
        intro: 'Estas metricas quedan editables desde configuracion para ajustar la landing conforme crece la app.',
        items: [
          {
            value: '800+',
            label: 'Descargas',
            body: 'Mas de 800 descargas acumuladas en el producto publicado.',
          },
          {
            value: 'Varios',
            label: 'Paises',
            body: 'Disponible para jugadores en varios paises a traves de las tiendas moviles.',
          },
          {
            value: '4.2+',
            label: 'Calificacion',
            body: 'Espacio listo para mostrar la calificacion aproximada de la app.',
          },
        ],
      },
      screenshots: {
        title: 'Capturas',
        intro: 'La pagina queda preparada para screenshots reales de la app y puede mostrar placeholders si hicieran falta.',
        items: [
          {
            alt: 'Pantalla principal de Aphidex con busqueda y filtros.',
            caption: 'Busqueda y filtros para encontrar criaturas rapido.',
          },
          {
            alt: 'Pantalla de detalle de criatura con debilidades y vida.',
            caption: 'Debilidades, resistencias y detalles de combate en una sola vista.',
          },
          {
            alt: 'Pantalla de efectos y referencias utiles de Aphidex.',
            caption: 'Datos utiles para decidir mejor sin abrir varias guias.',
          },
        ],
      },
      languages: {
        title: 'Idiomas',
        intro: 'La app ya contempla una experiencia multilenguaje para una comunidad mas amplia.',
        items: [
          {
            label: 'Espanol',
            body: 'Interfaz y contenido accesibles para jugadores hispanohablantes.',
          },
          {
            label: 'Ingles',
            body: 'Soporte en ingles para ampliar el alcance internacional del companion app.',
          },
          {
            label: 'Ruso',
            body: 'Idioma adicional dentro de la app para cubrir otra parte activa de la comunidad.',
          },
        ],
      },
      legal: {
        title: 'Aclaracion legal',
        body:
          'Aphidex es una app companion no oficial creada por ByteShark. Grounded y sus marcas pertenecen a sus respectivos propietarios.',
      },
    },
    privacy: {
      seo: {
        title: 'Politica de privacidad | Aphidex',
        description:
          'Politica de privacidad de la landing y companion app Aphidex publicada por ByteShark.',
      },
      hero: {
        eyebrow: 'PRIVACIDAD',
        title: 'Politica de privacidad',
        intro:
          'Esta pagina resume como se maneja la informacion relacionada con la landing de Aphidex y con el producto publicado en tiendas.',
        updatedLabel: 'Ultima actualizacion',
        updatedValue: '14 de junio de 2026',
      },
      sections: [
        {
          title: 'Informacion general',
          body:
            'Aphidex es una app companion no oficial creada por ByteShark. La landing publica informacion del producto y enlaces a sus tiendas oficiales.',
        },
        {
          title: 'Datos que puede involucrar el producto',
          body:
            'La app no requiere crear una cuenta propia de Aphidex. Dependiendo de la plataforma, la descarga, compra, anuncios, diagnosticos o metricas pueden involucrar servicios operados por Google Play, App Store u otros proveedores de infraestructura.',
        },
        {
          title: 'Proveedores externos',
          body:
            'Cuando uses Google Play, App Store, redes publicitarias o servicios de terceros vinculados al producto, esos proveedores pueden procesar datos bajo sus propias politicas de privacidad. Aphidex enlaza a esos ecosistemas, pero no reemplaza sus terminos ni controles.',
        },
        {
          title: 'Landing y enlaces',
          body:
            'La landing no solicita registro ni formularios obligatorios. Puede incluir enlaces externos a tiendas, la web principal de ByteShark y canales de contacto.',
        },
        {
          title: 'Cambios a esta politica',
          body:
            'Esta politica puede actualizarse conforme cambien las funciones del producto, las integraciones o los requisitos de publicacion en tiendas.',
        },
      ],
      contact: {
        title: 'Contacto',
        body: 'Si necesitas solicitar una aclaracion sobre privacidad o publicacion del producto, puedes escribir a ByteShark.',
      },
    },
  },
  en: {
    navigation: [
      { label: 'Features', section: 'features' },
      { label: 'Platforms', section: 'platforms' },
      { label: 'Screenshots', section: 'screenshots' },
      { label: 'Privacy', page: 'privacy' },
    ],
    footer: {
      tagline: 'Unofficial companion app created by ByteShark',
      links: {
        byteShark: 'ByteShark',
        privacy: 'Privacy Policy',
        googlePlay: 'Google Play',
        appStore: 'App Store',
      },
    },
    ui: {
      skipToContent: 'Skip to content',
      homeAria: 'Aphidex home',
      languageLabel: 'Language',
      menuLabel: 'Open navigation',
      closeMenuLabel: 'Close navigation',
      menuPanelTitle: 'Menu',
      mobileHeaderCta: 'Download',
      localeLabels: {
        es: 'ES',
        en: 'EN',
      },
    },
    home: {
      seo: {
        title: 'Aphidex | Companion app for Grounded and Grounded 2',
        description:
          'Browse creatures, weaknesses, resistances, attacks and useful combat data for Grounded and Grounded 2 with Aphidex.',
      },
      hero: {
        eyebrow: 'COMPANION APP FOR GROUNDED AND GROUNDED 2',
        title: 'Aphidex',
        description: 'Companion app for Grounded and Grounded 2.',
        subtext:
          'Browse creatures, weaknesses, resistances, attacks, behavior and useful data to play better.',
        primaryCta: 'Download on Google Play',
        secondaryCta: 'Download on the App Store',
        storeNote: 'Available on Android and iOS.',
        badges: ['Android', 'iOS', 'Offline guide', 'ByteShark'],
        sideTitle: 'A faster way to check combat data',
        sideBody:
          'Aphidex brings creature data, game filters and useful references into one lightweight app built for quick in-session lookups.',
      },
      features: {
        title: 'Features',
        intro:
          'The landing focuses on the product value for players who want less external searching and faster answers.',
        items: [
          {
            icon: 'pest_control',
            title: 'Creature guide',
            body: 'Check key enemies, variants and useful references before difficult encounters.',
          },
          {
            icon: 'shield',
            title: 'Weaknesses and resistances',
            body: 'See which damage types work best and which ones are worth avoiding before a fight.',
          },
          {
            icon: 'ads_click',
            title: 'Attacks and weak points',
            body: 'Spot important attacks, dangerous effects and weak points so you can plan smarter.',
          },
          {
            icon: 'filter_alt',
            title: 'Game filters',
            body: 'Separate Grounded and Grounded 2 content so you reach the right information faster.',
          },
          {
            icon: 'trophy',
            title: 'Dual compatibility',
            body: 'Built to support both current Grounded content and the growing scope of Grounded 2.',
          },
          {
            icon: 'bolt',
            title: 'Fast, lightweight UI',
            body: 'A clear mobile experience designed to surface useful data without friction.',
          },
        ],
      },
      platforms: {
        title: 'Platforms',
        intro:
          'Aphidex ships as a mobile companion app so the reference stays with you while you play.',
        items: [
          {
            icon: 'android',
            title: 'Android',
            body: 'Available through Google Play with updates tied to the shipped product.',
          },
          {
            icon: 'phone_iphone',
            title: 'iOS',
            body: 'Available on the App Store to carry the same guide onto iPhone with a consistent experience.',
          },
        ],
        compatibilityTitle: 'Built for Grounded and Grounded 2',
        compatibilityBody:
          'The content structure and filters are prepared to support both games without mixing references.',
      },
      metrics: {
        title: 'Trust',
        intro: 'These metrics stay editable from config so the landing can evolve with the product.',
        items: [
          {
            value: '800+',
            label: 'Downloads',
            body: 'More than 800 cumulative downloads across the published product.',
          },
          {
            value: 'Multi',
            label: 'Countries',
            body: 'Available to players across multiple countries through the mobile stores.',
          },
          {
            value: '4.2+',
            label: 'Rating',
            body: 'Ready to display the app approximate rating as the stores evolve.',
          },
        ],
      },
      screenshots: {
        title: 'Screenshots',
        intro: 'The page is ready for real app screenshots and can fall back to placeholders if needed.',
        items: [
          {
            alt: 'Aphidex main screen with search and filters.',
            caption: 'Search and filter creatures fast.',
          },
          {
            alt: 'Aphidex creature detail screen with weaknesses and health.',
            caption: 'Weaknesses, resistances and combat data in one view.',
          },
          {
            alt: 'Aphidex effects reference screen.',
            caption: 'Useful details for smarter decisions without multiple guides.',
          },
        ],
      },
      languages: {
        title: 'Languages',
        intro: 'The app already supports a multilingual experience for a wider community.',
        items: [
          {
            label: 'Spanish',
            body: 'Localized UI and content for Spanish-speaking players.',
          },
          {
            label: 'English',
            body: 'English support to broaden the reach of the companion app.',
          },
          {
            label: 'Russian',
            body: 'Additional in-app language coverage for another active part of the community.',
          },
        ],
      },
      legal: {
        title: 'Legal note',
        body:
          'Aphidex is an unofficial companion app created by ByteShark. Grounded and related trademarks belong to their respective owners.',
      },
    },
    privacy: {
      seo: {
        title: 'Privacy Policy | Aphidex',
        description:
          'Privacy policy for the Aphidex landing page and companion app published by ByteShark.',
      },
      hero: {
        eyebrow: 'PRIVACY',
        title: 'Privacy Policy',
        intro:
          'This page summarizes how information is handled around the Aphidex landing page and the product published in app stores.',
        updatedLabel: 'Last updated',
        updatedValue: 'June 14, 2026',
      },
      sections: [
        {
          title: 'General information',
          body:
            'Aphidex is an unofficial companion app created by ByteShark. The landing page presents product information and links to its official store listings.',
        },
        {
          title: 'Data the product may involve',
          body:
            'The app does not require a dedicated Aphidex account. Depending on the platform, downloads, purchases, ads, diagnostics or product metrics may involve services operated by Google Play, the App Store or other infrastructure providers.',
        },
        {
          title: 'Third-party providers',
          body:
            'When you use Google Play, the App Store, ad networks or other linked services, those providers may process data under their own privacy policies. Aphidex can link into those ecosystems but does not replace their terms or controls.',
        },
        {
          title: 'Landing page and links',
          body:
            'The landing page does not require registration or mandatory forms. It may contain external links to store listings, the main ByteShark website and contact channels.',
        },
        {
          title: 'Policy updates',
          body:
            'This policy may change as product features, integrations or store publication requirements evolve.',
        },
      ],
      contact: {
        title: 'Contact',
        body: 'If you need a privacy or publication clarification, you can contact ByteShark directly.',
      },
    },
  },
};

function buildPaths(pageKey) {
  const isHome = pageKey === 'home';
  const sectionPrefix = isHome ? '#' : '../#';
  const rootPrefix = isHome ? './' : '../';

  return {
    homeHref: isHome ? '#home' : '../',
    privacyHref: isHome ? './privacy/' : './',
    downloadHref: `${sectionPrefix}downloads`,
    sectionHrefs: {
      features: `${sectionPrefix}features`,
      platforms: `${sectionPrefix}platforms`,
      metrics: `${sectionPrefix}metrics`,
      screenshots: `${sectionPrefix}screenshots`,
      languages: `${sectionPrefix}languages`,
      legal: `${sectionPrefix}legal`,
    },
    assetBase: `${rootPrefix}assets`,
  };
}

function buildAssets(pageKey) {
  const { assetBase } = buildPaths(pageKey);

  return {
    logoIcon: `${assetBase}/images/Aphidex_logo.webp`,
    ogImage: `${assetBase}/images/project-aphidex.webp`,
    playBadge: `${assetBase}/google-play-badge.svg`,
    appStoreBadge: `${assetBase}/app-store-badge.svg`,
    screenshots: screenshotFiles.map((file) => `${assetBase}/aphidex/${file}`),
  };
}

export const siteConfig = {
  defaultLocale,
  supportedLocales,
  year: 2026,
  brand: {
    name: 'Aphidex',
    owner: 'ByteShark',
    parentName: 'ByteShark',
    parentUrl: 'https://byteshark-dev.github.io/',
    slogan: 'Companion app for Grounded and Grounded 2',
  },
  seo: {
    siteUrl: 'https://byteshark-dev.github.io/aphidex/',
    defaultOgImagePath: 'assets/images/project-aphidex.webp',
    pages: {
      home: {
        path: '',
        ogImagePath: 'assets/images/project-aphidex.webp',
        twitterCard: 'summary_large_image',
        ogType: 'website',
      },
      privacy: {
        path: 'privacy/',
        ogImagePath: 'assets/images/project-aphidex.webp',
        twitterCard: 'summary_large_image',
        ogType: 'article',
      },
    },
  },
  links: {
    googlePlay: 'https://play.google.com/store/apps/details?id=com.byteshark.aphidex&hl=es_419',
    appStore: 'https://apps.apple.com/mx/app/aphidex/id6766727089',
    byteSharkHome: 'https://byteshark-dev.github.io/',
    email: 'mailto:byteshark098@gmail.com',
    emailAddress: 'byteshark098@gmail.com',
  },
  socialLinks: [
    'https://byteshark-dev.github.io/',
    'https://play.google.com/store/apps/details?id=com.byteshark.aphidex&hl=es_419',
    'https://apps.apple.com/mx/app/aphidex/id6766727089',
  ],
  localizedContent,
};

const staticLocaleByPage = {
  home: 'es',
  privacy: 'es',
};

function getActiveLocale(locale) {
  return localizedContent[locale] ? locale : defaultLocale;
}

function getLocalizedPage(copy, pageKey, assets) {
  if (pageKey !== 'home') {
    return copy[pageKey];
  }

  return {
    ...copy.home,
    screenshots: {
      ...copy.home.screenshots,
      items: copy.home.screenshots.items.map((item, index) => ({
        ...item,
        src: assets.screenshots[index] ?? assets.ogImage,
      })),
    },
  };
}

export function getStaticLocale(pageKey) {
  return staticLocaleByPage[pageKey] ?? defaultLocale;
}

export function getPageSeo(pageKey, locale = defaultLocale) {
  const activeLocale = getActiveLocale(locale);
  const pageCopy = localizedContent[activeLocale][pageKey];
  const pageSeo = siteConfig.seo.pages[pageKey];
  const pageUrl = new URL(pageSeo.path, siteConfig.seo.siteUrl).toString();

  return {
    ...pageSeo,
    ...pageCopy.seo,
    siteUrl: siteConfig.seo.siteUrl,
    pageUrl,
    ogImagePath: pageCopy.seo.ogImagePath ?? pageSeo.ogImagePath ?? siteConfig.seo.defaultOgImagePath,
  };
}

export function getPageStructuredData(pageKey, locale = defaultLocale) {
  const activeLocale = getActiveLocale(locale);
  const content = getPageContent(pageKey, activeLocale);
  const { brand, links, seo } = content;
  const organization = {
    '@type': 'Organization',
    name: brand.owner,
    url: brand.parentUrl,
  };
  const website = {
    '@type': 'WebSite',
    name: brand.name,
    url: siteConfig.seo.siteUrl,
    inLanguage: activeLocale,
    description: localizedContent[activeLocale].home.seo.description,
  };

  if (pageKey !== 'home') {
    return {
      '@context': 'https://schema.org',
      '@graph': [organization, website],
    };
  }

  return {
    '@context': 'https://schema.org',
    '@graph': [
      organization,
      website,
      {
        '@type': 'MobileApplication',
        name: brand.name,
        operatingSystem: 'Android, iOS',
        applicationCategory: 'GameApplication',
        url: seo.pageUrl,
        downloadUrl: links.googlePlay,
        image: new URL(content.assets.ogImage, seo.pageUrl).toString(),
        sameAs: [links.googlePlay, links.appStore],
        author: {
          '@type': 'Organization',
          name: brand.owner,
        },
        publisher: {
          '@type': 'Organization',
          name: brand.owner,
        },
        description: localizedContent[activeLocale].home.seo.description,
        inLanguage: ['es', 'en', 'ru'],
        offers: {
          '@type': 'Offer',
          price: '0',
          priceCurrency: 'USD',
        },
      },
    ],
  };
}

export function getPageContent(pageKey, locale = defaultLocale) {
  const activeLocale = getActiveLocale(locale);
  const copy = localizedContent[activeLocale];
  const paths = buildPaths(pageKey);
  const assets = buildAssets(pageKey);

  return {
    ...siteConfig,
    brand: {
      ...siteConfig.brand,
      slogan: copy.footer.tagline,
    },
    locale: activeLocale,
    navigation: copy.navigation,
    footer: {
      copyright: `Copyright ${siteConfig.year} ByteShark.`,
      ...copy.footer,
    },
    ui: copy.ui,
    links: {
      ...siteConfig.links,
    },
    assets,
    paths,
    seo: getPageSeo(pageKey, activeLocale),
    pageKey,
    page: getLocalizedPage(copy, pageKey, assets),
  };
}
