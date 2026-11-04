#!/usr/bin/env bash
# desfecho.sh · aula 6.2 · qual dos desfechos aconteceu, e onde olhar primeiro
#
# Uso:
#   .claude/scripts/desfecho.sh                      # o run.tsv do .phases/ deste repositório
#   .claude/scripts/desfecho.sh .loop-logs/<run>/    # a cópia que o loop.sh guardou
#   .claude/scripts/desfecho.sh caminho/run.tsv      # qualquer run.tsv (fixture, outra máquina)
# Opções:
#   --git <repo>   cruza fases e commits nesse repositório (padrão: o repositório
#                  dono do .phases/ ou do .loop-logs/ lido; arquivo solto, não cruza)
#   --sem-git      não cruza fases e commits
#   --sem-pid      não confere se o processo do ralph está vivo (run.tsv de outra máquina)
#
# Lê só o .phases/state/run.tsv (formato do ralph.sh do bc-harness 0.2.0) e os
# logs ao lado dele. Não roda o loop, não chama o Claude, não escreve nada.
#
# Desfechos (status do run.tsv + PID + fases):
#   ENTREGOU          status=finished
#   RODANDO           status=running e o PID do ralph vivo
#   ESPERANDO LIMITE  status=waiting e o PID vivo (dorme até o reset do limite de uso)
#   FALHOU            status=failed e alguma fase failed
#   INTERROMPIDO      status=failed e nenhuma fase failed: Ctrl-C ou terminal fechado
#                     (o on_exit do ralph grava failed e deixa a fase em running)
#   MORTO             status=running ou waiting com o PID morto: SIGKILL, queda, reboot.
#                     Com waiting, também Ctrl-C durante a espera: o on_exit só grava
#                     failed quando o status é running (ralph.sh, on_exit)
#
# Exit: 0 ENTREGOU · 10 RODANDO · 11 ESPERANDO LIMITE · 20 FALHOU · 21 INTERROMPIDO
#       · 22 MORTO · 2 erro de uso ou run.tsv ilegível
#
# Requer bash 4+ e GNU date. jq é opcional (lê permission_denials).
set -euo pipefail

uso() { sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

ENTRADA=""
GIT_REPO=""
SEM_GIT=0
SEM_PID=0
while [ $# -gt 0 ]; do
  case "$1" in
    --git) GIT_REPO="${2:?--git pede um caminho}"; shift 2 ;;
    --sem-git) SEM_GIT=1; shift ;;
    --sem-pid) SEM_PID=1; shift ;;
    -h|--help) uso ;;
    -*) echo "opção desconhecida: $1" >&2; uso ;;
    *) ENTRADA="$1"; shift ;;
  esac
done

if [ -t 1 ]; then VERM=$'\033[0;31m'; VERD=$'\033[0;32m'; AMAR=$'\033[1;33m'; NEG=$'\033[1m'; NC=$'\033[0m'
else VERM=""; VERD=""; AMAR=""; NEG=""; NC=""; fi

erro() { echo "desfecho: $*" >&2; exit 2; }

# --- onde está o run.tsv -----------------------------------------------------
if [ -z "$ENTRADA" ]; then
  raiz=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  ENTRADA="$raiz/.phases/state/run.tsv"
fi
if [ -d "$ENTRADA" ]; then
  if   [ -f "$ENTRADA/run.tsv" ]; then RUN="$ENTRADA/run.tsv"
  elif [ -f "$ENTRADA/state/run.tsv" ]; then RUN="$ENTRADA/state/run.tsv"
  else erro "nenhum run.tsv em $ENTRADA (nem em $ENTRADA/state/)"; fi
else
  RUN="$ENTRADA"
fi
[ -f "$RUN" ] || erro "não achei $RUN. O loop já rodou neste repositório? Passe o caminho do run.tsv ou do .loop-logs/<run>/."
RUN=$(cd "$(dirname "$RUN")" && pwd)/$(basename "$RUN")
PASTA=$(dirname "$RUN")
[ "$(basename "$PASTA")" = "state" ] && PASTA=$(dirname "$PASTA")
LOGS="$PASTA/logs"
PROMPTS="$PASTA/prompts"

# --- lê o run.tsv --------------------------------------------------------------
declare -A META=() PH_ST=() PH_AT=() PH_GT=() PH_TI=() TK_TOTAL=() TK_INC=()
FASES=()
while IFS=$'\x1f' read -r tipo a b c d e; do
  case "$tipo" in
    META)  META[$a]="$b" ;;
    PHASE) FASES+=("$a"); PH_ST[$a]="$b"; PH_AT[$a]="$c"; PH_GT[$a]="$d"; PH_TI[$a]="$e" ;;
    TASK)  TK_TOTAL[$a]=$(( ${TK_TOTAL[$a]:-0} + 1 ))
           [ "$c" = "incomplete" ] && TK_INC[$a]="${TK_INC[$a]:-}  T$b ${d}"$'\n' ;;
  esac
done < <(awk -F'\t' '{ s = $1; for (i = 2; i <= NF; i++) s = s "\x1f" $i; print s }' "$RUN")

STATUS="${META[status]:-}"
[ -n "$STATUS" ] || erro "$RUN não parece um run.tsv do ralph (sem META status)."

# --- utilidades ------------------------------------------------------------------
data() { [ -n "${1:-}" ] && date -d "@$1" '+%d/%m/%Y %H:%M:%S' 2>/dev/null || echo "?"; }
duracao() {
  local s="${1:-0}"
  if [ "$s" -ge 3600 ]; then printf '%dh %02dm' $((s / 3600)) $((s % 3600 / 60))
  else printf '%dm %02ds' $((s / 60)) $((s % 60)); fi
}
pad() { local s="$1" w="$2"; printf '%s%*s' "$s" $(( w > ${#s} ? w - ${#s} : 0 )) ''; }
arq_fase() { printf 'phase-%02d' "$1"; }
gates_legiveis() {  # "pass skip pass fail" -> "G0 ok · G1 sem escrita · G2 ok · G3 FALHOU"
  local -a g; read -r -a g <<< "$1"; local i out="" v
  for i in 0 1 2 3; do
    case "${g[$i]:-pending}" in
      pass) v="ok" ;; fail) v="FALHOU" ;; run) v="rodando" ;; pending) v="." ;;
      skip) if [ "$i" -eq 1 ]; then v="sem escrita"; else v="pulou"; fi ;;
      *) v="${g[$i]}" ;;
    esac
    out+="G$i $v"; [ "$i" -lt 3 ] && out+=" · "
  done
  echo "$out"
}
gate_reprovado() {  # índice do primeiro gate fail, ou vazio
  local -a g; read -r -a g <<< "$1"; local i
  for i in 0 1 2 3; do [ "${g[$i]:-}" = "fail" ] && { echo "$i"; return 0; }; done
  return 0
}
nome_status() {
  case "$1" in
    done) echo "concluída" ;; failed) echo "FALHOU" ;; running) echo "em execução" ;;
    pending) echo "não rodou" ;; skipped) echo "pulada (--from)" ;; *) echo "$1" ;;
  esac
}

PID="${META[pid]:-}"
PID_OBS=""
pid_vivo() {
  [ "$SEM_PID" -eq 1 ] && return 0
  [[ "$PID" =~ ^[0-9]+$ ]] || { PID_OBS="o run.tsv não tem PID"; return 1; }
  if ! kill -0 "$PID" 2>/dev/null && [ ! -e "/proc/$PID" ]; then
    PID_OBS="o processo $PID não existe"; return 1
  fi
  # PID reaproveitado por outro programa depois de um reboot: no Linux dá para ver.
  if [ -r "/proc/$PID/cmdline" ] && ! tr '\0' ' ' < "/proc/$PID/cmdline" | grep -q 'ralph'; then
    PID_OBS="o PID $PID existe, mas é outro programa ($(tr '\0' ' ' < "/proc/$PID/cmdline" | cut -c1-40))"
    return 1
  fi
  return 0
}

# --- classifica -------------------------------------------------------------------
FALHADAS=(); EM_EXEC=()
for n in "${FASES[@]}"; do
  [ "${PH_ST[$n]}" = "failed" ] && FALHADAS+=("$n")
  [ "${PH_ST[$n]}" = "running" ] && EM_EXEC+=("$n")
done

case "$STATUS" in
  finished) DESFECHO="ENTREGOU"; CODIGO=0 ;;
  running)  if pid_vivo; then DESFECHO="RODANDO"; CODIGO=10; else DESFECHO="MORTO"; CODIGO=22; fi ;;
  waiting)  if pid_vivo; then DESFECHO="ESPERANDO LIMITE"; CODIGO=11; else DESFECHO="MORTO"; CODIGO=22; fi ;;
  failed)   if [ "${#FALHADAS[@]}" -gt 0 ]; then DESFECHO="FALHOU"; CODIGO=20; else DESFECHO="INTERROMPIDO"; CODIGO=21; fi ;;
  *) erro "status desconhecido no run.tsv: $STATUS" ;;
esac

# --- repositório para cruzar fases e commits --------------------------------------
GITD=""
if [ "$SEM_GIT" -eq 0 ]; then
  if [ -n "$GIT_REPO" ]; then
    GITD=$(git -C "$GIT_REPO" rev-parse --show-toplevel 2>/dev/null) || erro "--git $GIT_REPO não é um repositório git"
  else
    topo=$(git -C "$PASTA" rev-parse --show-toplevel 2>/dev/null || true)
    case "$PASTA" in
      "$topo"/.phases|"$topo"/.loop-logs/*) GITD="$topo" ;;
    esac
  fi
fi

declare -A COMMIT_DA_FASE=()
if [ -n "$GITD" ]; then
  desde=$(( ${META[started]:-0} - 5 ))
  while IFS=$'\t' read -r h ct s; do
    [ "$ct" -ge "$desde" ] || continue
    if [[ "$s" =~ ^(feat|wip)\(phase-([0-9]+)\) ]]; then
      COMMIT_DA_FASE[${BASH_REMATCH[2]}]="${COMMIT_DA_FASE[${BASH_REMATCH[2]}]:-}${h:0:7} $s"$'\n'
    fi
  done < <(git -C "$GITD" log --format='%H%x09%ct%x09%s' HEAD 2>/dev/null || true)
fi

# --- cabeçalho ---------------------------------------------------------------------
INICIO="${META[started]:-}"; FIM="${META[ended]:-}"
echo "Run ${META[run]:-?} · projeto ${META[project]:-?} · engine ${META[engine]:-?}"
echo "Arquivo: $RUN"
if [ -n "$FIM" ]; then
  echo "Início $(data "$INICIO") · fim $(data "$FIM") · duração $(duracao $((FIM - INICIO)))"
else
  echo "Início $(data "$INICIO") · sem fim gravado · $(duracao $(( $(date +%s) - ${INICIO:-0} ))) desde o início"
fi
echo "Comando de teste (gate 2): ${META[test_cmd]:-}"
FEITAS=0
for n in "${FASES[@]}"; do [ "${PH_ST[$n]}" = "done" ] && FEITAS=$((FEITAS + 1)); done
TOTAL="${META[phase_total]:-${#FASES[@]}}"
echo ""
case "$DESFECHO" in
  ENTREGOU) echo "${NEG}${VERD}DESFECHO: ENTREGOU $FEITAS/$TOTAL fases${NC}" ;;
  RODANDO|"ESPERANDO LIMITE") echo "${NEG}${AMAR}DESFECHO: $DESFECHO ($FEITAS/$TOTAL fases concluídas até agora)${NC}" ;;
  *) echo "${NEG}${VERM}DESFECHO: $DESFECHO ($FEITAS/$TOTAL fases concluídas)${NC}" ;;
esac
echo ""

# --- fases --------------------------------------------------------------------------
ALERTAS=0
echo "Fases:"
for n in "${FASES[@]}"; do
  st="${PH_ST[$n]}"; at="${PH_AT[$n]}"; gt="${PH_GT[$n]}"
  if [ "$at" = "0" ]; then gl="sem sessão neste run"; else gl="ciclo $at/${META[cycle_max]:-?}   $(gates_legiveis "$gt")"; fi
  printf '  F%s %s %s   %s\n' "$(pad "$n" 3)" "$(pad "$(nome_status "$st")" 16)" "$gl" "${PH_TI[$n]}"
  [ "$st" = "done" ] || continue
  read -r -a g <<< "$gt"
  if [ "$at" = "0" ]; then
    echo "        pulada: já estava concluída num run anterior (.phases/.progress), sem sessão neste run"
    continue
  fi
  commit="${COMMIT_DA_FASE[$n]:-}"
  if [ "${g[1]:-}" = "skip" ] && [ "$at" = "1" ]; then
    echo "        já implementada: a sessão não escreveu e os gates passaram contra o código em HEAD; sem commit, e está certo"
    continue
  fi
  if [ -z "$GITD" ]; then continue; fi
  if [ -n "$commit" ]; then
    printf '%s' "$commit" | sed 's/^/        commit /'
  elif [ "${g[1]:-}" = "skip" ]; then
    echo "        sem commit: o último ciclo não escreveu; se os anteriores também não, não havia o que commitar"
  else
    echo "        ${VERM}ALERTA${NC}: fase verde, a sessão escreveu, e não há commit feat(phase-$n) neste run."
    echo "        Assinatura do hook de pre-commit que recusou: o ralph diz \"Commit criado\" mesmo assim (ralph.sh, commit_phase)."
    ALERTAS=$((ALERTAS + 1))
  fi
done
if [ -n "$GITD" ] && [ "$ALERTAS" -gt 0 ] && ! git -C "$GITD" diff --cached --quiet 2>/dev/null; then
  echo "  Há mudanças staged em $GITD: o trabalho das fases sem commit está ali (git status)."
fi
if [ -z "$GITD" ] && [ "$SEM_GIT" -eq 0 ] && [ "$DESFECHO" = "ENTREGOU" ]; then
  echo "  (fases e commits não cruzados: run.tsv fora de um .phases/ ou .loop-logs/; use --git <repo>)"
fi
echo ""

# --- causa final de uma fase que falhou --------------------------------------------
linha_resultado() {  # última linha "type":"result" de um log stream-json
  grep -F '"type":"result"' "$1" 2>/dev/null | tail -n 1 || true
}
negacoes() {  # quantas permission_denials no resultado
  local r="$1"
  [ -n "$r" ] || { echo 0; return; }
  if command -v jq >/dev/null 2>&1; then
    jq -r '(.permission_denials // []) | length' <<< "$r" 2>/dev/null || echo 0
  elif grep -qE '"permission_denials"[[:space:]]*:[[:space:]]*\[[[:space:]]*[^][:space:]]' <<< "$r"; then
    echo "1+"
  else
    echo 0
  fi
}
incompletas_do_ciclo() {  # números das tasks INCOMPLETE num verify log
  sed 's/^[[:space:]]*//' "$1" 2>/dev/null | grep -E '^TASK [0-9]+: INCOMPLETE' | sed -E 's/^TASK ([0-9]+):.*/\1/' | sort -n | tr '\n' ' ' || true
}

causa_da_fase() {
  local n="$1" k="${PH_AT[$1]}" gi base arq
  base="$LOGS/$(arq_fase "$n")"
  gi=$(gate_reprovado "${PH_GT[$n]}")
  read -r -a g <<< "${PH_GT[$n]}"
  echo "${NEG}Fase $n · \"${PH_TI[$n]}\" · falhou no ciclo $k de ${META[cycle_max]:-?}${NC}"
  if [ ! -d "$LOGS" ]; then
    echo "  Logs não encontrados em $LOGS. Se o .phases/ já foi substituído, aponte para a cópia: desfecho.sh .loop-logs/<run>/"
  fi
  case "$gi" in
    3) arq="$base.verify-$k.log"
       echo "  Gate que reprovou: G3, verificação independente (o juiz)"
       echo "  Causa final: $arq"
       if [ -f "$arq" ]; then
         local esperadas="${TK_TOTAL[$n]:-0}" emitidas inc
         emitidas=$(sed 's/^[[:space:]]*//' "$arq" | grep -cE '^TASK [0-9]+: (DONE|INCOMPLETE)' || true)
         inc=$(sed 's/^[[:space:]]*//' "$arq" | grep -E '^TASK [0-9]+: INCOMPLETE' || true)
         [ -n "$inc" ] && printf '%s\n' "$inc" | sed 's/^/    /'
         if [ "$emitidas" -eq 0 ]; then
           echo "  Sinal: o juiz não respondeu no formato TASK n: DONE|INCOMPLETE."
           echo "  Camada provável: nenhuma da feature. Ruído do juiz: rode de novo; se repetir, leia o verify log inteiro."
         elif [ -z "$inc" ] && [ "$emitidas" -ne "$esperadas" ]; then
           echo "  Sinal: o juiz cobriu $emitidas de $esperadas tasks e não reprovou nenhuma."
           echo "  Camada provável: ruído do juiz. Rode de novo (resolveu nos casos observados, não é garantia)."
         else
           local comuns="" c ciclo_inc
           comuns=" $(incompletas_do_ciclo "$arq")"
           for ((c = 1; c < k; c++)); do
             [ -f "$base.verify-$c.log" ] || continue
             ciclo_inc=" $(incompletas_do_ciclo "$base.verify-$c.log")"
             local novo="" t
             for t in $comuns; do [[ "$ciclo_inc" == *" $t "* ]] && novo+=" $t"; done
             comuns="$novo "
           done
           comuns=$(echo "$comuns" | xargs || true)
           if [ "$k" -gt 1 ] && [ -n "$comuns" ]; then
             echo "  Sinal: a mesma task INCOMPLETE em todos os $k ciclos (task $comuns)."
             echo "  Camada provável: Prova. Critério que não se prova ou ambíguo (aula 4.3). Releia o Acceptance criteria da task."
           else
             echo "  Sinal: tasks INCOMPLETE diferentes entre os ciclos."
             echo "  Camada provável: Prova (critério) ou Loop (fase grande demais para uma sessão)."
           fi
           if [ "${g[1]:-}" = "skip" ]; then
             echo "  Sinal: no último ciclo a sessão não escreveu nada e mesmo assim o juiz reprovou."
             echo "  Camada provável: Regra. Fase mal descrita: a sessão achou que não havia o que fazer."
           fi
         fi
       fi
       ;;
    2) arq="$base.test-$k.log"
       echo "  Gate que reprovou: G2, a suíte do projeto rodada pelo ralph"
       echo "  Causa final: $arq"
       [ -f "$arq" ] && tail -n 12 "$arq" | sed 's/^/    /'
       if grep -qE 'falhou com codigo 127' <<< "${META[last_error]:-}" || { [ -f "$arq" ] && grep -qE 'command not found|No such file' "$arq"; }; then
         echo "  Sinal: o comando de teste não existe ou não roda."
         echo "  Camada provável: Prova. O comando da Prova está errado (aula 4.1, qual-comando.sh)."
       else
         echo "  Camada provável: Prova (teste errado ou instável, o termômetro com mau contato) ou Loop (fase grande)."
         echo "  Compare os test logs dos ciclos: o mesmo teste vermelho nos $k ciclos aponta para o teste ou o critério."
       fi
       ;;
    0) arq="$base.cycle-$k.log"
       local r d
       r=$(linha_resultado "$arq")
       echo "  Gate que reprovou: G0, a sessão de implementação não terminou direito"
       echo "  Causa final: o fim de $arq"
       [ -f "$arq" ] && tail -n 5 "$arq" | cut -c1-200 | sed 's/^/    /'
       if [ -z "$r" ]; then
         echo "  Sinal: a sessão terminou sem a linha de resultado."
         echo "  Camada provável: Loop. Sessão morta ou teto de tempo do shim (o timeout sai com 124, aula 5.2)."
       elif grep -q 'error_max_budget_usd' <<< "$r"; then
         echo "  Sinal: error_max_budget_usd no resultado."
         echo "  Camada provável: Loop. O teto de gasto do shim (--max-budget-usd) cortou a sessão."
       else
         echo "  Sinal: o engine reportou is_error no resultado."
         echo "  Camada provável: Loop. Leia o campo result da última linha do log."
       fi
       ;;
    *) if [ "${g[0]:-}" = "pass" ] && [ "${g[2]:-}" != "fail" ] && [ "${g[3]:-}" != "fail" ] && [ "${g[3]:-}" != "pending" ]; then
         echo "  Nenhum gate reprovou: a fase passou nos gates e o commit falhou (ralph.sh, commit_phase)."
         echo "  Camada provável: Trava do git. Um hook de pre-commit recusou. Rode git status e o hook à mão."
       else
         echo "  Nenhum gate marcado como FALHOU no run.tsv. Leia os logs da fase em $base.*"
       fi
       ;;
  esac
  # A Trava barrou algo na sessão? Vale para qualquer gate.
  local nd
  nd=$(negacoes "$(linha_resultado "$base.cycle-$k.log")")
  if [ "$nd" != "0" ]; then
    echo "  Sinal: $nd permission_denials no resultado da sessão (tail -n1 $base.cycle-$k.log | jq '.permission_denials')."
    echo "  Camada provável: Trava. Bloqueio legítimo? Ajuste a Trava. Tentou mexer no teste? Olhe o teste ou o critério."
  fi
  [ -n "${TK_INC[$n]:-}" ] && { echo "  Tasks que o juiz deixou incompletas:"; printf '%s' "${TK_INC[$n]}" | sed 's/^/  /'; }
  if [ "$k" -gt 1 ]; then
    echo "  Atenção: $PROMPTS/$(arq_fase "$n").cycle-$k.txt traz a causa do ciclo $((k - 1)), não a final."
  fi
  echo ""
}

case "$DESFECHO" in
  ENTREGOU)
    echo "Olhe primeiro: git log --oneline (um feat(phase-N) por fase que mudou algo) e o ralph-watch.sh --once ."
    ;;
  FALHOU)
    [ -n "${META[last_error]:-}" ] && echo "Último erro (run.tsv, primeira linha cortada em 70 caracteres): ${META[last_error]}" && echo ""
    for n in "${FALHADAS[@]}"; do causa_da_fase "$n"; done
    echo "O trabalho parcial da fase fica na árvore (git status). Antes de rodar de novo:"
    echo "  meça (/diagnostico-operador depois), copie o .phases/ (o loop.sh já copia),"
    echo "  e limpe a árvore commitando o parcial ou descartando só o que a fase escreveu (git checkout -- .)."
    echo "  git clean -fd apaga arquivo seu fora do git, inclusive o diagnóstico da 1.1."
    ;;
  INTERROMPIDO)
    if [ "${#EM_EXEC[@]}" -gt 0 ]; then
      n="${EM_EXEC[0]}"
      echo "Parou no meio da fase $n (\"${PH_TI[$n]}\"), ciclo ${PH_AT[$n]}, gate ${META[gate]:-de implementação}."
    else
      echo "Parou entre fases ou antes da primeira."
    fi
    echo "Sem causa no log: ninguém reprovou. Foi Ctrl-C, terminal fechado ou um exit do próprio ralph."
    echo "O trabalho parcial pode estar na árvore (git status). Decida: commitar ou descartar, e rodar de novo."
    ;;
  MORTO)
    echo "O run.tsv diz status=$STATUS, mas $PID_OBS."
    if [ "$STATUS" = "waiting" ]; then
      echo "Parou durante a espera do limite de uso: kill, queda, ou Ctrl-C (com waiting o ralph não grava failed)."
    else
      echo "O ralph morreu sem gravar o fim: SIGKILL, queda da máquina, reboot."
    fi
    if [ "${#EM_EXEC[@]}" -gt 0 ]; then
      n="${EM_EXEC[0]}"; echo "Estava na fase $n (\"${PH_TI[$n]}\"), ciclo ${PH_AT[$n]}."
    fi
    echo "O painel vai mostrar \"Em execução\" para sempre. Confira a árvore (git status) e rode de novo."
    ;;
  RODANDO)
    n="${META[phase_cur]:-?}"
    echo "Está rodando agora (PID $PID): fase $n, ciclo ${META[cycle]:-?}, gate ${META[gate]:-de implementação}."
    [ -n "${META[activity]:-}" ] && echo "Atividade: ${META[activity]}"
    echo "Acompanhe: o ralph-watch.sh do plugin em outro terminal. Não mexa na árvore enquanto roda."
    ;;
  "ESPERANDO LIMITE")
    echo "O ralph bateu no limite de uso e dorme até o reset, sem gastar ciclo (PID $PID)."
    [ -n "${META[activity]:-}" ] && echo "Atividade: ${META[activity]}"
    echo "Limite semanal, de Opus ou de Sonnet não é lido pelo ralph (deduzido do código): se a espera repetir, confira a mensagem no log."
    ;;
esac

[ "$ALERTAS" -gt 0 ] && echo "" && echo "${VERM}$ALERTAS alerta(s) de fase sem commit.${NC}"
exit "$CODIGO"
