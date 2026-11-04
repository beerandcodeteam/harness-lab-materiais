# Aula 4.2 · O teste verde que mente

Módulo 4 · Prova. Material de apoio em PDF: [material-de-apoio-aula-4.2.pdf](material-de-apoio-aula-4.2.pdf).

Verde só prova o caminho que o teste percorreu. No caso da aula, o agente relatou 162 testes
passando e a primeira chamada real à OpenAI voltou HTTP 400: todos os testes conversavam com um
dublê, e um campo `->nullable()` sem `->required()` ficou fora do `required` do structured
output. Esta pasta tem a guarda que impede o agente de reescrever o teste para passar, o teste de
contrato do schema (Pest e qualquer stack), o dublê na borda HTTP com a resposta gravada e a
versão de borda, o smoke real fora do juiz e o bloco que leva o ponto de fora para a spec.

## O que é instalado

| Arquivo no seu projeto | Evento · matcher | O que faz |
| --- | --- | --- |
| `.claude/hooks/guarda-aceite.py` | PreToolUse · `Edit\|Write\|MultiEdit` | Nos testes listados em `.claude/aceite.txt`, a única edição permitida é tirar o marcador de pendente (`->todo()`, `.skip`, `@pytest.mark.skip`). Write sobre arquivo existente e qualquer outra edição voltam com exit 2 e o motivo |
| `.claude/aceite.exemplo.txt` | | O formato da lista: um caminho por linha, relativo à raiz, aceita curinga |
| `.claude/settings.json` | | Liga o hook. Se você já tem um, é somado ao seu |

Sem `.claude/aceite.txt` o hook não faz nada. Liste cada teste **depois** de revisado e visto
vermelho: listado antes, o agente não consegue corrigir o teste que acabou de escrever.

O matcher vem do slide da aula. `MultiEdit` não aparece mais na lista de ferramentas da
documentação atual do Claude Code (Tools reference), que usa `Edit|Write` nos exemplos de hook;
fica no matcher porque não atrapalha. O limite é outro: Bash e NotebookEdit passam por fora do
hook ("Rules match tool calls, not intent").

## Instalar

Precisa de `python3` e `jq` (`sudo apt install python3 jq` no Ubuntu e WSL, `brew install jq` no macOS).

```bash
cd ~
git clone https://github.com/beerandcodeteam/harness-lab-materiais
cd /caminho/do/seu/projeto
~/harness-lab-materiais/instalar.sh 4.2
```

Já baixou antes? `git -C ~/harness-lab-materiais pull`. O `settings.json.antes-harness-lab` é só backup: não commite.

Na ordem do PDF: instalar, testar o hook, ver o contrato vermelho e verde, só então pôr o teste
sob guarda. O resto desta página segue essa ordem.

## 1. Teste o hook antes de confiar nele

Na raiz do seu projeto:

```bash
A=~/harness-lab-materiais/modulo-4-prova/aula-4.2-o-teste-verde-que-mente
bash $A/modelos/testes/testa-guarda.sh .claude/hooks/guarda-aceite.py
```

Esperado: `16 passaram, 0 falharam`. O script monta um projeto falso numa pasta temporária e não
mexe no seu.

## 2. O contrato do caso, em qualquer stack

```bash
M=~/harness-lab-materiais/modulo-4-prova/aula-4.2-o-teste-verde-que-mente/modelos
python3 -I $M/schema_estrito.py $M/fixtures/schema-antes.json || echo "exit $?"
python3 -I $M/schema_estrito.py $M/fixtures/schema-depois.json
```

O primeiro lista 6 campos fora do `required` e sai com 1; o segundo diz `ok`. O script aceita o
JSON Schema puro ou o corpo inteiro do pedido (Responses API ou Chat Completions). Os dois
fixtures são **reconstrução didática** do caso, gerados pelo `laravel/ai` a partir de
`laravel/AnalisaProduto.antes.php` e `.depois.php`, não o schema original.

## 3. O contrato no seu projeto Laravel, vermelho uma vez

```bash
A=~/harness-lab-materiais/modulo-4-prova/aula-4.2-o-teste-verde-que-mente
mkdir -p tests/Feature/Ai
cp $A/modelos/laravel/SchemaEstritoTest.php tests/Feature/Ai/
```

No Claude Code: `troque AnalisaProduto no SchemaEstritoTest pelos agentes do app`. Depois tire
um `->required()` de um campo do seu agente e rode `php artisan test --filter=SchemaEstrito`
(com Sail, `vendor/bin/sail test --filter=SchemaEstrito`). O vermelho tem que trazer o nome do
campo. Desfaça e rode de novo: verde. Fora do Laravel, o pedido de `modelos/pedir-o-contrato.md`
escreve o teste de contrato da sua stack.

## 4. Ponha o contrato sob guarda e prove o bloqueio

Só agora, com o teste revisado e já visto vermelho:

```bash
echo 'tests/Feature/Ai/SchemaEstritoTest.php' >> .claude/aceite.txt
T=tests/Feature/Ai/SchemaEstritoTest.php
j='{"tool_name":"Edit","tool_input":{"file_path":"'$T'",'
j+='"old_string":"toBe([])","new_string":"toBeArray()"}}'
echo "$j" | python3 .claude/hooks/guarda-aceite.py || echo "exit $?"
```

Esperado: `Bloqueado: essa edição muda o teste, não só o marcador...` e `exit 2`. No Claude Code,
`/hooks` mostra o hook em PreToolUse.

## 5. Smoke real e dublê na borda

No Laravel:

```bash
A=~/harness-lab-materiais/modulo-4-prova/aula-4.2-o-teste-verde-que-mente
L=$A/modelos/laravel
mkdir -p tests/Fixtures/openai/gravada
cp $L/SmokeOpenAiTest.php $L/DubleNaBordaHttpTest.php tests/Feature/Ai/
cp $L/gravada/analisa-produto.json tests/Fixtures/openai/gravada/
```

Cole o bloco de `modelos/laravel/phpunit-groups.xml` no `phpunit.xml`, depois de `</testsuites>`, e troque o agente nos dois testes:

```bash
php artisan test                         # o juiz: o smoke fica de fora
php artisan test --group=integration     # só o smoke, com a OPENAI_API_KEY do .env
```

Como as duas respostas se separam:

- **Gravada** (`tests/Fixtures/openai/gravada/analisa-produto.json`): o smoke grava ali a
  resposta crua de cada chamada real. É a forma real e as chaves que o provedor manda. A do
  repositório é reconstrução até você rodar o smoke com chave. Olhe o `git diff` dela antes de
  commitar: chave nova ou sumida aparece ali.
- **Borda**: a gravada com o pior caso injetado à mão dentro do `DubleNaBordaHttpTest.php`
  (`respostaDeBorda()`): texto maior que a coluna e `null` em cada campo nullable. Uma chamada
  real não garante esse pior caso; você o escreve sobre a forma real. O smoke nunca mexe nele,
  então rodar o smoke não deixa o juiz vermelho.

No Python, junte o bloco de `modelos/python/pyproject-integration.toml` ao seu `pyproject.toml`
e copie `modelos/python/test_smoke_openai.py` para `tests/`: `pytest -q` é o juiz,
`pytest -m integration` roda só o smoke. Ele grava em `tests/fixtures/openai/gravada/` o que a sua função
devolveu (a forma), não o corpo HTTP. O dublê em Python não vem pronto: troque só a rede, com
respx se você chama o provedor com httpx. O openai-python 3.x usa HTTPX2, que o respx não
intercepta (testado com openai 3.44.0 e respx 0.23.1); para qualquer versão do SDK, sirva o
corpo gravado num servidor local e aponte `OPENAI_BASE_URL` para ele.

## 6. Leve o ponto de fora para a spec

`modelos/integracao-na-spec.md` tem o bloco "Pontos de fora" para colar no seu `FEATURE-ALVO.md`
antes do `/plan` da aula 4.3, com critérios binários (smoke aceito, contrato montado pelo SDK,
dublê com a gravada e a borda, coluna que comporta o maior texto, erro do provedor tratado) e o
pedido de sessão:

```text
> antes do plano, rode um smoke real do ponto de fora e liste os campos
```

No fim da feature, antes do PR, navegue o caminho principal com a configuração de staging e o log
aberto (`tail -f storage/logs/laravel.log`). Foi assim que o 400 do caso apareceu.

## Para ler e adaptar (não são instalados)

| Arquivo | Para quê |
| --- | --- |
| `modelos/pedir-o-contrato.md` | Os pedidos da demo e da prática, as quatro perguntas para ler o teste que voltou e o "vermelho uma vez" |
| `modelos/integracao-na-spec.md` | O bloco "Pontos de fora" para o `FEATURE-ALVO.md` e a SPEC, com o exemplo do caso preenchido |
| `modelos/schema_estrito.py` + `fixtures/` | Teste de contrato para qualquer stack: cada chave de `properties` fora do `required`, em todo nível. Só biblioteca padrão |
| `modelos/laravel/SchemaEstritoTest.php` | O mesmo contrato em Pest, montando o schema pelo caminho do SDK (`ObjectSchema` e `toSchema()`). Vai em `tests/Feature/Ai/`; troque `AnalisaProduto` pelos seus agentes |
| `modelos/laravel/AnalisaProduto.antes.php`, `.depois.php` | O agente do caso, quebrado e corrigido, para ver o contrato vermelho e verde |
| `modelos/laravel/DubleNaBordaHttpTest.php` + `gravada/analisa-produto.json` | O dublê na borda HTTP: `Http::fake()` troca só a rede e o SDK monta o pedido de verdade. Três casos: a gravada, a de borda (injetada no teste) e o 400 real |
| `modelos/laravel/SmokeOpenAiTest.php` | A chamada real, no grupo `integration`, pulada sem `OPENAI_API_KEY`. Grava a resposta crua em `tests/Fixtures/openai/gravada/` |
| `modelos/laravel/phpunit-groups.xml` | O bloco `<groups>` que tira o smoke do comando do juiz. Cole no `phpunit.xml`, depois de `</testsuites>` |
| `modelos/python/test_smoke_openai.py` + `pyproject-integration.toml` | O smoke em pytest, com o marcador `integration` fora do `pytest` padrão |
| `modelos/testes/testa-guarda.sh`, `testa-schema.sh` | Os testes do hook (16 casos) e do script (9 casos) |

## O que foi testado (03/11/2026)

- `guarda-aceite.py`: 16 casos com JSON falso (Pest, Vitest, pytest).
- `schema_estrito.py`: 9 casos; o schema do caso dá os 6 campos e exit 1.
- Modelos Laravel num projeto `livewire-starter-kit` (Laravel 13, Pest 5.3.5, `laravel/ai` 1.3.0, SQLite em memória):
  `SchemaEstritoTest` vermelho com o agente `.antes`, verde com o `.depois`; `DubleNaBordaHttpTest`
  verde nos três casos e vermelho com um `TypeError` quando o agente devolve JSON Schema cru;
  `AnalisaProduto::fake()` com resposta pronta fica verde com o schema quebrado; com o `<groups>`
  no `phpunit.xml`, a suíte inteira (38 testes) não roda o smoke e `--group=integration` roda só ele.
- O ciclo smoke e juiz, com chave, contra um servidor falso local (`OPENAI_URL`) que devolvia uma
  resposta diferente da reconstrução (item de reasoning antes da mensagem, nada `null`, texto
  curto): o smoke gravou essa resposta na gravada, o corpo do pedido passou no
  `schema_estrito.py`, e o juiz rodado em seguida, sem chave, continuou verde.
- Modelos Python no pytest 9.2.0: o `addopts` deixa o smoke de fora, `-m integration` roda só ele,
  e um import quebrado no topo do arquivo derruba a coleta (por isso o import fica dentro do teste).

Não testado: chamada real à OpenAI (o teste de contrato é sem rede por desenho), Laravel Sail e
Pest 4.

Para quem mantém o repositório: o `projeto/.claude/aceite.exemplo.txt` tem uma linha a mais que o
`exemplos/4.2/aceite.exemplo.txt` do curso, `tests/Feature/Ai/SchemaEstritoTest.php`, como no
slide da aula. `bash testes/rodar.sh 4.2` roda os comandos do PDF numa sandbox e o
`teste/verificar.sh`.
