#!/usr/bin/env bash
# verificar.sh · aula 1.5 · roda no ~/projeto da sandbox, depois dos comandos do material.
# Prova: o instalar.sh pôs o modelo do FEATURE-ALVO.md na raiz, com os mesmos títulos que o
# Módulo 4 usa; o commit e o exclude do material funcionam; o plugin feature-alvo aparece no
# Claude Code com a skill válida; os três scripts do plugin fazem o que o material diz e
# só leem; o pedido e a tabela de exemplos estão no repositório.
set -euo pipefail

n=0
ok() { n=$((n + 1)); printf '  ok  %s\n' "$1"; }
erro() { printf 'FALHOU: %s\n' "$1" >&2; exit 1; }
REPO="$HOME/harness-lab-materiais"
AULA="$REPO/modulo-1-o-operador-e-o-trilho/aula-1.5-escolha-sua-feature-alvo"
F=FEATURE-ALVO.md
T=$(mktemp -d)

# ---------------------------------------------------------------- modelo na raiz
[ -f "$F" ] || erro "$F não foi criado pelo instalar.sh"
cmp -s "$F" "$AULA/projeto/$F" || erro "$F na raiz difere do modelo da aula"
titulos() { grep -E '^#{1,2} ' "$1"; }
[ "$(titulos "$F")" = "$(titulos "$AULA/modelos/FEATURE-ALVO.exemplo.md")" ] ||
  erro "os títulos do modelo e do exemplo preenchido não batem"
[ "$(grep -c '^## ' "$F")" -eq 6 ] || erro "o modelo deveria ter 6 seções"
[ "$(grep -c '^- \[ \] Quando <ação>, então' "$F")" -eq 3 ] || erro "o modelo deveria ter 3 critérios para preencher"
for x in "$F" "$AULA/modelos/FEATURE-ALVO.exemplo.md"; do
  if grep -qE 'AC-[0-9]' "$x"; then erro "$x tem AC-NN: o confere-phases do Módulo 5 leria como critério"; fi
done
ok "FEATURE-ALVO.md na raiz: 6 seções, 3 critérios, mesmos títulos do exemplo, sem AC-NN"

git ls-files --error-unmatch "$F" >/dev/null 2>&1 || erro "$F não entrou no commit"
git log -1 --format=%s | grep -q 'feature-alvo' || erro "o último commit não é o do material"
grep -qxF "/$F" .git/info/exclude || erro "/$F não está no .git/info/exclude"
git check-ignore --no-index -q "$F" || erro "a linha do exclude não casa com $F"
[ -z "$(git status --porcelain)" ] || erro "árvore suja depois do commit e do exclude"
ok "commit e exclude: o arquivo versionado, a regra do exclude casa, árvore limpa"

# ---------------------------------------------------------------- plugin
claude plugin list 2>&1 | grep -q 'feature-alvo' || erro "plugin não aparece em claude plugin list"
SK=$(find "$HOME/.claude/plugins" -path '*feature-alvo*' -name SKILL.md | head -1)
[ -n "$SK" ] || erro "SKILL.md do plugin não está no cache de plugins"
[ "$(head -1 "$SK")" = "---" ] || erro "SKILL.md sem frontmatter na primeira linha"
fm=$(awk 'NR == 1 { next } /^---$/ { exit } { print }' "$SK")
grep -q '^name: feature-alvo$' <<<"$fm" || erro "frontmatter sem name"
grep -q '^description: .\{80,\}' <<<"$fm" || erro "frontmatter sem description"
grep -q '^disable-model-invocation: true$' <<<"$fm" || erro "a skill deveria ser só manual"
DIR=$(dirname "$SK")
for rel in $(grep -oE 'CLAUDE_SKILL_DIR\}/[A-Za-z0-9_./-]+' "$SK" | sed 's|^CLAUDE_SKILL_DIR}/||' | sort -u); do
  [ -f "$DIR/$rel" ] || erro "SKILL.md cita $rel, que não veio no plugin"
done
for s in candidatas area confere; do
  [ -x "$DIR/scripts/$s.sh" ] || erro "scripts/$s.sh sem chmod +x no plugin instalado"
  grep -q "scripts/$s.sh" <<<"$fm" || erro "allowed-tools sem o $s.sh"
done
cmp -s "$DIR/references/modelo.md" "$AULA/projeto/$F" || erro "references/modelo.md difere do modelo da aula"
cmp -s "$DIR/references/exemplo-preenchido.md" "$AULA/modelos/FEATURE-ALVO.exemplo.md" ||
  erro "references/exemplo-preenchido.md difere de modelos/FEATURE-ALVO.exemplo.md"
ok "plugin instalado, skill /feature-alvo manual, todo arquivo citado existe, modelo e exemplo iguais aos da aula"

# ---------------------------------------------------------------- confere.sh
C="$DIR/scripts/confere.sh"
out=$("$C" "$AULA/modelos/FEATURE-ALVO.exemplo.md") || erro "confere.sh reprovou o exemplo preenchido: $out"
grep -q 'critérios de aceite: 4' <<<"$out" || erro "confere.sh não contou os 4 critérios do exemplo"
grep -q '^resultado: ok' <<<"$out" || erro "confere.sh sem 'resultado: ok' no exemplo"
"$C" "$AULA/teste/casos/FEATURE-ALVO.modulo-4.md" >/dev/null || erro "confere.sh reprovou o formato AC-NN do Módulo 4"
set +e; out=$("$C"); rc=$?; set -e
[ "$rc" -eq 1 ] || erro "confere.sh deveria reprovar o modelo vazio (saiu $rc)"
[ "$(grep -c 'espaço do modelo sobrando' <<<"$out")" -eq 7 ] || erro "confere.sh não achou os 7 espaços do modelo"
[ "$(grep -c 'peneira sem marcar' <<<"$out")" -eq 5 ] || erro "confere.sh não achou as 5 peneiras sem marcar"
{
  printf '# Feature-alvo · Harness Lab\n\n## Descrição\nFiltro de busca.\n\n'
  printf '## Por que é pequena\nUma tela.\n\n## Critérios de aceite (rascunho)\n'
  printf -- '- [ ] A busca fica mais rápida.\n'
  printf -- '- [ ] Quando abro a lista, então o campo `<input type="search">` já vem com foco.\n\n'
  printf '## Como eu verificaria hoje, na mão\nAbro a lista.\n\n## Riscos\n- Nenhum.\n\n## Cinco peneiras\n'
  printf -- '- [x] Pequena: cabe em poucas fases.\n- [ ] Verificável: cada critério tem resposta sim ou não.\n'
  printf -- '- [x] Isolada: não exige mexer em metade do sistema.\n- [x] Valor real: eu faria isso de qualquer jeito.\n'
  printf -- '- [x] Sem terceiro instável: dá para provar sem serviço de fora.\n'
} >"$T/ruim.md"
set +e; out=$("$C" "$T/ruim.md"); rc=$?; set -e
[ "$rc" -eq 1 ] || erro "confere.sh deveria reprovar o arquivo ruim (saiu $rc)"
grep -q 'critérios de aceite: 2' <<<"$out" || erro "confere.sh não reprovou 2 critérios"
grep -q 'palavra vaga "rápida"' <<<"$out" || erro "confere.sh não avisou a palavra vaga"
grep -q 'peneira sem marcar: Verificável' <<<"$out" || erro "confere.sh não pegou a peneira sem marcar"
if grep -q 'espaço do modelo' <<<"$out"; then erro "confere.sh confundiu código entre crases com espaço do modelo"; fi
set +e; "$C" "$T/nao-existe.md" >/dev/null; rc=$?; set -e
[ "$rc" -eq 1 ] || erro "confere.sh deveria sair com 1 sem o arquivo"
ok "confere.sh: aprova o exemplo e o formato do Módulo 4; reprova o modelo vazio e o arquivo ruim pelos motivos certos"

# ---------------------------------------------------------------- candidatas.sh e area.sh
antes=$(git status --porcelain; git rev-parse HEAD; cat .git/info/exclude)
out=$(CLAUDE_PROJECT_DIR="$PWD" "$DIR/scripts/candidatas.sh" 20)
for s in '## Últimos 20 commits' '## Branches locais' '## Marcados para depois' '## Arquivos mais mexidos' '## Testes'; do
  grep -q "^$s" <<<"$out" || erro "candidatas.sh sem a seção $s"
done
grep -q 'CadastroController.php:[0-9]*: *// FIXME' <<<"$out" || erro "candidatas.sh não listou o FIXME do cadastro"
grep -q 'Frete.php:[0-9]*: *// TODO' <<<"$out" || erro "candidatas.sh não listou o TODO do frete"
grep -q '^1 arquivo(s) de teste' <<<"$out" || erro "candidatas.sh não contou o arquivo de teste"
out=$(CLAUDE_PROJECT_DIR="$PWD" "$DIR/scripts/area.sh" email)
grep -q '^## 4 arquivo(s) falam da área: 3 de código, 1 de teste' <<<"$out" || erro "area.sh email contou errado: $out"
grep -q '^app/Http/Controllers/CadastroController.php$' <<<"$out" || erro "area.sh não listou o controller"
git ls-files --error-unmatch vendor/acme/mailer/src/Mailer.php >/dev/null 2>&1 || erro "o vendor/ do projeto falso deveria estar versionado"
if grep -q '^vendor/' <<<"$out"; then erro "area.sh contou o vendor/ versionado"; fi
out=$(CLAUDE_PROJECT_DIR="$PWD" "$DIR/scripts/area.sh" frete correios)
grep -q 'Frete.php:[0-9]*:.*Http::get' <<<"$out" || erro "area.sh não apontou a chamada externa do frete"
grep -q 'Nenhum teste fala dessa área' <<<"$out" || erro "area.sh não avisou que a área não tem teste"
depois=$(git status --porcelain; git rev-parse HEAD; cat .git/info/exclude)
[ "$antes" = "$depois" ] || erro "candidatas.sh ou area.sh alteraram o repositório"
fora=$(cd "$T" && CLAUDE_PROJECT_DIR="$T" "$DIR/scripts/candidatas.sh")
grep -q 'não é um repositório git' <<<"$fora" || erro "candidatas.sh fora de repositório deveria só avisar"
set +e; "$DIR/scripts/candidatas.sh" abc >/dev/null 2>&1; rc=$?; "$DIR/scripts/area.sh" >/dev/null 2>&1; rc2=$?; set -e
[ "$rc" -eq 2 ] && [ "$rc2" -eq 2 ] || erro "uso errado deveria sair com 2 ($rc, $rc2)"
ok "candidatas.sh e area.sh: acham commits, marcadores, testes, a área (sem o vendor/) e a pista de terceiro, sem alterar nada"

# ---------------------------------------------------------------- pedido e tabela de exemplos
P="$AULA/modelos/pedido-feature-alvo.md"
[ -f "$P" ] || erro "modelos/pedido-feature-alvo.md não veio no clone"
for w in pequena verificável isolada 'valor real' 'terceiro instável' FEATURE-ALVO.md 'plan mode on'; do
  grep -qi "$w" "$P" || erro "o pedido não fala de: $w"
done
X="$DIR/references/exemplos.md"
linhas=$(grep -cE '^\| (Backend|Front-end|Legado|IA|Qualquer) \|' "$X")
[ "$linhas" -ge 12 ] || erro "a tabela de exemplos tem só $linhas linhas"
ruins=$(grep -E '^\| (Backend|Front-end|Legado|IA|Qualquer) \|' "$X" | awk -F' \\| ' '{print $3}' |
  tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep -vxE 'pequena|verificável|isolada|valor real|sem terceiro' || true)
[ -z "$ruins" ] || erro "peneira desconhecida na tabela de exemplos: $ruins"
for p in pequena verificável isolada 'valor real' 'sem terceiro'; do
  grep -E '^\| (Backend|Front-end|Legado|IA|Qualquer) \|' "$X" | awk -F' \\| ' '{print $3}' | grep -q "$p" ||
    erro "nenhum exemplo cai na peneira $p"
done
ok "pedido com as cinco peneiras; tabela com $linhas exemplos cobrindo as cinco peneiras"

rm -rf "$T"
echo "verificar.sh: $n grupos ok"
