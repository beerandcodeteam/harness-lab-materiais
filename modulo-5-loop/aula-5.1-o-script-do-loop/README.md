# Aula 5.1 · O script do loop

Módulo 5 · Loop. Material de apoio em PDF: [material-de-apoio-aula-5.1.pdf](material-de-apoio-aula-5.1.pdf).

Pega a fase, executa, roda a Prova, commita ou tenta de novo. Esta pasta tem as duas coisas que a
aula ofereceu: o loop pronto (o `ralph.sh` do BC Harness, chamado pelo `loop.sh` do curso) e o
caminho para construir o seu, com dois juízes que aprovam o script sem gastar token.

## O que é instalado

| Arquivo no seu projeto | O que faz |
| --- | --- |
| `.claude/scripts/loop.sh` | O único jeito de rodar o loop no curso. `loop.sh [--checa] PHASES.md`. Pré-voo, chamada do ralph com `--engine claude`, log em `.loop-logs/<run>/` e `resumo.txt` |
| `.claude/scripts/confere-phases.sh` | Confere o PHASES contra o contrato do ralph: heading, outro `## ` no meio de fase, task sem critério de aceite ou sem teste, AC e teste de aceite sem task |
| `.claude/scripts/shim/claude` | Teto de tempo e de gasto por sessão (aula 5.2) |
| `.claude/scripts/vigia.sh`, `.claude/scripts/aviso.sh` | O "travou?" e o aviso no fim do run (aula 5.3) |

A 5.1 e a 5.2 instalam os mesmos cinco arquivos. A 5.3 acrescenta `ralph.sh`, `aviso-env.sh` e
`.gitignore`. Os cinco em comum são iguais byte a byte: rodar o `instalar.sh` das três em sequência
não gera conflito. O `loop.sh` sempre usa o `ralph.sh` mais novo do cache do plugin `bc-harness`;
`RALPH_SH=caminho` troca.

Qual ralph é qual: o que aparece aberto na gravação é uma cópia de julho, com o avaliador em
`haiku`. O do plugin, que o `loop.sh` usa e que este material descreve, é o de agosto (bc-harness
0.2.0): 1.903 linhas, avaliador em `sonnet` e painel ao vivo (`--dashboard`).

Os comentários dos scripts seguem a numeração das aulas: `[5.1]` é esta aula (pré-voo mínimo,
chamada e resumo), `[5.2]` os freios e `[5.3]` o aviso.

## Antes

- O plugin BC Harness (aula 3.4), que traz o `ralph.sh`:

  ```bash
  claude plugin marketplace add beerandcodeteam/beer-and-code-harness
  claude plugin install bc-harness@beer-and-code
  ```

- O PHASES da feature, gerado pelo `/plan` da aula 4.3 e commitado numa branch de trabalho.
- O hook `guarda-aceite.py` registrado e o `.claude/aceite.txt` com os seus testes de aceite: vêm
  da aula 4.2 (`~/harness-lab-materiais/instalar.sh 4.2`), que instala `.claude/aceite.exemplo.txt`.
  Copie para `.claude/aceite.txt` e liste os seus testes de aceite. Sem eles o pré-voo recusa; só
  para ensaiar o encanamento, `LOOP_SEM_ACEITE=1`. O `confere-phases.sh` desta aula é o mesmo da 4.3:
  instalar as duas não gera conflito.
- Rodou o diagnóstico da aula 1.1? `.diagnostico-operador/` e `diagnostico-operador.md` precisam
  estar commitados ou no exclude, senão o pré-voo recusa. Não apague: é o "antes" do curso.
  `echo '/.diagnostico-operador' >> "$(git rev-parse --git-path info/exclude)"` (e o mesmo para o
  `.md`; vale também numa worktree).
- bash 4 ou mais novo, `date` do GNU, `sha256sum`, `timeout`, `git`. Linux ou WSL. No macOS, rode o
  `test-ralph.sh` do plugin antes (comando no PDF, passo 3).

## Instalar e conferir

```bash
cd ~
git clone https://github.com/beerandcodeteam/harness-lab-materiais
cd /caminho/do/seu/projeto
~/harness-lab-materiais/instalar.sh 5.1
git add .claude/scripts && git commit -m "harness: scripts do loop"
.claude/scripts/loop.sh --checa .spec/features/<slug>/PHASES.md
```

Já baixou antes? `git -C ~/harness-lab-materiais pull`. O `--checa` não gasta token: termina em
`pré-voo ok` ou lista cada `NÃO` com o que corrigir.

## Ensaio com o motor falso (zero token)

O ralph de verdade e a sua Prova de verdade, com um `claude` falso que só escreve `src/fase-N.txt`.
Numa branch descartável:

```bash
A=~/harness-lab-materiais/modulo-5-loop/aula-5.1-o-script-do-loop
git switch -c ensaio-motor-falso
CLAUDE_REAL=$A/modelos/motor-falso/claude .claude/scripts/loop.sh .spec/features/<slug>/PHASES.md
git switch - && git branch -D ensaio-motor-falso && rm -rf .phases
```

Esperado: `desfecho: ENTREGOU` e um commit `feat(phase-N)` por fase. O `rm -rf .phases` é
obrigatório: o ralph guarda as fases feitas para o mesmo PHASES, e sem ele o run de verdade pula
tudo e diz "ENTREGOU" em 0 segundos, sem commit.

## O run de verdade (gasta token)

```bash
.claude/scripts/loop.sh .spec/features/<slug>/PHASES.md
```

Num terminal seu ou num tmux. O resumo fica em `.loop-logs/<run>/resumo.txt`. O curso faz o primeiro
run pago no fim da aula 5.3, com uma task só.

## Codex, Cursor e o modelo

- **Codex.** O ralph troca de motor com `--engine codex` (é o padrão dele): implementa com
  `codex exec --sandbox danger-full-access - < prompt` e avalia com `codex exec --sandbox read-only`,
  em que o só leitura é sandbox de verdade (`ralph.sh` 1341-1343). Para rodar assim, chame o
  `ralph.sh` do cache direto, na raiz do projeto, sem o pré-voo, os freios e o aviso do `loop.sh`.
  O `loop.sh` é só claude: o shim passa flags do claude.

  ```bash
  RALPH=$(ls -d ~/.claude/plugins/cache/beer-and-code/bc-harness/*/scripts/ralph.sh | sort -V | tail -n 1)
  bash "$RALPH" --engine codex .spec/features/<slug>/PHASES.md
  ```

- **Cursor.** O headless do Cursor CLI é `agent -p --force "<prompt>"`; sem `--force` ele só propõe
  as mudanças (cursor.com/docs/cli/headless). O ralph não tem engine para ele.
- **Modelo, pelo `loop.sh`.** Avaliador: `RALPH_VERIFY_MODEL=haiku .claude/scripts/loop.sh <PHASES>`
  (padrão `sonnet`). Implementação: `ANTHROPIC_MODEL=<alias>`, que vale para a sessão lançada com
  ela (model-config, "Setting your model"); a sessão do ralph não passa `--model`.

## Construa o seu (não são instalados)

Na pasta de ensaio, fora de qualquer repositório:

```bash
A=~/harness-lab-materiais/modulo-5-loop/aula-5.1-o-script-do-loop
mkdir -p ~/harness-lab-sandbox && cd ~/harness-lab-sandbox
cp -r $A/modelos/teste $A/modelos/motor-falso $A/modelos/pedido-*.md .
```

| Arquivo | O que é |
| --- | --- |
| `modelos/pedido-nucleo.md` | O pedido para o Claude escrever o `loop-minimo.sh`, o que ler no resultado e como conferir |
| `modelos/pedido-gates.md` | O pedido dos dois gates que faltam no núcleo: árvore limpa antes e avaliador depois da Prova verde |
| `modelos/loop-minimo.sh` | O núcleo de referência, 39 linhas |
| `modelos/loop-com-gates.sh` | A receita inteira da aula, 69 linhas. O avaliador roda com `--tools "Read,Glob,Grep"`, `--disallowedTools "mcp__*"` (o `--tools` não tira as ferramentas de MCP) e sem bypass |
| `modelos/teste/testa-loop-minimo.sh` | O juiz do núcleo: `bash teste/testa-loop-minimo.sh [script]`. Esperado: 15 passaram |
| `modelos/teste/testa-loop-com-gates.sh` | O juiz da receita inteira: `bash teste/testa-loop-com-gates.sh ./loop-com-gates.sh`. Esperado: 29 passaram |
| `modelos/motor-falso/claude` | O `claude` falso dos juízes e do ensaio. Cenários por `MOTOR_CENARIO`: `ok`, `falha-uma-vez`, `nunca-passa`, `incompleta`, `pendura`, `sem-resultado` |

O `ENGINE` dos modelos troca só o binário: serve para um CLI com as flags do claude, como o motor
falso. Com `ENGINE=codex` o script quebra (no codex, `-p` é `--profile`).

Sem argumento, cada juiz testa o arquivo de mesmo nome da pasta de cima: na pasta de ensaio, o seu.
O `testa-loop-minimo.sh` reprova script com o gate da árvore limpa (ele grava a saída dentro do
repositório de teste); script com gates se testa no `testa-loop-com-gates.sh`.

## Testes deste material

`teste/verificar.sh` roda depois dos comandos do PDF numa sandbox com HOME falso
(`bash testes/rodar.sh 5.1` na raiz do repositório): instalação igual à da aula, ensaio com o motor
falso, o pré-voo recusando chave de API, `apiKeyHelper`, árvore suja, `master` e `RALPH_TEST_CMD`,
a armadilha do progresso e os dois juízes aprovando as referências e reprovando o que está errado.
O projeto falso da sandbox fica em `teste/projeto/` (Node, `npm test`, a agenda .ics em 2 fases).
