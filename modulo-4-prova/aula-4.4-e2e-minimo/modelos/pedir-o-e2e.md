# Pedir o E2E · aula 4.4

Um pedido, um fluxo: o principal da sua feature-alvo. Cole no Claude Code, na raiz do
repositório, com o `FEATURE-ALVO.md` e os testes de aceite da aula 4.3 já commitados e o
smoke passando no comando da Prova (ver `pedir-o-ambiente.md`).

## O pedido

Troque "Pest browser" pela ferramenta da sua stack: "Playwright Test" (Node),
"pytest-playwright" (Python) ou "HTTP test do Laravel" (feature só de API).

```
Escreva UM teste E2E com Pest browser para o fluxo principal da feature do
FEATURE-ALVO.md: o caminho que o usuário faz do começo ao fim, na ordem dele, pela tela
(pela rota, se a feature é só API). Escolha o critério de aceite que só esse caminho
prova e ponha o ID dele (AC-NN) no nome do teste. No Laravel, "E2E" no nome do arquivo:
é por ele que o --filter=E2E e o confere-e2e.py acham o teste.
- A pré-condição nasce no próprio teste (factory, seed ou pela tela). Nada de depender
  de dado que já está no banco.
- Serviço de fora (e-mail, pagamento, API de terceiro) fica fakeado, como na aula 4.2.
  No Playwright Test e no pytest-playwright com o app num subprocess, o app roda em
  outro processo: o fake entra pela configuração do app (env do webServer, ou da
  fixture do conftest.py), não por mock dentro do teste.
- Se a feature ainda não existe, deixe pendente com o corpo escrito: ->todo() no Pest,
  test.skip no Playwright, @pytest.mark.skip no pytest.
- Modelos em ~/harness-lab-materiais/modulo-4-prova/aula-4.4-e2e-minimo/modelos/
- Um teste só. Não mexa em nenhum teste que já existe.
Rode o comando da Prova inteiro no fim e me mostre o comando e a saída.
```

## O exemplo da aula (cadastro com e-mail duplicado)

```
Escreva um E2E com Pest browser para o AC-03 do FEATURE-ALVO.md, em
tests/Browser/CadastroE2ETest.php: abre o cadastro, preenche com um e-mail
que já existe em outra caixa, envia, e confere a mensagem abaixo do campo e
que não há erro no console. Use o mesmo ID no nome do teste. Se a feature
ainda não existe, deixe com ->todo() e o corpo escrito. Um teste só.
Rode a suíte inteira no fim e me mostre o comando e a saída.
```

O resultado esperado está em `pest-browser/CadastroE2ETest.php` (e, nas outras stacks, em
`playwright/cadastro.spec.ts`, `pytest-playwright/test_cadastro_e2e.py`,
`laravel-http/CadastroHttpE2ETest.php` e `laravel-http/CadastroApiE2ETest.php`).

## O que ler no resultado

- O caminho do usuário, na ordem do usuário: `visit`, `type`, `press`, `assertSee` (Pest);
  `goto`, `fill`, `click`, `expect(...).toBeVisible()` (Playwright).
- O fim do fluxo é conferido no que o usuário vê E no que ficou gravado (no Pest,
  `expect(User::count())` depois da tela; no Playwright, o efeito na tela seguinte).
- Erro de JavaScript conferido: `assertNoSmoke()` no Pest; `page.on('pageerror')` no
  Playwright. Não use todo `console.error`: o navegador registra "Failed to load resource"
  de qualquer resposta 4xx, inclusive o 422 de uma validação que funcionou.
- O nome começa com o ID do critério. No Laravel, o arquivo tem "E2E" no nome: o
  `--filter=E2E` do Pest acha o teste pelo nome do arquivo, e o `confere-e2e.py` acha o
  HTTP test do Laravel por ele. Os modelos de Node e Python não dependem do nome.
- Um teste. Se vieram cinco, peça para ficar só o do fluxo principal.

## Conferir você mesmo

1. Tire o marcador e rode só ele: `./vendor/bin/pest --filter=E2E`
   (Sail: `vendor/bin/sail test --filter=E2E`; Node: `npx playwright test`; Python:
   `pytest tests/e2e`).
2. Antes da feature existir, ele falha pelo motivo certo: a mensagem, a tela ou o registro
   que o critério pede não aparece. Falhou por outro motivo (rota, seletor, ambiente)?
   Conserte o teste ou o ambiente antes de seguir.
3. Devolva o marcador. Rode o comando da Prova inteiro: verde, com o pendente no placar.
4. `python3 .claude/scripts/confere-e2e.py`: o E2E aparece e o resultado é "os E2E entram
   no comando do juiz".
5. Se você instalou a trava da aula 4.2, acrescente o caminho do E2E ao `.claude/aceite.txt`:
   o loop só vai poder tirar o marcador.
6. Commite. O loop do Módulo 5 roda esse comando em toda fase.

## Se der errado

- "No tests found." com `--filter`, ou a suíte verde sem o E2E no placar: `tests/Browser`
  fora das `<testsuite>` do `phpunit.xml`.
- "Target class [config] does not exist.": `tests/Browser` fora do `->in()` do
  `tests/Pest.php`.
- "Playwright is outdated" (Pest) ou "Executable doesn't exist" (Playwright): o Chromium
  da versão do Playwright não está no ambiente onde o teste rodou (`npx playwright install`;
  Python: `playwright install`). Se o erro aponta para firefox ou webkit, é o config do
  `npm init` rodando três navegadores: deixe um só.
- "net::ERR_CONNECTION_REFUSED" (Python): o app não está de pé. O pytest-playwright não
  sobe servidor: use a fixture do `conftest.py` (modelo ao lado do smoke).
- Passou sem o marcador antes de existir a feature: o teste não olha o que o critério pede.
  Leia a asserção.
