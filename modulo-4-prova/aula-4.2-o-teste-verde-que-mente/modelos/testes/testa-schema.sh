#!/usr/bin/env bash
# testa-schema.sh · aula 4.2 · confere o schema_estrito.py
# Uso: bash testes/testa-schema.sh
set -uo pipefail
raiz="$(cd "$(dirname "$0")/.." && pwd)"
script="$raiz/schema_estrito.py"
ok=0; ruim=0

caso() {   # caso "descrição" exit_esperado "texto que precisa aparecer" ARQUIVO|-  [json no stdin]
  local desc="$1" exit_esp="$2" precisa="$3" arq="$4" entrada="${5:-}" saida rc
  if [ "$arq" = "-" ]; then saida=$(python3 -I "$script" - <<<"$entrada" 2>&1); rc=$?
  else saida=$(python3 -I "$script" "$arq" 2>&1); rc=$?; fi
  if [ "$rc" = "$exit_esp" ] && grep -qF -- "$precisa" <<<"$saida"; then
    ok=$((ok+1)); printf '  \033[32m✓\033[0m  %-48s exit %s\n' "$desc" "$rc"
  else
    ruim=$((ruim+1)); printf '  \033[31m✗\033[0m  %-48s esperado exit %s com "%s", veio exit %s\n' "$desc" "$exit_esp" "$precisa" "$rc"
    sed 's/^/        /' <<<"$saida"
  fi
}

caso "schema-antes.json (o caso da aula)"        1 "product.name fora do required"   "$raiz/fixtures/schema-antes.json"
caso "schema-antes.json pega o item de array"    1 "similar_products[].reason"       "$raiz/fixtures/schema-antes.json"
caso "schema-depois.json (corrigido)"            0 "ok:"                             "$raiz/fixtures/schema-depois.json"

caso "objeto dentro de array dentro de objeto"   1 "pedido.itens[].preco fora"       - \
  '{"type":"object","required":["pedido"],"properties":{"pedido":{"type":"object","required":["itens"],"properties":{"itens":{"type":"array","items":{"type":"object","required":["nome"],"properties":{"nome":{"type":"string"},"preco":{"type":["number","null"]}}}}}}}}'

caso "anyOf com ramo incompleto"                  1 "contato.email fora"              - \
  '{"type":"object","required":["contato"],"properties":{"contato":{"anyOf":[{"type":"object","properties":{"email":{"type":"string"}}},{"type":"null"}]}}}'

caso "corpo da requisição (Responses API)"       1 "product.name"                    - \
  "{\"model\":\"x\",\"text\":{\"format\":{\"type\":\"json_schema\",\"name\":\"schema_definition\",\"strict\":true,\"schema\":$(cat "$raiz/fixtures/schema-antes.json")}}}"

caso "corpo da requisição (Chat Completions)"    0 "ok:"                             - \
  "{\"response_format\":{\"type\":\"json_schema\",\"json_schema\":{\"name\":\"x\",\"strict\":true,\"schema\":$(cat "$raiz/fixtures/schema-depois.json")}}}"

caso "objeto sem properties"                      0 "ok:"                             - '{"type":"object"}'
caso "entrada que não é JSON"                      2 "não consegui ler"                - 'isso não é json'

echo
echo "$ok passaram, $ruim falharam"
[ "$ruim" -eq 0 ]
