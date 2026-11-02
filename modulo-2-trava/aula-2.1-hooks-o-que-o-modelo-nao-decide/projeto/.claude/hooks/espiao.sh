#!/usr/bin/env bash
# espiao.sh · aula 2.1 · qualquer evento
# Anota cada evento do ciclo de vida em .claude/logs/eventos.log, sem interferir em nada.
# Nunca imprime no stdout: em SessionStart e UserPromptSubmit, o stdout vira contexto do modelo.
# Para assistir ao vivo, em outro terminal:  tail -f .claude/logs/eventos.log
entrada=$(cat)
dir="${CLAUDE_PROJECT_DIR:-.}/.claude/logs"
mkdir -p "$dir"
command -v jq >/dev/null 2>&1 || { echo "$(date +%T) · (jq não instalado)" >> "$dir/eventos.log"; exit 0; }
jq -r '[ (now | strflocaltime("%H:%M:%S")),
         .hook_event_name,
         (.tool_name // ""),
         ((.tool_input.command // .tool_input.file_path // .prompt // .source
           // .notification_type // "") | tostring | gsub("\n"; " ") | .[0:70]) ]
       | map(select(. != "")) | join(" · ")' <<<"$entrada" >> "$dir/eventos.log"
exit 0
