#!/usr/bin/env bash
# verificar.sh · aula 4.2 · roda no ~/projeto da sandbox, depois dos comandos do material.
# Prova que o guarda-aceite.py foi instalado e ligado (somado ao settings que o projeto já
# tinha), que ele responde certo a JSON falso igual ao que o Claude Code manda, que o
# contrato do schema pega o caso da aula, que o smoke grava num arquivo que o dublê de borda
# não usa como pior caso, e que os modelos copiados estão íntegros.
# Nenhuma chamada de rede sai daqui.
set -euo pipefail

n=0
ok() { n=$((n + 1)); printf '  ok  %s\n' "$1"; }
erro() { printf 'FALHOU: %s\n' "$1" >&2; exit 1; }
AULA="$HOME/harness-lab-materiais/modulo-4-prova/aula-4.2-o-teste-verde-que-mente"
M="$AULA/modelos"
TMPDIR=$(mktemp -d)
export TMPDIR

# ------------------------------------------------------------------ instalação
H=.claude/hooks/guarda-aceite.py
[ -f "$H" ] || erro "$H não instalado"
cmp -s "$H" "$AULA/projeto/.claude/hooks/guarda-aceite.py" || erro "$H diferente do da aula"
cmp -s .claude/aceite.exemplo.txt "$AULA/projeto/.claude/aceite.exemplo.txt" || erro "aceite.exemplo.txt não instalado"
grep -qx 'tests/Feature/Ai/SchemaEstritoTest.php' .claude/aceite.exemplo.txt || erro "aceite.exemplo.txt sem o contrato do slide"
python3 -m py_compile "$H"
S=.claude/settings.json
jq -e '.hooks.PreToolUse[] | select(.matcher == "Edit|Write|MultiEdit") | .hooks[]
       | select(.command | test("guarda-aceite.py"))' "$S" >/dev/null || erro "guarda-aceite.py não ligado no PreToolUse"
jq -e '.permissions.allow | index("Bash(php artisan test *)")' "$S" >/dev/null ||
  erro "o instalar.sh apagou a permissão que o projeto já tinha"
[ -f "$S.antes-harness-lab" ] || erro "sem o backup do settings.json"
ok "hook instalado igual ao da aula, ligado em Edit|Write|MultiEdit, settings somado (o allow antigo ficou)"

T=tests/Feature/Ai/SchemaEstritoTest.php
grep -qx "$T" .claude/aceite.txt || erro ".claude/aceite.txt sem a linha $T"
for f in SchemaEstritoTest.php SmokeOpenAiTest.php DubleNaBordaHttpTest.php; do
  cmp -s "tests/Feature/Ai/$f" "$M/laravel/$f" || erro "tests/Feature/Ai/$f não copiado do modelo"
done
G=tests/Fixtures/openai/gravada/analisa-produto.json
cmp -s "$G" "$M/laravel/gravada/analisa-produto.json" || erro "gravada não copiada para $G"
[ "$(find tests/Fixtures -type f | wc -l)" = 1 ] || erro "tests/Fixtures devia ter só a gravada"
cmp -s tests/test_smoke_openai.py "$M/python/test_smoke_openai.py" || erro "smoke Python não copiado"
ok "aceite.txt lista o contrato; contrato, smoke, dublê e a gravada copiados dos modelos"

# ------------------------------------------------------------------ guarda-aceite.py
export CLAUDE_PROJECT_DIR="$PWD"
# roda JSON: guarda rc e err
roda() {
  set +e
  printf '%s' "$1" | python3 "$H" 2>"$TMPDIR/err"
  rc=$?
  set -e
  err=$(cat "$TMPDIR/err")
}
edit() {   # edit ARQUIVO OLD NEW
  jq -nc --arg f "$1" --arg o "$2" --arg n "$3" \
    '{hook_event_name: "PreToolUse", tool_name: "Edit", tool_input: {file_path: $f, old_string: $o, new_string: $n}}'
}
write() {  # write ARQUIVO
  jq -nc --arg f "$1" '{hook_event_name: "PreToolUse", tool_name: "Write", tool_input: {file_path: $f, content: "<?php"}}'
}

roda "$(edit "$T" 'expect(chavesForaDoRequired($schema))->toBe([]);' 'expect(chavesForaDoRequired($schema))->toBeArray();')"
[ "$rc" = 2 ] || erro "mudar o assert do teste protegido devia dar exit 2 (veio $rc)"
grep -q 'Bloqueado' <<<"$err" && grep -q 'aceite.txt' <<<"$err" || erro "bloqueio sem motivo no stderr: $err"
roda "$(edit "$PWD/$T" 'toBe([])' 'toBe(["product.name"])')"
[ "$rc" = 2 ] || erro "caminho absoluto do teste protegido devia bloquear (veio $rc)"
roda "$(write "$T")"
[ "$rc" = 2 ] || erro "Write sobre o teste protegido devia bloquear (veio $rc)"
roda "$(jq -nc --arg f "$T" '{tool_name: "MultiEdit", tool_input: {file_path: $f, edits: [
       {old_string: "})->todo();", new_string: "});"}, {old_string: "toBe([])", new_string: "toBeArray()"}]}}')"
[ "$rc" = 2 ] || erro "MultiEdit que tira o todo e muda o assert devia bloquear (veio $rc)"
ok "teste protegido: mudar assert, Write por cima e MultiEdit misturado voltam exit 2 com o motivo"

roda "$(edit "$T" "    expect(\$x)->toBe(1);
})->todo();" "    expect(\$x)->toBe(1);
});")"
[ "$rc" = 0 ] || erro "tirar o ->todo() devia passar (veio $rc: $err)"
roda "$(edit app/Cadastro.php '// Código' '// Código da feature')"
[ "$rc" = 0 ] || erro "editar o código da feature devia passar (veio $rc)"
roda "$(write tests/Feature/Ai/NovoTest.php)"
[ "$rc" = 0 ] || erro "criar teste fora da lista devia passar (veio $rc)"
roda "$(jq -nc '{tool_name: "Bash", tool_input: {command: "php artisan test"}}')"
[ "$rc" = 0 ] || erro "Bash não é com este hook (veio $rc)"
roda 'isto não é JSON'
[ "$rc" = 2 ] || erro "entrada ilegível devia bloquear (veio $rc)"
ok "libera tirar o marcador, o código da feature, teste novo e Bash; JSON ilegível bloqueia"

rm .claude/aceite.txt
roda "$(edit "$T" 'toBe([])' 'toBeArray()')"
[ "$rc" = 0 ] || erro "sem aceite.txt o hook não devia bloquear nada (veio $rc)"
echo "$T" > .claude/aceite.txt
ok "sem .claude/aceite.txt o hook não faz nada (por isso o passo de listar o teste)"

# ------------------------------------------------------------------ contrato do schema
set +e
saida=$(python3 -I "$M/schema_estrito.py" "$M/fixtures/schema-antes.json"); r1=$?
python3 -I "$M/schema_estrito.py" "$M/fixtures/schema-depois.json" >/dev/null; r2=$?
corpo=$(jq -c '{model: "x", text: {format: {type: "json_schema", name: "schema_definition", strict: true, schema: .}}}' \
        "$M/fixtures/schema-antes.json")
printf '%s' "$corpo" | python3 -I "$M/schema_estrito.py" - >/dev/null; r3=$?
set -e
[ "$r1" = 1 ] && [ "$r2" = 0 ] && [ "$r3" = 1 ] || erro "schema_estrito.py: esperado 1, 0, 1 (veio $r1, $r2, $r3)"
[ "$(grep -c 'fora do required$' <<<"$saida")" = 6 ] || erro "schema-antes devia dar 6 campos"
for c in product.name similar_products[].reason recommendation.decision; do
  grep -qF "  $c fora do required" <<<"$saida" || erro "faltou $c na saída"
done
ok "schema_estrito.py: 6 campos no schema do caso (exit 1), ok no corrigido, e lê o corpo do pedido da Responses API"

# ------------------------------------------------------------------ gravada e borda
# A gravada é o que uma chamada real devolve: a forma, não o pior caso. O respostaDeBorda()
# do dublê lê o texto da última saída (como o laravel/ai) e injeta o pior caso por cima.
jq -e '.output[-1].content[0].text | fromjson
       | keys == ["product", "recommendation", "similar_products", "summary"]' "$G" >/dev/null ||
  erro "gravada sem a forma da Responses API ou sem as quatro chaves"
D="$M/laravel/DubleNaBordaHttpTest.php"; S="$M/laravel/SmokeOpenAiTest.php"
grep -qF "base_path('tests/Fixtures/openai/gravada/analisa-produto.json')" "$S" || erro "smoke não grava na gravada"
grep -oE 'tests/Fixtures/openai/[A-Za-z0-9_./-]*' "$S" | grep -qv '^tests/Fixtures/openai/gravada/' &&
  erro "o smoke só pode escrever em tests/Fixtures/openai/gravada/"
grep -qF "base_path('tests/Fixtures/openai/gravada/analisa-produto.json')" "$D" || erro "dublê não lê a gravada"
grep -qF 'function respostaDeBorda()' "$D" || erro "dublê sem a versão de borda"
grep -qF "str_repeat(" "$D" && grep -qF "['category'] = null" "$D" && grep -qF "['decision'] = null" "$D" ||
  erro "versão de borda sem texto longo ou sem null"
[ "$(grep -c "^it('" "$D")" = 3 ] || erro "dublê devia ter três casos: gravada, borda e 400"
ok "gravada com a forma real; o smoke só escreve nela; a borda (texto longo, null) fica no dublê, com três casos"

# ------------------------------------------------------------------ spec
I="$M/integracao-na-spec.md"
grep -qx '## Pontos de fora' "$I" || erro "integracao-na-spec.md sem o bloco Pontos de fora"
grep -qx '> antes do plano, rode um smoke real do ponto de fora e liste os campos' "$I" || erro "sem o pedido de sessão"
[ "$(grep -cE '^- AC-0[5-9] \[(Evento|Estado|Condição|Indesejado)\] ' "$I")" = 5 ] ||
  erro "exemplo preenchido devia ter 5 critérios no formato da 4.3"
[ "$(grep -cE '^  - (Confere|Teste): ' "$I")" -ge 20 ] || erro "cada critério precisa de Confere e Teste"
ok "integracao-na-spec.md: bloco Pontos de fora, pedido de sessão e 5 critérios no formato da 4.3"

# ------------------------------------------------------------------ modelos

grep -qF -- "->group('integration')" "$M/laravel/SmokeOpenAiTest.php" || erro "smoke Pest fora do grupo integration"
grep -q "blank(config('ai.providers.openai.key'))" "$M/laravel/SmokeOpenAiTest.php" || erro "smoke Pest sem o skip sem chave"
grep -q 'Http::preventStrayRequests()' "$M/laravel/DubleNaBordaHttpTest.php" || erro "dublê sem preventStrayRequests"
python3 - "$M/laravel/phpunit-groups.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
r = ET.parse(sys.argv[1]).getroot()
assert r.tag == "groups" and [g.text for g in r.iter("group")] == ["integration"], "phpunit-groups.xml"
PY
python3 -m py_compile "$M/python/test_smoke_openai.py"
python3 - "$M/python/pyproject-integration.toml" <<'PY'
import sys, tomllib
c = tomllib.load(open(sys.argv[1], "rb"))["tool"]["pytest"]["ini_options"]
assert c["addopts"] == "-m 'not integration'" and c["markers"][0].startswith("integration:"), c
PY
if command -v php >/dev/null; then
  for f in "$M"/laravel/*.php; do php -l "$f" >/dev/null || erro "sintaxe PHP: $f"; done
  ok "modelos: grupo integration e skip sem chave, XML e TOML válidos, PHP e Python sem erro de sintaxe"
else
  ok "modelos: grupo integration e skip sem chave, XML e TOML válidos, Python sem erro (sem php para o -l)"
fi

echo "verificar.sh: $n grupos de checagem passaram."
