# Pedir o ambiente de E2E · aula 4.4

Na aula: "tem uma parte de infraestrutura que é importante que você saiba configurar, ou ao
menos solicitar ao seu assistente de código que configure o seu ambiente para ser capaz de
rodar testes end-to-end". Este é o pedido.

Quando usar: depois de instalar a ferramenta da sua stack e copiar o smoke (passos 3 e 4 do
PDF), na raiz do repositório, com o `confere-e2e.py` instalado (`instalar.sh 4.4`).

## O pedido

```
Configure este projeto para rodar testes E2E no comando de teste que o loop roda
(a Prova). Primeiro descubra qual é esse comando e onde ele roda: na minha máquina, num
container (Sail, Docker Compose, devcontainer) ou no CI. Me diga antes de mudar.

1. A ferramenta de E2E da stack e o Chromium do Playwright instalados NO MESMO
   ambiente em que o comando da Prova roda. Se for container, a instalação vai para o
   Dockerfile ou para o compose, para não sumir quando o container for recriado.
2. O comando da Prova precisa achar o teste:
   - Laravel: tests/Browser numa <testsuite> do phpunit.xml e no ->in() do
     tests/Pest.php (o TestCase e o RefreshDatabase valem para Browser também).
   - Node: o script "test" do package.json chama o playwright test; o Vitest não pega
     a pasta do E2E; o playwright.config tem testDir na pasta do E2E, webServer e um
     navegador só, sem os projects de Firefox e WebKit e sem o example.spec.ts do
     npm init.
   - Python: o pytest acha a pasta do E2E (testpaths no pytest.ini) e o próprio pytest
     sobe o app, como o webServer do Playwright. Django: a fixture live_server do
     pytest-django, com o base_url vindo de live_server.url. FastAPI ou Flask: uma
     fixture de sessão no conftest.py que sobe o servidor e espera a porta.
3. Laravel: tests/Browser/Screenshots e tests/Browser/Traces no .gitignore.
4. O smoke fica ATIVO, sem marcador de pendente. Não escreva o E2E da feature agora.
Modelos em ~/harness-lab-materiais/modulo-4-prova/aula-4.4-e2e-minimo/modelos/

No fim, rode o comando da Prova inteiro e me mostre o comando e a saída, com o smoke
passando. Rode python3 .claude/scripts/confere-e2e.py e resolva cada linha ERRO.
Não mexa em nenhum teste que já existe.
```

## O que conferir na resposta

- O comando que ele rodou é o mesmo que o loop vai rodar (o da aula 4.1), inteiro, não um
  `--filter` só do smoke.
- O smoke aparece como passou na saída. Pendente não conta: teste pendente não abre o
  navegador.
- Node e Python: feche o app que você deixou aberto e rode a Prova de novo. O smoke
  continua passando, porque quem sobe o app é o teste (webServer no Node, fixture do
  `conftest.py` no Python). Se cair em `net::ERR_CONNECTION_REFUSED`, a Prova dependia do
  app aberto à mão.
- `confere-e2e.py` termina com "os E2E entram no comando do juiz".
- Container: a mudança está num arquivo versionado (Dockerfile, compose, script de setup),
  não só num comando que ele rodou dentro do container de pé.

## Referências por stack (modelos ao lado deste arquivo)

| Stack | Smoke | Config |
| --- | --- | --- |
| Laravel + Pest browser | `pest-browser/SmokeTest.php` | `pest-browser/gitignore.exemplo` |
| Node + Playwright Test | `playwright/smoke.spec.ts` | `playwright/playwright.config.ts`, `playwright/vitest.config.ts` |
| Python + pytest-playwright | `pytest-playwright/test_smoke_e2e.py` | `pytest-playwright/conftest.py` (sobe o app), `testpaths` no `pytest.ini` |

Comandos de instalação, da documentação de cada ferramenta:

- Pest browser (pestphp.com/docs/browser-testing): `composer require pestphp/pest-plugin-browser --dev`,
  `npm install playwright@latest`, `npx playwright install`. O plugin só existe no Pest 4
  (PHP 8.3+) e no Pest 5 (PHP 8.4+). Em PHPUnit, Pest 3 ou PHP mais antigo, o E2E é o HTTP
  test (`laravel-http/`), sem tela, ou o Laravel Dusk, com o comando dusk no `LOOP_TEST_CMD` do
  `loop.sh` (no `confere-e2e.py`, por `--test-cmd`, e ele reconhece).
- Playwright Test (playwright.dev/docs/intro): `npm init playwright@latest`. Ele cria um
  config que roda Chromium, Firefox e WebKit e um `tests/example.spec.ts` que abre
  playwright.dev. Apague o example e use o `playwright/playwright.config.ts` daqui.
- pytest-playwright (playwright.dev/python/docs/intro): `pip install pytest-playwright`, `playwright install`.
- Navegador mais as bibliotecas do sistema, numa máquina ou container Linux limpo
  (playwright.dev/docs/browsers, "Install system dependencies"): `npx playwright install --with-deps chromium`
  (Python: `playwright install --with-deps chromium`). Ele instala pacotes do sistema: sem root,
  o Playwright tenta virar root (sudo).

Pest browser dentro do Laravel Sail não está na documentação do Pest e não foi testado neste
curso. O smoke rodando com `vendor/bin/sail test --filter=Smoke` é a prova.
