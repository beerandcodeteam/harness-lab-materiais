#!/usr/bin/env bash
# prova.sh · skill nova-migration · Harness Lab, aula 3.3
#
# Prova que a migration nova sobe, desce e sobe de novo no banco de DESENVOLVIMENTO.
# Imprime só o resumo: o modelo lê a saída, não este código.
#
#   prova.sh [pasta-do-projeto] [--seco]
#
#   --seco     mostra a stack detectada e os comandos, sem rodar nada
#   PROVA_SAIL=nao   no Laravel, roda no host mesmo com Sail no projeto
#
# Stacks: Laravel (com ou sem Sail), Rails, Alembic, Prisma, Django.
# Recusa rodar quando o ambiente parece produção. Nunca passa --force.
# Saída: 0 = prova ok · 1 = um passo falhou ou ambiente de produção · 2 = uso ou stack desconhecida
set -uo pipefail

seco=0
dir=.
for a in "$@"; do
  case "$a" in
    --seco) seco=1 ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "prova: opção desconhecida: $a" >&2; exit 2 ;;
    *) dir="$a" ;;
  esac
done
cd "$dir" 2>/dev/null || { echo "prova: pasta não existe: $dir" >&2; exit 2; }

recusa() { echo "prova: FALHOU · $1. Nada foi rodado." ; exit 1; }

env_do_arquivo() {   # env_do_arquivo ARQUIVO CHAVE
  [ -f "$1" ] || return 0
  sed -n "s/^[[:space:]]*$2[[:space:]]*=[[:space:]]*//p" "$1" | tail -n 1 | tr -d '"'"'"'\r'
}

stack=""
passos=()
if [ -f artisan ]; then
  stack="Laravel"
  app_env="${APP_ENV:-$(env_do_arquivo .env APP_ENV)}"
  [ "$app_env" = production ] && recusa "APP_ENV=production"
  art="php artisan"
  if [ "${PROVA_SAIL:-auto}" != nao ] && [ -x vendor/bin/sail ] &&
     { [ -f compose.yaml ] || [ -f compose.yml ] || [ -f docker-compose.yml ] || [ -f docker-compose.yaml ]; }; then
    art="./vendor/bin/sail artisan"
    stack="Laravel (Sail)"
  fi
  passos=("$art migrate --no-interaction"
          "$art migrate:rollback --step=1 --no-interaction"
          "$art migrate --no-interaction")
elif [ -x bin/rails ]; then
  stack="Rails"
  case "${RAILS_ENV:-}${RACK_ENV:-}" in *production*) recusa "RAILS_ENV=production" ;; esac
  passos=("bin/rails db:migrate" "bin/rails db:rollback STEP=1" "bin/rails db:migrate")
elif [ -f alembic.ini ]; then
  stack="Alembic"
  passos=("alembic upgrade head" "alembic downgrade -1" "alembic upgrade head")
elif [ -f prisma/schema.prisma ] || [ -d prisma/schema ]; then
  stack="Prisma"
  [ "${NODE_ENV:-}" = production ] && recusa "NODE_ENV=production"
  passos=("npx prisma migrate deploy" "npx prisma migrate status")
elif [ -f manage.py ]; then
  stack="Django"
  case "${DJANGO_SETTINGS_MODULE:-}" in *prod*) recusa "DJANGO_SETTINGS_MODULE=${DJANGO_SETTINGS_MODULE}" ;; esac
  passos=("python manage.py migrate --no-input" "python manage.py makemigrations --check --dry-run")
else
  echo "prova: stack não reconhecida em $(pwd)." >&2
  echo "Procurei artisan, bin/rails, alembic.ini, prisma/schema.prisma e manage.py." >&2
  echo "Rode a prova da sua stack à mão (veja references/stacks.md)." >&2
  exit 2
fi

echo "prova: $stack · $(pwd)"
if [ "$seco" = 1 ]; then
  for p in "${passos[@]}"; do echo "  rodaria  $p"; done
  echo "prova: seco (nada foi rodado)"
  exit 0
fi

saida="$(mktemp)"
trap 'rm -f "$saida"' EXIT
n=0
for p in "${passos[@]}"; do
  n=$((n + 1))
  # shellcheck disable=SC2086 # os passos são comandos fixos deste script, sem entrada externa
  if $p >"$saida" 2>&1; then
    echo "  ok      $p"
  else
    rc=$?
    echo "  FALHOU  $p   (exit $rc)"
    echo "  ---- começo da saída ----"
    sed $'s/\x1b\\[[0-9;]*m//g' "$saida" | grep -v '^[[:space:]]*$' | head -n 15 | sed 's/^/  /'
    echo "prova: FALHOU no passo $n de ${#passos[@]}. Corrija a migration e rode a prova de novo."
    exit 1
  fi
done
echo "prova: ok · ${#passos[@]} passos sem erro"
