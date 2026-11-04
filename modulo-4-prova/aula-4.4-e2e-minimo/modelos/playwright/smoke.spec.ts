// smoke.spec.ts · aula 4.4 · o comando da Prova consegue abrir um navegador? (Playwright Test)
//
// Onde pôr: tests/e2e/smoke.spec.ts (a pasta do testDir do playwright.config.ts)
// Fica ATIVO, sem marcador de pendente. O E2E da feature nasce pendente, e teste pendente não abre
// o navegador: sem este smoke, a Prova fica verde mesmo sem Chromium no ambiente.
// Rode pelo comando da Prova (npm test), não só com npx playwright test.
import { expect, test } from '@playwright/test';

test('a home abre sem erro de JavaScript', async ({ page }) => {
  // Só erro de JavaScript. O console também registra "Failed to load resource" de
  // qualquer 4xx, que não é defeito da página.
  const erros: string[] = [];
  page.on('pageerror', (erro) => erros.push(erro.message));

  const resposta = await page.goto('/');

  expect(resposta?.ok()).toBe(true);
  expect(erros).toEqual([]);
});
