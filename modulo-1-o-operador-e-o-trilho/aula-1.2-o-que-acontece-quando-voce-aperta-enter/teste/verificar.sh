#!/usr/bin/env bash
# verificar.sh · aula 1.2 · roda no ~/projeto da sandbox, depois dos comandos do material.
# Prova que:
#   - a status line de contexto foi instalada e ligada no .claude/settings.json do projeto,
#     sem apagar o que o projeto já tinha;
#   - o script responde certo ao JSON que o Claude Code manda (verde, amarelo, vermelho,
#     antes da 1ª resposta, cache quente e frio, JSON quebrado);
#   - a "foto" do /context (claude -p "/context") foi gravada e traz as categorias da aula.
set -euo pipefail

S=.claude/statusline-contexto.sh
n=0
ok() { n=$((n + 1)); printf '  ok  %s\n' "$1"; }
erro() { printf 'FALHOU: %s\n' "$1" >&2; exit 1; }

# ------------------------------------------------------------------ instalação
[ -x "$S" ] || erro "$S não instalado ou sem chmod +x"
bash -n "$S"
jq -e '.statusLine.type == "command"
       and (.statusLine.command | test("CLAUDE_PROJECT_DIR.*statusline-contexto.sh"))' \
  .claude/settings.json >/dev/null || erro "statusLine do settings.json não aponta para o script"
jq -e '.permissions.allow | index("Bash(php artisan test)")' .claude/settings.json >/dev/null ||
  erro "o instalar.sh apagou a permissão que o projeto já tinha"
ok "script executável, statusLine ligada, settings do projeto preservado"

unset NO_COLOR HL_CONTEXTO_LIMITE 2>/dev/null || true   # a sandbox exporta NO_COLOR=1

# roda JSON [VAR=valor...]: guarda rc e out
roda() {
  local json="$1"
  shift
  set +e
  out=$(env "$@" "$S" <<<"$json")
  rc=$?
  set -e
  [ "$rc" = 0 ] || erro "a status line saiu com $rc (tem que sair 0 sempre): $json"
}
tem() { grep -qF -- "$1" <<<"$out" || erro "esperado '$1' na saída: $out"; }
nao_tem() { ! grep -qF -- "$1" <<<"$out" || erro "não esperado '$1' na saída: $out"; }
VERDE=$'\033[32m'; AMARELO=$'\033[33m'; VERMELHO=$'\033[31m'

# ------------------------------------------------------------------ percentuais
roda '{"model":{"display_name":"Opus"},"context_window":{"used_percentage":null,"context_window_size":1000000}}'
tem "Opus"; tem "aparece depois da 1ª resposta"; tem "/context"
ok "antes da 1ª resposta (used_percentage null): manda rodar /context"

roda '{"context_window":{"used_percentage":12,"context_window_size":1000000,"total_input_tokens":123456}}'
tem "${VERDE}contexto 12% (123k de 1M)"; nao_tem "/clear"
ok "12% de 1M: verde, com os tokens da última chamada"

roda '{"context_window":{"used_percentage":35.8,"context_window_size":200000}}'
tem "${AMARELO}contexto 35% (70k de 200k)"; tem "passou de 30%"; tem "/clear"
ok "35%: amarelo, passou da regra dos 30% da aula"

roda '{"context_window":{"used_percentage":71}}'
tem "${VERMELHO}contexto 71%"; tem "recomece com o pedido completo"
ok "71%: vermelho"

roda '{"context_window":{"used_percentage":35}}' HL_CONTEXTO_LIMITE=40
tem "${VERDE}contexto 35%"; nao_tem "passou"
roda '{"context_window":{"used_percentage":35}}' HL_CONTEXTO_LIMITE=abc
tem "passou de 30%"
ok "HL_CONTEXTO_LIMITE muda o limite; valor inválido volta para 30"

roda '{"context_window":{"used_percentage":35}}' NO_COLOR=1
[ "$out" = "contexto 35% · passou de 30%: feche a tarefa e use /clear" ] || erro "NO_COLOR: $out"
ok "NO_COLOR=1: sem códigos de cor"

# ------------------------------------------------------------------ cache
fim=$(($(date +%s) + 600))
roda "{\"context_window\":{\"used_percentage\":5},\"prompt_cache\":{\"warm\":true,\"ttl\":\"5m\",\"expires_at\":$fim,\"caching_observed\":true}}"
tem "cache quente (5m), esfria em 10 min"
roda '{"context_window":{"used_percentage":5},"prompt_cache":{"warm":false,"caching_observed":true,"expires_at":null}}'
tem "cache frio"
roda '{"context_window":{"used_percentage":5}}'
nao_tem "cache"
ok "cache quente com tempo até esfriar, cache frio avisado, sem prompt_cache não fala de cache"

# ------------------------------------------------------------------ entrada ruim
roda 'isto não é JSON'
tem "JSON inesperado"
roda ''
tem "JSON inesperado"
ok "entrada quebrada: mensagem curta e exit 0 (status line nunca derruba nada)"

# ------------------------------------------------------------------ foto do /context
F="$HOME/contexto-antes.md"
[ -s "$F" ] || erro "$F não foi gravado pelo claude -p \"/context\""
grep -q '^## Context Usage' "$F" || erro "$F não tem o cabeçalho do /context"
for c in "System prompt" "System tools" "Memory files" "Free space"; do
  grep -q "| $c |" "$F" || erro "$F sem a categoria '$c'"
done
grep -q 'projeto/CLAUDE.md' "$F" || erro "$F não mostra o CLAUDE.md do projeto em Memory Files"
ok "foto do /context gravada, com as categorias e o CLAUDE.md do projeto"

echo "verificar.sh: $n grupos de checagem passaram."
