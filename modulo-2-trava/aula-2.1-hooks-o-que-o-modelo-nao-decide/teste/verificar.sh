#!/usr/bin/env bash
# verificar.sh · aula 2.1 · roda no ~/projeto da sandbox, depois dos comandos do material.
# Prova que os três hooks foram instalados e respondem certo ao JSON que o Claude Code manda:
# o espião anota sem imprimir nada, o contexto-inicio põe fatos no stdout, o avisa devolve
# terminalSequence. E que o esqueleto de modelos/ libera, pergunta e bloqueia.
set -euo pipefail

n=0
ok() { n=$((n + 1)); printf '  ok  %s\n' "$1"; }
erro() { printf 'FALHOU: %s\n' "$1" >&2; exit 1; }
H=.claude/hooks
AULA=$(ls -d "$HOME"/harness-lab-materiais/modulo-2-trava/aula-2.1-*/)
E="$AULA/modelos/entradas"

# ------------------------------------------------------------------ instalação
for h in espiao contexto-inicio avisa; do
  [ -x "$H/$h.sh" ] || erro "$H/$h.sh não instalado ou sem chmod +x"
  bash -n "$H/$h.sh"
done
S=.claude/settings.json
jq -e '.hooks.SessionStart[].hooks[] | select(.command | test("contexto-inicio.sh"))' $S >/dev/null ||
  erro "SessionStart não aponta para o contexto-inicio.sh"
jq -e '.hooks.Notification[] | select(.matcher == "permission_prompt|idle_prompt") | .hooks[]
       | select(.command | test("avisa.sh"))' $S >/dev/null || erro "Notification sem o avisa.sh"
jq -e '.permissions.allow | index("Bash(git status)")' $S >/dev/null ||
  erro "o instalar.sh apagou a permissão que o projeto já tinha"
[ -f .claude/settings.json.antes-harness-lab ] || erro "sem a cópia do settings original"
ok "três hooks executáveis, settings somado ao do projeto (permissão preservada)"

jq -e '.hooks | keys == ["Notification","PostToolUse","PostToolUseFailure","PreToolUse",
       "SessionEnd","SessionStart","Stop","UserPromptSubmit"]' .claude/settings.espiao.json >/dev/null ||
  erro "settings.espiao.json não liga os 8 eventos"
[ "$(jq '[.hooks[][].hooks[] | select(.command | test("CLAUDE_PROJECT_DIR.*espiao.sh"))] | length' \
  .claude/settings.espiao.json)" = 8 ] || erro "algum evento do espião não usa \$CLAUDE_PROJECT_DIR"
[ ! -e .claude/settings.local.json ] || erro "o material não devia criar settings.local.json"
ok "settings.espiao.json: 8 eventos, caminho a partir de \$CLAUDE_PROJECT_DIR, nada no settings.local"

git check-ignore -q .claude/logs/eventos.log || erro ".claude/logs/ não está fora do git"
git check-ignore -q .claude/logs/.gitignore && erro "o .gitignore dos logs devia ir para o git"
ok ".claude/logs/ fora do git, o .gitignore dele dentro"

export CLAUDE_PROJECT_DIR="$PWD"
roda() {   # roda HOOK ARQUIVO_JSON: guarda rc e out
  set +e; out=$("$H/$1.sh" < "$2" 2>/tmp/verif-err); rc=$?; set -e
}

# ------------------------------------------------------------------ espião
rm -f .claude/logs/eventos.log
for f in sessionstart userpromptsubmit pretooluse-bash posttooluse-write notification stop; do
  roda espiao "$E/$f.json"
  [ "$rc" = 0 ] || erro "espiao.sh saiu com $rc em $f"
  [ -z "$out" ] || erro "espiao.sh imprimiu no stdout em $f (viraria contexto)"
done
[ "$(wc -l < .claude/logs/eventos.log)" -eq 6 ] || erro "eventos.log devia ter 6 linhas"
grep -q ' · PreToolUse · Bash · cat notas.txt$' .claude/logs/eventos.log || erro "linha do PreToolUse errada"
grep -q ' · SessionStart · startup$' .claude/logs/eventos.log || erro "linha do SessionStart errada"
grep -q ' · Notification · permission_prompt$' .claude/logs/eventos.log || erro "linha do Notification errada"
ok "espião: 6 eventos anotados, exit 0 e stdout vazio em todos"

# ------------------------------------------------------------------ contexto-inicio
roda contexto-inicio "$E/sessionstart.json"
[ "$rc" = 0 ] || erro "contexto-inicio.sh saiu com $rc"
grep -q "^Branch atual: $(git branch --show-current)\.$" <<<"$out" || erro "sem a branch: $out"
grep -q 'Próxima: carrinho com cupom' <<<"$out" || erro "sem a próxima tarefa: $out"
grep -q '2 tarefa(s) pendente(s)' <<<"$out" || erro "contagem de tarefas errada: $out"
ok "contexto-inicio: branch, commits e próxima tarefa no stdout"
mv tarefas.md /tmp/verif-tarefas.md
roda contexto-inicio "$E/sessionstart.json"
mv /tmp/verif-tarefas.md tarefas.md
[ "$rc" = 0 ] && ! grep -q 'Próxima' <<<"$out" || erro "sem tarefas.md devia só pular a linha"
ok "contexto-inicio sem tarefas.md: segue, sem a linha da tarefa"

# ------------------------------------------------------------------ avisa
roda avisa "$E/notification.json"
[ "$rc" = 0 ] || erro "avisa.sh saiu com $rc"
jq -e '.terminalSequence | startswith("\u0007\u001b]9;") and endswith("\u0007")' <<<"$out" >/dev/null ||
  erro "avisa.sh não devolveu terminalSequence com BEL e OSC 9: $out"
jq -e '.terminalSequence | test("Claude needs your permission to use Bash")' <<<"$out" >/dev/null ||
  erro "terminalSequence sem a mensagem"
[ "$(jq 'keys' <<<"$out" | jq -c .)" = '["terminalSequence"]' ] || erro "stdout do avisa tem algo além do JSON"
roda avisa <(printf '{"message":"linha 1\\nlinha 2\\u001b[31m"}')
jq -e '.terminalSequence | test("linha 1linha 2\\[31m")' <<<"$out" >/dev/null ||
  erro "controle na mensagem devia ser removido: $out"
ok "avisa: devolve terminalSequence (bipe + OSC 9) e limpa caractere de controle"

# ------------------------------------------------------------------ modelo libera, pergunta, bloqueia
M="$AULA/modelos/libera-pergunta-bloqueia.sh"
d() { jq -nc --arg c "$1" '{tool_input:{command:$c}}' | bash "$M"; }
[ -z "$(d 'git status')" ] || erro "git status devia passar sem imprimir"
[ "$(d 'rm -rf build' | jq -r .hookSpecificOutput.permissionDecision)" = ask ] || erro "rm -rf sem ask"
[ "$(d 'php artisan migrate:fresh' | jq -r .hookSpecificOutput.permissionDecision)" = deny ] ||
  erro "migrate:fresh sem deny"
[ "$(d 'rails db:reset' | jq -r .hookSpecificOutput.permissionDecision)" = deny ] || erro "db:reset sem deny"
ok "modelo: git status libera, rm -rf pergunta, migrate:fresh e db:reset bloqueiam"

echo "verificar.sh: $n grupos de checagem passaram."
