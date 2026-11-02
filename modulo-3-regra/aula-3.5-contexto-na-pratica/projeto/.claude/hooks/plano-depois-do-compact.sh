#!/usr/bin/env bash
# Harness Lab · aula 3.5 · plano-depois-do-compact.sh
#
# Hook de SessionStart com matcher "compact": roda logo depois de toda compactação,
# manual (/compact) ou automática, e devolve ao modelo o estado que mora em disco:
# qual PLANO.md está em andamento, o próximo item e o que já foi tentado e não deu.
#
# Por quê: depois do /compact, o que foi dito só na conversa vira resumo e pode se
# perder. O CLAUDE.md da raiz volta do disco; o plano da feature, não. Este hook faz
# o plano voltar também. Ele não lê a conversa nem chama o modelo: só lê arquivos.
#
# Saída: JSON com additionalContext (vai para o contexto do modelo) e systemMessage
# (uma linha para você ver na tela). Sem plano pendente, sai calado com exit 0.
# Nunca bloqueia: qualquer problema vira exit 0 sem saída.
#
# Ajustes (variável na frente do comando no settings.json, ou exportada):
#   PLANO_GLOB      onde procurar os planos, separado por espaço
#                   (padrão: "features/*/PLANO.md PLANO.md")
#   PLANO_MAX_NAO   máximo de linhas de "Não deu certo" devolvidas (padrão: 8)
#
# Formato esperado do PLANO.md (veja modelos/PLANO.md): itens "- [ ]" pendentes,
# "- [x]" feitos e uma seção "## Não deu certo". Só os itens "- [ ]" são obrigatórios.

PLANO_GLOB="${PLANO_GLOB:-features/*/PLANO.md PLANO.md}"
PLANO_MAX_NAO="${PLANO_MAX_NAO:-8}"

entrada="$(cat 2>/dev/null || true)"
raiz="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$raiz" ] && command -v jq >/dev/null 2>&1; then
    raiz="$(printf '%s' "$entrada" | jq -r '.cwd // empty' 2>/dev/null || true)"
fi
[ -n "$raiz" ] || raiz="$PWD"
cd "$raiz" 2>/dev/null || exit 0

# Planos que existem e têm pelo menos um item pendente, do mais recente para o mais antigo.
# Separa os padrões sem expandir (set -f), e só depois expande cada um. Assim um
# caminho com espaço vindo do glob não é partido em dois.
planos=()
set -f
read -ra padroes <<< "$PLANO_GLOB"
set +f
for padrao in "${padroes[@]}"; do
    for f in $padrao; do
        [ -f "$f" ] || continue
        grep -Eq '^[[:space:]]*[-*] \[ \]' "$f" 2>/dev/null && planos+=("$f")
    done
done
[ "${#planos[@]}" -gt 0 ] || exit 0
ordenados=()
while IFS= read -r f; do ordenados+=("$f"); done < <(ls -t "${planos[@]}" 2>/dev/null)
[ "${#ordenados[@]}" -gt 0 ] || exit 0

atual="${ordenados[0]}"
pendentes="$(grep -Ec '^[[:space:]]*[-*] \[ \]' "$atual")"
proximo="$(grep -Em1 '^[[:space:]]*[-*] \[ \]' "$atual" | sed -E 's/^[[:space:]]*[-*] \[ \][[:space:]]*//')"
# Linhas da seção "Não deu certo" (até o próximo título), sem linhas vazias.
nao_deu="$(awk -v max="$PLANO_MAX_NAO" '
    /^#+[[:space:]]/ { dentro = ($0 ~ /[Nn](ã|Ã|a|A)[Oo][[:space:]]+[Dd][Ee][Uu][[:space:]]+[Cc][Ee][Rr][Tt][Oo]/); next }
    dentro && NF { print "  " $0; n++; if (n >= max) exit }
' "$atual")"

ctx="Estado em disco, reinjetado depois da compactação (hook plano-depois-do-compact):
- Plano em andamento: $atual ($pendentes item(ns) pendente(s)).
- Próximo item: $proximo"
if [ -n "$nao_deu" ]; then
    ctx="$ctx
- Já tentado e não deu certo:
$nao_deu"
fi
if [ "${#ordenados[@]}" -gt 1 ]; then
    outros="$(printf '%s, ' "${ordenados[@]:1}")"
    ctx="$ctx
- Outros planos com pendência: ${outros%, }."
fi
ctx="$ctx
- O plano completo está em $atual. O fluxo do projeto: ao terminar um item, commit e atualização do plano (feito, próximo, o que não deu)."

msg="plano reinjetado depois do compact: $atual, próximo: $proximo"

if command -v jq >/dev/null 2>&1; then
    jq -nc --arg c "$ctx" --arg m "$msg" \
        '{systemMessage: $m, hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $c}}'
else
    # Sem jq: texto puro no stdout também vai para o contexto do modelo.
    printf '%s\n' "$ctx"
fi
exit 0
