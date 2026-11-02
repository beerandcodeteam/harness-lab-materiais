#!/usr/bin/env bash
# libera-pergunta-bloqueia.sh · aula 2.1 · PreToolUse (matcher: Bash)
# Esqueleto de leitura, NÃO é instalado. Mostra as três respostas de um PreToolUse:
#   libera   → exit 0 sem imprimir nada: o fluxo normal de permissão segue
#   pergunta → JSON com "ask": o Claude Code pede a sua confirmação
#   bloqueia → JSON com "deny": não roda, e o motivo vai para o modelo
# A versão completa (banco, produção, push --force, .env) é montada na aula 2.3.
#
# Teste sem abrir o Claude Code:
#   jq -nc '{tool_input:{command:"rm -rf build"}}' | bash libera-pergunta-bloqueia.sh
set -uo pipefail
entrada=$(cat)
# Sem jq não dá para ler o comando: exit 2 bloqueia, porque exit 1 deixaria passar.
command -v jq >/dev/null 2>&1 || { echo "hook sem jq: instale o jq" >&2; exit 2; }
cmd=$(jq -r '.tool_input.command // empty' <<<"$entrada")

responde() {   # responde ask|deny MOTIVO
  jq -nc --arg d "$1" --arg r "$2" '{hookSpecificOutput: {hookEventName: "PreToolUse",
    permissionDecision: $d, permissionDecisionReason: $r}}'
  exit 0
}

case "$cmd" in
  *migrate:fresh*|*"prisma migrate reset"*|*"db:reset"*)
    responde deny "Apaga o banco inteiro. Use a migration normal (migrate, sem fresh)." ;;
  *"rm -rf"*)
    responde ask "rm -rf: confira o caminho antes de aprovar." ;;
esac
exit 0   # libera: nada bateu, quem decide é a permissão normal (não é "allow")
