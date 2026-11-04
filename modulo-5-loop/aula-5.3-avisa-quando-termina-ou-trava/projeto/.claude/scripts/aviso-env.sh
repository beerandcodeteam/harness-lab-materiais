#!/usr/bin/env bash
# aviso-env.sh · Harness Lab · aula 5.3 · o aviso do loop com os segredos num arquivo
#
# Uso: .claude/scripts/aviso-env.sh "loop blog: terminou 3/3"
#      export AVISO_CMD=.claude/scripts/aviso-env.sh   (o loop.sh e o vigia.sh passam a usar)
#
# Lê o .env ao lado deste arquivo, o mesmo que o ralph.sh da aula lê. Pode ser um link
# para ~/.config/harness-lab/aviso.env, fora do repositório. Lê sem executar nada e sem
# exportar para o terminal: o token não chega às sessões do loop. Variável que já está
# no ambiente ganha do arquivo.
#
# Canal: o primeiro configurado, nesta ordem.
#   1. WhatsApp pela Evolution API: EVOLUTION_API_URL, AUTHENTICATION_API_KEY e
#      EVOLUTION_INSTANCE. EVOLUTION_NUMBER é opcional: sem ele, vai para o número
#      da própria instância (a mesma busca do ralph.sh da aula).
#   2. O aviso.sh ao lado, com TELEGRAM_TOKEN e TELEGRAM_CHAT_ID, SLACK_WEBHOOK_URL
#      (Slack, ou Discord com /slack no fim da URL) ou AVISO_WEBHOOK, passados só
#      para ele. Sem nenhum: notificação local.
#
# AVISO_DRY=1 mostra o curl sem mandar, com o nome das variáveis no lugar dos segredos.
# Nunca falha: aviso que falha não derruba o loop.
set -u
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

msg="${*:-}"
[ -n "$msg" ] || [ -t 0 ] || msg="$(cat 2>/dev/null || true)"
[ -n "$msg" ] || { echo "uso: aviso-env.sh \"mensagem\"" >&2; exit 0; }

# KEY=valor, uma por linha. Tolera CRLF, aspas e "export". Só as chaves do aviso.
chaves=" EVOLUTION_API_URL AUTHENTICATION_API_KEY EVOLUTION_INSTANCE EVOLUTION_NUMBER"
chaves+=" TELEGRAM_TOKEN TELEGRAM_CHAT_ID SLACK_WEBHOOK_URL AVISO_WEBHOOK "
if [ -f "$dir/.env" ]; then
  while IFS= read -r linha || [ -n "$linha" ]; do
    linha="${linha%$'\r'}"
    [[ "$linha" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Z_]+)=(.*)$ ]] || continue
    k="${BASH_REMATCH[2]}"; v="${BASH_REMATCH[3]}"
    [[ "$chaves" == *" $k "* ]] || continue
    v="${v#\"}"; v="${v%\"}"; v="${v#\'}"; v="${v%\'}"
    [ -n "${!k:-}" ] || printf -v "$k" '%s' "$v"
  done < "$dir/.env"
fi

url="${EVOLUTION_API_URL:-}"; url="${url%/}"
chave="${AUTHENTICATION_API_KEY:-}"; inst="${EVOLUTION_INSTANCE:-}"; num="${EVOLUTION_NUMBER:-}"

if [ -z "$url" ] || [ -z "$chave" ] || [ -z "$inst" ]; then
  # Sem Evolution: o aviso.sh decide o canal. Os segredos vão só para o ambiente dele.
  TELEGRAM_TOKEN="${TELEGRAM_TOKEN:-}" TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}" \
  SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}" AVISO_WEBHOOK="${AVISO_WEBHOOK:-}" \
    bash "$dir/aviso.sh" "$msg"
  exit 0
fi

json() {  # texto -> string JSON, sem depender de jq (o mesmo escape do aviso.sh)
  local s="$1"
  s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"; s="${s//$'\r'/}"; s="${s//$'\t'/\\t}"
  printf '"%s"' "$s"
}

if [ "${AVISO_DRY:-0}" = 1 ]; then
  destino='$EVOLUTION_NUMBER'; [ -n "$num" ] || destino='(número da instância)'
  echo "curl -sS -m 15 -X POST \"\$EVOLUTION_API_URL/message/sendText/\$EVOLUTION_INSTANCE\" -H \"apikey: \$AUTHENTICATION_API_KEY\" -H 'Content-Type: application/json' --data '{\"number\":\"$destino\",\"text\":$(json "$msg")}'"
  exit 0
fi

if [ -z "$num" ]; then
  num="$(curl -sS -m 10 -H "apikey: $chave" "$url/instance/fetchInstances?instanceName=$inst" 2>/dev/null \
    | grep -oE '"ownerJid"[[:space:]]*:[[:space:]]*"[0-9]+' | grep -oE '[0-9]+$' | head -1)"
fi
if [ -z "$num" ]; then
  echo "aviso-env.sh: não achei o número da instância '$inst'. Defina EVOLUTION_NUMBER. Mensagem: $msg" >&2
  exit 0
fi

codigo="$(curl -sS -m 15 -o /dev/null -w '%{http_code}' -X POST "$url/message/sendText/$inst" \
  -H "apikey: $chave" -H 'Content-Type: application/json' \
  --data "{\"number\":$(json "$num"),\"text\":$(json "$msg")}" 2>/dev/null)"
case "$codigo" in
  2*) ;;
  *) echo "aviso-env.sh: a Evolution respondeu HTTP ${codigo:-000} (o loop segue). Mensagem: $msg" >&2 ;;
esac
exit 0
