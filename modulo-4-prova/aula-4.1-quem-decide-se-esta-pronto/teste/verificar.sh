#!/usr/bin/env bash
# verificar.sh · aula 4.1 · roda no ~/projeto da sandbox, depois dos comandos do material.
# Prova que o qual-comando.sh foi instalado igual ao da aula e escolhe o comando na ordem do
# pré-voo do loop.sh do Módulo 5 (LOOP_TEST_CMD, depois a detecção do gate 2 do ralph.sh,
# bc-harness 0.2.0, e RALPH_TEST_CMD recusada), que as armadilhas citadas no material são reais
# (pipe, "|| true", script de teste padrão do npm, --test-cmd sem valor), que a cadeia com &&
# devolve o exit do primeiro que falha, que o CLAUDE.md tem a Prova e o ## Pronto, que o juiz tem
# o frontmatter certo e que a variante com Bash só deixa rodar o que lista.
set -euo pipefail

n=0
ok() { n=$((n + 1)); printf '  ok  %s\n' "$1"; }
erro() { printf 'FALHOU: %s\n' "$1" >&2; exit 1; }
AULA="$HOME/harness-lab-materiais/modulo-4-prova/aula-4.1-quem-decide-se-esta-pronto"
PROJ="$PWD"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

# campo NOME ARQUIVO: valor do campo no frontmatter (entre os dois ---)
campo() { awk -v k="$1" 'NR==1 && $0!="---"{exit} NR>1 && $0=="---"{exit} NR>1 && index($0, k": ")==1{sub(k": ", ""); print}' "$2"; }

# ------------------------------------------------------------------ instalação
Q=.claude/scripts/qual-comando.sh
[ -f "$Q" ] || erro "$Q não instalado"
[ -x "$Q" ] || erro "$Q sem chmod +x"
cmp -s "$Q" "$AULA/projeto/$Q" || erro "$Q diferente do arquivo da aula"
bash -n "$Q"
QA="$PROJ/$Q"
ok "qual-comando.sh instalado, executável e igual ao da aula"

# ------------------------------------------------------------------ no projeto do aluno
saida=$(env -u RALPH_TEST_CMD -u LOOP_TEST_CMD bash "$Q") || erro "qual-comando.sh saiu com erro no projeto: $saida"
grep -qx 'comando: npm test' <<<"$saida" || erro "devia escolher npm test: $saida"
grep -qx 'origem:  detectado: package.json com scripts.test' <<<"$saida" || erro "origem errada: $saida"
saida=$(env -u RALPH_TEST_CMD -u LOOP_TEST_CMD bash "$Q" --rodar 2>&1) || erro "--rodar devia sair com 0 (suíte verde): $saida"
grep -qx 'exit:    0' <<<"$saida" || erro "--rodar sem a linha exit: 0"
ok "no projeto: comando npm test, origem detectada, --rodar verde (exit 0)"

grep -q '^Testes: ' CLAUDE.md || erro "CLAUDE.md sem a linha Testes:"
grep -q '^## Pronto' CLAUDE.md || erro "CLAUDE.md sem a seção ## Pronto"
M="$AULA/modelos/claude-md-prova.md"
for frase in 'Pronto é o comando de testes acima saindo com 0. Mostre o comando e a saída, não um resumo.' \
             'Teste que parece errado: me avise. Não edite nem apague teste para ele passar.' \
             'Tarefa impossível ou faltando informação: pare e diga o que falta, em vez de contornar.'; do
  grep -qF -- "- $frase" CLAUDE.md || erro "## Pronto do CLAUDE.md sem: $frase"
  grep -qF -- "- $frase" "$M" || erro "claude-md-prova.md sem: $frase"
done
ok "CLAUDE.md com a linha Testes: e o ## Pronto do modelo, palavra por palavra"

# ------------------------------------------------------------------ a ordem do pré-voo do loop.sh
mkdir -p "$T/bin"
for b in composer php npm pytest go cargo; do printf '#!/bin/sh\nexit 0\n' > "$T/bin/$b"; chmod +x "$T/bin/$b"; done
PT="$T/bin:/usr/bin:/bin"
p() { mkdir -p "$T/p/$1"; echo "$T/p/$1"; }
sail() {   # sail DIR up|parado
  mkdir -p "$1/vendor/bin"
  if [ "$2" = up ]; then
    printf '#!/bin/sh\n[ "$1" = ps ] && { echo "laravel.test-1   Up 3 minutes"; exit 0; }\nexit 0\n' > "$1/vendor/bin/sail"
  else
    printf '#!/bin/sh\necho "Sail is not running."\nexit 1\n' > "$1/vendor/bin/sail"
  fi
  chmod +x "$1/vendor/bin/sail"
}
caso() {   # caso DIR "comando esperado" exit_esperado [args...]   (RTC=... RALPH_TEST_CMD, LTC=... LOOP_TEST_CMD)
  local d="$1" esp="$2" xesp="$3"; shift 3
  local s rc=0
  s=$(cd "$d" && env -u RALPH_TEST_CMD -u LOOP_TEST_CMD PATH="$PT" ${RTC:+RALPH_TEST_CMD="$RTC"} \
      ${LTC:+LOOP_TEST_CMD="$LTC"} timeout 20 bash "$QA" "$@" 2>&1) || rc=$?
  [ "$(sed -n 's/^comando: //p' <<<"$s" | head -1)" = "$esp" ] && [ "$rc" = "$xesp" ] ||
    erro "em $(basename "$d"): esperado \"$esp\" exit $xesp, veio exit $rc: $s"
  saida_caso="$s"
}

d=$(p sail-up); touch "$d/artisan"; echo '{"scripts":{"test":"pest"}}' > "$d/composer.json"; sail "$d" up
caso "$d" "vendor/bin/sail test" 0
grep -qx 'sail:    containers de pé' <<<"$saida_caso" || erro "Sail de pé sem a linha sail:"
d=$(p sail-parado); touch "$d/artisan"; sail "$d" parado
caso "$d" "vendor/bin/sail test" 5
grep -q 'containers parados' <<<"$saida_caso" || erro "Sail parado sem o aviso"
d=$(p starter-kit); touch "$d/artisan"; echo '{"require-dev":{"laravel/sail":"^1.41"}}' > "$d/composer.json"
caso "$d" "vendor/bin/sail test" 4
d=$(p composer); touch "$d/artisan"; echo '{"scripts":{"test":["@php artisan test"]}}' > "$d/composer.json"
caso "$d" "composer test" 0
d=$(p artisan); touch "$d/artisan"; echo '{"require":{}}' > "$d/composer.json"
caso "$d" "php artisan test" 0
d=$(p pytest); printf '[pytest]\n' > "$d/pytest.ini"
caso "$d" "pytest" 0
d=$(p go); echo 'module x' > "$d/go.mod"
caso "$d" "go test ./..." 0
d=$(p rust); echo '[package]' > "$d/Cargo.toml"
caso "$d" "cargo test" 0
d=$(p rails); printf "source 'https://rubygems.org'\ngem 'rspec'\n" > "$d/Gemfile"
caso "$d" "(nenhum)" 3
grep -q 'Sem Prova, não tem loop' <<<"$saida_caso" || erro "sem comando: devia avisar que o loop.sh não começa"
grep -q 'LOOP_TEST_CMD' <<<"$saida_caso" || erro "sem comando: devia sugerir LOOP_TEST_CMD"
d=$(p node); echo '{"scripts":{"test":"vitest run"}}' > "$d/package.json"
LTC="npm run test:unit" caso "$d" "npm run test:unit" 0
grep -qx 'origem:  LOOP_TEST_CMD (o mesmo que o loop.sh lê)' <<<"$saida_caso" || erro "origem LOOP_TEST_CMD não aparece"
RTC="pytest -q" caso "$d" "pytest -q" 6
grep -q 'loop.sh recusa RALPH_TEST_CMD' <<<"$saida_caso" || erro "RALPH_TEST_CMD sem o aviso de recusa"
grep -q 'unset RALPH_TEST_CMD' <<<"$saida_caso" || erro "RALPH_TEST_CMD sem a correção"
RTC="pytest -q" caso "$d" "pytest -q" 6 --rodar
! grep -q '^rodando:' <<<"$saida_caso" || erro "RALPH_TEST_CMD com --rodar não devia rodar nada"
RTC="pytest -q" LTC="npm run test:unit" caso "$d" "npm run test:unit" 0
LTC="pytest -q" caso "$d" "npm run test:e2e" 0 --test-cmd "npm run test:e2e"
LTC="nao-existe test" caso "$d" "nao-existe test" 4
ok "ordem do pré-voo: Sail (de pé, parado, sem vendor), composer, artisan, pytest, go, cargo, Rails sem detecção, LOOP_TEST_CMD, RALPH_TEST_CMD recusada (exit 6), --test-cmd"

# --test-cmd sem comando: antes, laço infinito; agora, exit 64 na hora.
for args in "--test-cmd" "--rodar --test-cmd" "--test-cmd="; do
  rc=0; s=$(cd "$d" && env -u RALPH_TEST_CMD -u LOOP_TEST_CMD timeout 5 bash "$QA" $args 2>&1) || rc=$?
  [ "$rc" = 64 ] || erro "'$args' devia sair com 64 na hora, veio $rc (124 = travou): $s"
  grep -q 'precisa de um comando' <<<"$s" || erro "'$args' sem a mensagem de uso: $s"
done
rc=0; s=$(cd "$d" && env -u RALPH_TEST_CMD -u LOOP_TEST_CMD timeout 5 bash "$QA" --test-cmd "" 2>&1) || rc=$?
[ "$rc" = 64 ] || erro "--test-cmd vazio devia sair com 64, veio $rc"
ok "--test-cmd sem comando (no fim, depois de --rodar, com = vazio, string vazia): exit 64 na hora"

# ------------------------------------------------------------------ as armadilhas do material
d=$(p npm-padrao); printf '{"scripts":{"test":"echo \\"Error: no test specified\\" && exit 1"}}\n' > "$d/package.json"
rc=0; s=$(cd "$d" && env -u RALPH_TEST_CMD -u LOOP_TEST_CMD bash "$QA" --rodar 2>&1) || rc=$?
[ "$rc" = 1 ] && grep -q 'Error: no test specified' <<<"$s" || erro "script padrão do npm devia dar vermelho (exit 1): $s"
ok "package.json do npm init: a Prova é npm test e volta sempre vermelha (exit 1)"

rc=0; s=$(cd "$T" && env -u RALPH_TEST_CMD -u LOOP_TEST_CMD bash "$QA" --rodar --test-cmd "sh -c 'exit 1' | tail -1" 2>&1) || rc=$?
[ "$rc" = 0 ] || erro "pipe: o exit devia ser o do tail (0), veio $rc"
rc=0; s=$(cd "$T" && env -u RALPH_TEST_CMD -u LOOP_TEST_CMD bash "$QA" --rodar --test-cmd "sh -c 'exit 1' || true" 2>&1) || rc=$?
[ "$rc" = 0 ] || erro "|| true: o exit devia ser 0, veio $rc"
rc=0; s=$(cd "$T" && env -u RALPH_TEST_CMD -u LOOP_TEST_CMD bash "$QA" --rodar --test-cmd "sh -c 'exit 1'" 2>&1) || rc=$?
[ "$rc" = 1 ] || erro "sem pipe: o exit devia ser 1, veio $rc"
ok "teste vermelho com '| tail' ou '|| true' no comando: a Prova vê exit 0 (sem eles, exit 1)"

# Build e lint no mesmo portão: a cadeia com && devolve o exit do primeiro que falha.
rc=0; s=$(cd "$T" && env -u RALPH_TEST_CMD -u LOOP_TEST_CMD \
  LOOP_TEST_CMD="sh -c 'exit 0' && sh -c 'exit 2' && sh -c 'exit 0'" bash "$QA" --rodar 2>&1) || rc=$?
[ "$rc" = 2 ] || erro "cadeia com &&: o exit devia ser o do primeiro que falha (2), veio $rc: $s"
mkdir -p "$T/cadeia"; printf '{"scripts":{"test":"sh -c \\"exit 0\\" && sh -c \\"exit 3\\" && sh -c \\"exit 0\\""}}\n' > "$T/cadeia/package.json"
rc=0; s=$(cd "$T/cadeia" && env -u RALPH_TEST_CMD -u LOOP_TEST_CMD bash "$QA" --rodar 2>&1) || rc=$?
[ "$rc" = 3 ] || erro "cadeia no script test do package.json: o exit devia ser 3, veio $rc: $s"
rc=0; s=$(cd "$T" && env -u RALPH_TEST_CMD -u LOOP_TEST_CMD \
  LOOP_TEST_CMD="sh -c 'exit 0' && sh -c 'exit 0'" bash "$QA" --rodar 2>&1) || rc=$?
[ "$rc" = 0 ] || erro "cadeia toda verde devia dar 0, veio $rc"
ok "build e lint encadeados com && (no LOOP_TEST_CMD e no script test): exit do primeiro que falha"


# ------------------------------------------------------------------ o juiz
J=.claude/agents/juiz.md
[ -f "$J" ] || erro "$J não instalado"
[ "$(campo name "$J")" = juiz ] || erro "name do juiz"
[ -n "$(campo description "$J")" ] || erro "juiz sem description (o Claude Code pularia o arquivo)"
[ "$(campo model "$J")" = sonnet ] || erro "juiz devia rodar no sonnet"
tj=$(campo tools "$J")
! grep -Eq 'Edit|Write' <<<"$tj" || erro "juiz não pode ter Edit nem Write"
if grep -q 'Bash' <<<"$tj"; then
  grep -q 'bash-so-permitido.sh' "$J" || erro "juiz com Bash precisa do hook bash-so-permitido.sh"
  [ -x .claude/hooks/bash-so-permitido.sh ] || erro "variante instalada sem o hook da 3.4 em .claude/hooks/"
  ok "juiz (variante que roda teste): Bash travado pelo hook da 3.4, que está instalado"
else
  [ "$tj" = "Read, Grep, Glob" ] || erro "juiz devia ter só Read, Grep, Glob (veio: $tj)"
  ok "juiz: só Read, Grep, Glob"
fi
JA="$AULA/projeto/.claude/agents/juiz.md"
[ "$(campo tools "$JA")" = "Read, Grep, Glob" ] && [ "$(campo model "$JA")" = sonnet ] || erro "juiz.md da aula devia ter Read, Grep, Glob e sonnet"
for f in "$JA" "$AULA/modelos/juiz-que-roda-teste.md"; do
  for frase in 'Na dúvida, INCOMPLETE.' 'VEREDITO: PRONTO' 'SEM CRITÉRIO' 'FEATURE-ALVO.md'; do
    grep -qF "$frase" "$f" || erro "$(basename "$f") sem \"$frase\""
  done
done
ok "juiz.md da aula: Read, Grep, Glob, sonnet, caderneta, 'Na dúvida, INCOMPLETE' e VEREDITO"

out=$(claude plugin validate .claude/agents 2>&1) || { echo "$out" >&2; erro "claude plugin validate .claude/agents"; }
! grep -qi 'warning' <<<"$out" || { echo "$out" >&2; erro "validate passou com aviso"; }
mkdir -p "$T/a/.claude/agents"
cp "$JA" "$T/a/.claude/agents/juiz.md"
out=$(claude plugin validate "$T/a/.claude/agents" 2>&1) || { echo "$out" >&2; erro "juiz.md da aula inválido"; }
! grep -qi 'warning' <<<"$out" || { echo "$out" >&2; erro "juiz.md da aula com aviso"; }
ok "claude plugin validate: .claude/agents do projeto e juiz.md da aula, sem erro e sem aviso"

# ------------------------------------------------------------------ a variante com Bash
V="$AULA/modelos/juiz-que-roda-teste.md"
mkdir -p "$T/v/.claude/agents"
cp "$V" "$T/v/.claude/agents/juiz.md"
out=$(claude plugin validate "$T/v/.claude/agents" 2>&1) || { echo "$out" >&2; erro "variante inválida"; }
! grep -qi 'warning' <<<"$out" || { echo "$out" >&2; erro "variante com aviso"; }
tv=$(campo tools "$V")
[ "$tv" = "Bash, Read" ] || erro "variante: com Bash, Glob e Grep não existem no Linux/WSL (veio: $tv)"
[ "$(campo model "$V")" = sonnet ] || erro "variante devia rodar no sonnet"
cmd=$(sed -n "s/^ *command: '\(.*\)'\$/\1/p" "$V")
[ -n "$cmd" ] || erro "variante sem o command do hook"
grep -q '^"\$CLAUDE_PROJECT_DIR"/.claude/hooks/bash-so-permitido.sh ' <<<"$cmd" || erro "hook da variante fora de .claude/hooks/"
H=$(echo "$HOME"/harness-lab-materiais/modulo-3-regra/aula-3.4-*/projeto/.claude/hooks/bash-so-permitido.sh)
[ -f "$H" ] || erro "hook da 3.4 não encontrado no repositório"
mkdir -p "$T/pj/.claude/hooks"
cp "$H" "$T/pj/.claude/hooks/"; chmod +x "$T/pj/.claude/hooks/bash-so-permitido.sh"
roda() {   # roda COMANDO: guarda rc e err, rodando o command do frontmatter como o Claude Code roda
  set +e
  jq -nc --arg c "$1" '{hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $c}}' |
    CLAUDE_PROJECT_DIR="$T/pj" bash -c "$cmd" 2>"$T/err"
  rc=$?
  set -e
  err=$(cat "$T/err")
}
for c in "./vendor/bin/sail artisan test --filter CadastroTest" \
         "./vendor/bin/sail artisan test --filter CadastroTest | tail -20" \
         "./vendor/bin/sail artisan route:list" "grep -rn Route::post routes" "grep -rl CadastroTest tests"; do
  roda "$c"
  [ "$rc" = 0 ] || erro "variante devia deixar passar: $c (exit $rc: $err)"
done
for c in "./vendor/bin/sail artisan test" "./vendor/bin/sail artisan test --filter=CadastroTest" \
         "./vendor/bin/sail artisan migrate:fresh" "./vendor/bin/sail artisan test --filter X; rm -rf ." \
         "rm -rf ." "git checkout -- tests"; do
  roda "$c"
  [ "$rc" = 2 ] || erro "variante devia bloquear com exit 2: $c (veio $rc)"
  grep -q 'Bloqueado' <<<"$err" || erro "bloqueio sem motivo no stderr: $c"
done
ok "variante: teste filtrado, route:list e grep passam; suíte inteira, --filter=, migrate:fresh e encadeamento: exit 2"

echo "verificar.sh: $n grupos de checagem passaram."
