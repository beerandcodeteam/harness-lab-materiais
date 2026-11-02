#!/usr/bin/env bash
# verificar.sh · aula 3.1 · roda no ~/projeto da sandbox, depois dos comandos do material.
# Prova que: o backup CLAUDE.old.md foi feito, o CLAUDE.md.exemplo foi instalado e passa no
# filtro, os dois plugins (enxuto@harness-lab e claude-md-management@claude-plugins-official)
# estão instalados, e o filtro.py marca os falsos padrões do CLAUDE.md inchado do projeto falso.
set -euo pipefail

n=0
ok() { n=$((n + 1)); printf '  ok  %s\n' "$1"; }
erro() { printf 'FALHOU: %s\n' "$1" >&2; exit 1; }

# ------------------------------------------------------------------ backup e instalação
[ -s CLAUDE.old.md ] || erro "CLAUDE.old.md não foi criado"
cmp -s CLAUDE.md CLAUDE.old.md || erro "CLAUDE.old.md difere do CLAUDE.md (o backup deveria ser cópia)"
ok "backup CLAUDE.old.md feito antes de cortar"

[ -f CLAUDE.md.exemplo ] || erro "instalar.sh 3.1 não criou o CLAUDE.md.exemplo"
grep -q '^## Comandos' CLAUDE.md.exemplo && grep -q '^## Decisões' CLAUDE.md.exemplo &&
  grep -q '^## Erros que já aconteceram' CLAUDE.md.exemplo && grep -q '^## Onde procurar' CLAUDE.md.exemplo ||
  erro "CLAUDE.md.exemplo sem os quatro blocos do esqueleto"
ok "CLAUDE.md.exemplo instalado com os quatro blocos"

# ------------------------------------------------------------------ plugins
lista=$(claude plugin list 2>&1)
grep -q 'enxuto@harness-lab' <<<"$lista" || erro "enxuto@harness-lab não aparece em claude plugin list"
grep -q 'claude-md-management@claude-plugins-official' <<<"$lista" ||
  erro "claude-md-management@claude-plugins-official não aparece em claude plugin list"
ok "claude plugin list mostra enxuto e claude-md-management"

SK=$(find "$HOME/.claude/plugins/cache" -path '*enxuto*' -name SKILL.md -path '*enxugar-claude-md*' | head -1)
[ -n "$SK" ] || erro "SKILL.md do enxugar-claude-md não está no cache de plugins"
head -1 "$SK" | grep -qx -- '---' || erro "SKILL.md sem frontmatter na primeira linha"
fm=$(awk 'NR==1{next} /^---$/{exit} {print}' "$SK")
grep -q '^name: enxugar-claude-md$' <<<"$fm" || erro "frontmatter sem name: enxugar-claude-md"
grep -q '^disable-model-invocation: true$' <<<"$fm" || erro "a skill grava arquivo: precisa de disable-model-invocation: true"
grep -q '^description: ' <<<"$fm" || erro "frontmatter sem description"
grep -q 'CLAUDE_SKILL_DIR}/scripts/filtro.py' "$SK" || erro "SKILL.md não chama o filtro.py por \${CLAUDE_SKILL_DIR}"
F="$(dirname "$SK")/scripts/filtro.py"
[ -x "$F" ] || erro "filtro.py não está executável no cache do plugin"
ok "skill /enxugar-claude-md com frontmatter válido e filtro.py executável"

CMD=$(find "$HOME/.claude/plugins/cache" -path '*claude-md-management*' -name revise-claude-md.md | head -1)
[ -n "$CMD" ] || erro "comando /revise-claude-md não está no cache"
SK2=$(find "$HOME/.claude/plugins/cache" -path '*claude-md-management*' -path '*claude-md-improver*' -name SKILL.md | head -1)
[ -n "$SK2" ] || erro "skill claude-md-improver não está no cache"
ok "claude-md-management traz /revise-claude-md e a skill claude-md-improver"

# ------------------------------------------------------------------ filtro no CLAUDE.md inchado
J=$(python3 -I "$F" . --json)
tem() { jq -e --arg c "$1" '[.arquivos[] | select(.arquivo == "CLAUDE.md") | .marcas[].categoria] | index($c)' \
  <<<"$J" >/dev/null || erro "filtro.py não marcou a categoria $1 no CLAUDE.md inchado"; }
for c in framework arvore estilo generico enfase historia procedimento; do tem "$c"; done
jq -e '.arquivos[] | select(.arquivo == "modules/pagamentos/CLAUDE.md") | .quando_carrega | test("subpasta")' \
  <<<"$J" >/dev/null || erro "filtro.py não achou o CLAUDE.md de subpasta"
jq -e '.linhas_no_contexto_toda_sessao == 69' <<<"$J" >/dev/null ||
  erro "linhas em toda sessão: esperado 69, veio $(jq .linhas_no_contexto_toda_sessao <<<"$J")"
ok "filtro.py marca framework, árvore, estilo, genérico, ênfase, história e procedimento; acha a subpasta"

# a linha que fica não pode ser marcada
jq -e '[.arquivos[] | select(.arquivo == "CLAUDE.md") | .marcas[] | select(.texto | test("app/Actions|centavos|sail artisan test"))] | length == 0' \
  <<<"$J" >/dev/null || erro "filtro.py marcou linha que deveria ficar (Actions, centavos ou comando)"
ok "linhas que ficam (comando, decisão) não são marcadas"

# ------------------------------------------------------------------ o exemplo passa no próprio filtro
T=$(mktemp -d)
cp CLAUDE.md.exemplo "$T/CLAUDE.md"
JE=$(python3 -I "$F" "$T" --json)
jq -e '.total_marcas == 0' <<<"$JE" >/dev/null || erro "o CLAUDE.md.exemplo tem linha marcada: $(jq -c '.arquivos[0].marcas' <<<"$JE")"
ctx=$(jq '.arquivos[0].linhas_no_contexto' <<<"$JE")
tot=$(jq '.arquivos[0].linhas' <<<"$JE")
[ "$ctx" -lt 200 ] && [ "$ctx" -lt "$tot" ] || erro "exemplo: $ctx linhas no contexto de $tot (comentário HTML devia sair)"
ok "CLAUDE.md.exemplo: 0 marcas, $ctx linhas no contexto de $tot no arquivo (comentário HTML não conta)"

# ------------------------------------------------------------------ casos de borda do filtro
printf '# x\n- linha\n' > "$T/AGENTS.md"
printf -- '- prefiro respostas curtas\n' > "$T/CLAUDE.local.md"
printf 'Veja @docs/nao-existe.md\n' >> "$T/CLAUDE.md"
git -C "$T" init -q
JB=$(python3 -I "$F" "$T" --json)
jq -e '.avisos | map(test("AGENTS.md")) | any' <<<"$JB" >/dev/null || erro "sem aviso de AGENTS.md ignorado"
jq -e '.avisos | map(test("gitignore")) | any' <<<"$JB" >/dev/null || erro "sem aviso de CLAUDE.local.md fora do .gitignore"
jq -e '.avisos | map(test("nao-existe")) | any' <<<"$JB" >/dev/null || erro "sem aviso de @import quebrado"
printf 'CLAUDE.local.md\n' > "$T/.gitignore"
JB=$(python3 -I "$F" "$T" --json)
jq -e '.avisos | map(test("gitignore")) | any | not' <<<"$JB" >/dev/null || erro "avisou do .gitignore com CLAUDE.local.md ignorado"
rm "$T/CLAUDE.md" "$T/CLAUDE.local.md"
JB=$(python3 -I "$F" "$T" --json)
jq -e '.arquivos[] | select(.arquivo == "AGENTS.md") | .quando_carrega | test("no lugar")' <<<"$JB" >/dev/null ||
  erro "sem CLAUDE.md, o AGENTS.md devia aparecer como lido no lugar"
rm -rf "$T"
ok "avisos: AGENTS.md ignorado com CLAUDE.md, CLAUDE.local.md fora do .gitignore, @import quebrado"

echo "verificar.sh: $n grupos de checagem passaram."
