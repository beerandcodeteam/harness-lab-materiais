# Aula 4.3 · Spec com critério de aceite verificável

Módulo 4 · Prova. Material de apoio em PDF: [material-de-apoio-aula-4.3.pdf](material-de-apoio-aula-4.3.pdf).

Spec não é "faz o cadastro, valida o e-mail, mensagem amigável". É critério binário, que um teste
confere. Esta pasta tem o `/plan` da aula, o comando que orquestra três subagentes (especificador,
clarificador e planejador) e transforma a sua frase, ou o `FEATURE-ALVO.md` da aula 1.5, em SPEC,
plano e fases prontas para o loop do Módulo 5. Mais o script que confere o `PHASES.md` fora da
sessão e o exemplo do cadastro com um teste por critério.

## O que é instalado

| Arquivo no seu projeto | O que faz |
| --- | --- |
| `.claude/commands/plan.md` | O `/plan`. Roteador: normaliza a entrada, faz as 4 paradas com você (critérios, SPEC, perguntas, fases), delega aos três agentes e confere os arquivos em disco. Nunca escreve código |
| `.claude/agents/specifier.md` | O especificador. Lê `AGENTS.md`, `docs/agents/` e o código, e escreve a `SPEC.md`: requisitos com ID, formas de evento, estado, condição, indesejado e opcional, critério binário, AS IS e TO BE |
| `.claude/agents/clarifier.md` | O clarificador, "chato de propósito". Acha ambiguidade, lacuna e contradição na SPEC e devolve perguntas com o impacto de cada resposta. Não fala com você: quem pergunta é o `/plan` |
| `.claude/agents/planner.md` | O planejador. Escreve `PLAN.md` e `PHASES.md`: tasks com arquivos, mudança, critério de aceite e testes, em fases no formato que o loop lê |
| `.claude/scripts/confere-phases.sh` | Confere o `PHASES.md` contra o contrato do loop: `## Phase N: título`, nenhum outro `## ` no meio, toda task com `Acceptance criteria:` e `Testes:`, mesmo número de tasks do `PLAN.md`. É o mesmo script do Módulo 5 |

Os quatro arquivos do `/plan` são os da gravação: os do BC Harness 0.2.0 (licença MIT), com a
delegação pelo nome local (`specifier`, `clarifier`, `planner`) em vez de `bc-harness:specifier`.
Nenhum fixa `model`: rodam no modelo da sua sessão.

## Antes

- **`AGENTS.md` e `docs/agents/`** do `/bc-harness:ai-context` (aula 3.4). Sem eles o `/plan` para
  e pergunta se segue sem arquitetura. Só o `CLAUDE.md` não basta.
- **A feature-alvo** da aula 1.5 (`FEATURE-ALVO.md` na raiz) ou uma frase sobre ela.

Nenhuma aula anterior precisa ser instalada antes desta.

## Instalar

```bash
cd ~
git clone https://github.com/beerandcodeteam/harness-lab-materiais
cd /caminho/do/seu/projeto
~/harness-lab-materiais/instalar.sh 4.3
claude plugin validate .claude/commands
claude plugin validate .claude/agents
```

Já baixou antes? `git -C ~/harness-lab-materiais pull`.

Abra o Claude Code na raiz do projeto **depois** de instalar. Se a pasta `.claude/agents/` não
existia quando a sessão abriu, feche e abra de novo.

Sem o BC Harness ainda (para o `/bc-harness:ai-context`):

```bash
claude plugin marketplace add beerandcodeteam/beer-and-code-harness
claude plugin install bc-harness@beer-and-code
```

## Usar

**1. Critérios com ID e um teste por critério, antes do `/plan`.** É o entregável da aula: "faz o
cadastro" virando critério que um teste confere. Os dois pedidos estão em
`modelos/pedir-os-testes.md` (o molde dos critérios, em `modelos/modelo-criterios.md`). Esperado:
`FEATURE-ALVO.md` com AC-01 a AC-NN e a suíte verde, com os novos pendentes no placar (no exemplo do
cadastro: `Tests: 2 todos, 2 passed` no Pest, `2 passed, 2 skipped` no pytest). Tire o marcador de
um pendente uma vez e rode só ele: tem que falhar pelo motivo do critério. Vem antes do `/plan`
porque, com os pendentes já na suíte, o planner cria a task que tira cada marcador. Com a guarda da
4.2 instalada, ponha o arquivo revisado no `.claude/aceite.txt`.

Tem ponto de fora (API, fila, e-mail)? Antes do `/plan`, cole no `FEATURE-ALVO.md` o bloco Pontos de
fora de `modulo-4-prova/aula-4.2-o-teste-verde-que-mente/modelos/integracao-na-spec.md`.

**2. O `/plan`**, dentro do Claude Code, na raiz do projeto:

```text
/plan FEATURE-ALVO.md
```

Ou em texto, como na aula: `/plan Quero incluir um contador de visitas aos posts do blog`.

Ele escreve só em `.spec/features/<slug>/`: `SPEC.md`, `PLAN.md`, `PHASES.md` e, quando a SPEC
declara uma API, `openapi.yaml`. O passo a passo das paradas, com o que responder em cada uma, está
em `modelos/pedir-o-plan.md`. Na parada 1, peça ao planner uma task que tira o marcador de cada
teste pendente, citando o AC-NN. Com o `tests/Feature/Ai/SchemaEstritoTest.php` da 4.2 no
`.claude/aceite.txt`, peça também que uma task cite esse caminho no `Testes:` (a do critério de
contrato, se houver).

Num terminal local, o `/plan` do projeto substitui o `/plan` nativo do Claude Code (o que entra no
modo de planejamento). O modo de planejamento continua no `Shift+Tab`. Só com o plugin BC Harness,
sem a cópia local, o pipeline está em `/bc-harness:plan` e o `/plan` puro segue o nativo. Commitou o
`.claude/commands/plan.md`? O `/plan` muda para todo o time nesse repositório. Para não mexer no
nativo, use só o `/bc-harness:plan`, sem a cópia local.

**3. Confira o `PHASES.md` fora da sessão:**

```bash
.claude/scripts/confere-phases.sh .spec/features/<slug>/PHASES.md
```

Esperado: `resultado: ok`. É o mesmo script, do mesmo jeito, que o pré-voo do `loop.sh` roda na
aula 5.1. Com `.claude/aceite.txt` e `FEATURE-ALVO.md` na raiz, ele também exige que cada `AC-NN` e
cada arquivo do `aceite.txt` apareçam numa task, com o caminho escrito igual. Deu erro? Peça ao
`/plan` para re-delegar ao planner. Não edite o `PHASES.md` à mão: ele é a vista 1:1 do `PLAN.md`.

O `aceite.txt` da aula 4.2 lista o `tests/Feature/Ai/SchemaEstritoTest.php`. Sem uma task que cite
esse caminho, o script dá `NÃO PASSA` aqui e o pré-voo do `loop.sh` barra na 5.1. Não tire o
arquivo do `aceite.txt`: re-delegue ao planner com o pedido do passo 2.

**4. Commit numa branch de trabalho** (`git switch -c` antes do primeiro commit), que é onde o loop
do Módulo 5 roda: `FEATURE-ALVO.md`, os testes e o `.spec/` (quem não quer a spec no repositório
põe `.spec` no `.gitignore`; o loop exige árvore limpa). O resumo do `/plan` termina com
`./ralph.sh ...`: não rode ainda.

## Para ler e adaptar (não são instalados)

- `modelos/pedir-o-plan.md`: o `/plan` na sua feature-alvo, parada por parada.
- `modelos/modelo-criterios.md`: a seção "Critérios de aceite" para o `FEATURE-ALVO.md`, com as
  quatro formas (evento, estado, condição, indesejado) e a linha "Confere".
- `modelos/exemplo-cadastro/`: o exemplo da 1.5 antes (`FEATURE-ALVO.antes.md`) e depois
  (`FEATURE-ALVO.md`, AC-01 a AC-04), um teste por critério em Pest, Vitest e pytest (ativo se já
  funciona, pendente com o corpo escrito se é novo), e um `PLAN.md` e um `PHASES.md` escritos à mão
  no formato do planner, para você ver a forma antes de rodar o seu.
- `modelos/pedir-os-testes.md`: os pedidos para reescrever os critérios e escrever um teste por
  critério, e como conferir que o pendente falha pelo motivo certo.

## Ver um PHASES que passa, antes do seu

```bash
A=~/harness-lab-materiais/modulo-4-prova/aula-4.3-spec-com-criterio-de-aceite
C=.claude/scripts/confere-phases.sh
$C --sem-aceite "$A/modelos/exemplo-cadastro/PHASES.md"
```

Esperado: `fases: 2 · tasks: 4 · erros: 0` e `resultado: ok`. O `--sem-aceite` pula a comparação
com o `FEATURE-ALVO.md` e o `.claude/aceite.txt` do seu projeto, que são de outra feature.

Para quem mantém o repositório: `bash testes/rodar.sh 4.3` roda os comandos do PDF numa sandbox e o
`teste/verificar.sh`, sem chamar o Claude de verdade.
