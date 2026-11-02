#!/usr/bin/env bash
# mensagens.sh · plugin correcoes · Harness Lab, aula 1.3
#
# Lista o que VOCÊ digitou nas últimas sessões do Claude Code neste projeto e
# marca com * as mensagens com cara de correção ("não", "volta", "de novo"...).
# Só lê. Não altera nada.
#
#   mensagens.sh            últimas 5 sessões, só as mensagens marcadas e a anterior a cada uma
#   mensagens.sh 10         últimas 10 sessões
#   mensagens.sh --todas    todas as mensagens das sessões, marcadas ou não
#
# De onde lê: ~/.claude/history.jsonl (ou $CLAUDE_CONFIG_DIR/history.jsonl), o arquivo
# do "seta para cima" do Claude Code: cada linha tem o texto digitado, a hora, a pasta
# do projeto e a sessão. O formato é interno do Claude Code e pode mudar entre versões.
# Projeto: $CLAUDE_PROJECT_DIR (dentro do Claude Code) ou a pasta atual.
set -euo pipefail

sessoes=5
todas=0
for a in "$@"; do
  case "$a" in
    --todas) todas=1 ;;
    -h | --help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    '' ) ;;
    *[!0-9]* | 0) echo "uso: $(basename "$0") [número de sessões] [--todas]" >&2; exit 2 ;;
    *) sessoes="$a" ;;
  esac
done

command -v jq >/dev/null 2>&1 || {
  echo "mensagens.sh: precisa do jq (sudo apt install jq · brew install jq)" >&2
  exit 1
}

proj="${CLAUDE_PROJECT_DIR:-$PWD}"
proj="${proj%/}"
hist="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/history.jsonl"

if [ ! -s "$hist" ]; then
  echo "Nenhum histórico em $hist."
  echo "Ainda não há sessão do Claude Code nesta máquina, ou o histórico foi apagado."
  exit 0
fi

# Frases com cara de correção, em português e inglês. É só um filtro: confira cada uma.
padrao='(^|[^[:alpha:]])(n[aã]o|errad[oa]s?|errou|de novo|volta|desfaz|desfa[cç]a|revert[ea]?|reverter|pare|para com|para tudo|pera|espera|eu (te )?(disse|falei|pedi)|j[aá] (te )?(disse|falei|pedi)|por que (voc[eê]|vc)|pq|esqueceu|ignorou|sem (me )?(pedir|perguntar)|wrong|undo|stop|don.t)([^[:alpha:]]|$)'

jq -R -r -n \
  --arg p "$proj" --argjson n "$sessoes" --argjson todas "$todas" --arg re "$padrao" '
  def texto: (.display // "") | gsub("[\\r\\n\\t]+"; " ") | gsub("  +"; " ");
  def hora: ((.timestamp // 0) / 1000 | floor | strflocaltime("%Y-%m-%d %H:%M"));
  [ inputs
    | fromjson?
    | select(type == "object")
    | select((.project // "") as $x | $x == $p or ($x | startswith($p + "/")))
    | select(texto | length > 0)
    | select(texto | startswith("/") | not)            # comandos como /clear e /context
  ]
  | group_by(.sessionId // "sem-sessao")
  | map(sort_by(.timestamp // 0))
  | sort_by(.[-1].timestamp // 0)
  | .[-$n:]
  | if length == 0 then
      "Nenhuma mensagem deste projeto (\($p)) no histórico.\nAbriu o Claude Code em outra pasta? Rode na raiz do projeto em que você trabalhou."
    else
      (map(length) | add) as $total
      | ([.[][] | select(texto | test($re; "i"))] | length) as $marc
      | "# \(length) sessão(ões) deste projeto · \($total) mensagens suas · \($marc) com cara de correção (*)\n",
        ( .[]
          | . as $s
          | ([.[] | select(texto | test($re; "i"))] | length) as $ms
          | "## sessão \((.[0].sessionId // "sem-id")[0:8]) · \(.[0] | hora) a \(.[-1] | hora[11:]) · \(length) mensagens",
            (select($todas == 0 and $ms == 0) | "  (nenhuma com cara de correção; veja tudo com --todas)"),
            ( range(0; length) as $i
              | ($s[$i] | texto | test($re; "i")) as $m
              | (($i + 1 < length) and ($s[$i + 1] | texto | test($re; "i"))) as $antes
              | select($todas == 1 or $m or $antes)
              | "\(if $m then "*" else " " end) \($s[$i] | hora[11:])  \($s[$i] | texto | if length > 240 then .[0:240] + "…" else . end)"
            ),
            ""
        )
    end
' "$hist"
