#!/usr/bin/env bash
# Harness Lab · instalar.sh
# Copia os arquivos de uma aula para o projeto onde você está.
#
#   ~/harness-lab-materiais/instalar.sh 2.2        instala a aula 2.2 no diretório atual
#   ~/harness-lab-materiais/instalar.sh --lista    mostra o que cada aula instala
#
# Regras (nunca apaga nada seu):
#   - arquivo que não existe: é criado (scripts .sh ganham chmod +x);
#   - arquivo igual ao da aula: fica como está;
#   - arquivo diferente: o seu fica intacto e o da aula vai para <arquivo>.harness-lab-novo;
#   - .claude/settings.json que já existe: os hooks e as permissões da aula são somados
#     aos seus (precisa de jq). Uma cópia do original fica em settings.json.antes-harness-lab.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
verde=$'\033[32m'; amarelo=$'\033[33m'; vermelho=$'\033[31m'; fim=$'\033[0m'
[ -t 1 ] || { verde=""; amarelo=""; vermelho=""; fim=""; }

uso() {
    sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

acha_aula() {
    local n="${1#aula-}"
    local d
    for d in "$REPO"/modulo-*/aula-"$n"-*/; do
        [ -d "$d" ] && { echo "${d%/}"; return 0; }
    done
    return 1
}

lista() {
    local d n arqs
    for d in "$REPO"/modulo-*/aula-*/; do
        d="${d%/}"; n="$(basename "$d")"
        if [ -d "$d/projeto" ]; then
            arqs="$(cd "$d/projeto" && find . -type f | sed 's|^\./||' | sort | tr '\n' ' ')"
            printf '%s\n    %s\n' "${n#aula-}" "$arqs"
        fi
    done
}

mescla_settings() {
    # $1 = settings da aula, $2 = settings do projeto (existe)
    local novo="$1" atual="$2" tmp
    command -v jq >/dev/null || {
        cp "$novo" "$atual.harness-lab-novo"
        echo "${amarelo}sem jq${fim}: não deu para somar. Veja $atual.harness-lab-novo"
        return 0
    }
    if ! jq empty "$atual" 2>/dev/null; then
        cp "$novo" "$atual.harness-lab-novo"
        echo "${vermelho}JSON inválido${fim} no seu settings.json: não mexi nele. O da aula está em $atual.harness-lab-novo"
        return 0
    fi
    tmp="$(mktemp)"
    jq -s '
      def uniq_keep: reduce .[] as $x ([]; if index([$x]) then . else . + [$x] end);
      .[0] as $a | .[1] as $b
      | ($b * $a)
      | .hooks = ((($a.hooks // {}) | keys) + (($b.hooks // {}) | keys) | unique
                  | map({key: ., value: ((($a.hooks // {})[.] // []) + (($b.hooks // {})[.] // []) | uniq_keep)})
                  | from_entries)
      | if (.hooks | length) == 0 then del(.hooks) else . end
      | .permissions = (($a.permissions // {}) * ($b.permissions // {}))
      | .permissions |= with_entries(if (.value | type) == "array"
            then .value = ((($a.permissions // {})[.key] // []) + (($b.permissions // {})[.key] // []) | uniq_keep)
            else . end)
      | if (.permissions | length) == 0 then del(.permissions) else . end
    ' "$atual" "$novo" > "$tmp" || { rm -f "$tmp"; cp "$novo" "$atual.harness-lab-novo"; echo "não deu para somar: veja $atual.harness-lab-novo"; return 0; }
    if [ "$(jq -S . "$tmp")" = "$(jq -S . "$atual")" ]; then rm -f "$tmp"; echo "igual"; return 0; fi
    cp "$atual" "$atual.antes-harness-lab"
    cat "$tmp" > "$atual"   # mantém a permissão do arquivo original
    rm -f "$tmp"
    echo "somado"
}

[ $# -ge 1 ] || { uso; exit 2; }
case "$1" in
    -h|--help) uso; exit 0 ;;
    --lista) lista; exit 0 ;;
esac

AULA="$(acha_aula "$1")" || { echo "${vermelho}Aula '$1' não encontrada.${fim} Veja: $0 --lista" >&2; exit 1; }
ORIGEM="$AULA/projeto"
[ -d "$ORIGEM" ] || { echo "A aula $(basename "$AULA") não tem arquivos para instalar (só material de leitura)."; exit 0; }
DEST="$(pwd)"
case "$DEST" in
    "$REPO"|"$REPO"/*) echo "${vermelho}Rode dentro do SEU projeto, não dentro do harness-lab-materiais.${fim}" >&2; exit 1 ;;
    "$HOME"|/) echo "${vermelho}Rode na raiz do seu projeto, não em $DEST.${fim}" >&2; exit 1 ;;
esac
git -C "$DEST" rev-parse --is-inside-work-tree >/dev/null 2>&1 || \
    echo "${amarelo}aviso${fim}: $DEST não é um repositório git. Recomendado: git init antes, para ver o que mudou."

echo "Instalando $(basename "$AULA") em $DEST"
criados=0; iguais=0; conflitos=0
while IFS= read -r rel; do
    src="$ORIGEM/$rel"; dst="$DEST/$rel"
    mkdir -p "$(dirname "$dst")"
    if [ ! -e "$dst" ]; then
        cp "$src" "$dst"
        case "$rel" in *.sh) chmod +x "$dst" ;; esac
        echo "  ${verde}criado${fim}     $rel"; criados=$((criados + 1))
    elif cmp -s "$src" "$dst"; then
        echo "  igual      $rel"; iguais=$((iguais + 1))
    elif [ "$rel" = ".claude/settings.json" ]; then
        r="$(mescla_settings "$src" "$dst")"
        echo "  ${verde}$r${fim}     $rel"; [ "$r" = "igual" ] && iguais=$((iguais + 1)) || criados=$((criados + 1))
    else
        cp "$src" "$dst.harness-lab-novo"
        case "$rel" in *.sh) chmod +x "$dst.harness-lab-novo" ;; esac
        echo "  ${amarelo}conflito${fim}   $rel  →  o da aula está em $rel.harness-lab-novo"; conflitos=$((conflitos + 1))
    fi
done < <(cd "$ORIGEM" && find . -type f ! -name '.DS_Store' | sed 's|^\./||' | sort)

echo "Pronto: $criados novo(s), $iguais igual(is), $conflitos conflito(s)."
[ "$conflitos" -eq 0 ] || echo "Compare os .harness-lab-novo com os seus e junte o que fizer sentido."
[ -f "$DEST/.claude/settings.json.antes-harness-lab" ] && echo "Backup do seu settings: .claude/settings.json.antes-harness-lab (pode apagar depois de conferir)."
if [ -f "$AULA/README.md" ]; then echo "Próximo passo: veja $AULA/README.md"; fi
