#!/usr/bin/env bash
# verificar.sh · aula 4.3 · roda no ~/projeto da sandbox, depois dos comandos do material.
# Prova que o /plan e os três agentes da aula foram instalados como na gravação
# (delegação pelo nome local, frontmatter válido, nenhum model fixo), que o PHASES
# de exemplo passa nas mesmas checagens que o /plan faz em disco e que o
# confere-phases.sh aprova o que está certo e barra o que o ralph engoliria calado.
# Nada aqui chama o Claude de verdade: zero token.
set -euo pipefail

n=0
ok() { n=$((n + 1)); printf '  ok  %s\n' "$1"; }
erro() { printf 'FALHOU: %s\n' "$1" >&2; exit 1; }
AULA="$HOME/harness-lab-materiais/modulo-4-prova/aula-4.3-spec-com-criterio-de-aceite"
TMPDIR=$(mktemp -d)
export TMPDIR

# campo NOME ARQUIVO: valor do campo no frontmatter (entre os dois ---)
campo() { awk -v k="$1" 'NR==1 && $0!="---"{exit} NR>1 && $0=="---"{exit} NR>1 && index($0, k": ")==1{sub(k": ", ""); print}' "$2"; }

# ------------------------------------------------------------------ o que o instalar.sh pôs
P=.claude/commands/plan.md
C=.claude/scripts/confere-phases.sh
for f in "$P" .claude/agents/specifier.md .claude/agents/clarifier.md .claude/agents/planner.md; do
  [ -f "$f" ] || erro "$f não instalado"
  cmp -s "$f" "$AULA/projeto/$f" || erro "$f diferente do arquivo da aula"
done
[ -x "$C" ] || erro "$C não instalado ou sem chmod +x"
bash -n "$C"
ok "plan.md, specifier.md, clarifier.md, planner.md e confere-phases.sh (executável) instalados"

# ------------------------------------------------------------------ o comando
grep -q '^allowed-tools: .*Agent' "$P" || erro "plan.md sem a ferramenta Agent: não delega"
grep -q '^allowed-tools: .*AskUserQuestion' "$P" || erro "plan.md sem AskUserQuestion: não faz os checkpoints"
grep -q 'Delegate by local agent name' "$P" || erro "plan.md devia delegar pelo nome local"
! grep -q 'bc-harness:' "$P" || erro "plan.md ainda delega para os agentes do plugin (bc-harness:...)"
for a in specifier clarifier planner; do
  grep -q "| \`$a\` |" "$P" || erro "a tabela do pipeline não cita o agente $a"
done
for c in '^### 3 .*Checkpoint: confirm normalized input' 'Human checkpoint.*present the returned summary' 'AskUserQuestion, one batch' 'Human checkpoint.*task count'; do
  grep -Eq "$c" "$P" || erro "plan.md sem o checkpoint humano: $c"
done
ok "/plan: delega a specifier, clarifier e planner pelo nome local, com os 4 checkpoints humanos"

# ------------------------------------------------------------------ os agentes
for a in specifier clarifier planner; do
  f=.claude/agents/$a.md
  [ "$(campo name "$f")" = "$a" ] || erro "name do $a.md"
  [ -n "$(campo description "$f")" ] || erro "$a.md sem description (o Claude Code pularia o arquivo)"
  [ -z "$(campo model "$f")" ] || erro "$a.md não devia fixar model (roda no modelo da sessão)"
done
[ "$(campo tools .claude/agents/specifier.md)" = "Read, Write, Glob, Grep, Bash" ] || erro "tools do specifier"
[ "$(campo tools .claude/agents/clarifier.md)" = "Read, Edit, Glob, Grep, Bash" ] || erro "tools do clarifier"
[ "$(campo tools .claude/agents/planner.md)" = "Read, Write, Glob, Grep, Bash" ] || erro "tools do planner"
grep -q 'Event-Driven, State-Driven, Conditional, Unwanted, Optional' .claude/agents/specifier.md || erro "specifier sem as formas GEARS"
grep -q 'never guess' .claude/agents/specifier.md || erro "specifier sem a regra do marcador"
grep -q '"fast", "good", "adequate"' .claude/agents/specifier.md || erro "specifier sem as palavras proibidas"
grep -q 'Never question the FLEXIBLE section' .claude/agents/clarifier.md || erro "clarifier sem a regra do FLEXIBLE"
grep -q 'Acceptance criteria:` is mandatory' .claude/agents/planner.md || erro "planner sem a regra do Acceptance criteria"
ok "agentes: name igual ao arquivo, description, sem model, tools e regras da gravação"

for d in .claude/commands .claude/agents; do
  out=$(claude plugin validate "$d" 2>&1) || { echo "$out" >&2; erro "claude plugin validate $d"; }
  ! grep -qi 'warning' <<<"$out" || { echo "$out" >&2; erro "validate $d passou com aviso"; }
done
ok "claude plugin validate .claude/commands e .claude/agents: sem erro e sem aviso"

# ------------------------------------------------------------------ as checagens em disco do /plan (§7)
s=cadastro-email-duplicado
D=.spec/features/$s
test -f $D/PLAN.md
head -1 $D/PLAN.md | grep -q '^# Implementation Plan'
grep -q '^## Tasks' $D/PLAN.md
grep -q '^## TO BE' $D/PLAN.md
test -f $D/PHASES.md
grep -Eq '^## Phase [0-9]+: ' $D/PHASES.md
[ -z "$(grep -E '^## ' $D/PHASES.md | grep -Ev '^## Phase [0-9]+: ')" ] || erro "PHASES com outro ## fora de fase"
[ "$(grep -c '^- \[ \]' $D/PHASES.md)" -eq "$(grep -Ec '^### T[0-9]+' $D/PLAN.md)" ] || erro "PHASES e PLAN com número de tasks diferente"
cmp -s $D/PHASES.md "$AULA/modelos/exemplo-cadastro/PHASES.md" || erro "o PHASES da sandbox devia ser o de modelos/exemplo-cadastro"
ok "PHASES e PLAN de exemplo passam nas checagens em disco do plan.md (§7)"

# ------------------------------------------------------------------ confere-phases.sh
roda() {  # roda ARGS...: guarda rc e a saída em $TMPDIR/saida
  rc=0
  "$C" "$@" > "$TMPDIR/saida" 2>&1 || rc=$?
}
roda $D/PHASES.md
[ "$rc" = 0 ] || { cat "$TMPDIR/saida" >&2; erro "confere-phases.sh devia aprovar o exemplo"; }
grep -q 'fases: 2 · tasks: 4 · erros: 0' "$TMPDIR/saida" || erro "contagem do exemplo"
grep -q 'sem .claude/aceite.txt e FEATURE-ALVO.md' "$TMPDIR/saida" || erro "sem aceite.txt devia avisar que não conferiu os testes de aceite"
ok "confere-phases.sh: exemplo com 2 fases e 4 tasks, resultado ok"

echo 'tests/Feature/CadastroEmailDuplicadoTest.php' > "$TMPDIR/aceite.txt"
roda --aceite "$TMPDIR/aceite.txt" --feature FEATURE-ALVO.md $D/PHASES.md
[ "$rc" = 0 ] || { cat "$TMPDIR/saida" >&2; erro "com aceite.txt e FEATURE-ALVO.md o exemplo devia passar"; }
sed 's/AC-03/o terceiro critério/g' $D/PHASES.md > "$TMPDIR/PHASES.md"
cp $D/PLAN.md "$TMPDIR/PLAN.md"
roda --aceite "$TMPDIR/aceite.txt" --feature FEATURE-ALVO.md "$TMPDIR/PHASES.md"
[ "$rc" = 1 ] || erro "sem task para o AC-03 devia barrar"
grep -q 'AC-03 está no FEATURE-ALVO.md e em nenhuma task' "$TMPDIR/saida" || erro "devia apontar o AC-03"
ok "critério do FEATURE-ALVO.md sem task: barrado, com o AC-NN apontado"

# aceite.txt da 4.2 com o SchemaEstritoTest.php (passos 8 e 9 do PDF): o modo padrão,
# o mesmo que o pré-voo do loop.sh da 5.1 roda, barra até uma task citar o caminho.
mkdir -p .claude
[ ! -e .claude/aceite.txt ] || erro "a sandbox não devia ter .claude/aceite.txt aqui"
echo 'tests/Feature/Ai/SchemaEstritoTest.php' > .claude/aceite.txt
roda $D/PHASES.md
[ "$rc" = 1 ] || erro "aceite.txt da 4.2 sem task que cite o SchemaEstritoTest.php devia barrar"
grep -q 'SchemaEstritoTest.php está no aceite.txt e em nenhuma task' "$TMPDIR/saida" || erro "devia apontar o SchemaEstritoTest.php"
sed 's|AC-01, AC-02, AC-03, AC-04\.$|& Regressão: `tests/Feature/Ai/SchemaEstritoTest.php`.|' $D/PHASES.md > "$TMPDIR/PHASES.md"
cp $D/PLAN.md "$TMPDIR/PLAN.md"
grep -q 'Regressão: `tests/Feature/Ai/SchemaEstritoTest.php`' "$TMPDIR/PHASES.md" || erro "o sed do teste não achou a linha Testes: da T04"
roda "$TMPDIR/PHASES.md"
[ "$rc" = 0 ] || { cat "$TMPDIR/saida" >&2; erro "com uma task citando o SchemaEstritoTest.php o padrão devia passar"; }
rm -f .claude/aceite.txt
ok "aceite.txt da 4.2: sem task que cite o SchemaEstritoTest.php, barra; com o caminho no Testes:, passa"

awk '/^## Phase 2/{print "## Notas\n\nrevisar depois\n"} {print}' $D/PHASES.md > "$TMPDIR/PHASES.md"
roda --sem-aceite "$TMPDIR/PHASES.md"
[ "$rc" = 1 ] || erro "## Notas entre fases devia barrar"
grep -q "'## Notas' entre duas fases" "$TMPDIR/saida" || erro "devia apontar o ## Notas"
sed 's/^## Phase 2: /## Phase 2 - /' $D/PHASES.md > "$TMPDIR/PHASES.md"
roda --sem-aceite "$TMPDIR/PHASES.md"
[ "$rc" = 1 ] || erro "heading torto devia barrar"
sed 's/^## Phase 2: /## Phase 3: /' $D/PHASES.md > "$TMPDIR/PHASES.md"
roda --sem-aceite "$TMPDIR/PHASES.md"
[ "$rc" = 1 ] || erro "numeração que pula devia barrar"
grep -q 'fase 3, esperada a fase 2' "$TMPDIR/saida" || erro "devia apontar o salto de numeração"
grep -v 'Testes: `tests/Feature/CadastroMensagemTest.php`' $D/PHASES.md > "$TMPDIR/PHASES.md"
roda --sem-aceite "$TMPDIR/PHASES.md"
[ "$rc" = 1 ] || erro "task sem Testes devia barrar"
grep -q "task 3 da fase 2 sem 'Testes:'" "$TMPDIR/saida" || erro "devia apontar a task 3"
printf '\n### T05: Task a mais só no PLAN\n' >> "$TMPDIR/PLAN.md"
cp $D/PHASES.md "$TMPDIR/PHASES.md"
roda --sem-aceite "$TMPDIR/PHASES.md"
[ "$rc" = 1 ] || erro "PLAN com uma task a mais devia barrar"
grep -q "o PLAN tem 5 tasks" "$TMPDIR/saida" || erro "devia contar as tasks do PLAN"
ok "barra: ## no meio, heading torto, numeração que pula, task sem Testes, PLAN e PHASES divergentes"

# ------------------------------------------------------------------ modelos (para ler e adaptar)
for f in modelo-criterios.md pedir-os-testes.md pedir-o-plan.md exemplo-cadastro/FEATURE-ALVO.antes.md \
         exemplo-cadastro/FEATURE-ALVO.md exemplo-cadastro/CadastroEmailDuplicadoTest.php \
         exemplo-cadastro/cadastro.test.ts exemplo-cadastro/cadastro.ts exemplo-cadastro/test_cadastro.py \
         exemplo-cadastro/cadastro.py exemplo-cadastro/PLAN.md exemplo-cadastro/PHASES.md; do
  [ -f "$AULA/modelos/$f" ] || erro "modelos/$f não existe"
done
[ "$(grep -c '^- AC-0[1-4] \[' "$AULA/modelos/exemplo-cadastro/FEATURE-ALVO.md")" = 4 ] || erro "FEATURE-ALVO.md de exemplo devia ter AC-01 a AC-04"
[ "$(grep -c -- '->todo()' "$AULA/modelos/exemplo-cadastro/CadastroEmailDuplicadoTest.php")" -ge 2 ] || erro "teste Pest devia ter 2 pendentes"
python3 -m py_compile "$AULA/modelos/exemplo-cadastro/cadastro.py" "$AULA/modelos/exemplo-cadastro/test_cadastro.py"
if command -v php >/dev/null; then php -l "$AULA/modelos/exemplo-cadastro/CadastroEmailDuplicadoTest.php" >/dev/null; fi
if python3 -c 'import pytest' 2>/dev/null; then
  cp "$AULA"/modelos/exemplo-cadastro/{cadastro.py,test_cadastro.py} "$TMPDIR/"
  out=$(cd "$TMPDIR" && python3 -m pytest -q -p no:cacheprovider test_cadastro.py 2>&1) || { echo "$out" >&2; erro "pytest do exemplo"; }
  grep -q '2 passed, 2 skipped' <<<"$out" || { echo "$out" >&2; erro "pytest devia dar 2 passed, 2 skipped"; }
  ok "modelos: arquivos presentes, 4 critérios, pytest do exemplo 2 passed, 2 skipped"
else
  ok "modelos: arquivos presentes, 4 critérios, Python compila (pytest ausente: não rodou)"
fi

echo "verificar.sh: $n grupos de checagem passaram."
