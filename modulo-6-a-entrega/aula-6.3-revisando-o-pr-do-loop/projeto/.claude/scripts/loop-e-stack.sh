#!/usr/bin/env bash
# loop-e-stack.sh · aula 6.3 · o fim do loop em código: entregou, a stack de PRs abre sozinha
#
# Uso: .claude/scripts/loop-e-stack.sh .spec/features/<slug>/PHASES.md [opções do stack-pr.sh]
#   1. confere o gh (instalado e logado) e o remote origin, antes de gastar token;
#   2. roda o loop.sh do Módulo 5 (pré-voo, ralph, cópia do log em .loop-logs/<run>/);
#   3. lê o desfecho do run com o desfecho.sh (aula 6.2). Não entregou: nenhum PR,
#      mostra o desfecho e sai com o exit dele (20 FALHOU, 21 INTERROMPIDO, 22 MORTO);
#   4. entregou: grava o revisa-loop.sh em .loop-logs/<run>/revisao.txt (vai junto no
#      pacote-prova.sh) e roda o stack-pr.sh --criar: uma branch por fase, push e um
#      PR por fase, em rascunho, cada um com base no de baixo.
#   O que vier depois do PHASES.md vai para o stack-pr.sh (ex.: --prefixo, --trunk).
#
# Os PRs saem em rascunho: a revisão (alertas do revisa-loop.sh, suíte inteira,
# fumaça real) continua sua, antes do Ready for review. Não faz merge. O LOOP_PR do
# loop.sh fica desligado aqui, para não abrir um PR único além da stack.
#
# Exit: 0 entregou e a stack abriu · 1 o loop não chegou a rodar, ou a stack falhou
#       · exit do desfecho.sh se não entregou · 2 erro de uso
set -uo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOOP="${LOOP_SH:-$AQUI/loop.sh}"   # LOOP_SH: só os testes trocam
case "${1:-}" in
  ""|-h|--help) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
  -*) echo "loop-e-stack: o primeiro argumento é o PHASES.md (veio $1)" >&2; exit 2 ;;
esac
phases="$1"; shift

RAIZ=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "loop-e-stack: rode dentro do repositório" >&2; exit 2; }
cd "$RAIZ"
[ -f "$LOOP" ] || { echo "loop-e-stack: falta $LOOP. Ele vem do Módulo 5: instalar.sh 5.3." >&2; exit 2; }
for s in desfecho revisa-loop stack-pr; do
  [ -f "$AQUI/$s.sh" ] || { echo "loop-e-stack: falta $AQUI/$s.sh (instalar.sh 6.3)." >&2; exit 2; }
done
command -v gh >/dev/null || { echo "loop-e-stack: sem o gh (GitHub CLI), a stack não abre. Instale e logue antes: gh auth login." >&2; exit 2; }
gh auth status >/dev/null 2>&1 || { echo "loop-e-stack: o gh não está logado. Rode gh auth login antes de soltar o loop." >&2; exit 2; }
git remote get-url origin >/dev/null 2>&1 || { echo "loop-e-stack: sem remote origin; a stack precisa do GitHub." >&2; exit 2; }

# --- o loop ------------------------------------------------------------------------------
inicio=$(date +%s)
env -u LOOP_PR bash "$LOOP" "$phases"; rc=$?

# --- o run deste loop: a cópia em .loop-logs/ com META started depois do início ------------
run=""
for d in .loop-logs/*/; do
  [ -f "$d/run.tsv" ] || continue
  s=$(awk -F'\t' '$1=="META" && $2=="started" {print $3}' "$d/run.tsv")
  [[ "$s" =~ ^[0-9]+$ ]] && [ "$s" -ge "$inicio" ] && run="${d%/}"
done
if [ -z "$run" ]; then
  echo "" >&2
  echo "loop-e-stack: o loop não chegou a rodar (loop.sh saiu com $rc, sem run novo em .loop-logs/). Nenhum PR aberto." >&2
  exit 1
fi

# --- entregou? ------------------------------------------------------------------------------
d=0
saida=$(bash "$AQUI/desfecho.sh" "$run/" 2>&1) || d=$?
if [ "$d" -ne 0 ]; then
  echo ""
  echo "$saida"
  echo ""
  echo "loop-e-stack: não entregou (desfecho acima). Nenhum PR aberto: o que não passou nos gates não vira PR."
  echo "Leia onde parou e a camada provável (aula 6.2). O log do run, num arquivo só: .claude/scripts/pacote-prova.sh $run"
  exit "$d"
fi
echo ""
sed -n 's/^DESFECHO: /loop-e-stack: /p' <<< "$saida" | head -n 1

# --- revisão gravada e a stack ------------------------------------------------------------------
bash "$AQUI/revisa-loop.sh" --run "$run" > "$run/revisao.txt" 2>&1 || true
alertas=$(sed -n 's/^\([0-9][0-9]*\) alerta(s).*/\1/p' "$run/revisao.txt" | head -n 1)
echo "revisa-loop.sh: ${alertas:-0} alerta(s), em $run/revisao.txt. Decida cada um antes do Ready for review."
echo ""
bash "$AQUI/stack-pr.sh" --criar "$@" || { echo "loop-e-stack: o stack-pr.sh falhou. O trabalho está commitado; rode .claude/scripts/stack-pr.sh para ver o plano." >&2; exit 1; }
echo ""
echo "Próximo: revise de baixo para cima (revisao.txt, suíte inteira, fumaça real); depois Ready for review e Merge stack."
exit 0
