import { mountPage } from './app.js';
import { renderPrivacyPage } from './components/PrivacyPage.js';

mountPage({
  pageKey: 'privacy',
  render: renderPrivacyPage,
});
