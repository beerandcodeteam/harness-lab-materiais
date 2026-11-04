#!/usr/bin/env bash
# testa-guarda.sh · aula 4.2 · teste o guarda-aceite.py ANTES de confiar nele
# Manda JSON de PreToolUse no stdin, igual ao que o Claude Code manda, e confere o exit code.
# Mesmo padrão do testa-hooks.sh da aula 2.4. Precisa de jq e python3.
# Uso, na raiz do seu projeto, depois do instalar.sh 4.2:
#   bash <esta pasta>/testa-guarda.sh [caminho do hook]   (padrão: .claude/hooks/guarda-aceite.py)
# Não mexe no seu projeto: monta um projeto falso numa pasta temporária.
set -uo pipefail
alvo="${1:-.claude/hooks/guarda-aceite.py}"
[ -f "$alvo" ] || { echo "hook não encontrado: $alvo (rode na raiz do projeto, depois do instalar.sh 4.2)" >&2; exit 1; }
hook="$(cd "$(dirname "$alvo")" && pwd)/$(basename "$alvo")"
proj=$(mktemp -d); trap 'rm -rf "$proj"' EXIT
mkdir -p "$proj/.claude" "$proj/tests/Feature" "$proj/tests/e2e"
cat > "$proj/.claude/aceite.txt" <<'EOF'
# testes de aceite da feature-alvo
tests/Feature/CadastroEmailDuplicadoTest.php
tests/test_cadastro.py
tests/e2e/*.test.ts
EOF
touch "$proj/tests/Feature/CadastroEmailDuplicadoTest.php" "$proj/tests/test_cadastro.py" "$proj/tests/e2e/cadastro.test.ts"
ok=0; ruim=0

edit_json() {   # edit_json ARQUIVO OLD NEW
  jq -nc --arg f "$1" --arg o "$2" --arg n "$3" --arg cwd "$proj" \
    '{hook_event_name:"PreToolUse", tool_name:"Edit", cwd:$cwd, tool_input:{file_path:$f, old_string:$o, new_string:$n}}'; }
write_json() {  # write_json ARQUIVO
  jq -nc --arg f "$1" --arg cwd "$proj" \
    '{hook_event_name:"PreToolUse", tool_name:"Write", cwd:$cwd, tool_input:{file_path:$f, content:"<?php // novo"}}'; }

caso() {   # caso "descrição" JSON libera|bloqueia
  local desc="$1" json="$2" esperado="$3" erro codigo obtido
  erro=$(env -u CLAUDE_PROJECT_DIR python3 -I "$hook" <<<"$json" 2>&1 >/dev/null); codigo=$?
  case "$codigo" in 0) obtido=libera ;; 2) obtido=bloqueia ;; *) obtido="falhou(exit $codigo)" ;; esac
  if [ "$obtido" = "$esperado" ]; then ok=$((ok+1)); printf '  \033[32m✓\033[0m  %-52s %s\n' "$desc" "$obtido"
  else ruim=$((ruim+1)); printf '  \033[31m✗\033[0m  %-52s esperado %s, veio %s %s\n' "$desc" "$esperado" "$obtido" "$erro"; fi
}

PEST="$proj/tests/Feature/CadastroEmailDuplicadoTest.php"
echo "Pest"
caso "tirar ->todo() do fim do teste" \
  "$(edit_json "$PEST" "    expect(User::count())->toBe(1);
})->todo();" "    expect(User::count())->toBe(1);
});")" libera
caso "tirar ->todo() em linha própria" \
  "$(edit_json "$PEST" "})
    ->todo();" "});")" libera
caso "tirar ->todo('motivo')" \
  "$(edit_json "$PEST" "})->todo('AC-02 · pendente');" "});")" libera
caso "trocar o texto esperado (assertSee)" \
  "$(edit_json "$PEST" "->assertSee('Este e-mail já está cadastrado')" "->assertSee('cadastrado')")" bloqueia
caso "tirar ->todo() e afrouxar a asserção junto" \
  "$(edit_json "$PEST" "    expect(User::count())->toBe(1);
})->todo();" "    expect(User::count())->toBeGreaterThan(0);
});")" bloqueia
caso "pôr ->todo() num teste ativo (esconder o vermelho)" \
  "$(edit_json "$PEST" "});" "})->todo();")" bloqueia
caso "Write sobre o arquivo protegido" "$(write_json "$PEST")" bloqueia
caso "caminho relativo também é protegido" \
  "$(edit_json "tests/Feature/CadastroEmailDuplicadoTest.php" "toBe(1)" "toBe(2)")" bloqueia

echo "Jest/Vitest"
caso "test.skip( -> test(" \
  "$(edit_json "$proj/tests/e2e/cadastro.test.ts" "test.skip('AC-03 · mostra a mensagem', async () => {" "test('AC-03 · mostra a mensagem', async () => {")" libera
caso "apagar o teste inteiro" \
  "$(edit_json "$proj/tests/e2e/cadastro.test.ts" "test('AC-01 · recusa', () => {
  expect(r.status).toBe(422);
});" "")" bloqueia

echo "pytest"
caso "tirar a linha @pytest.mark.skip" \
  "$(edit_json "$proj/tests/test_cadastro.py" '@pytest.mark.skip(reason="AC-02 · pendente")
def test_ac02_recusa_outra_caixa(cliente):' 'def test_ac02_recusa_outra_caixa(cliente):')" libera
caso "trocar assert" \
  "$(edit_json "$proj/tests/test_cadastro.py" "assert resposta.status_code == 422" "assert resposta.status_code in (200, 422)")" bloqueia

echo "fora da lista"
caso "Edit no código da feature" \
  "$(edit_json "$proj/app/Actions/CreateNewUser.php" "'email' => 'required'" "'email' => ['required', 'unique:users']")" libera
caso "Write de teste novo que não está na lista" "$(write_json "$proj/tests/Feature/OutroTest.php")" libera
caso "Write criando o teste de aceite pela 1ª vez" "$(write_json "$proj/tests/e2e/novo.test.ts")" libera
caso "entrada que não é JSON" "isso não é json" bloqueia

echo
echo "$ok passaram, $ruim falharam"
[ "$ruim" -eq 0 ]
