// vitest.config.ts · aula 4.4 · Vitest e Playwright na mesma suíte, sem um pegar o arquivo do outro.
//
// O padrão do Vitest pega todo *.spec.ts e *.test.ts, inclusive os do Playwright, e o
// "npm test" quebra com "test.skip() can only be called inside test, describe block or
// fixture". Tire a pasta do E2E do Vitest. Do outro lado, o playwright.config.ts aponta
// testDir para tests/e2e, senão o Playwright tenta rodar os testes do Vitest.
//
// Já tem vite.config.ts com bloco test? Junte só o exclude lá.
import { configDefaults, defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    exclude: [...configDefaults.exclude, 'tests/e2e/**'],
  },
});
