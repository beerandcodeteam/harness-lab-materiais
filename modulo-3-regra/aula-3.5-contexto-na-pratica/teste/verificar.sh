#!/usr/bin/env bash
# verificar.sh · aula 3.5 · roda no ~/projeto da sandbox, depois dos comandos do material.
# Prova que:
#   - o instalar.sh pôs o hook de SessionStart "compact" e somou ao settings que o projeto já tinha;
#   - o hook devolve o plano certo (próximo item, o que não deu certo) num JSON válido,
#     fica calado sem plano pendente e nunca bloqueia;
#   - o ligar-statusline.sh ligou a status line no ~/.claude da sandbox, e ela pinta a régua 30/45.
set -euo pipefail

H=.claude/hooks/plano-depois-do-compact.sh
AULA="$HOME/harness-lab-materiais/modulo-3-regra/aula-3.5-contexto-na-pratica"
n=0
ok() { n=$((n + 1)); printf '  ok  %s\n' "$1"; }
erro() { printf 'FALHOU: %s\n' "$1" >&2; exit 1; }

# ------------------------------------------------------------------ instalação
[ -x "$H" ] || erro "$H não instalado ou sem chmod +x"
bash -n "$H"
jq -e '.hooks.SessionStart[] | select(.matcher == "compact") | .hooks[]
       | select(.command | test("plano-depois-do-compact.sh"))' .claude/settings.json >/dev/null ||
  erro "SessionStart com matcher compact não aponta para o hook"
jq -e '.hooks.SessionStart[] | select(.matcher == "startup")' .claude/settings.json >/dev/null ||
  erro "o instalar.sh apagou o SessionStart que o projeto já tinha"
jq -e '.permissions.allow | index("Bash(git status)")' .claude/settings.json >/dev/null ||
  erro "o instalar.sh apagou a permissão que o projeto já tinha"
ok "hook executável, SessionStart compact ligado, settings do projeto preservado"

export CLAUDE_PROJECT_DIR="$PWD"
compact='{"session_id":"verificar","hook_event_name":"SessionStart","source":"compact"}'
roda() {   # roda [VAR=valor...]: guarda rc e out
  set +e
  out=$(env "$@" "$H" <<<"$compact" 2>/dev/null)
  rc=$?
  set -e
}

# ------------------------------------------------------------------ plano pendente
touch features/frete/PLANO.md
roda
[ "$rc" = 0 ] || erro "o hook nunca deve sair diferente de 0 (veio $rc)"
jq -e . <<<"$out" >/dev/null || erro "saída não é JSON válido: $out"
ctx=$(jq -r '.hookSpecificOutput.additionalContext' <<<"$out")
[ "$(jq -r '.hookSpecificOutput.hookEventName' <<<"$out")" = SessionStart ] || erro "hookEventName errado"
grep -q 'features/frete/PLANO.md' <<<"$ctx" || erro "contexto sem o caminho do plano"
grep -q 'Próximo item: frete grátis acima de R\$ 300' <<<"$ctx" || erro "contexto sem o próximo item"
grep -q 'dobrou o arredondamento' <<<"$ctx" || erro "contexto sem o que não deu certo"
! grep -q 'cadastro' <<<"$ctx" || erro "plano sem pendência (cadastro) não deveria entrar"
jq -e '.systemMessage | test("features/frete/PLANO.md")' <<<"$out" >/dev/null || erro "sem systemMessage para você"
ok "plano pendente: próximo item e 'não deu certo' no additionalContext, aviso na tela"

# ------------------------------------------------------------------ mais de um plano
mkdir -p features/busca
cp "$AULA/modelos/PLANO.md" features/busca/PLANO.md
sleep 1
touch features/busca/PLANO.md
roda
ctx=$(jq -r '.hookSpecificOutput.additionalContext' <<<"$out")
grep -q 'Plano em andamento: features/busca/PLANO.md' <<<"$ctx" || erro "o plano mexido por último deveria vir primeiro"
grep -q 'Outros planos com pendência: features/frete/PLANO.md' <<<"$ctx" || erro "o outro plano pendente sumiu"
grep -q 'Cache da tabela de faixas' <<<"$ctx" || erro "o modelos/PLANO.md não foi lido certo"
ok "dois planos: o mexido por último vem primeiro, o outro é citado; o modelos/PLANO.md funciona"

roda PLANO_MAX_NAO=1
ctx=$(jq -r '.hookSpecificOutput.additionalContext' <<<"$out")
! grep -q 'Cache da tabela' <<<"$ctx" || erro "PLANO_MAX_NAO=1 não cortou o 'não deu certo'"
rm -rf features/busca
ok "PLANO_MAX_NAO limita as linhas de 'não deu certo'"

# ------------------------------------------------------------------ outros lugares e casos
mkdir -p docs
printf '# Plano solto\n\n- [ ] item do docs\n' > docs/PLANO.md
roda PLANO_GLOB="docs/PLANO.md"
grep -q 'item do docs' <<<"$(jq -r '.hookSpecificOutput.additionalContext' <<<"$out")" ||
  erro "PLANO_GLOB não foi respeitado"
rm -rf docs
ok "PLANO_GLOB muda onde procurar"

roda PLANO_GLOB="nada/*/PLANO.md"
[ "$rc" = 0 ] && [ -z "$out" ] || erro "sem plano pendente o hook deveria sair calado com exit 0"
ok "sem plano pendente: exit 0, sem saída (não suja o contexto)"

P="$PWD"
out=$(cd / && env -u CLAUDE_PROJECT_DIR "$P/$H" <<<"{\"source\":\"compact\",\"cwd\":\"$P\"}")
grep -q 'features/frete/PLANO.md' <<<"$out" || erro "sem CLAUDE_PROJECT_DIR, deveria usar o cwd do JSON"
ok "sem CLAUDE_PROJECT_DIR: usa o cwd que vem no JSON"

# ------------------------------------------------------------------ status line
SL="$HOME/.claude/statusline-contexto.sh"
[ -x "$SL" ] || erro "status line não copiada para $SL"
[ "$(jq -r '.statusLine.command' "$HOME/.claude/settings.json")" = "$SL" ] ||
  erro "statusLine do ~/.claude/settings.json não aponta para o script"
ok "ligar-statusline.sh: script em ~/.claude e statusLine no settings do usuário"

sl() { printf '{"model":{"display_name":"Opus 5.5"},"context_window":{"context_window_size":%s,"used_percentage":%s}}' "$1" "$2" | NO_COLOR=1 "$SL"; }
[ "$(sl 1000000 12)" = "Opus 5.5 · ctx 12% de 1M (120k) · ok" ] || erro "12%: $(sl 1000000 12)"
[ "$(sl 1000000 34)" = "Opus 5.5 · ctx 34% de 1M (340k) · /compact com foco" ] || erro "34%: $(sl 1000000 34)"
[ "$(sl 200000 51)" = "Opus 5.5 · ctx 51% de 200k (102k) · /compact ou /clear agora" ] || erro "51%: $(sl 200000 51)"
[ "$(sl 1000000 null)" = "Opus 5.5 · ctx -- de 1M" ] || erro "null: $(sl 1000000 null)"
[ "$(printf 'lixo' | "$SL")" = "statusline: JSON inesperado" ] || erro "JSON quebrado deveria virar aviso curto"
ok "status line: verde até 30%, amarelo até 45%, vermelho acima; começo de sessão sem número"

out=$(bash "$AULA/modelos/ligar-statusline.sh")
grep -q 'já estava ligada' <<<"$out" || erro "rodar de novo deveria dizer que já estava ligada"
ok "ligar-statusline.sh rodado de novo não mexe em nada"

echo "verificar.sh: $n grupos de checagem passaram."
