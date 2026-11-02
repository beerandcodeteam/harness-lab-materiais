#!/usr/bin/env bash
# verificar.sh · aula 1.4 · roda no ~/projeto da sandbox, depois dos comandos do material.
# Prova: o modelo do diagnóstico foi instalado, o plugin diagnostico-camadas aparece no
# Claude Code com a skill válida, o script de evidências lê o git sem alterar nada, e os
# arquivos de modelos/mapa-das-camadas fazem o que o material diz.
set -euo pipefail

n=0
ok() { n=$((n + 1)); printf '  ok  %s\n' "$1"; }
erro() { printf 'FALHOU: %s\n' "$1" >&2; exit 1; }
REPO="$HOME/harness-lab-materiais"
AULA="$REPO/modulo-1-o-operador-e-o-trilho/aula-1.4-as-4-camadas-do-harness"

# ---------------------------------------------------------------- diagnostico-camadas.md
D=diagnostico-camadas.md
[ -f "$D" ] || erro "$D não foi criado pelo instalar.sh"
for s in '## As perguntas' '## Correções' '## Contagem' '## Por onde começar'; do
  grep -q "^$s" "$D" || erro "$D sem a seção $s"
done
[ "$(grep -cE '^\| [1-5] \|' "$D")" -eq 5 ] || erro "$D sem as 5 linhas da tabela"
for c in Regra Trava Prova Loop Inteligência; do grep -q "^| $c |" "$D" || erro "contagem sem $c"; done
ok "diagnostico-camadas.md na raiz, com perguntas, 5 linhas e contagem por camada"

# ---------------------------------------------------------------- plugin
claude plugin list 2>&1 | grep -q 'diagnostico-camadas' || erro "plugin não aparece em claude plugin list"
SK=$(find "$HOME/.claude/plugins" -path '*diagnostico-camadas*' -name SKILL.md | head -1)
[ -n "$SK" ] || erro "SKILL.md do plugin não está no cache de plugins"
[ "$(head -1 "$SK")" = "---" ] || erro "SKILL.md sem frontmatter na primeira linha"
fm=$(awk 'NR == 1 { next } /^---$/ { exit } { print }' "$SK")
grep -q '^name: diagnostico-camadas$' <<<"$fm" || erro "frontmatter sem name"
grep -q '^description: .\{40,\}' <<<"$fm" || erro "frontmatter sem description"
grep -q '^disable-model-invocation: true$' <<<"$fm" || erro "a skill deveria ser só manual"
grep -q 'CLAUDE_SKILL_DIR}/scripts/evidencias.sh' "$SK" || erro "SKILL.md não aponta para o script"
DIR=$(dirname "$SK")
[ -x "$DIR/scripts/evidencias.sh" ] || erro "evidencias.sh sem chmod +x no plugin instalado"
[ -f "$DIR/references/exemplos.md" ] || erro "references/exemplos.md não veio no plugin"
ok "plugin instalado, skill /diagnostico-camadas manual, script e exemplos no lugar"

# ---------------------------------------------------------------- evidencias.sh
E="$DIR/scripts/evidencias.sh"
g() { git -c user.name=Aluno -c user.email=aluno@harness.lab "$@"; }
git add -A >/dev/null && g commit -qm "chore: diagnóstico da aula 1.4" >/dev/null || true
echo "// v2" >> app/Http/Controllers/ProdutoController.php
g commit -qam "fix: corrige o formato da resposta de produtos"
g revert --no-edit HEAD >/dev/null
antes=$(git status --porcelain; git rev-parse HEAD)
out=$(CLAUDE_PROJECT_DIR="$PWD" "$E" 50)
depois=$(git status --porcelain; git rev-parse HEAD)
[ "$antes" = "$depois" ] || erro "evidencias.sh alterou o repositório"
grep -qE '^## Com cara de correção: [2-9]' <<<"$out" || erro "evidencias.sh não contou os commits de correção"
sed -n '/^## Com cara/,/^$/p' <<<"$out" | grep -q ' fix: corrige o formato' || erro "evidencias.sh não listou o fix"
grep -q '^Revert "fix: corrige' <<<"$(sed -n '/^## Reverts/,/^$/p' <<<"$out" | cut -d' ' -f2-)" ||
  erro "evidencias.sh não listou o revert"
grep -qE '^ +[2-9] app/Http/Controllers/ProdutoController.php$' <<<"$out" ||
  erro "evidencias.sh não contou o arquivo que voltou"
fora=$(cd "$HOME" && CLAUDE_PROJECT_DIR="$HOME" "$E")
grep -q 'não é um repositório git' <<<"$fora" || erro "evidencias.sh fora de repositório deveria só avisar"
ok "evidencias.sh: acha fix e revert, conta o arquivo que voltou, não altera nada"

# ---------------------------------------------------------------- modelos/mapa-das-camadas
M="$AULA/modelos/mapa-das-camadas"
[ -d "$M" ] || erro "modelos/mapa-das-camadas não veio no clone"
jq -e '.permissions.deny | index("Read(./.env)")' "$M/.claude/settings.json" >/dev/null || erro "settings do mapa sem deny do .env"
jq -e '.hooks.PreToolUse[] | select(.matcher == "Bash")' "$M/.claude/settings.json" >/dev/null || erro "settings do mapa sem PreToolUse Bash"
B="$M/.claude/hooks/bloqueia.sh"
pede() { jq -nc --arg c "$1" '{tool_name: "Bash", tool_input: {command: $c}}'; }
for c in 'php artisan migrate:fresh --seed' 'rm -rf storage' 'git push --force origin main' 'git push -f'; do
  set +e; pede "$c" | "$B" 2>/dev/null; rc=$?; set -e
  [ "$rc" -eq 2 ] || erro "bloqueia.sh deveria barrar: $c (saiu $rc)"
done
for c in 'php artisan migrate' './vendor/bin/pest' 'git push origin main'; do
  pede "$c" | "$B" || erro "bloqueia.sh barrou o que devia passar: $c"
done
msg=$(pede 'php artisan migrate:fresh' | "$B" 2>&1 >/dev/null || true)
grep -q 'Bloqueado' <<<"$msg" || erro "bloqueia.sh não explica o motivo no stderr"
A="$M/.claude/hooks/avisa.sh"
echo '{"hook_event_name":"Notification","message":"oi","notification_type":"idle_prompt"}' |
  env -u AVISO_WEBHOOK "$A" || erro "avisa.sh deveria sair com 0"
ok "mapa: deny do .env, bloqueia.sh barra 4 e libera 3, avisa.sh não trava"

# loop.sh com um claude falso: prova que a Prova decide e que travar para o loop
L="$M/loop.sh"
bash -n "$L"
T=$(mktemp -d)
mkdir -p "$T/bin" "$T/p"
printf '#!/usr/bin/env bash\necho "$*" >> chamadas.log\necho x >> feito.txt\n' > "$T/bin/claude"
chmod +x "$T/bin/claude"
(
  cd "$T/p"
  git init -q && cp "$M/tarefas.md" . && git add . && g commit -qm inicio
  printf 'chamadas.log\n' > .gitignore
  PATH="$T/bin:$PATH" TESTE=true "$L" tarefas.md >/dev/null
  [ "$(grep -c '^- \[x\]' tarefas.md)" -eq 3 ] || exit 11
  [ "$(git log --oneline | wc -l | tr -d ' ')" -eq 4 ] || exit 12
  grep -q -- '-p Implemente só esta tarefa' chamadas.log || exit 13
  grep -q -- '--permission-mode acceptEdits' chamadas.log || exit 14
  if grep -q -- '--bare' chamadas.log; then exit 15; fi
) || erro "loop.sh com Prova verde não marcou, não fez commit ou chamou o claude errado ($?)"
(
  cd "$T" && rm -rf q && mkdir q && cd q
  git init -q && cp "$M/tarefas.md" . && git add . && g commit -qm inicio
  set +e; PATH="$T/bin:$PATH" TESTE=false "$L" tarefas.md >saida.txt; rc=$?; set -e
  [ "$rc" -eq 1 ] && grep -q 'travou em: 01' saida.txt && [ "$(grep -c 'tentativa' saida.txt)" -eq 3 ]
) || erro "loop.sh com Prova vermelha não tentou 3 vezes e parou avisando"
ok "loop.sh: Prova verde marca e commita; vermelha tenta 3 vezes e avisa que travou"

echo "verificar.sh: $n grupos ok"
