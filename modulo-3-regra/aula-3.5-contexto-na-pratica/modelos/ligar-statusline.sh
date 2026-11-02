#!/usr/bin/env bash
# Harness Lab · aula 3.5 · ligar-statusline.sh
#
# Liga a status line de contexto (statusline-contexto.sh) para você, em todos os
# projetos: copia o script para ~/.claude/ e põe o "statusLine" no seu
# ~/.claude/settings.json. É configuração pessoal, por isso não vai para o
# repositório do projeto nem passa pelo instalar.sh.
#
#   modelos/ligar-statusline.sh            liga (não troca uma status line que você já tem)
#   modelos/ligar-statusline.sh --trocar   troca a sua pela da aula (guarda uma cópia)
#
# Nunca apaga nada: antes de mexer no settings.json, guarda settings.json.antes-harness-lab.
set -euo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SCRIPT="$DEST/statusline-contexto.sh"
S="$DEST/settings.json"
trocar=0
[ "${1:-}" = "--trocar" ] && trocar=1

command -v jq >/dev/null || { echo "Precisa do jq: sudo apt install jq (ou brew install jq)." >&2; exit 1; }

mkdir -p "$DEST"
cp "$AQUI/statusline-contexto.sh" "$SCRIPT"
chmod +x "$SCRIPT"
echo "script:  $SCRIPT"

[ -f "$S" ] || echo '{}' > "$S"
jq -e . "$S" >/dev/null 2>&1 || { echo "$S não é um JSON válido. Corrija antes (jq . $S mostra a linha)." >&2; exit 1; }

atual="$(jq -r '.statusLine.command // empty' "$S")"
if [ "$atual" = "$SCRIPT" ]; then
    echo "settings: a status line da aula já estava ligada em $S"
    exit 0
fi
if [ -n "$atual" ] && [ "$trocar" -eq 0 ]; then
    echo "settings: você já tem uma status line ($atual). Nada foi trocado."
    echo "          Para usar a da aula: $0 --trocar"
    exit 0
fi

cp "$S" "$S.antes-harness-lab"
tmp="$(mktemp)"
jq --arg c "$SCRIPT" '.statusLine = {type: "command", command: $c}' "$S" > "$tmp"
mv "$tmp" "$S"
echo "settings: statusLine ligado em $S (cópia do anterior em settings.json.antes-harness-lab)"
echo "Abra uma sessão nova do Claude Code: a barra fica logo abaixo de onde você digita."
