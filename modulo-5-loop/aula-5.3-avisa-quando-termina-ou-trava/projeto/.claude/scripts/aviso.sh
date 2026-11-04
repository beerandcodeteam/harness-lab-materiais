#!/usr/bin/env bash
# aviso.sh · aula 5.3 · manda uma mensagem para fora do terminal
#
# Uso: .claude/scripts/aviso.sh "loop blog: terminou 3/3"
#
# Canal: o primeiro que estiver configurado, nesta ordem.
#   1. Telegram   TELEGRAM_TOKEN e TELEGRAM_CHAT_ID (bot do @BotFather; mande /start
#                 ao bot antes: "Bots can't start conversations with users")
#   2. Slack      SLACK_WEBHOOK_URL (a URL é segredo)
#   3. Webhook    AVISO_WEBHOOK: POST JSON {"texto": ..., "text": ...}. O mesmo campo
#                 do avisa.sh da 2.1. Serve para n8n, Evolution ou o que você tiver.
#   4. Local      notify-send (Linux) ou osascript (macOS), e a mensagem no stderr.
#
# Guarde token e URL fora do repositório (ex.: ~/.config/harness-lab/aviso.env,
# carregado pelo seu shell). AVISO_DRY=1 mostra o curl sem mandar, com o nome
# das variáveis no lugar dos segredos. Nunca falha: aviso que falha não derruba o loop.
set -u

msg="${*:-}"
[ -n "$msg" ] || [ -t 0 ] || msg="$(cat 2>/dev/null || true)"
[ -n "$msg" ] || { echo "uso: aviso.sh \"mensagem\"" >&2; exit 0; }
msg="${msg:0:4000}"    # Telegram aceita até 4096 caracteres

json() {  # texto -> string JSON, sem depender de jq
  local s="$1"
  s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"; s="${s//$'\r'/}"; s="${s//$'\t'/\\t}"
  printf '"%s"' "$s"
}

dry="${AVISO_DRY:-0}"

if [ -n "${TELEGRAM_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
  api="${TELEGRAM_API:-https://api.telegram.org}"
  if [ "$dry" = 1 ]; then
    echo "curl -sS -m 10 -X POST \"$api/bot\$TELEGRAM_TOKEN/sendMessage\" --data-urlencode chat_id=\"\$TELEGRAM_CHAT_ID\" --data-urlencode text=$(json "$msg")"
  else
    curl -sS -m 10 -o /dev/null -X POST "$api/bot$TELEGRAM_TOKEN/sendMessage" \
      --data-urlencode "chat_id=$TELEGRAM_CHAT_ID" --data-urlencode "text=$msg" \
      || echo "aviso.sh: o Telegram não respondeu (o loop segue)" >&2
  fi
elif [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
  corpo="{\"text\":$(json "$msg")}"
  if [ "$dry" = 1 ]; then
    echo "curl -sS -m 10 -X POST -H 'Content-Type: application/json' --data '$corpo' \"\$SLACK_WEBHOOK_URL\""
  else
    curl -sS -m 10 -o /dev/null -X POST -H 'Content-Type: application/json' --data "$corpo" "$SLACK_WEBHOOK_URL" \
      || echo "aviso.sh: o Slack não respondeu (o loop segue)" >&2
  fi
elif [ -n "${AVISO_WEBHOOK:-}" ]; then
  corpo="{\"texto\":$(json "$msg"),\"text\":$(json "$msg")}"
  if [ "$dry" = 1 ]; then
    echo "curl -sS -m 10 -X POST -H 'Content-Type: application/json' --data '$corpo' \"\$AVISO_WEBHOOK\""
  else
    curl -sS -m 10 -o /dev/null -X POST -H 'Content-Type: application/json' --data "$corpo" "$AVISO_WEBHOOK" \
      || echo "aviso.sh: o webhook não respondeu (o loop segue)" >&2
  fi
else
  if [ "$dry" = 1 ]; then
    echo "local: $msg"
  elif command -v notify-send >/dev/null 2>&1; then
    notify-send "Harness Lab" "$msg" 2>/dev/null || true
  elif command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification $(json "$msg") with title \"Harness Lab\"" 2>/dev/null || true
  fi
  [ "$dry" = 1 ] || echo "aviso: $msg" >&2
fi
exit 0
