import { renderFooter, renderNavbar } from './SiteChrome.js';

export function renderPrivacyPage(content) {
  const { hero, sections, contact } = content.page;

  return `
    ${renderNavbar(content)}
    <main id="main-content">
      <section class="relative overflow-hidden pt-28 sm:pt-32">
        <div aria-hidden="true" class="hero-grid absolute inset-0 opacity-[0.12]"></div>
        <div class="section-shell relative space-y-6 pb-16 pt-10 sm:pb-20">
          <span class="eyebrow">${hero.eyebrow}</span>
          <h1 class="max-w-4xl font-headline text-[clamp(2.8rem,10vw,4.6rem)] font-bold leading-[0.95] tracking-tight text-on-surface">
            ${hero.title}
          </h1>
          <p class="max-w-3xl text-lg leading-8 text-on-surface-variant sm:text-xl">
            ${hero.intro}
          </p>
          <span class="signal-chip">${hero.updatedLabel}: ${hero.updatedValue}</span>
        </div>
      </section>
      <section class="pb-24 sm:pb-28">
        <div class="section-shell grid gap-5 lg:grid-cols-2">
          ${sections
            .map(
              (item) => `
                <article class="info-card">
                  <h2 class="text-2xl font-bold text-on-surface">${item.title}</h2>
                  <p class="mt-4 text-sm leading-7 text-on-surface-variant">${item.body}</p>
                </article>
              `,
            )
            .join('')}
          <article class="glass-panel rounded-[28px] border border-outline-variant/30 p-6">
            <h2 class="text-2xl font-bold text-on-surface">${contact.title}</h2>
            <p class="mt-4 text-sm leading-7 text-on-surface-variant">${contact.body}</p>
            <a class="cta-primary mt-6" href="${content.links.email}">
              ${content.links.emailAddress}
            </a>
          </article>
        </div>
      </section>
    </main>
    ${renderFooter(content)}
  `;
}
