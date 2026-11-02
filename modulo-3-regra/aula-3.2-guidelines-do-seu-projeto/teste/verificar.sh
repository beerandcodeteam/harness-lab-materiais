#!/usr/bin/env bash
# verificar.sh · aula 3.2 · roda no ~/projeto da sandbox, depois dos comandos do material.
# Prova que o plugin boostify foi instalado pelo marketplace harness-lab, que a skill tem o
# frontmatter certo e que o detecta.py lê a stack do jeito que a skill espera:
# versão instalada do lockfile, Laravel detectado (para a skill parar), bloco existente achado.
# O ~/projeto é o teste/projeto: um projeto Python falso (uv.lock, Makefile, CI, CLAUDE.md do time).
set -euo pipefail

n=0
ok() { n=$((n + 1)); printf '  ok  %s\n' "$1"; }
erro() { printf 'FALHOU: %s\n' "$1" >&2; exit 1; }

# ------------------------------------------------------------------ plugin
lista=$(claude plugin list --json)
jq -e '.[] | select(.id == "boostify@harness-lab") | select(.enabled == true)' <<<"$lista" >/dev/null ||
  erro "boostify@harness-lab não aparece habilitado em claude plugin list: $lista"
raiz=$(jq -r '.[] | select(.id == "boostify@harness-lab") | .installPath' <<<"$lista")
[ -d "$raiz" ] || erro "installPath do plugin não existe: $raiz"
ok "claude plugin list: boostify@harness-lab instalado e habilitado"

S="$raiz/skills/boostify"
[ -f "$S/SKILL.md" ] && [ -f "$S/scripts/detecta.py" ] && [ -f "$S/references/modelo-bloco.md" ] ||
  erro "faltam arquivos da skill em $S"
fm=$(awk 'NR==1 && /^---$/ {f=1; next} f && /^---$/ {exit} f' "$S/SKILL.md")
grep -qx 'name: boostify' <<<"$fm" || erro "frontmatter sem name: boostify"
grep -qx 'disable-model-invocation: true' <<<"$fm" || erro "a skill escreve arquivo: precisa de disable-model-invocation"
grep -q '^description: .\{40,\}' <<<"$fm" || erro "description curta ou ausente"
grep -q 'CLAUDE_SKILL_DIR' "$S/SKILL.md" || erro "o SKILL.md não usa \${CLAUDE_SKILL_DIR} para achar o script"
ok "skill com os 3 arquivos, name, description e disable-model-invocation: true"

# ------------------------------------------------------------------ detecta.py no projeto do aluno
D="$S/scripts/detecta.py"
antes=$(git status --porcelain; find . -newer .git/HEAD -type f -not -path "./.git/*" | sort)
j=$(python3 -I "$D" .)
jq -e '.linguagens == ["python"] and .gerenciador == "uv" and .laravel == false' <<<"$j" >/dev/null ||
  erro "detecção errada da stack: $j"
jq -e '.pacotes[] | select(.nome == "torch" and .maior == "2" and (.origem | test("instalada")))' \
  <<<"$j" >/dev/null || erro "torch 2.5.1 do uv.lock não saiu como versão instalada"
jq -e '.pacotes[] | select(.nome == "fastapi" and .maior == "0.115")' <<<"$j" >/dev/null ||
  erro "pacote 0.x deveria ter a versão menor como 'maior' (0.115)"
jq -e '.ci | index("uv run pytest -q")' <<<"$j" >/dev/null || erro "comando do CI não detectado"
jq -e '.arquivos_agente["CLAUDE.md"] | .bloco_boostify == false and .linhas > 0' <<<"$j" >/dev/null ||
  erro "CLAUDE.md do time não detectado"
depois=$(git status --porcelain; find . -newer .git/HEAD -type f -not -path "./.git/*" | sort)
[ "$antes" = "$depois" ] || erro "o detecta.py escreveu no projeto (deveria só ler)"
ok "projeto Python: uv, versões do uv.lock, comandos do CI, CLAUDE.md do time, nada escrito"

T=$(mktemp -d)
printf '{"require": {"laravel/framework": "^13.0"}}\n' > "$T/composer.json"
python3 -I "$D" "$T" | jq -e '.laravel == true' >/dev/null || erro "projeto Laravel não detectado"
ok "projeto Laravel: laravel=true (a skill para e manda usar o Laravel Boost)"

mkdir -p "$T/next/node_modules/next"
printf '{"dependencies": {"next": "^15.0.0"}}\n' > "$T/next/package.json"
printf '{"version": "15.2.4"}\n' > "$T/next/node_modules/next/package.json"
printf '<boostify-guidelines>\n=== base ===\n</boostify-guidelines>\n\n# do time\n' > "$T/next/CLAUDE.md"
jn=$(python3 -I "$D" "$T/next")
jq -e '.pacotes[] | select(.nome == "next" and .versao == "15.2.4" and (.origem | test("instalada")))' \
  <<<"$jn" >/dev/null || erro "Next: versão do node_modules deveria vencer a do package.json"
jq -e '.arquivos_agente["CLAUDE.md"].bloco_boostify == true' <<<"$jn" >/dev/null ||
  erro "bloco boostify existente não detectado (a segunda rodada precisa trocar só o bloco)"
ok "projeto Next: versão do node_modules (instalada), bloco boostify existente achado"

mkdir -p "$T/lock"
printf '{"dependencies": {"next": "^15.0.0"}}\n' > "$T/lock/package.json"
printf '{"packages": {"node_modules/next": {"version": "15.1.3"}}}\n' > "$T/lock/package-lock.json"
python3 -I "$D" "$T/lock" | jq -e '.pacotes[] | select(.nome == "next" and .versao == "15.1.3"
  and (.origem | test("instalada")))' >/dev/null || erro "Next sem node_modules: package-lock.json não lido"
ok "projeto Next sem node_modules: versão do package-lock.json (instalada)"

printf '<laravel-boost-guidelines>\n</laravel-boost-guidelines>\n' > "$T/next/CLAUDE.md"
python3 -I "$D" "$T/next" | jq -e '.arquivos_agente["CLAUDE.md"].bloco_laravel_boost == true' >/dev/null ||
  erro "bloco do Laravel Boost não detectado"
ok "CLAUDE.md com <laravel-boost-guidelines>: detectado (os dois blocos não convivem)"
rm -rf "$T"

# ------------------------------------------------------------------ modelos da aula
M=~/harness-lab-materiais/modulo-3-regra/aula-3.2-guidelines-do-seu-projeto/modelos
for r in "$M"/rules/*.md; do
  head -1 "$r" | grep -qx -- '---' || erro "$r sem frontmatter"
  awk 'NR>1 && /^---$/ {exit} NR>1' "$r" | grep -q '^paths:' || erro "$r sem paths:"
done
[ -f "$M/ai-guidelines/decisoes.md" ] || erro "modelo de .ai/guidelines ausente"
ok "modelos: rules com paths: no frontmatter e o modelo de .ai/guidelines"

if [ -f .claude/rules/testes.md ]; then
  cmp -s .claude/rules/testes.md "$M/rules/testes.md" || erro ".claude/rules/testes.md diferente do modelo"
  ok "rule copiada para .claude/rules/testes.md"
fi

echo "verificar.sh: $n grupos de checagem passaram."
