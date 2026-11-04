# Aula 4.4 · E2E mínimo: um fluxo, de ponta a ponta

Módulo 4 · Prova. Material de apoio em PDF: [material-de-apoio-aula-4.4.pdf](material-de-apoio-aula-4.4.pdf).

Um teste que usa a feature como o usuário usa, rodando no comando da Prova, o mesmo que o loop roda.
Um fluxo, não uma suíte de E2E. Esta pasta tem o conferidor que diz se o seu E2E entra no comando
da Prova, o smoke que prova que esse comando abre um navegador, os modelos de E2E das quatro stacks
da aula e os dois pedidos (o ambiente e o E2E).

Antes desta aula: o `FEATURE-ALVO.md` com os critérios e os testes de aceite da 4.3 commitados, e
o comando da Prova da 4.1 verde. Nenhum arquivo de aula anterior é obrigatório para instalar a 4.4.

## O que é instalado

| Arquivo no seu projeto | O que faz |
| --- | --- |
| `.claude/scripts/confere-e2e.py` | Acha os E2E do projeto (Pest browser em `tests/Browser`, HTTP test do Laravel com "E2E" no nome, Playwright Test, pytest-playwright), descobre o comando da Prova na mesma ordem do `qual-comando.sh` da 4.1 e confere se cada E2E entra nele: `phpunit.xml`, `tests/Pest.php`, script `test` do `package.json`, Vitest, `playwright.config` (`webServer`, `testDir` e os navegadores que o `npm init` põe), `testpaths` do pytest e o `conftest.py` que sobe o app. Só lê arquivos, nunca o `.env`, e não roda teste. Saída 0 (entra), 1 (algum fica de fora) ou 3 (nenhum E2E) |

Precisa de `python3` (biblioteca padrão). Aceita `--test-cmd "<comando>"`: passe
nele o mesmo comando que vai no `LOOP_TEST_CMD` do `loop.sh`.

## Instalar

```bash
cd ~
git clone https://github.com/beerandcodeteam/harness-lab-materiais
cd /caminho/do/seu/projeto
~/harness-lab-materiais/instalar.sh 4.4
```

Já baixou antes? `git -C ~/harness-lab-materiais pull`.

### A ferramenta de E2E da sua stack (escolha uma linha)

| Stack | E2E mínimo | Instala com (documentação oficial) |
| --- | --- | --- |
| Laravel com tela | Pest browser (Pest 4+, PHP 8.3+) | `composer require pestphp/pest-plugin-browser --dev`, `npm install playwright@latest`, `npx playwright install` ([pestphp.com](https://pestphp.com/docs/browser-testing)) |
| Laravel só API | HTTP test do Laravel | já vem no framework ([laravel.com](https://laravel.com/framework/docs/http-tests)) |
| Node / TS | Playwright Test | `npm init playwright@latest` ([playwright.dev](https://playwright.dev/docs/intro)) |
| Python | pytest-playwright | `pip install pytest-playwright`, `playwright install` ([playwright.dev](https://playwright.dev/python/docs/intro)) |

Com Sail, rode os comandos do Laravel dentro do container (`vendor/bin/sail composer ...`,
`vendor/bin/sail npm ...`, `vendor/bin/sail npx ...`). Num Linux ou container limpo, o Chromium
precisa das bibliotecas do sistema: `npx playwright install --with-deps chromium`.

- **Pest browser pede Pest 4 (PHP 8.3+) ou Pest 5 (PHP 8.4+).** No Packagist, o
  `pest-plugin-browser` 4.x pede `php ^8.3` e `pestphp/pest ^4`; o 5.x, `php ^8.4` e `pest ^5`.
  Com Pest 3 ou PHP mais antigo, o Composer recusa (`requires php ^8.4 which does not match your
  installed version`, ou `conflicts with your root composer.json require (^3.8)`). Aí, ou com
  PHPUnit puro, o E2E é o HTTP test (`modelos/laravel-http/`), sem tela, ou o Laravel Dusk, com
  o comando dusk no `LOOP_TEST_CMD` do `loop.sh` (no `confere-e2e.py`, por `--test-cmd`, e ele reconhece).
- **O `npm init playwright@latest` roda tudo em três navegadores.** O config gerado tem os
  projects de Chromium, Firefox e WebKit, o `webServer` comentado e um `tests/example.spec.ts` que
  abre playwright.dev. Apague o example e use o `modelos/playwright/playwright.config.ts` (um
  navegador, `testDir` e `webServer`). Senão, com só o Chromium instalado, cada teste roda três
  vezes e o Firefox e o WebKit caem em `Executable doesn't exist`.
- **No Python, o próprio pytest sobe o app.** O pytest-playwright não tem `webServer`: sem
  servidor de pé, o smoke cai em `Page.goto: net::ERR_CONNECTION_REFUSED`. O
  `modelos/pytest-playwright/conftest.py` sobe o app numa fixture de sessão e define o `base_url`;
  no Django, o `live_server` do pytest-django faz isso (o modelo traz as linhas).

### O smoke, ativo

```bash
A=~/harness-lab-materiais/modulo-4-prova/aula-4.4-e2e-minimo/modelos
# Laravel (também põe as duas pastas do Pest no .gitignore)
mkdir -p tests/Browser
cp "$A/pest-browser/SmokeTest.php" tests/Browser/
cat "$A/pest-browser/gitignore.exemplo" >> .gitignore
# Node
mkdir -p tests/e2e && cp "$A/playwright/smoke.spec.ts" tests/e2e/
# Python (o conftest.py que sobe o app vem do pedido do ambiente, a partir do modelo)
mkdir -p tests/e2e && cp "$A/pytest-playwright/test_smoke_e2e.py" tests/e2e/
```

Depois, o pedido do ambiente (`modelos/pedir-o-ambiente.md`) no Claude Code: ele deixa o comando da
Prova achando o teste, o navegador instalado onde a Prova roda e, no Node e no Python, o app subindo
pelo próprio teste.

## Conferir

```bash
python3 .claude/scripts/confere-e2e.py
```

Esperado: cada E2E listado (ativo ou pendente) e, no fim, "os E2E entram no comando do juiz".
Cada linha `ERRO` diz o que falta; cada `AVISO`, o que ainda pode quebrar na Prova. Depois, rode o
smoke no comando da Prova, no ambiente dela: `vendor/bin/sail test --filter=Smoke` (sem Sail:
`./vendor/bin/pest --filter=Smoke`; Node: `npm test`; Python: `pytest`). O smoke tem que passar. No
Node e no Python, com o app fechado: quem sobe o app é o teste.

## O E2E da sua feature

Peça com `modelos/pedir-o-e2e.md`: um teste, o fluxo principal, o ID do critério no nome, "E2E" no
nome do arquivo no Laravel (é por ele que o `--filter=E2E` e o `confere-e2e.py` acham o teste),
pendente se a feature é nova. Tire o marcador uma vez, veja falhar pelo motivo
certo, devolva e rode a Prova inteira. Se você instalou a trava da 4.2 (`guarda-aceite.py`), ponha o
caminho do E2E no `.claude/aceite.txt`. Commite.

## Para ler e adaptar (não são instalados)

| Arquivo | O que é |
| --- | --- |
| `modelos/pedir-o-ambiente.md` | O pedido para o Claude configurar o ambiente de E2E no comando da Prova (container incluso) e o que conferir na resposta |
| `modelos/pedir-o-e2e.md` | O pedido de um E2E do fluxo principal, o exemplo da aula, o que ler no resultado e como conferir |
| `modelos/pest-browser/SmokeTest.php` | Smoke do Laravel: `visit('/')->assertNoSmoke()`, ativo |
| `modelos/pest-browser/CadastroE2ETest.php` | O AC-03 da aula clicando (`visit`, `type`, `press`, `assertSee`, `assertNoSmoke`), com `->todo()` |
| `modelos/pest-browser/gitignore.exemplo` | As duas pastas que o Pest browser grava |
| `modelos/laravel-http/CadastroApiE2ETest.php` | E2E de API: `postJson` na rota, 422, erro no campo e o banco, com `->todo()` |
| `modelos/laravel-http/CadastroHttpE2ETest.php` | O fluxo da tela sem navegador: segue o redirect e confere o HTML |
| `modelos/playwright/smoke.spec.ts` | Smoke do Playwright Test, só erro de JavaScript (`pageerror`) |
| `modelos/playwright/cadastro.spec.ts` | O AC-03 em Playwright Test, com `test.skip` |
| `modelos/playwright/playwright.config.ts` | O mínimo: `testDir`, `baseURL` e `webServer` |
| `modelos/playwright/vitest.config.ts` | O `exclude` que tira a pasta do E2E do Vitest, para os dois rodarem no mesmo `npm test` |
| `modelos/pytest-playwright/test_smoke_e2e.py` | Smoke do pytest-playwright (precisa do app de pé: o `conftest.py` ao lado) |
| `modelos/pytest-playwright/conftest.py` | O equivalente do `webServer` no Python: fixture de sessão que sobe o app, espera a porta e define o `base_url`. Traz as linhas do Django (`live_server`) |
| `modelos/pytest-playwright/test_cadastro_e2e.py` | O AC-03 em pytest-playwright, com `@pytest.mark.skip` |

## O que foi testado

- `confere-e2e.py`: no projeto Laravel de teste (Laravel 13, Pest 5.3.5, pest-plugin-browser 5.2.0),
  num projeto Node, num Python e num Django reais, no projeto que o `npm init playwright@latest`
  gera, e nos 20 grupos do `teste/verificar.sh` (projetos falsos de Laravel, Laravel com Dusk, Node,
  Python e Django, sem rede).
- `conftest.py`: o smoke passou com o app subindo pela fixture (FastAPI com o modelo sem mudar
  nada, Flask com a linha do comentário, e um app de teste), e a porta fechou no fim; o E2E
  pendente sozinho não subiu o app. Sem a fixture, `Page.goto: net::ERR_CONNECTION_REFUSED`. Com
  `@pytest.fixture` sem escopo, `ScopeMismatch`. No Django, o `live_server` passou com
  `DJANGO_ALLOW_ASYNC_UNSAFE` (sem ela, `SynchronousOnlyOperation`), e um `mock.patch` no teste
  chegou ao app.
- `npm init playwright@latest` (create-playwright 1.17.139): com só o Chromium instalado,
  "Running 6 tests" para 2 testes e 4 falhas `Executable doesn't exist` (Firefox e WebKit).
- Pest browser num projeto Pest 3: com PHP 8.2, `requires php ^8.4 which does not match your
  installed version`; com PHP 8.4, `conflicts with your root composer.json require (^3.8)`.
- `./vendor/bin/pest --filter=E2E` acha o `CadastroE2ETest.php` pelo nome do arquivo (a descrição
  do teste não tem "E2E").
- Os modelos de E2E rodaram: pendente, vermelho sem o marcador e verde no controle. O
  `CadastroApiE2ETest.php` rodou com uma rota `/api/register` de teste (o starter kit não tem API):
  pendente, `Expected response status code [422] but received 201.` e verde no controle.
- Os três smokes passaram contra um app de teste e falharam sem navegador (`Playwright is outdated`
  no Pest, `Executable doesn't exist` no Playwright), enquanto o E2E pendente seguia verde.
- Não testado: Pest browser dentro do Laravel Sail (não está na doc do Pest). A prova é o smoke com
  `vendor/bin/sail test --filter=Smoke`.

Versões: Pest 5.3.5, pest-plugin-browser 5.2.0, Playwright Test 1.64.1 (Node 22.20.0), Vitest 4.1.12,
pytest-playwright 0.10.0 (Python 3.14), Django 6.1.3 com pytest-django 4.14.0, FastAPI 0.162.0 com
uvicorn 0.54.0, Flask 3.1.3, PHP 8.5.
