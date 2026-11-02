#!/usr/bin/env bash
# QUEBRADO DE PROPÓSITO · aula 2.4 · "bloqueia demais"
# O padrão procura a palavra em qualquer lugar do comando, inclusive dentro de texto.
# Resultado: barra 'php artisan migrate:status', barra 'cat .env.example',
# e barra até um grep que só PROCURA a palavra num arquivo de documentação.
# Hook que barra coisa inofensiva ensina o time a desligar o hook.
entrada=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$entrada")
if grep -qE 'migrate|\.env|--force|rm ' <<<"$cmd"; then
  echo "Bloqueado: comando perigoso." >&2
  exit 2
fi
exit 0
