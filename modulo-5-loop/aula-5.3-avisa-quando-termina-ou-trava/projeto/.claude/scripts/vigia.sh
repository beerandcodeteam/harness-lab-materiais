#!/usr/bin/env bash
# vigia.sh · aula 5.3 · avisa quando o loop trava, olhando de fora
#
# Uso: .claude/scripts/vigia.sh [raiz-do-repositório]   (o loop.sh roda em segundo plano)
#
# Lê .phases/state/run.tsv (o estado que o ralph publica) a cada LOOP_VIGIA_S e
# avisa uma vez por evento:
#   - status mudou para waiting (limite de uso), finished ou failed
#   - o PID do ralph sumiu com status=running (SIGKILL, queda, reboot)
#   - o log da sessão de implementação está parado há mais de LOOP_QUIETO,
#     com status=running e nenhum gate rodando (META gate vazio)
# Só começa quando o run.tsv é do run novo (META started >= LOOP_INICIO): até o
# preflight passar, o arquivo ainda é o do run anterior, porque o ralph só
# recria .phases/ depois do preflight.
#
# Variáveis:
#   LOOP_INICIO      epoch de início do loop.sh (padrão: agora)
#   LOOP_VIGIA_S     segundos entre leituras (padrão 60)
#   LOOP_QUIETO      log parado por quanto tempo vira "travou?" (padrão 15m; aceita 90, 90s, 15m, 1h)
#   AVISO_CMD        quem manda a mensagem (padrão: aviso.sh ao lado deste arquivo)
#   VIGIA_SO_TRAVOU  1 = não avisa finished e failed (o loop.sh avisa no fim do run)
#   LOOP_PID         PID do loop.sh: se ele some, o vigia sai junto
set -uo pipefail

raiz="${1:-.}"
cd "$raiz" || exit 1
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
estado=".phases/state/run.tsv"
inicio="${LOOP_INICIO:-$(date +%s)}"
intervalo="${LOOP_VIGIA_S:-60}"
so_travou="${VIGIA_SO_TRAVOU:-0}"

segundos() {  # 90 | 90s | 15m | 1h -> segundos
  local v="$1"
  case "$v" in
    *h) echo $(( ${v%h} * 3600 )) ;;
    *m) echo $(( ${v%m} * 60 )) ;;
    *s) echo "${v%s}" ;;
    *)  echo "$v" ;;
  esac
}
quieto=$(segundos "${LOOP_QUIETO:-15m}")

legivel() { local s="$1"; if [ "$s" -ge 60 ]; then echo "$((s / 60)) min"; else echo "${s} s"; fi; }

avisa() {
  if [ -n "${AVISO_CMD:-}" ]; then
    $AVISO_CMD "$1" || true
  else
    bash "$dir/aviso.sh" "$1" || true
  fi
}

declare -A M
le_meta() {
  M=()
  local k v
  while IFS=$'\t' read -r k v; do M[$k]="$v"; done < <(awk -F'\t' '$1=="META"{print $2 "\t" $3}' "$estado" 2>/dev/null)
}

fase_falhou() { awk -F'\t' '$1=="PHASE" && $3=="failed" {print "F" $2 " (" $6 "), ciclo " $4 ", gates " $5; exit}' "$estado"; }
fases_feitas() { awk -F'\t' '$1=="PHASE" && $3=="done"' "$estado" | wc -l; }

ultimo=""        # último status visto
declare -A ja    # eventos já avisados

while :; do
  if [ -n "${LOOP_PID:-}" ] && ! kill -0 "$LOOP_PID" 2>/dev/null; then exit 0; fi

  if [ -f "$estado" ]; then
    le_meta
    comecou="${M[started]:-0}"
    if [[ "$comecou" =~ ^[0-9]+$ ]] && [ "$comecou" -ge "$inicio" ]; then
      proj="${M[project]:-?}"; st="${M[status]:-}"; fase="${M[phase_cur]:-}"; ciclo="${M[cycle]:-}"

      if [ "$st" != "$ultimo" ]; then
        case "$st" in
          waiting)
            avisa "loop $proj: esperando limite de uso na fase ${fase:-?}. ${M[activity]:-}" ;;
          finished)
            [ "$so_travou" = 1 ] || avisa "loop $proj: terminou $(fases_feitas)/${M[phase_total]:-?} fases." ;;
          failed)
            [ "$so_travou" = 1 ] || avisa "loop $proj: falhou. $(fase_falhou) ${M[last_error]:-}" ;;
        esac
        ultimo="$st"
      fi

      case "$st" in
        finished|failed) exit 0 ;;
        running)
          pid="${M[pid]:-}"
          if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
            avisa "loop $proj: morto? o ralph (PID $pid) sumiu com status running na fase ${fase:-?}."
            exit 0
          fi
          if [ -z "${M[gate]:-}" ] && [ -n "$fase" ] && [ -n "$ciclo" ]; then
            log=$(printf '.phases/logs/phase-%02d.cycle-%s.log' "$fase" "$ciclo")
            if [ -f "$log" ]; then
              parado=$(( $(date +%s) - $(stat -c %Y "$log" 2>/dev/null || stat -f %m "$log" 2>/dev/null || date +%s) ))
              chave="quieto:$fase:$ciclo"
              if [ "$parado" -ge "$quieto" ] && [ -z "${ja[$chave]:-}" ]; then
                ja[$chave]=1
                avisa "loop $proj: travou? sessão quieta há $(legivel "$parado") na fase $fase (ciclo $ciclo)."
              fi
            fi
          fi
          ;;
      esac
    fi
  fi
  sleep "$intervalo"
done
