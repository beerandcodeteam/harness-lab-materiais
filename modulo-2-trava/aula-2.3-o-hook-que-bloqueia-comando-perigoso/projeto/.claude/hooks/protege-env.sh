#!/usr/bin/env bash
# protege-env.sh · Harness Lab · aula 2.3 · PreToolUse (matcher: Read|Edit|Write)
# Nenhuma ferramenta de arquivo toca o .env. O .env.example continua liberado.
set -uo pipefail
entrada=$(cat)
command -v jq >/dev/null 2>&1 || { echo "protege-env: jq não instalado, bloqueando por segurança" >&2; exit 2; }
arquivo=$(jq -r '.tool_input.file_path // empty' <<<"$entrada")
nome=$(basename "${arquivo:-x}")
case "$nome" in
  .env.example) exit 0 ;;
  .env|.env.*)
    jq -n --arg r "Bloqueado: $nome tem segredo e não é lido nem editado pelo agente. Use .env.example." \
      '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
    ;;
esac
exit 0
