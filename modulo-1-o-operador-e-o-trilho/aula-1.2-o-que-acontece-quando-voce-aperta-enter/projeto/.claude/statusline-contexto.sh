#!/usr/bin/env bash
# statusline-contexto.sh · Harness Lab · aula 1.2
#
# Barra de status do Claude Code com o que a aula mandou vigiar:
#   - quanto da janela de contexto a última chamada usou (o mesmo número do /context);
#   - se o cache de prompt está quente e quando esfria.
#
# Cores: verde até o limite (30% por padrão, a regra da aula), amarelo até o dobro,
# vermelho acima. Mude o limite com HL_CONTEXTO_LIMITE=40 na frente do "command" no
# settings.json. NO_COLOR=1 tira as cores.
#
# O Claude Code manda um JSON no stdin a cada resposta (veja
# https://code.claude.com/docs/en/statusline): context_window.used_percentage,
# context_window.context_window_size e prompt_cache.{warm,ttl,expires_at}.
# Antes da primeira resposta da sessão o percentual vem null: aí só o /context mostra.
# Testar fora do Claude Code:
#   echo '{"context_window":{"used_percentage":35}}' | .claude/statusline-contexto.sh

LIMITE="${HL_CONTEXTO_LIMITE:-30}"
case "$LIMITE" in '' | *[!0-9]*) LIMITE=30 ;; esac

entrada="$(cat)"

if ! command -v jq >/dev/null 2>&1; then
  echo "contexto: instale o jq para ver o uso da janela (ou rode /context)"
  exit 0
fi

# Uma linha, campos separados por tab. Campo ausente vira "-".
IFS=$'\t' read -r modelo pct tamanho usados quente ttl expira observado <<EOF
$(printf '%s' "$entrada" | jq -r '[
    (.model.display_name // "-"),
    (.context_window.used_percentage // "-" | if type == "number" then floor else . end),
    (.context_window.context_window_size // "-"),
    (.context_window.total_input_tokens // "-"),
    (if .prompt_cache == null then "-" else (.prompt_cache.warm | tostring) end),
    (.prompt_cache.ttl // "-"),
    (.prompt_cache.expires_at // "-"),
    (.prompt_cache.caching_observed // "-" | tostring)
  ] | map(tostring) | join("\t")' 2>/dev/null)
EOF

if [ -z "${modelo:-}" ]; then
  echo "contexto: JSON inesperado na status line (rode /context)"
  exit 0
fi

if [ -n "${NO_COLOR:-}" ]; then
  verde=""; amarelo=""; vermelho=""; cinza=""; fim=""
else
  verde=$'\033[32m'; amarelo=$'\033[33m'; vermelho=$'\033[31m'; cinza=$'\033[90m'; fim=$'\033[0m'
fi

# 1000000 -> 1M, 200000 -> 200k
curto() {
  case "$1" in
    '' | *[!0-9]*) printf '%s' "$1" ;;
    *) if [ "$1" -ge 1000000 ] && [ $(($1 % 1000000)) -eq 0 ]; then printf '%sM' $(($1 / 1000000))
       elif [ "$1" -ge 1000 ]; then printf '%sk' $(($1 / 1000))
       else printf '%s' "$1"; fi ;;
  esac
}

case "$pct" in '' | *[!0-9]*) pct="-" ;; esac

partes=""
[ "$modelo" = "-" ] || partes="$modelo · "

if [ "$pct" = "-" ]; then
  partes="${partes}contexto: aparece depois da 1ª resposta (antes, rode /context)"
else
  janela=""
  case "$tamanho" in
    '' | - | *[!0-9]*) ;;
    *) janela=" de $(curto "$tamanho")"
       case "$usados" in
         '' | - | 0 | *[!0-9]*) usados=$((tamanho * pct / 100)) ;;
       esac
       janela=" ($(curto "$usados")$janela)" ;;
  esac
  if [ "$pct" -ge $((LIMITE * 2)) ]; then
    cor="$vermelho"; dica=" · bem acima de ${LIMITE}%: /clear e recomece com o pedido completo"
  elif [ "$pct" -ge "$LIMITE" ]; then
    cor="$amarelo"; dica=" · passou de ${LIMITE}%: feche a tarefa e use /clear"
  else
    cor="$verde"; dica=""
  fi
  partes="${partes}${cor}contexto ${pct}%${janela}${fim}${dica}"
fi

# Cache de prompt (Claude Code 2.1.251 ou mais novo; o objeto só aparece depois da 1ª resposta)
if [ "$quente" = "true" ]; then
  resto=""
  case "$expira" in
    '' | - | *[!0-9]*) ;;
    *) agora=$(date +%s)
       if [ "$expira" -gt "$agora" ]; then
         min=$(((expira - agora + 59) / 60))
         resto=", esfria em ${min} min"
       fi ;;
  esac
  ttl_txt=""
  [ "$ttl" = "-" ] || ttl_txt=" ($ttl)"
  partes="${partes} ${cinza}· cache quente${ttl_txt}${resto}${fim}"
elif [ "$quente" = "false" ] && [ "$observado" = "true" ]; then
  partes="${partes} ${cinza}· cache frio: a próxima chamada relê tudo${fim}"
fi

printf '%s\n' "$partes"
