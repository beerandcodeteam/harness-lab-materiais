// cadastro.spec.ts · aula 4.4 · o AC-03 do FEATURE-ALVO.md, clicando como o usuário (Playwright Test)
//
// Onde pôr: tests/e2e/cadastro.spec.ts
// Pendente: test.skip com o corpo escrito, até a fase que implementa a mensagem.
// Rótulos ('E-mail', 'Criar conta') são exemplo: troque pelos da sua tela.
//
// O E2E só conta se rodar no comando da Prova. Se o seu "npm test" roda Vitest,
// junte os dois: "test": "vitest run && playwright test".
import { expect, test } from '@playwright/test';

test.skip('AC-03 · mostra "Este e-mail já está cadastrado" abaixo do campo', async ({ page }) => {
  // Erro de JavaScript na página. Não use console.error inteiro: o navegador registra
  // "Failed to load resource ... 422" quando o app responde 422 à validação.
  const erros: string[] = [];
  page.on('pageerror', (erro) => erros.push(erro.message));

  // Pré-condição: ana@exemplo.com já cadastrado. Crie pelo seed do teste ou pela própria tela.
  await page.goto('/register');
  await page.getByLabel('Nome').fill('Ana Souza');
  await page.getByLabel('E-mail').fill('ana@exemplo.com');
  await page.getByLabel('Senha').fill('senha-forte-123');
  await page.getByRole('button', { name: 'Criar conta' }).click();

  await page.goto('/register');
  await page.getByLabel('Nome').fill('Ana de novo');
  await page.getByLabel('E-mail').fill('Ana@Exemplo.com');
  await page.getByLabel('Senha').fill('senha-forte-123');
  await page.getByRole('button', { name: 'Criar conta' }).click();

  await expect(page.getByText('Este e-mail já está cadastrado')).toBeVisible();
  expect(erros).toEqual([]);
});
