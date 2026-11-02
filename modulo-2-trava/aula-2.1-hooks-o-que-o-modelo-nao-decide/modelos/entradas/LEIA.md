# Entradas de hook para teste

O JSON que o Claude Code manda no stdin de cada evento. Capturado de uma sessão real
(Claude Code 2.1.316, 02/11/2026), com caminhos e IDs trocados por exemplos.
O `notification.json` segue o exemplo da documentação: `claude -p` não dispara Notification.

Use para testar um hook sem abrir o Claude Code:

    .claude/hooks/espiao.sh < modelos/entradas/pretooluse-bash.json; echo "exit $?"

| Arquivo | Evento | Campos que mais importam |
| --- | --- | --- |
| `sessionstart.json` | SessionStart | `source` (startup, resume, clear, compact) |
| `userpromptsubmit.json` | UserPromptSubmit | `prompt` |
| `pretooluse-bash.json` | PreToolUse | `tool_name`, `tool_input.command` |
| `posttooluse-write.json` | PostToolUse | `tool_input.file_path`, `tool_response` |
| `notification.json` | Notification | `message`, `notification_type` |
| `stop.json` | Stop | `stop_hook_active`, `last_assistant_message` |
