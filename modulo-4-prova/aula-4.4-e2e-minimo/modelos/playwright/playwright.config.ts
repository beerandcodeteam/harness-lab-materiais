// playwright.config.ts · aula 4.4 · o mínimo: um navegador, o servidor do app e a URL base.
// Troque o command e a url pelos do seu projeto. O resto (vários navegadores, CI,
// trace, relatórios) fica para o bônus de Playwright.
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  use: {
    baseURL: 'http://localhost:3000',
  },
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
  },
});
