#!/usr/bin/env bash
# bash-so-permitido.sh · Harness Lab · aula 3.4
# Hook PreToolUse para o frontmatter de um subagente: deixa o Bash rodar só os
# comandos que você listar. Usado pelas variantes em modelos/ (revisor com git,
# test-runner travado). Não faz nada sozinho: só roda se um subagente apontar para ele.
#
#   command: '"$CLAUDE_PROJECT_DIR"/.claude/hooks/bash-so-permitido.sh "git diff" "git log"'
#
# Regras:
#   - o comando começa com um dos prefixos passados (palavra inteira);
#   - pipe só para grep, head, tail ou wc;
#   - ; & > < ` $( e quebra de linha bloqueiam (2>&1 pode);
#   - --output bloqueia (git diff --output=arquivo escreve arquivo).
# exit 0 = deixa passar · exit 2 = bloqueia, e o stderr volta para o subagente.
# Sem jq e sem python3, bloqueia tudo: é trava, então falha fechada.
set -u

entrada=$(cat)
if command -v jq >/dev/null 2>&1; then
  cmd=$(printf '%s' "$entrada" | jq -r '.tool_input.command // empty' 2>/dev/null) ||
    { echo "bash-so-permitido: pedido do hook ilegível; Bash bloqueado." >&2; exit 2; }
elif command -v python3 >/dev/null 2>&1; then
  cmd=$(printf '%s' "$entrada" | python3 -I -c '
import json, sys
try:
    print(json.load(sys.stdin).get("tool_input", {}).get("command", ""))
except Exception:
    sys.exit(1)' 2>/dev/null) ||
    { echo "bash-so-permitido: pedido do hook ilegível; Bash bloqueado." >&2; exit 2; }
else
  echo "bash-so-permitido: sem jq nem python3 para ler o pedido; Bash bloqueado." >&2
  exit 2
fi

[ -n "$cmd" ] || exit 0

apara() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }

nega() {
  printf 'Bloqueado pelo hook do subagente: %s\nComandos permitidos:' "$1" >&2
  for p in "${permitidos[@]}"; do printf ' "%s"' "$p" >&2; done
  printf ' (pipe só para grep, head, tail, wc).\n' >&2
  exit 2
}

permitidos=("$@")
[ ${#permitidos[@]} -gt 0 ] || { echo "bash-so-permitido: nenhum comando permitido na configuração do hook." >&2; exit 2; }

case "$cmd" in
  *$'\n'*) nega "quebra de linha no comando" ;;
esac
limpo=${cmd//2>&1/}
case "$limpo" in
  *';'* | *'&'* | *'>'* | *'<'* | *'`'* | *'$('*) nega "encadeamento ou redirecionamento ($cmd)" ;;
  *'||'*) nega "encadeamento ($cmd)" ;;
  *--output*) nega "--output escreve arquivo ($cmd)" ;;
esac
case "$(apara "$limpo")" in
  *'|') nega "pipe sem comando depois ($cmd)" ;;
esac

IFS='|' read -r -a partes <<<"$limpo"
primeiro=$(apara "${partes[0]}")
ok=0
for p in "${permitidos[@]}"; do
  if [ "$primeiro" = "$p" ] || [ "${primeiro#"$p "}" != "$primeiro" ]; then ok=1; break; fi
done
[ "$ok" = 1 ] || nega "$primeiro"

for ((i = 1; i < ${#partes[@]}; i++)); do
  seg=$(apara "${partes[$i]}")
  case "${seg%% *}" in
    grep | head | tail | wc) ;;
    *) nega "pipe para '${seg%% *}'" ;;
  esac
done
exit 0
