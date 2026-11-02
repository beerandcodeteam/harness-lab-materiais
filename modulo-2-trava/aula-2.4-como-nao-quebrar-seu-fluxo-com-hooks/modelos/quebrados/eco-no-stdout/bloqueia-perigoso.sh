#!/usr/bin/env bash
# QUEBRADO DE PROPÓSITO · aula 2.4 · "stdout que vira lixo"
# Igual ao bloqueia-perigoso.sh certo, com UMA linha a mais: um echo de depuração no stdout.
# O Claude Code só lê a decisão se o stdout for um objeto JSON e mais nada. Com o texto
# antes, a saída não começa com {, vira texto puro, e a decisão "deny" some: libera.
# Depuração vai para o stderr (>&2) ou para um arquivo de log.
# Três respostas possíveis para cada comando que o modelo pede:
#   nada no stdout + exit 0      → libera
#   permissionDecision "ask"     → pergunta para você antes de rodar
#   permissionDecision "deny"    → não roda, e o motivo volta para o modelo
set -uo pipefail
entrada=$(cat)

# Sem jq não dá para ler o comando. Hook de segurança falha FECHADO (aula 2.4).
command -v jq >/dev/null 2>&1 || { echo "bloqueia-perigoso: jq não instalado, bloqueando por segurança" >&2; exit 2; }

cmd=$(jq -r '.tool_input.command // empty' <<<"$entrada")
[ -n "$cmd" ] || exit 0
echo "debug: analisando $cmd"   # <- o defeito

# casa REGEX → o comando bate com o padrão? (regex do jq: funciona igual no Linux e no macOS)
casa() { jq -e --arg re "$1" '(.tool_input.command // "") | test($re; "i")' >/dev/null <<<"$entrada"; }
decide() {
  jq -n --arg d "$1" --arg r "$2" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: $r}}'
  exit 0
}

# 1. Apaga o banco inteiro
casa '(artisan|sail)\b.*\b(migrate:(fresh|reset|refresh)|db:wipe)\b' &&
  decide deny "Bloqueado pelo harness: esse comando apaga o banco. Use 'php artisan migrate' (sem fresh) ou peça para o humano recriar o banco."

# 2. Mira produção
casa '(--env[= ]?prod|APP_ENV=prod|\bmigrate\b.*--force|--force\b.*\bmigrate\b)' &&
  decide deny "Bloqueado: comando contra produção ou migration com --force. Isso nunca roda pelo agente."

# 3. Reescreve o histórico remoto
casa '\bgit\b.*\bpush\b.*(\s--force(\s|$)|\s-f(\s|$))' &&
  decide deny "Bloqueado: push --force reescreve o histórico de todo mundo. Se precisar mesmo, use --force-with-lease e peça confirmação."

# 4. Toca o .env (qualquer comando que cite o arquivo, menos o .env.example)
#    Versão anterior olhava só "cat|grep ... .env" e deixou passar: grep -E '^(APP_ENV|DB_HOST)=' .env
#    O | dentro do padrão do grep enganou a regra. Caso real do teste deste módulo.
casa '(^|[\s/\x27"<=])\.env(\.(?!example)[a-z]+)?([\s\x27";|&)<>]|$)' &&
  decide deny "Bloqueado: .env tem segredo. Use .env.example para ver os nomes das variáveis."

# 5. Apaga a raiz, o home ou tudo com curinga
casa '\brm\s+-[a-z]*(rf|fr)[a-z]*\s+(/|~|\$HOME|\*)(\s|$)' &&
  decide deny "Bloqueado: rm -rf na raiz, no home ou com curinga solto."

# 6. Perigoso, mas às vezes necessário: pergunta para o humano
casa '\brm\s+-[a-z]*(rf|fr)' &&
  decide ask "rm -rf dentro do projeto. Confirme se pode apagar."
casa '\bgit\b.*\breset\b.*--hard' &&
  decide ask "git reset --hard descarta mudanças não commitadas. Confirme."

exit 0
