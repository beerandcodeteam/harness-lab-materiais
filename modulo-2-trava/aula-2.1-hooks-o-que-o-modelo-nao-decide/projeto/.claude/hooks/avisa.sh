#!/usr/bin/env bash
# avisa.sh · aula 2.1 · Notification (matcher: permission_prompt|idle_prompt)
# Ele parou esperando você: avisa fora do terminal. Notification não bloqueia nada.
#
# Hook não tem terminal: printf '\a' > /dev/tty falha em silêncio. Para o bipe e a
# notificação do terminal, o hook devolve "terminalSequence" e o Claude Code emite por ele.
# Só funciona em sessão interativa (no claude -p o campo é ignorado).
entrada=$(cat)
command -v jq >/dev/null 2>&1 || exit 0
msg=$(jq -r '.message // "Claude Code está esperando você"' <<<"$entrada" 2>/dev/null)
msg=$(printf '%s' "${msg:-Claude Code está esperando você}" | tr -d '\000-\037')

# Notificação do sistema, quando existe (Linux com notify-send, macOS com osascript).
# No WSL, quem mostra o aviso é o Windows Terminal, pela sequência OSC 9 lá embaixo.
if command -v notify-send >/dev/null 2>&1; then
  notify-send "Claude Code" "$msg" >/dev/null 2>&1 || true
elif command -v osascript >/dev/null 2>&1; then
  osascript -e 'on run argv' -e 'display notification (item 1 of argv) with title "Claude Code"' \
            -e 'end run' "$msg" >/dev/null 2>&1 || true
fi

# Módulo 5: o mesmo aviso vai para WhatsApp, Slack ou Telegram via webhook.
if [ -n "${AVISO_WEBHOOK:-}" ]; then
  curl -s -m 5 -X POST -H 'Content-Type: application/json' \
       -d "$(jq -nc --arg t "$msg" '{texto: $t}')" "$AVISO_WEBHOOK" >/dev/null 2>&1 || true
fi

# Bipe (BEL) + notificação do terminal (OSC 9: Windows Terminal, iTerm2, WezTerm).
# Ghostty, Warp e urxvt usam OSC 777: troque por printf '\a\033]777;notify;Claude Code;%s\007'.
seq=$(printf '\a\033]9;%s\007' "$msg")
jq -nc --arg s "$seq" '{terminalSequence: $s}'
exit 0
