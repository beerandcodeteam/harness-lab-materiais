#!/usr/bin/env bash
# candidatas.sh · plugin feature-alvo · Harness Lab, aula 1.5
#
# Junta o que o repositório sabe sobre candidatas a feature-alvo.
# Só lê. Não altera nada. Funciona no bash 3.2 do macOS, sem jq.
#
#   candidatas.sh          últimos 20 commits
#   candidatas.sh 50       últimos 50 commits
#
# Mostra os lugares onde a aula manda procurar:
#   - o que você mexeu por último (e pode ter ficado pela metade): commits e branches;
#   - o que você mesmo marcou para depois: TODO, FIXME e HACK no código versionado;
#   - onde o trabalho anda quente: os arquivos mais mexidos nos últimos 90 dias;
#   - quantos arquivos de teste o projeto tem (zero também serve: os primeiros nascem no Módulo 4).
# O backlog do time não está no git: pergunte para quem usa o sistema.
set -uo pipefail

n="${1:-20}"
case "$n" in '' | *[!0-9]* | 0) echo "uso: $(basename "$0") [número de commits]" >&2; exit 2 ;; esac

raiz="${CLAUDE_PROJECT_DIR:-$PWD}"
if ! git -C "$raiz" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "$raiz não é um repositório git. Sem histórico para olhar: liste as candidatas do backlog."
  exit 0
fi
g() { git -C "$raiz" "$@"; }
nome="$(basename "$(g rev-parse --show-toplevel)")"

echo "# Candidatas a feature-alvo · $nome"
echo

echo "## Últimos $n commits"
if g rev-parse --verify -q HEAD >/dev/null; then
  g log --no-decorate -"$n" --date=short --format='%ad %h %s'
else
  echo "(nenhum commit ainda)"
fi
echo

echo "## Branches locais, da mais recente para a mais antiga"
br=$(g for-each-ref --sort=-committerdate --count=10 refs/heads \
  --format='%(committerdate:short) %(refname:short)')
if [ -n "$br" ]; then printf '%s\n' "$br"; else echo "(nenhuma)"; fi
atual=$(g symbolic-ref --short -q HEAD || true)
[ -n "$atual" ] && echo "(você está em: $atual)"
echo

echo "## Marcados para depois: TODO, FIXME, HACK"
marc=$(g grep -n -I -w -E 'TODO|FIXME|HACK' 2>/dev/null || true)
qtd=$(printf '%s' "$marc" | grep -c . || true)
if [ "$qtd" -gt 0 ]; then
  printf '%s\n' "$marc" | cut -c1-160 | head -30
  [ "$qtd" -gt 30 ] && echo "(mostrando 30 de $qtd)"
else
  echo "(nenhum)"
fi
echo

echo "## Arquivos mais mexidos nos últimos 90 dias"
quentes=$(g log --since=90.days --no-decorate --format= --name-only 2>/dev/null | grep . | sort | uniq -c | sort -rn | head -10)
if [ -n "$quentes" ]; then printf '%s\n' "$quentes"; else echo "(nenhum commit nos últimos 90 dias)"; fi
echo

echo "## Testes"
testes=$(g ls-files | grep -E -c '(^|/)(tests?|spec|specs|__tests__)/|(_test|_spec|\.test|\.spec|Test)\.[A-Za-z]+$' || true)
if [ "$testes" -gt 0 ]; then
  echo "$testes arquivo(s) de teste versionado(s)."
else
  echo "Nenhum arquivo de teste. Tudo bem: os primeiros testes da feature nascem no Módulo 4."
fi
echo
echo "Isto é pista, não decisão. A candidata ainda passa nas cinco peneiras, e quem escolhe é você."
