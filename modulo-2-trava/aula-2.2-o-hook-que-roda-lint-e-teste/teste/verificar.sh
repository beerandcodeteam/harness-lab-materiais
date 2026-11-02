#!/usr/bin/env bash
# verificar.sh · aula 2.2 · roda no ~/projeto da sandbox, depois dos comandos do material.
# Prova que o quality-gate.sh foi instalado e responde certo a JSON falso, igual ao que o
# Claude Code manda: código quebrado = exit 2, ambiente fora do ar = aviso sem bloquear.
# O projeto falso (teste/projeto) tem stubs de pint e pest em vendor/bin: não são as ferramentas reais.
set -euo pipefail

H=.claude/hooks/quality-gate.sh
n=0
ok() { n=$((n + 1)); printf '  ok  %s\n' "$1"; }
erro() { printf 'FALHOU: %s\n' "$1" >&2; exit 1; }

# ------------------------------------------------------------------ instalação
[ -x "$H" ] || erro "$H não instalado ou sem chmod +x"
bash -n "$H"
jq -e '.hooks.PostToolUse[] | select(.matcher == "Edit|Write") | .hooks[]
       | select(.command | test("quality-gate.sh post-edit"))' .claude/settings.json >/dev/null ||
  erro "PostToolUse com matcher Edit|Write não aponta para o quality-gate.sh"
jq -e '.hooks.Stop[] | .hooks[] | select(.command | test("quality-gate.sh stop"))' \
  .claude/settings.json >/dev/null || erro "Stop não aponta para o quality-gate.sh"
jq -e '.permissions.allow | index("Bash(git status)")' .claude/settings.json >/dev/null ||
  erro "o instalar.sh apagou a permissão que o projeto já tinha"
ok "hook executável, PostToolUse e Stop ligados, settings do projeto preservado"

export CLAUDE_PROJECT_DIR="$PWD"
TMPDIR=$(mktemp -d)
export TMPDIR
unset QG_ESTILO QG_TESTE_NA_EDICAO QG_SAIL QG_LIMITE_EDICAO QG_LIMITE_STOP QG_MAX_TESTES 2>/dev/null || true

# roda MODO JSON [VAR=valor...]: guarda rc, out (stdout) e err (stderr)
roda() {
  local modo="$1" json="$2"
  shift 2
  set +e
  out=$(env "$@" "$H" "$modo" <<<"$json" 2>"$TMPDIR/err")
  rc=$?
  set -e
  err=$(cat "$TMPDIR/err")
}
arq() { jq -nc --arg f "$1" '{session_id: "verificar", tool_input: {file_path: $f}}'; }
fim() { jq -nc --argjson a "${1:-false}" '{session_id: "verificar", stop_hook_active: $a}'; }
espera() {   # espera CÓDIGO DESCRIÇÃO
  [ "$rc" = "$1" ] || { printf 'stdout: %s\nstderr: %s\n' "$out" "$err" >&2; erro "$2: esperado exit $1, veio $rc"; }
}

# ------------------------------------------------------------------ post-edit
roda post-edit "$(arq "$PWD/app/Services/Carrinho.php")"
espera 0 "arquivo PHP certo"
[ -z "$out$err" ] || erro "arquivo certo não deveria imprimir nada"
ok "arquivo certo: exit 0, em silêncio"

printf '<?php\necho "oi"\n' > app/Quebrado.php
roda post-edit "$(arq "$PWD/app/Quebrado.php")"
espera 2 "erro de sintaxe"
grep -q 'php -l app/Quebrado.php' <<<"$err" || erro "stderr sem o rótulo do php -l"
grep -qi 'syntax error' <<<"$err" || erro "stderr sem a mensagem do php -l"
ok "erro de sintaxe: exit 2, com o erro do php -l no stderr"
rm app/Quebrado.php

printf '<?php\n\nfunction feio()   \n{\n    return 1;\n}\n' > app/Feio.php
roda post-edit "$(arq "$PWD/app/Feio.php")"
espera 2 "estilo acusado"
grep -q 'pint --test app/Feio.php' <<<"$err" && grep -q 'Para corrigir o estilo' <<<"$err" ||
  erro "stderr sem o pint --test e a dica de correção"
ok "estilo (QG_ESTILO=acusa, o padrão da aula): exit 2 com o comando que corrige"
roda post-edit "$(arq "$PWD/app/Feio.php")" QG_ESTILO=corrige
espera 0 "estilo corrigido"
! grep -q '[[:space:]]$' app/Feio.php || erro "QG_ESTILO=corrige não formatou o arquivo"
ok "QG_ESTILO=corrige: formata sozinho e segue"
rm app/Feio.php

for f in README.md resources/views/welcome.blade.php vendor/bin/pest; do
  [ -e "$f" ] || printf 'x\n' > "$f"
  roda post-edit "$(arq "$PWD/$f")"
  espera 0 "$f deveria ser ignorado"
done
printf '<?php\necho "fora"\n' > "$TMPDIR/fora.php"
roda post-edit "$(arq "$TMPDIR/fora.php")"
espera 0 "arquivo fora do projeto"
roda post-edit '{"tool_input": {}}'
espera 0 "JSON sem file_path"
ok "ignora o que não é código do projeto: markdown, blade, vendor/, fora do projeto"

# ------------------------------------------------------------------ stop
rm -rf "$TMPDIR/claude-quality-gate"
roda post-edit "$(arq "$PWD/app/Services/Carrinho.php")"
roda stop "$(fim)"
espera 0 "stop com teste verde"
[ ! -e "$TMPDIR/claude-quality-gate/verificar.txt" ] || erro "a lista de arquivos devia ser limpa"
ok "stop com o teste ligado verde: exit 0 e lista limpa"

sed 's/0\.10/0.15/' app/Services/Carrinho.php > "$TMPDIR/c" && cat "$TMPDIR/c" > app/Services/Carrinho.php
roda post-edit "$(arq "$PWD/app/Services/Carrinho.php")"
espera 0 "post-edit não roda teste por padrão"
roda stop "$(fim)"
espera 2 "stop com teste vermelho"
grep -q 'tests/Unit/CarrinhoTest.php' <<<"$err" && grep -q 'identical to 10.0' <<<"$err" ||
  erro "stderr do stop sem o teste que falhou"
ok "stop com teste vermelho: exit 2, o modelo recebe a falha e continua"

roda stop "$(fim true)"
espera 0 "stop_hook_active"
jq -e '.systemMessage | test("ainda falha")' <<<"$out" >/dev/null || erro "sem systemMessage na segunda volta"
ok "segunda volta ainda vermelha: libera e avisa você (sem loop)"

roda stop "$(fim)"
espera 2 "resposta seguinte, teste ainda vermelho"
ok "resposta seguinte, sem edição nova: a lista fica e o stop bloqueia de novo"

roda post-edit "$(arq "$PWD/app/Services/Carrinho.php")" QG_TESTE_NA_EDICAO=1
espera 2 "QG_TESTE_NA_EDICAO=1"
ok "QG_TESTE_NA_EDICAO=1: o teste roda já na edição"

sed 's/0\.15/0.10/' app/Services/Carrinho.php > "$TMPDIR/c" && cat "$TMPDIR/c" > app/Services/Carrinho.php
roda stop "$(fim)"
espera 0 "stop depois de consertar"
ok "consertado: stop volta a liberar"

printf '<?php\n\nreturn [];\n' > app/config.php
roda post-edit "$(arq "$PWD/app/config.php")"
roda stop "$(fim)"
espera 0 "arquivo sem teste"
jq -e '.systemMessage | test("Nenhum teste ligado")' <<<"$out" >/dev/null || erro "sem aviso de arquivo sem teste"
ok "arquivo sem teste ligado: libera e avisa você"
rm app/config.php

# ------------------------------------------------------------------ ambiente fora do ar
printf 'services:\n  laravel.test:\n    image: sail-8.4/app\n' > compose.yaml
printf '#!/bin/sh\necho "Sail is not running." >&2\nexit 1\n' > vendor/bin/sail
chmod +x vendor/bin/sail
roda post-edit "$(arq "$PWD/app/Services/Carrinho.php")"
espera 0 "Sail parado não bloqueia"
jq -e '.hookSpecificOutput.additionalContext | test("Sail is not running")' <<<"$out" >/dev/null ||
  erro "sem additionalContext dizendo que o Sail está parado"
jq -e '.systemMessage | test("ambiente")' <<<"$out" >/dev/null || erro "sem systemMessage para você"
roda post-edit "$(arq "$PWD/app/Services/Carrinho.php")" QG_SAIL=nao
espera 0 "QG_SAIL=nao"
[ -z "$out" ] || erro "QG_SAIL=nao ainda tentou o Sail"
rm compose.yaml vendor/bin/sail
ok "Sail parado: aviso para o modelo e para você, sem exit 2"

mkdir -p web/node_modules/.bin web/src
printf '{"name": "web"}\n' > web/package.json
printf 'export const x = 1;\n' > web/src/a.js
printf '#!/bin/sh\necho "ESLint could not find an eslint.config file."\nexit 2\n' > web/node_modules/.bin/eslint
chmod +x web/node_modules/.bin/eslint
roda post-edit "$(arq "$PWD/web/src/a.js")"
espera 0 "ESLint com exit 2 (configuração)"
jq -e '.hookSpecificOutput.additionalContext | test("eslint")' <<<"$out" >/dev/null || erro "sem aviso do eslint"
printf '#!/bin/sh\necho "src/a.js  1:1  error  no-undef"\nexit 1\n' > web/node_modules/.bin/eslint
roda post-edit "$(arq "$PWD/web/src/a.js")"
espera 2 "ESLint com exit 1 (lint)"
grep -q 'eslint src/a.js' <<<"$err" || erro "o eslint não rodou na raiz de web/ (monorepo)"
ok "JS em subpasta: acha web/package.json; exit 2 do ESLint é ambiente, exit 1 é código"

if command -v timeout >/dev/null 2>&1; then
  printf '#!/bin/sh\nsleep 5\n' > web/node_modules/.bin/eslint
  roda post-edit "$(arq "$PWD/web/src/a.js")" QG_LIMITE_EDICAO=2
  espera 0 "comando lento"
  jq -e '.systemMessage | test("prazo de 2s")' <<<"$out" >/dev/null || erro "comando lento sem aviso"
  ok "comando lento: interrompido no prazo e avisado, em vez de estourar o timeout calado"

  # O prazo vale para o hook inteiro: lint (2s) + teste (10s) com QG_LIMITE_STOP=3 para em ~3s.
  # Com limite por comando, seriam 2s + 3s.
  printf '#!/bin/sh\nexit 0\n' > web/node_modules/.bin/eslint
  roda post-edit "$(arq "$PWD/web/src/a.js")"
  espera 0 "JS certo"
  printf '#!/bin/sh\nsleep 2\n' > web/node_modules/.bin/eslint
  printf '#!/bin/sh\nsleep 10\n' > web/node_modules/.bin/vitest
  chmod +x web/node_modules/.bin/vitest
  t0=$SECONDS
  roda stop "$(fim)" QG_LIMITE_STOP=3
  dt=$((SECONDS - t0))
  espera 0 "stop que estoura o prazo"
  jq -e '.systemMessage | test("vitest.*prazo de 3s")' <<<"$out" >/dev/null || erro "stop sem aviso do prazo"
  [ "$dt" -le 4 ] || erro "o stop levou ${dt}s: o prazo de 3s não valeu para o hook inteiro"
  ok "prazo do hook inteiro: lint e teste somados param no QG_LIMITE_STOP, com aviso"
fi
rm -rf web

if command -v python3 >/dev/null 2>&1 || command -v ruff >/dev/null 2>&1; then
  printf 'def f(:\n    pass\n' > quebrado.py
  roda post-edit "$(arq "$PWD/quebrado.py")"
  espera 2 "Python com erro de sintaxe"
  ok "Python com erro de sintaxe: exit 2 (ruff, ou ast se não houver ruff)"
  rm quebrado.py
fi

echo "verificar.sh: $n grupos de checagem passaram."
