#!/usr/bin/env bash
# qual-comando.sh · aula 4.1 · qual comando o loop vai usar como Prova?
#
# Replica a escolha do comando de teste do pré-voo do loop.sh (Módulo 5): o
# LOOP_TEST_CMD, se você passar; senão a detecção do gate 2 do ralph.sh
# (bc-harness 0.2.0, função resolve_test_cmd). Diz de onde o comando veio.
# Só lê arquivos do projeto; nunca lê o .env.
#
# Uso, na raiz do repositório:
#   bash qual-comando.sh                          mostra o comando e a origem
#   bash qual-comando.sh --rodar                  mostra, roda e devolve o exit code do comando
#   LOOP_TEST_CMD="<cmd>" bash qual-comando.sh    o comando que vai na frente do loop.sh
#   bash qual-comando.sh --test-cmd "<cmd>"       o mesmo que LOOP_TEST_CMD, só nesta chamada
#
# Ordem (a primeira que resolver):
#   1. --test-cmd   2. LOOP_TEST_CMD   3. detecção:
#   artisan + Sail  -> vendor/bin/sail test
#   composer.json com scripts.test -> composer test
#   artisan -> php artisan test
#   package.json com scripts.test -> npm test
#   pytest.ini ou pyproject.toml com [tool.pytest -> pytest
#   go.mod -> go test ./...
#   Cargo.toml -> cargo test
# RALPH_TEST_CMD exportada (sem LOOP_TEST_CMD): o loop.sh recusa, e aqui sai com 6.
#
# Exit: 0 resolvido · 3 nada detectado · 4 executável ausente · 5 Sail parado
#       6 RALPH_TEST_CMD exportada · 64 uso errado · com --rodar, o exit do comando
set -uo pipefail

uso_errado() { echo "$1" >&2; echo "uso: bash qual-comando.sh [--rodar] [--test-cmd \"<cmd>\"]" >&2; exit 64; }

flag_cmd=""
rodar=false
while [ $# -gt 0 ]; do
  case "$1" in
    --test-cmd)
      [ $# -ge 2 ] && [ -n "$2" ] || uso_errado "--test-cmd precisa de um comando."
      flag_cmd="$2"; shift 2 ;;
    --test-cmd=*)
      flag_cmd="${1#*=}"
      [ -n "$flag_cmd" ] || uso_errado "--test-cmd precisa de um comando."
      shift ;;
    --rodar)      rodar=true; shift ;;
    -h|--help)    sed -n 2,27p "$0"; exit 0 ;;
    *) uso_errado "opção desconhecida: $1" ;;
  esac
done

# Sail, do mesmo jeito do ralph: artisan e (vendor/bin/sail executável ou laravel/sail no composer.json).
sail=""
if [ -f artisan ]; then
  if [ -x vendor/bin/sail ]; then sail="vendor/bin/sail"
  elif [ -f composer.json ] && grep -qF 'laravel/sail' composer.json; then sail="vendor/bin/sail"
  fi
fi

cmd=""; origem=""
if [ -n "$flag_cmd" ]; then
  cmd="$flag_cmd"; origem="--test-cmd (o mesmo que LOOP_TEST_CMD, só nesta chamada)"
elif [ -n "${LOOP_TEST_CMD:-}" ]; then
  cmd="$LOOP_TEST_CMD"; origem="LOOP_TEST_CMD (o mesmo que o loop.sh lê)"
elif [ -n "${RALPH_TEST_CMD:-}" ]; then
  echo "comando: $RALPH_TEST_CMD"
  echo "origem:  RALPH_TEST_CMD (variável exportada no seu shell)"
  echo "aviso:   o loop.sh recusa RALPH_TEST_CMD exportada: ela vence a detecção em qualquer projeto."
  echo "         Rode 'unset RALPH_TEST_CMD' e, se precisar de outro comando, LOOP_TEST_CMD na frente."
  exit 6
elif [ -n "$sail" ]; then
  cmd="$sail test"; origem="detectado: artisan + Laravel Sail"
elif [ -f composer.json ] && grep -qE '"test"[[:space:]]*:' composer.json; then
  cmd="composer test"; origem="detectado: composer.json com scripts.test"
elif [ -f artisan ]; then
  cmd="php artisan test"; origem="detectado: artisan"
elif [ -f package.json ] && grep -qE '"test"[[:space:]]*:' package.json; then
  cmd="npm test"; origem="detectado: package.json com scripts.test"
elif [ -f pytest.ini ] || { [ -f pyproject.toml ] && grep -qF '[tool.pytest' pyproject.toml; }; then
  cmd="pytest"; origem="detectado: pytest.ini ou [tool.pytest] no pyproject.toml"
elif [ -f go.mod ]; then
  cmd="go test ./..."; origem="detectado: go.mod"
elif [ -f Cargo.toml ]; then
  cmd="cargo test"; origem="detectado: Cargo.toml"
fi

if [ -z "$cmd" ]; then
  echo "comando: (nenhum)"
  echo "origem:  nada detectado"
  echo "aviso:   o loop.sh não começa sem comando de teste (\"Sem Prova, não tem loop\"). Peça ao Claude"
  echo "         para instalar o runner de testes e criar um teste que passa, ou use LOOP_TEST_CMD=\"<comando>\"."
  exit 3
fi

echo "comando: $cmd"
echo "origem:  $origem"

# O executável existe? Mesma checagem do loop.sh e do ralph antes da primeira sessão.
primeiro="${cmd%% *}"
if [[ "$primeiro" == */* ]]; then
  [ -x "$primeiro" ] || { echo "aviso:   '$primeiro' não existe ou não é executável. O loop aborta antes de começar."; exit 4; }
else
  command -v "$primeiro" >/dev/null 2>&1 || { echo "aviso:   '$primeiro' não está no PATH. O loop aborta antes de começar."; exit 4; }
fi

# Sail com containers parados: o loop aborta no pré-voo.
if [ "$(basename -- "$primeiro")" = "sail" ]; then
  saida=$("$primeiro" ps 2>&1); rc=$?
  if grep -qiF 'is not running' <<<"$saida" || [ "$rc" -ne 0 ] || ! grep -qiE '(^|[[:space:]])(Up|running)([[:space:]]|$)' <<<"$saida"; then
    echo "aviso:   containers parados. Suba com '$primeiro up -d' ou use LOOP_TEST_CMD com o comando local."
    exit 5
  fi
  echo "sail:    containers de pé"
fi

$rodar || exit 0

echo "rodando: $cmd"
echo "--------"
bash -c "$cmd" </dev/null
rc=$?
echo "--------"
echo "exit:    $rc"
exit "$rc"
