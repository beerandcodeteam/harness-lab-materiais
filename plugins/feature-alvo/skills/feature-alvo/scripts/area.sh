#!/usr/bin/env bash
# area.sh · plugin feature-alvo · Harness Lab, aula 1.5
#
# Mede a peneira "isolada": quantos arquivos falam da área da feature.
# Só lê. Não altera nada. Funciona no bash 3.2 do macOS, sem jq.
#
#   area.sh email
#   area.sh cadastro register signup email
#
# Conta os arquivos versionados que citam qualquer um dos termos (sem diferenciar
# maiúscula) ou que têm o termo no caminho. O git grep só olha arquivo versionado, e
# vendor/ e node_modules/ ficam fora da conta mesmo quando versionados (legado).
# Separa código de teste e aponta pistas de serviço de fora (peneira "sem terceiro").
# A régua é a da aula: se a lista é maior do que você revisaria com calma num PR, corte.
set -uo pipefail

[ $# -ge 1 ] || { echo "uso: $(basename "$0") <termo> [outro termo...]" >&2; exit 2; }

raiz="${CLAUDE_PROJECT_DIR:-$PWD}"
if ! git -C "$raiz" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "$raiz não é um repositório git: o git grep precisa de um."
  exit 0
fi
g() { git -C "$raiz" "$@"; }

args=()
for t in "$@"; do args+=(-e "$t"); done
fora_da_conta=(':(exclude,glob)**/vendor/**' ':(exclude,glob)**/node_modules/**')
lista=$(
  {
    g grep -I -i -l -F "${args[@]}" -- . "${fora_da_conta[@]}" 2>/dev/null || true
    arquivos=$(g ls-files -- . "${fora_da_conta[@]}")
    for t in "$@"; do printf '%s\n' "$arquivos" | grep -i -F -- "$t" || true; done
  } | sort -u
)
total=$(printf '%s' "$lista" | grep -c . || true)

echo "# Área: $*"
echo
if [ "$total" -eq 0 ]; then
  echo "Nenhum arquivo versionado fala de: $*"
  echo "Tente outros nomes da mesma área (em português e em inglês, singular e plural)."
  exit 0
fi

re_teste='(^|/)(tests?|spec|specs|__tests__)/|(_test|_spec|\.test|\.spec|Test)\.[A-Za-z]+$'
testes=$(printf '%s\n' "$lista" | grep -E -c "$re_teste" || true)
codigo=$((total - testes))

echo "## $total arquivo(s) falam da área: $codigo de código, $testes de teste"
printf '%s\n' "$lista" | head -40
[ "$total" -gt 40 ] && echo "(mostrando 40 de $total)"
echo

echo "## Pistas de serviço de fora nesses arquivos"
re_fora='Http::|Guzzle|curl_|fetch\(|axios|requests\.(get|post|put|delete)|httpx|urllib|RestClient|Net::HTTP|Faraday|HttpClient|WebClient|RestTemplate|stripe|pagar\.?me|mercado.?pago|paypal|openai|anthropic|correios|amazonaws|https?://'
fora=$(printf '%s\n' "$lista" | while IFS= read -r f; do
  [ -f "$raiz/$f" ] || continue
  grep -n -i -E "$re_fora" "$raiz/$f" 2>/dev/null | head -3 | sed "s|^|$f:|"
done)
if [ -n "$fora" ]; then
  printf '%s\n' "$fora" | cut -c1-160 | head -15
  echo "Se a prova da feature depende disso, escolha a parte que dá para provar aqui dentro."
else
  echo "(nenhuma)"
fi
echo

if [ "$testes" -eq 0 ]; then
  echo "Nenhum teste fala dessa área ainda. Tudo bem: os primeiros nascem no Módulo 4."
  echo
fi
echo "Pergunta da peneira: você revisaria esses $total arquivo(s) com calma num PR? Se não, corte."
