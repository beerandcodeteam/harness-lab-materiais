#!/usr/bin/env bash
# log-comandos.sh · Harness Lab · aula 2.3 · PostToolUse e PostToolUseFailure (matcher: Bash)
# Uma linha por comando que rodou de verdade, com o resultado: o diário de bordo do agente.
#   PostToolUse        → o comando rodou e deu certo
#   PostToolUseFailure → o comando rodou e falhou (o motivo vem no campo "error")
# Comando barrado pelo PreToolUse não aparece aqui: ele nunca rodou.
entrada=$(cat)
dir="${CLAUDE_PROJECT_DIR:-.}/.claude/logs"
mkdir -p "$dir"
jq -c '{ hora: (now | strflocaltime("%Y-%m-%d %H:%M:%S")),
         status: (if .hook_event_name == "PostToolUseFailure" then "falhou" else "ok" end),
         comando: .tool_input.command,
         pasta: .cwd,
         erro: ((.error // "") | split("\n")[0]) }' <<<"$entrada" >> "$dir/comandos.jsonl" 2>/dev/null
exit 0
