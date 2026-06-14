import { mountPage } from './app.js';
import { renderLandingPage } from './components/LandingPage.js';

mountPage({
  pageKey: 'home',
  render: renderLandingPage,
});
