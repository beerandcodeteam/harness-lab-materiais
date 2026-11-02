#!/usr/bin/env bash
# Roda todas as validações do repositório. Uso: bash testes/rodar.sh [aula]   ex.: bash testes/rodar.sh 2.2
# 1. claude plugin validate (marketplace e plugins)
# 2. sintaxe de todos os scripts .sh
# 3. os comandos de cada material de apoio, numa sandbox com HOME falso (testes/validar.py)
set -uo pipefail
cd "$(dirname "$0")/.."
falhas=0
passo() { printf '\n\033[1;33m== %s\033[0m\n' "$*"; }

passo "claude plugin validate"
if command -v claude >/dev/null; then
    claude plugin validate . || falhas=$((falhas + 1))
else
    echo "claude não instalado: pulando (npm install -g @anthropic-ai/claude-code)"
fi

passo "bash -n em todos os .sh"
while IFS= read -r f; do
    bash -n "$f" || { echo "sintaxe: $f"; falhas=$((falhas + 1)); }
done < <(find . -name '*.sh' -not -path './.git/*')

passo "comandos dos materiais (sandbox)"
filtro="${1:-}"
for j in modulo-*/aula-*/teste/comandos.json; do
    [ -f "$j" ] || continue
    if [ -n "$filtro" ] && [[ "$j" != *"aula-$filtro-"* ]]; then continue; fi
    echo "-- $j"
    python3 testes/validar.py "$j" --repo . || falhas=$((falhas + 1))
done

echo
if [ "$falhas" -eq 0 ]; then echo "tudo ok"; else echo "$falhas falha(s)"; fi
exit $((falhas > 0))
