#!/usr/bin/env bash
# bloqueia.sh · Trava · esboço da aula 1.4 (a versão completa é a da aula 2.3)
# PreToolUse com matcher Bash: o Claude Code manda o pedido em JSON no stdin.
#   exit 0 → executa
#   exit 2 → não executa, e o stderr volta para o modelo como motivo
command -v jq >/dev/null 2>&1 || { echo "bloqueia.sh: instale o jq" >&2; exit 2; }
cmd=$(jq -r '.tool_input.command // empty')

if printf '%s' "$cmd" | grep -qiE 'migrate:fresh|rm +-[a-z]*r[a-z]*f|rm +-[a-z]*f[a-z]*r|push +(.* )?(--force|-f)( |$)'; then
  echo "Bloqueado pelo hook: $cmd. Use migrate sem fresh, apague só o arquivo certo, push sem force." >&2
  exit 2
fi
exit 0
