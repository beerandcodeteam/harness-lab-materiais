#!/usr/bin/env bash
# avisa.sh · Trava como "feature a mais" · aula 1.4
# Notification: o Claude Code parou e está esperando você (pedido de permissão ou
# 60 s parado depois de responder). Avisa fora do terminal. Não bloqueia nada.
#
# Celular ou WhatsApp: ponha em AVISO_WEBHOOK a URL de um webhook seu (n8n, Make,
# um tópico do ntfy, um bot do Telegram). O texto vai no campo "texto" do JSON.
entrada=$(cat)
msg=$(printf '%s' "$entrada" | jq -r '.message // "Claude Code está esperando você"' 2>/dev/null)
[ -n "$msg" ] || msg="Claude Code está esperando você"
proj=$(basename "${CLAUDE_PROJECT_DIR:-$PWD}")

if command -v notify-send >/dev/null 2>&1; then                  # Linux
  notify-send "Claude Code · $proj" "$msg" 2>/dev/null
elif command -v osascript >/dev/null 2>&1; then                  # macOS
  osascript -e 'on run argv' -e 'display notification (item 2 of argv) with title (item 1 of argv)' \
    -e 'end run' "Claude Code · $proj" "$msg" 2>/dev/null
fi

if [ -n "${AVISO_WEBHOOK:-}" ]; then
  jq -nc --arg t "[$proj] $msg" '{texto: $t}' |
    curl -s -m 5 -X POST -H 'Content-Type: application/json' --data-binary @- "$AVISO_WEBHOOK" >/dev/null 2>&1
fi
exit 0
