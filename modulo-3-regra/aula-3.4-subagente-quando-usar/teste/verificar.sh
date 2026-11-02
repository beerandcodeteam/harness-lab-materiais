#!/usr/bin/env bash
# verificar.sh · aula 3.4 · roda no ~/projeto da sandbox, depois dos comandos do material.
# Prova que os subagentes foram instalados com o frontmatter certo, que o hook
# bash-so-permitido.sh responde certo a JSON falso (igual ao que o Claude Code manda)
# e que o plugin bc-harness está instalado com os três agentes do /ai-context.
set -euo pipefail

n=0
ok() { n=$((n + 1)); printf '  ok  %s\n' "$1"; }
erro() { printf 'FALHOU: %s\n' "$1" >&2; exit 1; }
AULA="$HOME/harness-lab-materiais/modulo-3-regra/aula-3.4-subagente-quando-usar"
TMPDIR=$(mktemp -d)
export TMPDIR

# campo NOME ARQUIVO: valor do campo no frontmatter (entre os dois ---)
campo() { awk -v k="$1" 'NR==1 && $0!="---"{exit} NR>1 && $0=="---"{exit} NR>1 && index($0, k": ")==1{sub(k": ", ""); print}' "$2"; }

# ------------------------------------------------------------------ subagentes
T=.claude/agents/test-runner.md
V=.claude/agents/revisor.md
[ -f "$T" ] && [ -f "$V" ] || erro "test-runner.md ou revisor.md não instalados em .claude/agents/"
[ "$(campo name "$T")" = "test-runner" ] || erro "name do test-runner"
[ -n "$(campo description "$T")" ] || erro "test-runner sem description (o Claude Code pularia o arquivo)"
[ "$(campo model "$T")" = "haiku" ] || erro "test-runner devia rodar no haiku"
tt=$(campo tools "$T")
grep -q 'Bash' <<<"$tt" || erro "test-runner sem Bash não roda teste"
! grep -Eq 'Edit|Write' <<<"$tt" || erro "test-runner não pode ter Edit nem Write"
ok "test-runner: name, description, model haiku, tools sem Edit e Write"

[ "$(campo name "$V")" = "revisor" ] || erro "name do revisor"
tv=$(campo tools "$V")
! grep -Eq 'Edit|Write' <<<"$tv" || erro "revisor não pode ter Edit nem Write"
if grep -q 'Bash' <<<"$tv"; then
  grep -q 'bash-so-permitido.sh' "$V" || erro "revisor com Bash precisa do hook bash-so-permitido.sh"
  ok "revisor (variante com git): Bash travado pelo hook"
else
  [ "$tv" = "Read, Grep, Glob" ] || erro "revisor devia ter só Read, Grep, Glob (veio: $tv)"
  ok "revisor: só Read, Grep, Glob"
fi
[ "$(campo tools "$AULA/projeto/.claude/agents/revisor.md")" = "Read, Grep, Glob" ] || erro "revisor.md da aula devia ter só Read, Grep, Glob"
ok "revisor.md da aula (projeto/): só Read, Grep, Glob"

out=$(claude plugin validate .claude/agents 2>&1) || { echo "$out" >&2; erro "claude plugin validate .claude/agents"; }
! grep -qi 'warning' <<<"$out" || { echo "$out" >&2; erro "validate passou com aviso"; }
ok "claude plugin validate .claude/agents: sem erro e sem aviso"

mkdir -p "$TMPDIR/v/.claude/agents"
cp "$AULA"/modelos/*.md "$TMPDIR/v/.claude/agents/"
rm "$TMPDIR/v/.claude/agents/pedido-para-subagente.md"
out=$(claude plugin validate "$TMPDIR/v/.claude/agents" 2>&1) || { echo "$out" >&2; erro "variantes de modelos/ inválidas"; }
! grep -qi 'warning' <<<"$out" || { echo "$out" >&2; erro "variantes de modelos/ com aviso"; }
for f in "$AULA"/modelos/revisor-com-git.md "$AULA"/modelos/test-runner-travado.md; do
  grep -q '"$CLAUDE_PROJECT_DIR"/.claude/hooks/bash-so-permitido.sh' "$f" || erro "$(basename "$f") não aponta para o hook instalado"
done
for f in "$AULA"/modelos/revisor-com-git.md "$AULA"/modelos/test-runner-travado.md; do
  tf=$(campo tools "$f")
  if grep -q 'Bash' <<<"$tf" && grep -Eq 'Glob|Grep' <<<"$tf"; then
    erro "$(basename "$f"): com Bash na lista, Glob e Grep não existem no Linux/WSL (veio: $tf)"
  fi
done
ok "variantes de modelos/: frontmatter válido, hook apontando para .claude/hooks/, sem Glob/Grep junto do Bash"

# ------------------------------------------------------------------ hook
H=.claude/hooks/bash-so-permitido.sh
[ -x "$H" ] || erro "$H não instalado ou sem chmod +x"
bash -n "$H"
GIT=("git diff" "git log" "git show" "git status" "grep")
roda() {   # roda COMANDO PERMITIDOS...: guarda rc e err
  local c="$1"; shift
  set +e
  jq -nc --arg c "$c" '{hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $c}}' |
    "$H" "$@" 2>"$TMPDIR/err"
  rc=$?
  set -e
  err=$(cat "$TMPDIR/err")
}
for c in "git diff" "git diff --stat main...HEAD" "git diff | head -200" "git log --oneline -5" \
         "grep -rn calculaFrete app" "git diff 2>&1 | grep -n foo"; do
  roda "$c" "${GIT[@]}"
  [ "$rc" = 0 ] || erro "deveria passar: $c (exit $rc: $err)"
done
ok "comandos de leitura do git passam (com pipe para head e grep, e 2>&1)"
for c in "git diff; rm -rf ." "git diff && rm x" "git diff || true" "git diff > saida.txt" \
         'git diff $(rm x)' 'git diff `rm x`' "git diff | sh" "git diff |" "git diff --output=x" \
         "git push" "git diff-tree HEAD" "rm -rf ." $'git diff\nrm x' "cat .env"; do
  roda "$c" "${GIT[@]}"
  [ "$rc" = 2 ] || erro "deveria bloquear com exit 2: $c (veio $rc)"
  grep -q 'Bloqueado' <<<"$err" || erro "bloqueio sem motivo no stderr: $c"
done
ok "encadeamento, redirecionamento, substituição, pipe para shell e comando fora da lista: exit 2"

roda "./vendor/bin/sail artisan test --compact --filter=Frete" "./vendor/bin/sail artisan test"
[ "$rc" = 0 ] || erro "comando de teste listado devia passar"
roda "./vendor/bin/sail artisan migrate:fresh" "./vendor/bin/sail artisan test"
[ "$rc" = 2 ] || erro "artisan fora da lista devia bloquear"
ok "test-runner travado: só o comando de teste passa"

set +e
printf 'isto não é json' | "$H" "git diff" 2>/dev/null; r1=$?
printf '{"tool_input":{}}' | "$H" "git diff" 2>/dev/null; r2=$?
printf '{"tool_input":{"command":"git diff"}}' | "$H" 2>/dev/null; r3=$?
mkdir -p "$TMPDIR/bin"
for b in bash cat; do ln -sf "$(command -v $b)" "$TMPDIR/bin/$b"; done
printf '{"tool_input":{"command":"git diff"}}' | PATH="$TMPDIR/bin" "$TMPDIR/bin/bash" "$H" "git diff" 2>/dev/null; r4=$?
set -e
[ "$r1" = 2 ] || erro "JSON ilegível devia bloquear (veio $r1)"
[ "$r2" = 0 ] || erro "pedido sem command devia passar (veio $r2)"
[ "$r3" = 2 ] || erro "hook sem lista de comandos devia bloquear (veio $r3)"
[ "$r4" = 2 ] || erro "sem jq e sem python3 devia bloquear (veio $r4)"
ok "falha fechada: JSON ilegível, lista vazia, sem jq nem python3"

# ------------------------------------------------------------------ plugin bc-harness
lista=$(claude plugin list 2>&1)
grep -q 'bc-harness@beer-and-code' <<<"$lista" || { echo "$lista" >&2; erro "bc-harness não aparece em claude plugin list"; }
P=$(find "$HOME/.claude/plugins/cache" -type f -path '*bc-harness*/commands/ai-context.md' | head -1)
[ -n "$P" ] || erro "commands/ai-context.md do bc-harness não encontrado no cache"
D=$(dirname "$(dirname "$P")")
for a in inspector core docs; do
  [ -f "$D/agents/ai-context-$a.md" ] || erro "agente ai-context-$a não veio no plugin"
done
ti=$(campo tools "$D/agents/ai-context-inspector.md")
! grep -Eq 'Edit|Write' <<<"$ti" || erro "inspector não devia ter Edit nem Write"
grep -q -- '--adopt' "$P" || erro "ai-context sem --adopt"
ok "bc-harness instalado: /ai-context e os agentes inspector (sem Edit e Write), core e docs"

echo "verificar.sh: $n grupos de checagem passaram."
