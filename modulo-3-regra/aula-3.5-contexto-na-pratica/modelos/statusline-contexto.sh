#!/usr/bin/env bash
# Harness Lab · aula 3.5 · statusline-contexto.sh
#
# Status line do Claude Code com o quanto da janela de contexto está em uso,
# na régua da aula: até 30% tudo bem, de 30% a 45% hora do /compact com foco,
# acima de 45% não espere mais.
#
#   Opus 5.5 · ctx 12% de 1M (120k) · ok
#   Opus 5.5 · ctx 34% de 1M (340k) · /compact com foco
#   Opus 5.5 · ctx 51% de 1M (510k) · /compact ou /clear agora
#
# O Claude Code manda um JSON no stdin; o script lê context_window.used_percentage
# (já calculado, só tokens de entrada) e context_window.context_window_size.
# Instale com modelos/ligar-statusline.sh, ou aponte o "statusLine" do seu
# ~/.claude/settings.json para este arquivo.
#
# Ajustes (variáveis de ambiente):
#   CTX_AVISO=30     a partir daqui fica amarelo
#   CTX_LIMITE=45    a partir daqui fica vermelho
#   NO_COLOR=1       sem cor
# Precisa de jq. Nunca falha: problema vira um texto curto na barra.

CTX_AVISO="${CTX_AVISO:-30}"
CTX_LIMITE="${CTX_LIMITE:-45}"

command -v jq >/dev/null 2>&1 || { echo "statusline: instale o jq"; exit 0; }
entrada="$(cat)"

# Separador "|" e não tab: o read junta tabs seguidos e embaralharia um campo vazio.
linha="$(printf '%s' "$entrada" | jq -r '[
    (.model.display_name // .model.id // "Claude"),
    ((.context_window.used_percentage // "") | tostring),
    ((.context_window.context_window_size // 0) | tostring)
  ] | join("|")' 2>/dev/null)"
[ -n "$linha" ] || { echo "statusline: JSON inesperado"; exit 0; }
IFS='|' read -r modelo pct janela <<<"$linha"

curto() {   # 1000000 -> 1M, 200000 -> 200k, 12345 -> 12k
    local n="${1%%.*}"
    case "$n" in '' | *[!0-9]*) n=0 ;; esac
    if [ "$n" -ge 1000000 ] && [ $((n % 1000000)) -eq 0 ]; then echo "$((n / 1000000))M"
    elif [ "$n" -ge 1000 ]; then echo "$((n / 1000))k"
    else echo "$n"; fi
}

# A saída é capturada pelo Claude Code (não é um terminal): cor ligada, salvo NO_COLOR.
verde=$'\033[32m'; amarelo=$'\033[33m'; vermelho=$'\033[31m'; fim=$'\033[0m'
[ -z "${NO_COLOR:-}" ] || { verde=""; amarelo=""; vermelho=""; fim=""; }

j="${janela%%.*}"
case "$j" in '' | *[!0-9]*) j=0 ;; esac
tam=""
[ "$j" -gt 0 ] && tam=" de $(curto "$j")"

p="${pct%%.*}"
case "$p" in
    '' | *[!0-9]*)
        # Começo da sessão ou logo depois do /compact: ainda não houve resposta para medir.
        echo "$modelo · ctx --${tam}"
        exit 0 ;;
esac

usados=""
[ "$j" -gt 0 ] && usados=" ($(curto $((j * p / 100))))"

if [ "$p" -ge "$CTX_LIMITE" ]; then
    cor="$vermelho"; dica="/compact ou /clear agora"
elif [ "$p" -ge "$CTX_AVISO" ]; then
    cor="$amarelo"; dica="/compact com foco"
else
    cor="$verde"; dica="ok"
fi
echo "$modelo · ${cor}ctx ${p}%${fim}${tam}${usados} · ${dica}"
