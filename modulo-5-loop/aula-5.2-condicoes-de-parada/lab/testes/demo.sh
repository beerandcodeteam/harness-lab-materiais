#!/usr/bin/env bash
# demo.sh · aulas 5.2 e 5.3 · o loop.sh rodando na sua frente, sem gastar token
#
# Cria um repositório de exemplo numa pasta temporária (2 fases, a Prova é um
# test.sh, a Trava da 4.2 registrada, os scripts do Módulo 5 em .claude/scripts/)
# e roda o loop.sh com o motor falso no lugar do claude e o ralph do bc-harness.
#
# Exemplos (da pasta exemplos/):
#   MOTOR_CENARIO=pendura LOOP_TIMEOUT=20s MAX_CICLOS=2 bash testes/demo.sh    # 5.2: o shim estoura
#   MOTOR_CENARIO=pendura LOOP_TIMEOUT=5m bash testes/demo.sh                  # 5.2: Ctrl-C para tudo
#   MOTOR_CENARIO=incompleta bash testes/demo.sh                               # 5.3: aviso de falha
#   MOTOR_CENARIO=pendura LOOP_TIMEOUT=5m LOOP_QUIETO=1m bash testes/demo.sh   # 5.3: "travou?"
#   bash testes/demo.sh --checa                                                # só o pré-voo
#
# Cenários: ok (padrão), falha-uma-vez, nunca-passa, incompleta, pendura, sem-resultado.
# O aviso vai para o canal que estiver no seu ambiente (TELEGRAM_*, SLACK_WEBHOOK_URL,
# AVISO_WEBHOOK) ou para a notificação local; AVISO_DRY=1 só mostra o curl.
# LOOP_PAINEL=1 liga o painel do ralph. DEMO_DIR muda onde o repositório nasce.
set -uo pipefail
[ -z "${DEMO_DIR:-}" ] || export M5_TESTE_DIR="$DEMO_DIR"
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

repo="$BASE/repo-exemplo"
novo_repo "$repo"
echo "repositório de exemplo: $repo"
echo "cenário do motor falso: ${MOTOR_CENARIO:-ok}"
echo

args=("$@")
case "${#args[@]}:${args[0]:-}" in
  0:|1:--checa) args+=(.spec/features/exemplo/PHASES.md) ;;
esac

cd "$repo" || exit 1
rc=0
env -u RALPH_TEST_CMD -u CLAUDECODE PATH="$BIN:$PATH" RALPH_SH="$RALPH_DO_CACHE" LOOP_TEST_CMD=./test.sh \
    LOOP_PAINEL="${LOOP_PAINEL:-0}" LOOP_VIGIA_S="${LOOP_VIGIA_S:-10}" MOTOR_CENARIO="${MOTOR_CENARIO:-ok}" \
    bash .claude/scripts/loop.sh "${args[@]}" || rc=$?

echo
echo "exit: $rc"
echo "repositório: $repo"
ls -d "$repo"/.loop-logs/run-* 2>/dev/null | sed 's/^/log: /'
echo "prompts que o motor recebeu: $repo/.git/motor-falso/"
exit "$rc"
