# Aula 5.2 · Condições de parada: o freio do loop

Módulo 5 · Loop. Material de apoio em PDF: [material-de-apoio-aula-5.2.pdf](material-de-apoio-aula-5.2.pdf).

Um loop sem freio é o que estoura a conta. Esta pasta tem o freio da aula: três ciclos por fase,
teto de gasto (`--max-budget-usd`) e de tempo (`timeout`) em toda sessão, por um **shim** na frente
do `PATH` que não edita o ralph e deixa o Ctrl-C passar, e o pré-voo que barra antes de gastar. Mais
um laboratório para puxar o freio sem gastar token.

## O que é instalado

Os mesmos cinco scripts das aulas 5.1 e 5.3, byte a byte (quem já instalou a 5.1 vê "igual"):

| Arquivo no seu projeto | O que faz nesta aula |
| --- | --- |
| `.claude/scripts/shim/claude` | `timeout` (`LOOP_TIMEOUT`, padrão 40m) e `--max-budget-usd` (`LOOP_BUDGET_USD`, padrão 5) em toda sessão que o ralph abre, a de implementação e a do juiz. Repassa o Ctrl-C à sessão |
| `.claude/scripts/loop.sh` | Pré-voo completo (branch fora de `main`, árvore limpa, `confere-phases.sh`, hook de aceite registrado, `timeout`, shim executável), `MAX_CICLOS` (padrão 3) como `--max-cycles` do ralph, shim na frente do `PATH`, `camadas.txt` com a conta do pior caso |
| `.claude/scripts/confere-phases.sh` | Confere o PHASES contra o contrato do ralph antes da primeira sessão |
| `.claude/scripts/aviso.sh`, `.claude/scripts/vigia.sh` | O aviso e o vigia da aula 5.3 (o `loop.sh` já chama) |

O bloco `[5.2]` do `loop.sh` é desta aula (`[5.1]` é a 5.1, `[5.3]` a 5.3); o `--ate` do
`testa-loop.sh` usa a mesma numeração.

## Antes

- bc-harness instalado (aula 3.4): o motor do loop, o `ralph.sh`, vem dele.
- O hook `guarda-aceite.py` registrado (`instalar.sh 4.2`) e o seu `.claude/aceite.txt` com os testes
  de aceite. Sem eles o pré-voo barra; `LOOP_SEM_ACEITE=1` libera, sabendo que o agente pode
  reescrever o juiz.
- O PHASES do `/plan` da aula 4.3 (ou do `/bc-harness:plan`, sem a cópia local) em
  `.spec/features/<slug>/PHASES.md`.
- GNU `timeout` (coreutils), bash 4 ou mais novo, `git`. Linux ou WSL; macOS não foi testado (o
  `timeout` vem do `brew install coreutils`, com o `gnubin` no `PATH`).
- Para o laboratório: `python3` e `setsid` (util-linux; já vêm no Ubuntu e no WSL) e `jq` (o leitor
  de turnos e gasto).

## Instalar

```bash
cd ~
git clone https://github.com/beerandcodeteam/harness-lab-materiais
cd /caminho/do/seu/projeto
git switch -c feat/feature-alvo                  # o pré-voo recusa main e master
~/harness-lab-materiais/instalar.sh 5.2            # "conflito" em loop.sh? pare e veja abaixo
git add .claude/scripts
git diff --cached --quiet || git commit -m "harness: freios do loop"
```

Já baixou antes? `git -C ~/harness-lab-materiais pull`.

Escreveu o seu próprio `loop.sh` na 5.1? O `instalar.sh` diz "conflito" e deixa o do curso em
`loop.sh.harness-lab-novo`. Não commite esse arquivo: tire-o do projeto (o pré-voo exige árvore
limpa) e siga `modelos/pedido-freios.md`.

## Conferir (zero token)

```bash
P=$(ls -t .spec/features/*/PHASES.md | head -1)
.claude/scripts/loop.sh --checa "$P"
LOOP_BUDGET_USD=20 MAX_CICLOS=2 .claude/scripts/loop.sh --checa "$P"
ANTHROPIC_API_KEY=teste .claude/scripts/loop.sh --checa "$P"      # tem que barrar
```

Esperado no primeiro: "pré-voo ok", a linha `freios: MAX_CICLOS=3, LOOP_TIMEOUT=40m,
LOOP_BUDGET_USD=5 por sessão` e o pior caso (`fases x ciclos x 2 sessões`). O teto da funcionalidade
é esse número de sessões vezes o `LOOP_BUDGET_USD`, e é estimativa: o `--max-budget-usd` é por
sessão e pode passar um pouco do teto.

## Escolher os números

A ordem é esta: o teto por sessão fica acima da sessão mais cara e da mais longa que você já viu,
com folga, e o budget da funcionalidade sai da conta (sessões x teto). Teto abaixo de uma sessão
normal não economiza: corta a sessão no meio, gasta um ciclo e pode derrubar a fase. Conta alta
demais pede fase menor ou menos ciclos.

Sessões de implementação em runs reais do Lucas, com o ralph atual (linha de resultado de cada
`.phases/logs/phase-*.cycle-*.log`; `total_cost_usd` é estimativa do cliente):

| Run | US$ por sessão | Turnos | Minutos |
| --- | --- | --- | --- |
| 4 fases, 3 já implementadas (19/08/2026) | 0,58 a 2,19 | 7 a 43 | 1 a 5 |
| Outros dois (01/09 e 28/10/2026) | 0,94 a 4,39 | 21 a 65 | 3 a 14 |
| 12 fases (15/09/2026) | 0,72 a 13,89 | 9 a 116 | 1 a 24 |
| 8 fases (06/10/2026) | 0,46 a 15,51 | 11 a 122 | 3 a 95 |

Os padrões do curso (US$ 5 e 40m) cobrem sessões como as das duas primeiras linhas; no run de 12
fases cortariam 10 de 15 sessões, e no de 8 fases, 6 de 10. O `LOOP_TIMEOUT` mede a sessão, não a
fase: a fase (6 a 33 min na maioria) soma a sessão, a Prova e o juiz.

No run de verdade, é o mesmo comando sem o `--checa` (gasta token), com `LOOP_TIMEOUT` e
`LOOP_BUDGET_USD` na frente: acima da sua sessão mais longa e da mais cara, com folga.

Para ler os números de um run seu (na raiz do projeto, depois do run; `cd -` volta):

```bash
cd "$(ls -td .loop-logs/*/logs | head -1)"
F='fromjson?|select(.type=="result")'
C='[.num_turns,.total_cost_usd,(.duration_ms/6e4|round)]'
for f in *.cycle-*.log; do echo "$f $(jq -cR "$F|$C" "$f")"; done
```

Cada sessão sai com turnos, US$ estimado e minutos, por exemplo `phase-04.cycle-1.log
[43,2.1890825,5]`. Linha só com o nome: a sessão não deixou resultado (estouro ou sessão morta, o
gate 0). O juiz roda em modo texto e não registra gasto.

O shim não põe `--max-turns`: turno não mede dinheiro nem progresso (7 a 122 por sessão na tabela)
e o teto cortaria também o juiz, que passa pelo shim. Quem quiser acrescenta
`--max-turns "${LOOP_MAX_TURNS:-200}"` na própria cópia do shim (200 é exemplo); o `instalar.sh` das
aulas seguintes vai acusar conflito nesse arquivo.

## O laboratório: o freio puxado sem gastar token

`lab/` tem cópias dos mesmos scripts, um `claude` falso (`lab/motor-falso/claude`) e os testes do
módulo. O `demo.sh` cria um repositório de exemplo numa pasta temporária e roda o seu `ralph.sh` de
verdade pelo `loop.sh`, com o motor falso no `PATH`. Nada aqui é instalado no seu projeto.

```bash
S=~/harness-lab-materiais/modulo-5-loop/aula-5.2-condicoes-de-parada/lab
export DEMO_DIR=$HOME/harness-lab-sandbox

# estouro: cada sessão pendura, o timeout corta em 20 s, gate 0, 2 ciclos, para (cerca de 45 s)
env MOTOR_CENARIO=pendura LOOP_TIMEOUT=20s MAX_CICLOS=2 bash $S/testes/demo.sh

# onde parou e o que o ciclo 2 recebeu
R=$(ls -td ~/harness-lab-sandbox/run.*/repo-exemplo | head -1)
cat $R/.loop-logs/run-*/resumo.txt
grep -A3 "Motivo da falha" $R/.phases/prompts/phase-01.cycle-2.txt

# os números de cada sessão: aqui só os nomes dos logs (as sessões cortadas não deixaram resultado)
cd "$(ls -td ~/harness-lab-sandbox/run.*/repo-exemplo | head -1)"
cd "$(ls -td .loop-logs/*/logs | head -1)"
F='fromjson?|select(.type=="result")'
C='[.num_turns,.total_cost_usd,(.duration_ms/6e4|round)]'
for f in *.cycle-*.log; do echo "$f $(jq -cR "$F|$C" "$f")"; done

# freio de mão: aperte Ctrl-C depois de uns 10 s; depois, o pgrep não pode listar nada
env MOTOR_CENARIO=pendura LOOP_TIMEOUT=5m bash $S/testes/demo.sh
pgrep -af -- --max-budget-usd
```

Cenários do motor falso (`MOTOR_CENARIO`): `ok`, `falha-uma-vez`, `nunca-passa`, `incompleta`,
`pendura`, `sem-resultado`.

O teste do loop com os seus scripts (cerca de 30 s, na raiz do projeto):

```bash
C=$PWD/.claude/scripts
SHIM=$C/shim/claude bash $S/testes/testa-loop.sh $C/loop.sh
```

Esperado: `testa-loop (até a aula 5.3): 102 passaram`. Com `--ate 5.2`, só até os freios: 80.
`SHIM` precisa de caminho absoluto.

## Para ler e adaptar (não são instalados)

- `modelos/pedido-freios.md`: para quem escreveu o próprio `loop.sh` na 5.1. Os dois pedidos para o
  Claude Code (o shim, com o corpo exato, e o freio do pré-voo), o que ler no resultado, como
  conferir e como escolher os números.

## O que foi testado

Com o `ralph.sh` do bc-harness 0.2.0 do cache e o motor falso, sem gastar token: o `testa-loop.sh`
inteiro (102 verificações) com os scripts instalados, o estouro do demo (43 s, gate 0 no ciclo 2/2) e o
`teste/verificar.sh` desta pasta (o shim estoura com 124, passa `--max-budget-usd`, para no Ctrl-C;
o pré-voo barra credencial de API, `MAX_CICLOS=0`, árvore suja, shim sem `+x` e `master`). O leitor
de turnos e gasto rodou nos logs reais dos cinco runs da tabela e no demo (sem resultado, só os nomes).

Não testado: o `--max-budget-usd` dentro do shim com o CLI real (o primeiro uso é o ensaio da 5.3),
os processos filhos de uma sessão real depois do estouro, o Ctrl-C num terminal de verdade (simulado
com SIGINT no grupo de processos) e macOS.
