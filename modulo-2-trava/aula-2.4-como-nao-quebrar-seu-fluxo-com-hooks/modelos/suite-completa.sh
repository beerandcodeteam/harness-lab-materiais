#!/usr/bin/env bash
# suite-completa.sh · Harness Lab · aula 2.4 · PostToolUse em segundo plano (asyncRewake)
# A suíte inteira, sem segurar a sessão. Ligue com "asyncRewake": true (veja
# settings.sem-quebrar.json): o Claude segue trabalhando e, se a suíte falhar (exit 2),
# o stderr acorda o modelo com o erro. Com asyncRewake o "timeout" continua valendo.
# Não use onFailure aqui: em hook de segundo plano ele não tem efeito.
# Em claude -p, hook de segundo plano que ainda está rodando no fim é cancelado.
set -uo pipefail
cat > /dev/null
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
if   [ -x vendor/bin/pest ];             then teste=(vendor/bin/pest --compact)
elif [ -f package.json ];                then teste=(npm test --silent)
elif command -v pytest >/dev/null 2>&1;  then teste=(pytest -q)
else exit 0; fi

saida=$("${teste[@]}" 2>&1) && exit 0
{
  echo "A suíte completa falhou depois da última edição:"
  echo
  tail -20 <<<"$saida"
} >&2
exit 2
