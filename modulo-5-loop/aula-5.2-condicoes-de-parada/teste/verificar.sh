#!/usr/bin/env bash
# verificar.sh · aula 5.2 · roda no ~/projeto da sandbox, depois dos comandos do material.
# Prova que o freio da aula está instalado e funciona: os cinco scripts iguais aos da aula,
# commitados numa branch de trabalho; o shim põe --max-budget-usd e timeout, estoura com 124
# e repassa o Ctrl-C; o pré-voo passa no projeto e barra o que deve, sem chamar nada; o
# ralph do bc-harness ainda é o que o material descreve; o demo do lab parou no gate 0 sem
# nenhuma sessão viva. Zero token: o único "claude" executado aqui é de mentira.
set -euo pipefail

n=0
ok() { n=$((n + 1)); printf '  ok  %s\n' "$1"; }
erro() { printf 'FALHOU: %s\n' "$1" >&2; exit 1; }
AULA="$HOME/harness-lab-materiais/modulo-5-loop/aula-5.2-condicoes-de-parada"
TMPDIR=$(mktemp -d)
export TMPDIR
PH=.spec/features/agenda-ics/PHASES.md
S=.claude/scripts

# ------------------------------------------------------------------ instalação
for f in loop.sh confere-phases.sh aviso.sh vigia.sh shim/claude; do
  [ -x "$S/$f" ] || erro "$S/$f não instalado ou sem chmod +x"
  cmp -s "$S/$f" "$AULA/projeto/$S/$f" || erro "$S/$f diferente do projeto/ da aula"
  cmp -s "$S/$f" "$AULA/lab/$S/$f" || erro "lab/$S/$f diferente do projeto/ (o lab tem que testar o mesmo script)"
  bash -n "$S/$f" || erro "sintaxe: $S/$f"
done
[ "$(git ls-files "$S" | wc -l)" -eq 5 ] || erro "os 5 scripts não estão commitados"
[ -z "$(git status --porcelain)" ] || erro "árvore suja depois dos comandos do material"
b=$(git branch --show-current)
case "$b" in main|master|"") erro "o projeto ficou na branch '$b'" ;; esac
ok "5 scripts iguais aos da aula (projeto/ e lab/), executáveis e commitados na branch $b"

# ------------------------------------------------------------------ o shim
real="$TMPDIR/claude-real-v52"
printf '#!/usr/bin/env bash\necho "$*" > "%s/args"\nsleep 30\n' "$TMPDIR" > "$real"
chmod +x "$real"

set +e
out=$(env -u CLAUDE_REAL "$S/shim/claude" -p oi 2>&1); rc=$?
set -e
[ "$rc" -ne 0 ] && grep -q 'CLAUDE_REAL' <<<"$out" || erro "sem CLAUDE_REAL o shim devia recusar e explicar (exit $rc)"
ok "shim sem CLAUDE_REAL: recusa e explica"

t0=$(date +%s)
set +e
CLAUDE_REAL="$real" LOOP_TIMEOUT=2s "$S/shim/claude" -p oi; rc=$?
set -e
dt=$(( $(date +%s) - t0 ))
[ "$rc" = 124 ] || erro "o estouro devia sair com 124 (veio $rc)"
[ "$dt" -lt 10 ] || erro "o estouro de 2 s demorou ${dt} s"
grep -q -- '--max-budget-usd 5 -p oi' "$TMPDIR/args" || erro "o claude não recebeu --max-budget-usd 5 (veio: $(cat "$TMPDIR/args"))"
ok "shim: LOOP_TIMEOUT=2s estoura com exit 124 em ${dt} s; o claude recebe --max-budget-usd 5"

CLAUDE_REAL="$real" LOOP_TIMEOUT=1s LOOP_BUDGET_USD=1.5 "$S/shim/claude" -p x >/dev/null 2>&1 || true
grep -q -- '--max-budget-usd 1.5 -p x' "$TMPDIR/args" || erro "LOOP_BUDGET_USD=1.5 não chegou ao claude"
ok "shim: LOOP_BUDGET_USD=1.5 vira --max-budget-usd 1.5"

# O Ctrl-C do terminal manda SIGINT ao grupo de processos inteiro: aqui, o grupo que o setsid cria.
rm -f "$TMPDIR/args"
# Entre parênteses, como no testa-loop.sh: comando com & direto num script não interativo
# nasce com o SIGINT ignorado, e aí nenhum trap de INT vale (nem o do shim).
(CLAUDE_REAL="$real" LOOP_TIMEOUT=5m setsid "$S/shim/claude" -p ctrlc) >/dev/null 2>&1 &
job=$!
for _ in $(seq 50); do [ -s "$TMPDIR/args" ] && break; sleep 0.1; done
[ -s "$TMPDIR/args" ] || erro "o claude de mentira não subiu"
grupo=$(ps -o pgid= -p "$job" | tr -d ' ')
[ -n "$grupo" ] && [ "$grupo" != "$(ps -o pgid= -p $$ | tr -d ' ')" ] || erro "grupo de processos do shim não encontrado"
kill -INT -- "-$grupo"
for _ in $(seq 30); do kill -0 "$job" 2>/dev/null || break; sleep 0.1; done
if kill -0 "$job" 2>/dev/null; then kill -KILL -- "-$grupo" 2>/dev/null || true; erro "o shim não saiu em 3 s depois do Ctrl-C"; fi
wait "$job" 2>/dev/null || true
sleep 0.3
if pgrep -f "$real" >/dev/null; then pkill -f "$real" || true; erro "o claude seguiu vivo depois do Ctrl-C"; fi
ok "shim: Ctrl-C (SIGINT no grupo) para o shim e o claude"

# ------------------------------------------------------------------ o pré-voo
out=$("$S/loop.sh" --checa "$PH" 2>&1) || { echo "$out" >&2; erro "o --checa devia passar no projeto"; }
grep -q 'pré-voo ok' <<<"$out" || erro "--checa sem 'pré-voo ok'"
grep -q 'freios: MAX_CICLOS=3, LOOP_TIMEOUT=40m, LOOP_BUDGET_USD=5 por sessão' <<<"$out" || erro "--checa sem a linha dos freios padrão"
grep -qF 'pior caso: 3 fase(s) x 3 ciclos x 2 sessões = 18 sessões' <<<"$out" || erro "--checa sem a conta do pior caso (18)"
ok "--checa: pré-voo ok, freios padrão e pior caso de 18 sessões"

out=$(LOOP_BUDGET_USD=20 MAX_CICLOS=2 "$S/loop.sh" --checa "$PH" 2>&1) || erro "--checa com os números trocados devia passar"
grep -qF 'pior caso: 3 fase(s) x 2 ciclos x 2 sessões = 12 sessões' <<<"$out" || erro "MAX_CICLOS=2 não mudou a conta"
grep -q 'LOOP_BUDGET_USD=20 por sessão' <<<"$out" || erro "LOOP_BUDGET_USD=20 não aparece nos freios"
ok "--checa com MAX_CICLOS=2 e LOOP_BUDGET_USD=20 (o exemplo do passo 7): 12 sessões"

barra() {   # barra REGEX [VAR=valor ...]: o --checa sai com 1, diz o motivo e não gasta nada
  local re="$1" o rc; shift
  set +e
  o=$(env "$@" "$S/loop.sh" --checa "$PH" 2>&1); rc=$?
  set -e
  [ "$rc" = 1 ] || { echo "$o" >&2; erro "devia barrar ($re): veio exit $rc"; }
  grep -qE "$re" <<<"$o" || { echo "$o" >&2; erro "não disse /$re/"; }
  grep -q 'Nada rodou, nenhum token gasto' <<<"$o" || erro "sem 'nenhum token gasto' ($re)"
}
barra 'credencial de API no ambiente: ANTHROPIC_API_KEY' ANTHROPIC_API_KEY=teste
barra 'credencial de API no ambiente: CLAUDE_CODE_USE_BEDROCK' CLAUDE_CODE_USE_BEDROCK=1
barra 'MAX_CICLOS inválido' MAX_CICLOS=0
echo rascunho > rascunho.txt
barra 'árvore suja'
rm rascunho.txt
chmod -x "$S/shim/claude"
barra 'shim não encontrado ou sem chmod \+x'
chmod +x "$S/shim/claude"
git switch -q -c master
barra 'branch master'
git switch -q "$b"
git branch -q -D master
[ -z "$(git status --porcelain)" ] || erro "a checagem deixou a árvore suja"
ok "o pré-voo barra antes de gastar: ANTHROPIC_API_KEY, Bedrock, MAX_CICLOS=0, árvore suja, shim sem +x, master"

# ------------------------------------------------------------------ o motor (bc-harness)
claude plugin list 2>&1 | grep -q 'bc-harness@beer-and-code' || erro "bc-harness não aparece em claude plugin list"
R=$(ls -d "$HOME"/.claude/plugins/cache/beer-and-code/bc-harness/*/scripts/ralph.sh 2>/dev/null | sort -V | tail -1)
[ -n "$R" ] && [ -f "$R" ] || erro "ralph.sh não está no cache do plugin"
grep -qF 'MAX_CYCLES="${RALPH_MAX_CYCLES:-3}"' "$R" || erro "o ralph mudou: MAX_CYCLES padrão não é 3"
grep -qF 'O engine terminou sem emitir um resultado' "$R" || erro "o ralph mudou: a causa do gate 0 que o material cita"
grep -qF 'Parando na primeira fase que falhou' "$R" || erro "o ralph mudou: parar na primeira fase que falha"
grep -q 'env -u CLAUDECODE claude --dangerously-skip-permissions' "$R" || erro "o ralph mudou: não chama mais 'claude' pelo PATH"
! grep -q -- '--max-budget-usd' "$R" || erro "o ralph passou a usar --max-budget-usd: revise o material"
ok "bc-harness instalado; o ralph.sh ainda para em 3 ciclos e na primeira fase, chama claude pelo PATH e não tem teto de gasto"

# ------------------------------------------------------------------ o lab (demo do estouro)
D=$(ls -td "$HOME"/harness-lab-sandbox/run.*/repo-exemplo 2>/dev/null | head -1)
[ -n "$D" ] && [ -d "$D" ] || erro "o demo do lab não rodou em ~/harness-lab-sandbox"
res=$(cat "$D"/.loop-logs/run-*/resumo.txt)
grep -qE 'desfecho: +FALHOU' <<<"$res" || erro "resumo do demo sem 'desfecho: FALHOU'"
grep -qF 'onde parou: F1 (Primeira fase), ciclo 2/2, gate 0' <<<"$res" || erro "resumo do demo sem 'ciclo 2/2, gate 0'"
grep -q 'LOOP_TIMEOUT=20s' <<<"$res" || erro "o demo não rodou com LOOP_TIMEOUT=20s"
[ "$(grep -c -- '--max-budget-usd 5' "$D/.git/motor-falso/argumentos.txt")" = 2 ] || erro "as 2 sessões do demo deviam ter passado pelo shim"
grep -qF 'O engine terminou sem emitir um resultado' "$D/.phases/prompts/phase-01.cycle-2.txt" || erro "o prompt do ciclo 2 sem a causa do gate 0"
if pgrep -f "$(dirname "$D")/bin/claude" >/dev/null; then erro "motor falso do demo ainda vivo"; fi
ok "lab: o demo parou no gate 0 no ciclo 2/2, as 2 sessões com --max-budget-usd 5, causa no prompt do ciclo 2, nenhum motor vivo"

# O leitor de turnos e gasto (mesmo filtro do material, do README e do pedido-freios.md).
F='fromjson?|select(.type=="result")'
C='[.num_turns,.total_cost_usd,(.duration_ms/6e4|round)]'
le() { (cd "$1" && for f in *.cycle-*.log; do echo "$f $(jq -cR "$F|$C" "$f")"; done); }
L=$(ls -td "$D"/.loop-logs/*/logs | head -1)
[ "$(le "$L")" = "$(printf 'phase-01.cycle-1.log \nphase-01.cycle-2.log ')" ] || erro "leitor no demo: esperava só os 2 nomes (sessões cortadas, sem resultado); veio: $(le "$L")"
fake="$TMPDIR/logs-leitor"; mkdir -p "$fake"
# Uma sessão real: o resultado não é a última linha (no run de 8 fases, um task_notification veio depois).
printf '%s\n' '{"type":"system","subtype":"init"}' 'saida solta do stderr' \
  '{"type":"result","subtype":"success","is_error":false,"num_turns":43,"total_cost_usd":2.1890825,"duration_ms":288000}' \
  '{"type":"system","subtype":"task_notification","status":"stopped"}' > "$fake/phase-04.cycle-1.log"
[ "$(le "$fake")" = "phase-04.cycle-1.log [43,2.1890825,5]" ] || erro "leitor num log com resultado: veio '$(le "$fake")'"
for f in "$AULA/modelos/pedido-freios.md" "$AULA/README.md"; do
  grep -qF "C='[.num_turns,.total_cost_usd,(.duration_ms/6e4|round)]'" "$f" || erro "o leitor sumiu de $f"
done
ok "leitor de turnos e gasto: no demo, só os nomes; num log com resultado no meio, [43,2.1890825,5]"

# ------------------------------------------------------------------ o pedido (modelos/)
PF="$AULA/modelos/pedido-freios.md"
pedido=$(sed -n '/^> ```bash$/,/^> ```$/p' "$PF" | sed 's/^> //' | grep -v '^```' | grep -v '^#')
shim=$(grep -v '^#' "$S/shim/claude")
[ "$pedido" = "$shim" ] || erro "o corpo do shim em modelos/pedido-freios.md difere do shim instalado"
grep -qF 'C=$PWD/.claude/scripts' "$PF" && grep -qF 'SHIM=$C/shim/claude' "$PF" || erro "pedido-freios.md sem SHIM com caminho absoluto"
ok "modelos/pedido-freios.md: o corpo do shim é o instalado e o SHIM do teste tem caminho absoluto"

echo "verificar.sh: $n grupos de checagem passaram."
