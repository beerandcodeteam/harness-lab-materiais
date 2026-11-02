#!/usr/bin/env bash
# prova-no-stop.sh · aula 2.4 · Stop
# Antes de deixar o agente encerrar a resposta, roda os testes. Falhou: ele continua trabalhando.
# A proteção contra loop infinito é a linha do stop_hook_active.
set -uo pipefail
entrada=$(cat)

# Já estamos continuando por causa de um Stop hook? Então não bloqueia de novo.
[ "$(jq -r '.stop_hook_active // false' <<<"$entrada")" = "true" ] && exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
if   [ -x vendor/bin/pest ];             then teste=(vendor/bin/pest --compact)
elif [ -f package.json ];                then teste=(npm test --silent)
elif command -v pytest >/dev/null 2>&1;  then teste=(pytest -q)
else exit 0; fi

saida=$("${teste[@]}" 2>&1) && exit 0
{
  echo "Os testes falham. Não encerre ainda: corrija e rode de novo."
  echo
  tail -20 <<<"$saida"
} >&2
exit 2
