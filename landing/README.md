# Aphidex Landing

Standalone landing page for Aphidex, prepared to live in its own repository and publish with GitHub Pages at `https://byteshark-dev.github.io/aphidex/`.

## Stack

- Vite
- Tailwind CSS
- Vanilla JavaScript modules

## Install

```bash
npm install
```

## Run locally

```bash
npm run dev
```

## Build

```bash
npm run build
```

The production files are written to `dist/`.

## Publish to GitHub Pages

1. Move this folder into its own repository, ideally named `aphidex`.
2. Keep the workflow in `.github/workflows/deploy.yml`.
3. Push the repository to GitHub.
4. In repository settings, use GitHub Pages with GitHub Actions.
5. The site will publish at `https://byteshark-dev.github.io/aphidex/`.

## Project structure

- `index.html`: landing page entry
- `privacy/index.html`: privacy policy page
- `src/config/site.js`: editable copy, links, metrics and screenshot metadata
- `public/app-ads.txt`: ad inventory authorization for the companion domain

## Content updates

The following values are intentionally easy to edit from `src/config/site.js`:

- Google Play and App Store URLs
- Hero copy
- Feature cards
- Metrics
- Screenshot captions
- Supported languages list
- Legal note
- Privacy page text

## Notes

- The project uses relative paths so it can build correctly under a GitHub Pages project path.
- Review the privacy copy before using it as a final store policy if the app data flows change.
