#!/usr/bin/env bash
# testa-loop.sh · aulas 5.1 a 5.3 · o loop.sh, com o ralph de verdade e o motor falso
#
# Uso: bash testes/testa-loop.sh [--ate 5.1|5.2|5.3] [caminho/do/loop.sh]
#   --ate 5.1  só os casos da versão 1 (pré-voo mínimo, chamada, log, resumo)
#   --ate 5.2  + pré-voo completo, shim (estouro de tempo e flags), MAX_CICLOS
#   --ate 5.3  + aviso, vigia, Ctrl-C e LOOP_PR (padrão)
#
# Cada caso cria um repositório git temporário (lib.sh: novo_repo), instala os
# scripts em .claude/scripts/ (com o seu loop.sh, se passar o caminho) e roda o
# ralph.sh do cache do bc-harness com o motor falso no PATH. Zero token.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ate="5.3"; loop="$EXEMPLOS/.claude/scripts/loop.sh"
while [ $# -gt 0 ]; do
  case "$1" in
    --ate) ate="$2"; shift 2 ;;
    *) loop="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"; shift ;;
  esac
done
nivel() { [ "$(printf '%s\n%s\n' "$1" "$ate" | sort -V | head -1)" = "$1" ]; }   # o caso é da aula $1 ou anterior?
[ -f "$RALPH_DO_CACHE" ] || { echo "ralph.sh do bc-harness não encontrado (instale o plugin ou defina RALPH_SH)" >&2; exit 2; }
echo "loop.sh: $loop"
echo "ralph:   $RALPH_DO_CACHE"
echo "até a aula $ate"

PH=".spec/features/exemplo/PHASES.md"
avisos="$BASE/avisos.txt"
printf '#!/usr/bin/env bash\necho "$1" >> "%s"\n' "$avisos" > "$BASE/grava.sh"; chmod +x "$BASE/grava.sh"

# loop_em <repo> <cenário> [VAR=valor ...] [-- argumentos do loop.sh] -> exit code; saída em <repo>.saida
loop_em() {
  local d="$1" cen="$2"; shift 2
  local vars=()
  while [ $# -gt 0 ] && [ "$1" != -- ]; do vars+=("$1"); shift; done
  [ "${1:-}" = -- ] && shift
  [ $# -gt 0 ] || set -- "$PH"
  local rc=0
  (cd "$d" && ambiente MOTOR_CENARIO="$cen" AVISO_CMD="$BASE/grava.sh" LOOP_VIGIA_S=1 "${vars[@]}" \
     timeout 180 bash .claude/scripts/loop.sh "$@") > "$d.saida" 2>&1 || rc=$?
  echo "$rc"
}
run_dir() { ls -d "$1"/.loop-logs/run-* 2>/dev/null | head -1; }
nao_rodou() { if [ -d "$1/.phases" ]; then falha "$2 (o ralph rodou)"; else passa "$2"; fi; }
motor() { echo "$1/.git/motor-falso"; }
commits_fase() { git -C "$1" log --pretty=%s | grep -c '^feat(phase-' || true; }

# ============================================================================ 5.1
caso "[5.1] ok: duas fases, um commit por fase, log copiado e resumo"
r="$BASE/ok"; novo_repo "$r" "$loop"; : > "$avisos"
igual 0 "$(loop_em "$r" ok)" "exit 0"
igual 2 "$(commits_fase "$r")" "2 commits feat(phase-N)"
d="$(run_dir "$r")"
[ -n "$d" ] && passa ".loop-logs/run-* criado" || falha ".loop-logs/run-* criado"
for f in run.tsv resumo.txt logs/phase-01.cycle-1.log logs/phase-02.verify-1.log prompts/phase-01.cycle-1.txt; do
  [ -f "$d/$f" ] && passa "copiou $f" || falha "copiou $f"
done
tem "$d/resumo.txt" "desfecho: *ENTREGOU" "resumo: ENTREGOU"
tem "$d/resumo.txt" "fases feitas: *2/2" "resumo: 2/2"
tem "$d/resumo.txt" "feat\(phase-2\)" "resumo: commits do run"
contem "$r/.git/info/exclude" "/.loop-logs/" ".loop-logs no .git/info/exclude"
igual "" "$(git -C "$r" status --porcelain)" "árvore limpa depois do run"
contem "$(motor "$r")/argumentos.txt" "--dangerously-skip-permissions" "o ralph chamou o motor (engine claude)"
igual "$(stat -c %y "$r/.phases/logs/phase-01.cycle-1.log")" "$(stat -c %y "$d/logs/phase-01.cycle-1.log" 2>/dev/null)" \
  "a cópia mantém a hora dos logs (cp -p; o /diagnostico-operador da 6.3 mede a janela por ela)"

caso "[5.1] numa git worktree: o exclude é o do repositório principal"
r="$BASE/principal"; novo_repo "$r" "$loop"; git -C "$r" switch -q main
w="$BASE/wt"; git -C "$r" worktree add -q -b feat/wt "$w"
igual 0 "$(loop_em "$w" ok)" "exit 0"
contem "$r/.git/info/exclude" "/.loop-logs/" ".loop-logs no exclude comum (git rev-parse --git-path info/exclude)"
naocontem "$w.saida" "No such file" "sem erro de arquivo ao gravar o exclude"
igual "" "$(git -C "$w" status --porcelain)" "árvore limpa na worktree depois do run"
igual 0 "$(git -C "$w" ls-files -- .phases .loop-logs | wc -l)" "nem .phases nem .loop-logs commitados"

caso "[5.1] incompleta: o juiz reprova, o loop para e diz onde"
r="$BASE/incompleta"; novo_repo "$r" "$loop"; : > "$avisos"
igual 1 "$(loop_em "$r" incompleta)" "exit 1 (3 ciclos, o padrão do ralph)"
d="$(run_dir "$r")"
tem "$d/resumo.txt" "desfecho: *FALHOU" "resumo: FALHOU"
tem "$d/resumo.txt" "F1.*ciclo 3.*gate 3" "resumo: fase, ciclo e gate"
contem "$d/resumo.txt" "TASK 1: INCOMPLETE" "resumo: a causa do juiz"
tem "$d/resumo.txt" "phase-01\.verify-3\.log" "resumo: o arquivo da causa"
igual 0 "$(commits_fase "$r")" "nenhum commit de fase"

caso "[5.1] credencial de API no ambiente: aborta antes de gastar"
r="$BASE/credencial"; novo_repo "$r" "$loop"
for v in ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_VERTEX CLAUDE_CODE_USE_FOUNDRY; do
  igual 1 "$(loop_em "$r" ok "$v=1")" "$v: exit 1"
  tem "$r.saida" "$v" "$v: diz qual"
done
mkdir -p "$HOME_FALSO/.claude"; echo '{"apiKeyHelper": "~/bin/chave.sh"}' > "$HOME_FALSO/.claude/settings.json"
igual 1 "$(loop_em "$r" ok)" "apiKeyHelper em ~/.claude/settings.json: exit 1"
tem "$r.saida" "apiKeyHelper" "apiKeyHelper: diz qual"
rm -f "$HOME_FALSO/.claude/settings.json"
nao_rodou "$r" "nenhum caso chamou o ralph"
igual 0 "$(loop_em "$r" ok ANTHROPIC_API_KEY=1 LOOP_ACEITO_API=1 -- --checa "$PH")" "LOOP_ACEITO_API=1: o --checa passa"

caso "[5.1] sem comando de teste: sem Prova, não tem loop"
r="$BASE/sem-prova"; novo_repo "$r" "$loop"
igual 1 "$(loop_em "$r" ok LOOP_TEST_CMD=)" "exit 1"
tem "$r.saida" "prova|teste" "diz por quê"
igual 1 "$(loop_em "$r" ok LOOP_TEST_CMD= RALPH_TEST_CMD=./test.sh)" "RALPH_TEST_CMD exportada: exit 1"
tem "$r.saida" "RALPH_TEST_CMD" "diz por quê"
nao_rodou "$r" "o ralph não rodou"

caso "[5.1] --checa: confere e não roda"
r="$BASE/checa"; novo_repo "$r" "$loop"
igual 0 "$(loop_em "$r" ok -- --checa "$PH")" "exit 0"
nao_rodou "$r" "o ralph não rodou"
[ -f "$(motor "$r")/implementacoes" ] && falha "nenhuma sessão" || passa "nenhuma sessão"

caso "[5.1] painel ligado (--dashboard) sem terminal: roda e guarda o ralph.log"
r="$BASE/painel"; novo_repo "$r" "$loop"
igual 0 "$(loop_em "$r" ok LOOP_PAINEL=1)" "exit 0"
tem "$(run_dir "$r")/logs/ralph.log" "Commit criado: feat\\(phase-2\\)" "logs/ralph.log do painel copiado"

# ============================================================================ 5.2
if nivel 5.2; then
caso "[5.2] pré-voo completo: cada problema aborta antes do ralph"
r="$BASE/main"; novo_repo "$r" "$loop"; git -C "$r" switch -q main
igual 1 "$(loop_em "$r" ok)" "na main: exit 1"
tem "$r.saida" "main" "diz que é a main"
nao_rodou "$r" "na main: o ralph não rodou"

r="$BASE/suja"; novo_repo "$r" "$loop"; echo x > "$r/rascunho.txt"
igual 1 "$(loop_em "$r" ok)" "árvore suja: exit 1"
contem "$r.saida" "rascunho.txt" "mostra o arquivo"
nao_rodou "$r" "árvore suja: o ralph não rodou"

r="$BASE/sem-hook"; novo_repo "$r" "$loop"
echo '{"hooks":{}}' > "$r/.claude/settings.json"; git -C "$r" commit -qam "tira o hook"
igual 1 "$(loop_em "$r" ok)" "hook desligado: exit 1"
tem "$r.saida" "guarda-aceite" "diz qual hook"

r="$BASE/aceite-quebrado"; novo_repo "$r" "$loop"
echo "tests/NaoExiste.sh" >> "$r/.claude/aceite.txt"; git -C "$r" commit -qam "aceite errado"
igual 1 "$(loop_em "$r" ok)" "aceite.txt com arquivo inexistente: exit 1"
tem "$r.saida" "NaoExiste" "diz qual"

r="$BASE/diagnostico"; novo_repo "$r" "$loop"
mkdir -p "$r/.diagnostico-operador"; echo '{}' > "$r/.diagnostico-operador/antes.json"
igual 1 "$(loop_em "$r" ok)" "diagnóstico fora do git e do exclude: exit 1"
tem "$r.saida" "diagnostico-operador" "diz qual"
echo '/.diagnostico-operador/' >> "$r/.git/info/exclude"
igual 0 "$(loop_em "$r" ok -- --checa "$PH")" "no exclude: o --checa passa"

r="$BASE/phases-torto"; novo_repo "$r" "$loop"
sed -i 's/^## Phase 2: /## Phase 2 - /' "$r/$PH"; git -C "$r" commit -qam "heading torto"
igual 1 "$(loop_em "$r" ok)" "PHASES com heading torto: exit 1"
tem "$r.saida" "confere-phases|Phase 2 -" "diz que foi o PHASES"
nao_rodou "$r" "o ralph não rodou"

caso "[5.2] o shim no PATH: toda sessão leva --max-budget-usd"
r="$BASE/falha-uma-vez"; novo_repo "$r" "$loop"
igual 0 "$(loop_em "$r" falha-uma-vez LOOP_BUDGET_USD=2)" "falha-uma-vez: exit 0"
d="$(run_dir "$r")"
contem "$d/prompts/phase-02.cycle-2.txt" "Motivo da falha (gate 2" "o ciclo 2 da fase 2 recebe a causa do gate 2"
contem "$d/prompts/phase-02.cycle-2.txt" "src/fase-2.txt diz 'quebrado'" "a causa é a saída real da Prova"
igual 5 "$(grep -c -- '--max-budget-usd 2' "$(motor "$r")/argumentos.txt")" "5 sessões (3 de implementação, 2 do juiz), todas com --max-budget-usd 2"
contem "$d/camadas.txt" "LOOP_BUDGET_USD=2" "camadas.txt com os freios"
tem "$d/camadas.txt" "pior caso.*12" "camadas.txt com a conta do pior caso (12 sessões)"

caso "[5.2] sessão que nunca termina: o shim estoura, gate 0, ciclo com a causa, para"
r="$BASE/pendura"; novo_repo "$r" "$loop"
t0=$(date +%s)
igual 1 "$(loop_em "$r" pendura LOOP_TIMEOUT=3s MAX_CICLOS=2)" "exit 1"
dur=$(( $(date +%s) - t0 ))
[ "$dur" -lt 60 ] && passa "parou em ${dur} s (2 sessões de 3 s mais os gates)" || falha "demorou ${dur} s"
d="$(run_dir "$r")"
contem "$d/prompts/phase-01.cycle-2.txt" "Motivo da falha (gate 0" "o ciclo 2 recebe a causa do gate 0"
contem "$d/prompts/phase-01.cycle-2.txt" "O engine terminou sem emitir um resultado" "a causa diz que a sessão morreu sem resultado"
tem "$d/resumo.txt" "gate 0" "resumo: gate 0"
if pgrep -f "$BIN/claude" >/dev/null; then falha "nenhum motor falso vivo"; else passa "nenhum motor falso vivo"; fi

caso "[5.2] sessão sem linha de resultado: gate 0"
r="$BASE/sem-resultado"; novo_repo "$r" "$loop"
igual 1 "$(loop_em "$r" sem-resultado MAX_CICLOS=1)" "exit 1"
tem "$(run_dir "$r")/resumo.txt" "gate 0" "resumo: gate 0"
fi

# ============================================================================ 5.3
if nivel 5.3; then
caso "[5.3] aviso do fim pelo webhook, num receptor local"
python3 -I "$EXEMPLOS/testes/receptor.py" "$BASE/porta" "$BASE/recebido.jsonl" &
receptor=$!; trap 'kill "$receptor" 2>/dev/null || true' EXIT
for _ in $(seq 50); do [ -s "$BASE/porta" ] && break; sleep 0.1; done
r="$BASE/aviso-ok"; novo_repo "$r" "$loop"
igual 0 "$(loop_em "$r" ok AVISO_CMD= AVISO_WEBHOOK="http://127.0.0.1:$(cat "$BASE/porta")/n8n" NO_PROXY=127.0.0.1 no_proxy=127.0.0.1)" "exit 0"
tem "$BASE/recebido.jsonl" "terminou 2/2" "o webhook recebeu 'terminou 2/2'"
tem "$(run_dir "$r")/camadas.txt" "webhook" "camadas.txt diz o canal"

caso "[5.3] aviso de falha: fase, gate e a causa"
r="$BASE/aviso-falha"; novo_repo "$r" "$loop"; : > "$avisos"
igual 1 "$(loop_em "$r" incompleta MAX_CICLOS=1)" "exit 1"
tem "$avisos" "falhou.*F1.*gate 3.*TASK 1: INCOMPLETE" "aviso com F1, gate 3 e TASK 1"
igual 1 "$(wc -l < "$avisos")" "um aviso só (o vigia deixa o fim para o loop.sh)"

caso "[5.3] sessão quieta: o vigia avisa; Ctrl-C: tudo para na hora e avisa"
r="$BASE/ctrl-c"; novo_repo "$r" "$loop"; : > "$avisos"
(cd "$r" && ambiente MOTOR_CENARIO=pendura AVISO_CMD="$BASE/grava.sh" LOOP_VIGIA_S=1 LOOP_QUIETO=2s LOOP_TIMEOUT=5m \
   setsid bash .claude/scripts/loop.sh "$PH") > "$r.saida" 2>&1 &
job=$!
n=0; while [ "$n" -lt 150 ] && ! grep -q 'travou?' "$avisos"; do sleep 0.2; n=$((n + 1)); done
tem "$avisos" "travou\\?" "o vigia avisou 'travou?'"
pgrep -f "$BIN/claude" >/dev/null && passa "a sessão estava no ar antes do Ctrl-C" || falha "a sessão estava no ar antes do Ctrl-C"
# O Ctrl-C do terminal manda SIGINT ao grupo de processos inteiro: aqui, o grupo que o setsid criou.
pid_loop="$(pgrep -o -f "bash .claude/scripts/loop.sh $PH")"
grupo="$(ps -o pgid= -p "$pid_loop" | tr -d ' ')"
[ -n "$grupo" ] && [ "$grupo" != "$(ps -o pgid= -p $$ | tr -d ' ')" ] || { echo "grupo do loop não encontrado" >&2; exit 2; }
t0=$(date +%s%N)
kill -INT -- "-$grupo"
n=0; while [ "$n" -lt 100 ] && kill -0 "$job" 2>/dev/null; do sleep 0.1; n=$((n + 1)); done
ms=$(( ($(date +%s%N) - t0) / 1000000 ))
if kill -0 "$job" 2>/dev/null; then
  falha "o loop não saiu em 10 s depois do Ctrl-C"
  kill -KILL -- "-$grupo" 2>/dev/null || true
fi
rc=0; wait "$job" || rc=$?
[ "$ms" -lt 5000 ] && passa "o loop saiu em ${ms} ms depois do Ctrl-C" || falha "o loop levou ${ms} ms"
[ "$rc" -ne 0 ] && passa "exit diferente de 0 ($rc)" || falha "exit 0 depois do Ctrl-C"
sleep 0.5
if pgrep -f "$BIN/claude" >/dev/null; then falha "a sessão morreu junto"; pkill -f "$BIN/claude" || true; else passa "a sessão morreu junto"; fi
if pgrep -f "$r/.claude/scripts/vigia.sh" >/dev/null; then falha "o vigia morreu junto"; pkill -f "$r/.claude/scripts/vigia.sh" || true; else passa "o vigia morreu junto"; fi
tem "$avisos" "interrompido" "avisou 'interrompido'"
tem "$(run_dir "$r")/resumo.txt" "desfecho: *INTERROMPIDO" "resumo: INTERROMPIDO"
contem "$r/.phases/state/run.tsv" $'META\tstatus\tfailed' "o ralph marcou failed no run.tsv"

caso "[5.3] LOOP_PR=1: push e PR em rascunho só quando entrega"
printf '#!/usr/bin/env bash\necho "gh $*" >> "%s/gh.txt"\n' "$BASE" > "$BIN/gh"; chmod +x "$BIN/gh"
r="$BASE/pr-ok"; novo_repo "$r" "$loop"; git init -q --bare "$BASE/remoto-ok.git"; git -C "$r" remote add origin "$BASE/remoto-ok.git"
: > "$BASE/gh.txt"
igual 0 "$(loop_em "$r" ok LOOP_PR=1)" "ok: exit 0"
tem "$BASE/gh.txt" "pr create.*--draft" "abriu PR em rascunho"
tem "$BASE/gh.txt" "--body-file .*resumo\.txt|--body " "com o resumo no corpo"
igual "$(git -C "$r" rev-parse HEAD)" "$(git -C "$BASE/remoto-ok.git" rev-parse feat/exemplo)" "a branch subiu"
r="$BASE/pr-falha"; novo_repo "$r" "$loop"; git init -q --bare "$BASE/remoto-falha.git"; git -C "$r" remote add origin "$BASE/remoto-falha.git"
: > "$BASE/gh.txt"
igual 1 "$(loop_em "$r" incompleta LOOP_PR=1 MAX_CICLOS=1)" "falhou: exit 1"
igual 0 "$(wc -l < "$BASE/gh.txt")" "falhou: nenhum PR"
git -C "$BASE/remoto-falha.git" rev-parse -q --verify feat/exemplo >/dev/null && falha "falhou: nenhum push" || passa "falhou: nenhum push"
rm -f "$BIN/gh"
fi

echo; echo "repositórios em: $BASE"
placar "testa-loop (até a aula $ate)"
