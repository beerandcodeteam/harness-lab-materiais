# Pedido · aula 5.2 · o freio do seu loop.sh

Para quem escreveu o próprio `loop.sh` na 5.1 em vez de usar o do curso. Se você instalou o do curso
(`instalar.sh 5.1` ou `5.2`), ele já tem tudo isto: pule este arquivo.

O ralph já para por ciclos (`--max-cycles`), na primeira fase que falha e em parte dos limites de uso.
Tempo por sessão e teto de gasto você põe por fora, sem editar o ralph e sem perder o Ctrl-C.

Cole os dois pedidos no Claude Code, na raiz do seu projeto, um de cada vez.

## Pedido 1: o shim

> Crie .claude/scripts/shim/claude, executável, exatamente com este corpo. Ele fica na frente do PATH
> e o ralph o chama no lugar do claude, nas duas sessões de cada ciclo (implementação e juiz).
>
> ```bash
> #!/usr/bin/env bash
> # .claude/scripts/shim/claude · teto de tempo e de gasto por sessão, sem editar o ralph
> : "${CLAUDE_REAL:?CLAUDE_REAL vazio: rode pelo loop.sh, que resolve o claude de verdade antes de mexer no PATH}"
> timeout -k 60 "${LOOP_TIMEOUT:-40m}" "$CLAUDE_REAL" --max-budget-usd "${LOOP_BUDGET_USD:-5}" "$@" &
> pid=$!
> trap 'kill -TERM "$pid" 2>/dev/null' INT TERM HUP
> wait "$pid"; rc=$?
> if [ "$rc" -gt 128 ] && kill -0 "$pid" 2>/dev/null; then wait "$pid"; rc=$?; fi
> exit "$rc"
> ```

Por que não `exec timeout ...`: o `timeout` roda num grupo de processos próprio e não recebe o Ctrl-C
do terminal. Com `exec`, o Ctrl-C não para nada: o loop fica esperando a sessão, que segue mexendo no
repositório (testado: o loop não saiu em 10 s e a sessão seguiu viva). Aqui o shim recebe o Ctrl-C e
repassa TERM ao `timeout`, que repassa à sessão. `timeout --foreground` também deixaria o Ctrl-C
passar, mas no estouro não mata os filhos da sessão.

## Pedido 2: o loop.sh ganha freio

> No .claude/scripts/loop.sh, acrescente ao pré-voo, sempre listando todos os problemas e sem chamar o ralph:
> - branch fora de main e master (e não HEAD solto);
> - árvore limpa, mostrando os arquivos;
> - .claude/scripts/confere-phases.sh no arquivo de fases passa;
> - .claude/hooks/guarda-aceite.py existe e está registrado em .claude/settings.json (ou settings.local.json), e .claude/aceite.txt lista pelo menos um arquivo, todos existentes (LOOP_SEM_ACEITE=1 libera);
> - .diagnostico-operador/ e diagnostico-operador.md, se existirem, versionados ou ignorados (git check-ignore), porque o ralph sugere 'git clean -fd' quando uma fase falha;
> - comando timeout disponível e o shim executável.
> Antes de chamar o ralph: resolva CLAUDE_REAL com command -v claude, exporte CLAUDE_REAL, LOOP_TIMEOUT (padrão 40m) e LOOP_BUDGET_USD (padrão 5), e ponha .claude/scripts/shim na frente do PATH. Passe --max-cycles "$MAX_CICLOS" (padrão 3) ao ralph.
> Escreva camadas.txt (no --checa, mostre; no run, copie para .loop-logs/<run>/): Regra (CLAUDE.md e AGENTS.md com número de linhas, skills do projeto), Trava (hooks por evento no settings.json), Prova (comando de teste, SPEC ao lado do PHASES, arquivos de aceite e quantos marcadores de pendente), Loop (PHASES e o resultado do confere-phases, os freios, o pior caso = fases x MAX_CICLOS x 2 sessões, o canal de aviso).

O `confere-phases.sh` vem junto no `instalar.sh 5.2` (ou copie de `lab/.claude/scripts/` desta aula).

## O que ler no resultado

- O shim é o único lugar com `timeout` e `--max-budget-usd`. O `--max-budget-usd` é estimativa do
  cliente, por sessão, e pode passar do teto. Nada de "o loop nunca gasta mais que X".
- Teto do run inteiro não existe: é a conta do pior caso (fases x ciclos x 2 sessões x teto).
- Não ponha `timeout` em volta do ralph com `--dashboard` (mexe com o terminal).

## Como conferir, zero token

Na raiz do seu projeto, com o bc-harness instalado (o teste usa o `ralph.sh` de verdade e um `claude`
falso, sem gastar token):

```bash
S=~/harness-lab-materiais/modulo-5-loop/aula-5.2-condicoes-de-parada/lab
C=$PWD/.claude/scripts
SHIM=$C/shim/claude bash $S/testes/testa-loop.sh --ate 5.2 $C/loop.sh
```

`SHIM` precisa de caminho absoluto (`$PWD/...`): com caminho relativo o teste quebra no `cp`, porque
copia já dentro do repositório temporário. O `--ate 5.2` roda os casos até os freios
(esta aula). Esperado: `testa-loop (até a aula 5.2): 80 passaram`. Sem o `--ate`, roda também os
casos do aviso e do vigia (102 verificações).

Depois, o pré-voo no seu repositório:

```bash
P=$(ls -t .spec/features/*/PHASES.md | head -1)
.claude/scripts/loop.sh --checa "$P"
```

## Escolha seus números

| Variável | Padrão | Pergunta |
|---|---|---|
| `LOOP_TIMEOUT` | 40m | Quanto dura a sua **sessão** mais longa (`duration_ms` na linha de resultado do log)? Ponha acima, com folga. Nos runs reais do curso, de 1 a 24 min na maioria, e uma de 95 min. A fase (6 a 33 min na maioria) soma a sessão, a Prova e o juiz: é um teto da sessão, não a medida. |
| `LOOP_BUDGET_USD` | 5 | Qual foi a sua sessão mais cara (`total_cost_usd`, estimativa do cliente)? Ponha acima, com folga. Nos runs reais, de US$ 0,46 a 15,51 por sessão. |
| `MAX_CICLOS` | 3 | Quantas tentativas antes de te chamar? A aula recomenda 3. |

A ordem é essa: o teto por sessão vem da sua sessão mais cara e da mais longa, e o budget da
funcionalidade sai da conta (fases x ciclos x 2 sessões x teto), não o contrário. Teto abaixo de uma
sessão normal não economiza: corta a sessão no meio e gasta um ciclo, até a fase falhar. 40m, US$ 5
e 3 ciclos são os padrões do curso: cobrem sessões como as dos runs menores (até US$ 4,39 e 14 min);
nos runs de 12 e de 8 fases, cortariam 10 de 15 e 6 de 10 sessões.

Para ler os números de um run (na raiz do projeto, depois do run; `cd -` volta):

```bash
cd "$(ls -td .loop-logs/*/logs | head -1)"
F='fromjson?|select(.type=="result")'
C='[.num_turns,.total_cost_usd,(.duration_ms/6e4|round)]'
for f in *.cycle-*.log; do echo "$f $(jq -cR "$F|$C" "$f")"; done
```

Cada sessão sai com turnos, US$ estimado e minutos. Linha só com o nome do log: a sessão não deixou
resultado (estouro ou sessão morta).
