#!/usr/bin/env bash
# evidencias.sh · plugin diagnostico-camadas · Harness Lab, aula 1.4
#
# Junta o que o git sabe sobre as suas correções, para classificar por camada.
# Só lê. Não altera nada. Não precisa de jq.
#
#   evidencias.sh          últimos 100 commits
#   evidencias.sh 300      últimos 300 commits
#
# Mostra: os 15 commits mais recentes, os que têm cara de correção (fix, corrige,
# revert, hotfix...), os reverts, e os arquivos que mais voltaram em commit de correção.
# Arquivo que volta sempre é pista de Regra (informação que falta) ou de Prova (nada confere).
set -uo pipefail

n="${1:-100}"
case "$n" in '' | *[!0-9]* | 0) echo "uso: $(basename "$0") [número de commits]" >&2; exit 2 ;; esac

raiz="${CLAUDE_PROJECT_DIR:-$PWD}"
if ! git -C "$raiz" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "$raiz não é um repositório git: sem evidência do git. Use só a lista da aula 1.3."
  exit 0
fi
if ! git -C "$raiz" rev-parse --verify -q HEAD >/dev/null; then
  echo "Repositório sem nenhum commit ainda: sem evidência do git."
  exit 0
fi

g() { git -C "$raiz" "$@"; }
padrao='fix|corrig|conserta|arruma|revert|desfaz|hotfix|bug|quebr|volta|ajuste'

echo "# Evidências do git · $(basename "$raiz") · últimos $n commits"
echo
echo "## Os 15 mais recentes"
g log --no-decorate -15 --date=short --format='%ad %h %s'
echo

corr=$(g log --no-decorate -"$n" --date=short --format='%ad %h %s' -i -E --grep="$padrao")
qtd=$(printf '%s' "$corr" | grep -c . || true)
echo "## Com cara de correção: $qtd"
if [ "$qtd" -gt 0 ]; then printf '%s\n' "$corr" | head -20; else echo "(nenhum)"; fi
echo

rev=$(g log --no-decorate -"$n" --format='%h %s' -i --grep='^revert' | head -10)
echo "## Reverts"
if [ -n "$rev" ]; then printf '%s\n' "$rev"; else echo "(nenhum)"; fi
echo

echo "## Arquivos que mais voltaram em commit de correção"
arqs=$(g log --no-decorate -"$n" --format= --name-only -i -E --grep="$padrao" | grep . | sort | uniq -c | sort -rn | head -8)
if [ -n "$arqs" ]; then printf '%s\n' "$arqs"; else echo "(nenhum)"; fi
echo
echo "Isto é pista, não veredito: confirme cada caso com quem estava lá (você)."
