#!/usr/bin/env bash
# verificar.sh · aula 2.4 · roda no ~/projeto da sandbox, depois dos comandos do material.
# Prova que o testa-hooks.sh foi instalado e que ele pega, de verdade, cada defeito da aula:
# campo com nome errado, barrar demais, echo no stdout, sem chmod +x, hook lento, caminho
# errado, PreToolUse sem onFailure e Stop que ignora o stop_hook_active.
# O teste/projeto é um projeto falso com os hooks da aula 2.3 já instalados.
set -euo pipefail

n=0
ok() { n=$((n + 1)); printf '  ok  %s\n' "$1"; }
erro() { printf 'FALHOU: %s\n' "$1" >&2; exit 1; }
M=$(echo "$HOME"/harness-lab-materiais/modulo-2-trava/aula-2.4-*/modelos)
[ -d "$M" ] || erro "modelos da aula 2.4 não encontrados em $M"
TMP=$(mktemp -d)

# testa [PASTA]: roda o testa-hooks.sh e guarda rc e out
testa() {
  set +e
  out=$(bash testes/testa-hooks.sh "$@" 2>&1)
  rc=$?
  set -e
}
tem() { grep -qF -- "$1" <<<"$out" || { printf '%s\n' "$out" >&2; erro "$2"; }; }

# ------------------------------------------------------------------ instalação
[ -x testes/testa-hooks.sh ] || erro "testes/testa-hooks.sh não instalado ou sem chmod +x"
[ -f testes/casos-hooks.sh ] || erro "testes/casos-hooks.sh não instalado"
bash -n testes/testa-hooks.sh
bash -n testes/casos-hooks.sh
[ -x .claude/hooks/protege-env.sh ] || erro "o hook do projeto perdeu o chmod +x"
ok "testa-hooks.sh e casos-hooks.sh instalados, hooks do projeto intactos"

# ------------------------------------------------------------------ hooks certos
testa
[ "$rc" = 0 ] || { printf '%s\n' "$out" >&2; erro "os hooks certos deviam passar"; }
tem "0 falharam" "resumo sem 0 falharam"
tem "existe e inicia" "a parte do settings não rodou"
tem "prisma migrate reset" "faltam os casos do guard-destructive.py"
ok "hooks certos: settings conferido e todos os casos passam (exit 0)"

# projeto em pasta com espaço (~/Meus Projetos/app, /mnt/c/Users/Nome Sobrenome/...)
E="$TMP/meu projeto"
cp -r . "$E"
set +e
out=$(cd "$E" && bash testes/testa-hooks.sh 2>&1)
rc=$?
set -e
[ "$rc" = 0 ] || { printf '%s\n' "$out" >&2; erro "caminho com espaço devia passar"; }
tem "existe e inicia" "com espaço no caminho, a parte do settings não reconheceu os hooks"
ok "projeto em pasta com espaço: settings e casos passam (exit 0)"

# ------------------------------------------------------------------ defeitos nos hooks
testa "$M/quebrados/campo-errado"
[ "$rc" = 1 ] || erro "campo-errado devia reprovar"
tem "esperado bloqueia, veio libera" "campo-errado devia mostrar veio libera"
ok "campo com nome errado: tudo vem libera, o teste reprova"

testa "$M/quebrados/demais"
[ "$rc" = 1 ] || erro "demais devia reprovar"
tem "migrate:status" "faltou o caso migrate:status"
tem "esperado libera, veio bloqueia" "demais devia mostrar o barrou demais"
ok "barrou demais: os casos que têm que passar reprovam"

testa "$M/quebrados/eco-no-stdout"
[ "$rc" = 1 ] || erro "eco-no-stdout devia reprovar"
tem "esperado bloqueia, veio libera" "eco no stdout devia apagar a decisão"
ok "echo no stdout antes do JSON: a decisão some, o teste reprova"

cp -r .claude/hooks "$TMP/sem-x"
chmod -x "$TMP"/sem-x/*.sh
testa "$TMP/sem-x"
[ "$rc" = 1 ] || erro "sem chmod +x devia reprovar"
tem "falhou(exit 126)" "sem chmod +x devia mostrar exit 126"
ok "sem chmod +x: falhou(exit 126)"

mkdir -p "$TMP/ruins"
printf '#!/usr/bin/env bash\ncat >/dev/null\necho "{nao e json}"\n' > "$TMP/ruins/bloqueia-perigoso.sh"
printf '#!/usr/bin/env bash\ncat >/dev/null\necho "Bloqueado" >&2\nexit 1\n' > "$TMP/ruins/protege-env.sh"
chmod +x "$TMP"/ruins/*.sh
testa "$TMP/ruins"
tem "veio json-invalido" "JSON quebrado devia virar json-invalido"
tem "veio falhou(exit 1)" "exit 1 devia virar falhou (não bloqueia)"
ok "JSON quebrado e exit 1: o teste mostra que não barram"

if command -v timeout >/dev/null 2>&1; then
  mkdir -p "$TMP/lento"
  cp "$M/quebrados/lento.sh" "$TMP/lento/protege-env.sh"
  set +e
  out=$(TESTA_LIMITE=1 bash testes/testa-hooks.sh "$TMP/lento" 2>&1)
  rc=$?
  set -e
  [ "$rc" = 1 ] || erro "hook lento devia reprovar"
  tem "travou(>1s)" "hook lento devia aparecer como travou"
  ok "hook lento: travou(>1s) com TESTA_LIMITE=1"
fi

# ------------------------------------------------------------------ defeitos no settings
P="$TMP/proj"
cp -r . "$P"
cp "$M/quebrados/stop-em-loop.sh" "$M/prova-no-stop.sh" "$P/.claude/hooks/"
chmod -x "$P/.claude/hooks/protege-env.sh"
jq '.hooks.Stop = [{hooks: [
      {type: "command", command: "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/stop-em-loop.sh"},
      {type: "command", command: "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/prova-no-stop.sh",
       onFailure: "block"}]}]
    | .hooks.PreToolUse[0].hooks[0] |= del(.onFailure)
    | .hooks.PostToolUse += [{matcher: "Write", hooks: [
      {type: "command", command: ".claude/hooks/sumiu.sh"}]}]' \
  .claude/settings.json > "$P/.claude/settings.json"
set +e
out=$(cd "$P" && bash testes/testa-hooks.sh 2>&1)
rc=$?
set -e
[ "$rc" = 1 ] || erro "settings com defeito devia reprovar"
tem "ignora stop_hook_active" "Stop em loop não foi pego"
tem "respeita stop_hook_active" "prova-no-stop devia respeitar o stop_hook_active"
tem "onFailure não tem efeito em Stop" "onFailure no Stop devia gerar aviso"
tem "sem onFailure" "PreToolUse sem onFailure devia gerar aviso"
tem "sem chmod +x" "script sem chmod +x no settings não foi pego"
tem "sumiu.sh não existe" "caminho errado não foi pego"
tem "caminho relativo" "caminho relativo devia gerar aviso"
ok "settings: Stop em loop, sem onFailure, sem chmod +x, caminho errado e relativo"

# ------------------------------------------------------------------ modelos
jq empty "$M/settings.sem-quebrar.json"
jq -e '.hooks.PreToolUse[0].hooks[0].onFailure == "block"
       and (.hooks.PostToolUse[0].hooks[1].asyncRewake == true)' \
  "$M/settings.sem-quebrar.json" >/dev/null || erro "settings.sem-quebrar.json sem onFailure ou asyncRewake"
mkdir -p "$TMP/app/vendor/bin"
printf '#!/bin/sh\necho "FAILED  Tests\\\\Unit\\\\CarrinhoTest"\nexit 1\n' > "$TMP/app/vendor/bin/pest"
chmod +x "$TMP/app/vendor/bin/pest"
set +e
(cd "$TMP/app" && echo '{"stop_hook_active": true}' | CLAUDE_PROJECT_DIR="$TMP/app" "$M/prova-no-stop.sh")
r1=$?
(cd "$TMP/app" && echo '{"stop_hook_active": false}' | CLAUDE_PROJECT_DIR="$TMP/app" "$M/prova-no-stop.sh" 2>/dev/null)
r2=$?
err=$(cd "$TMP/app" && echo '{}' | CLAUDE_PROJECT_DIR="$TMP/app" "$M/suite-completa.sh" 2>&1 >/dev/null)
r3=$?
set -e
[ "$r1" = 0 ] || erro "prova-no-stop.sh devia liberar com stop_hook_active=true"
[ "$r2" = 2 ] || erro "prova-no-stop.sh devia barrar o fim com teste vermelho"
[ "$r3" = 2 ] && grep -q CarrinhoTest <<<"$err" || erro "suite-completa.sh devia sair 2 com o teste que falhou"
ok "modelos: settings válido, prova-no-stop com freio, suite-completa sai 2 com o erro"

rm -rf "$TMP"
echo "verificar.sh: $n grupos de checagem passaram."
