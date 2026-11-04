#!/usr/bin/env bash
# stack-pr.sh · aula 6.3 · um PR por fase do loop, empilhados (stacked pull requests do GitHub)
#
# Uso: .claude/scripts/stack-pr.sh [--trunk <branch>] [--prefixo <nome>] [--phases <PHASES.md>] [--criar] [--pronto]
#   sem --criar  só mostra o plano: as camadas, a base de cada PR, o título e os
#                comandos que o --criar rodaria. Não muda nada.
#   --criar      cria uma branch por fase, faz push e abre um PR por fase, cada um
#                com base na camada de baixo. Em rascunho, a não ser com --pronto.
#   --trunk      com o que comparar (padrão: origin/main, o que o GitHub tem; sem
#                ela, a main local; depois master). A base do PR de baixo é a branch
#                sem o "origin/". Commit que está na main local e ainda não subiu
#                entra no PR de baixo: o plano mostra como "leva também".
#   --prefixo    nome das branches: <prefixo>/phase-N (padrão: stack/<slug do PHASES>)
#   --phases     o PHASES.md do run (padrão: o META input do run.tsv mais novo em
#                .loop-logs/*/ ou .phases/state/, senão o único .spec/features/*/PHASES.md)
#
# Cada commit feat(phase-N) vira uma camada. Commits sem fase que vêm antes de uma
# fase entram na camada dela (o plano mostra). Commit wip(phase-N) é fase reprovada:
# não vira PR, o script para. O corpo de cada PR é a seção da fase no PHASES.md.
# Com a extensão gh-stack instalada, liga os PRs numa stack (gh stack link). Sem ela,
# abra um dos PRs: o GitHub mostra "Preview stack" e você cria a stack por ali.
# Não faz merge.
#
# Exit: 0 ok · 1 recusou (fase wip, branch existente com outro commit, push ou PR falhou) · 2 erro de uso
set -euo pipefail

TRUNK=""; PREFIXO=""; PHASES=""; CRIAR=0; PRONTO=0
while [ $# -gt 0 ]; do
  case "$1" in
    --trunk) TRUNK="${2:?}"; shift 2 ;;
    --prefixo) PREFIXO="${2:?}"; shift 2 ;;
    --phases) PHASES="${2:?}"; shift 2 ;;
    --criar) CRIAR=1; shift ;;
    --pronto) PRONTO=1; shift ;;
    -h|--help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
    *) echo "opção desconhecida: $1" >&2; exit 2 ;;
  esac
done

RAIZ=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "stack-pr: rode dentro do repositório" >&2; exit 2; }
cd "$RAIZ"

# --- trunk e intervalo ----------------------------------------------------------------
# Padrão: a origin/main. No GitHub, o PR de baixo mira a main de lá; um commit que só
# existe na main local (o do plano, um commit solto) vai junto nesse PR. Comparar com
# a origin/main põe esse commit no plano, antes de qualquer push.
if [ -z "$TRUNK" ]; then
  for t in main master; do
    if git rev-parse -q --verify "refs/remotes/origin/$t^{commit}" >/dev/null; then TRUNK="origin/$t"; break; fi
    if git rev-parse -q --verify "refs/heads/$t^{commit}" >/dev/null; then TRUNK="$t"; break; fi
  done
  [ -n "$TRUNK" ] || { echo "stack-pr: não achei origin/main, main nem master. Passe --trunk <branch>." >&2; exit 2; }
fi
git rev-parse -q --verify "$TRUNK^{commit}" >/dev/null || { echo "stack-pr: trunk inválido: $TRUNK" >&2; exit 2; }
BASE_PR="${TRUNK#origin/}"
MB=$(git merge-base "$TRUNK" HEAD)
mapfile -t LINHAS < <(git log --reverse --format='%H%x09%s' "$MB..HEAD")
if [ "${#LINHAS[@]}" -eq 0 ]; then
  echo "stack-pr: nenhum commit entre $TRUNK e HEAD." >&2
  if [ "$TRUNK" = "$BASE_PR" ]; then
    echo "Sem origin/$BASE_PR e o loop commitou na própria $BASE_PR? Passe --trunk <commit de antes do loop>." >&2
  else
    echo "HEAD já está em $TRUNK: nada para empilhar. Se a $BASE_PR do GitHub andou, git fetch origin $BASE_PR." >&2
  fi
  exit 2
fi
AVISO_TRUNK=""
if [ "$TRUNK" != "$BASE_PR" ] && git rev-parse -q --verify "refs/heads/$BASE_PR^{commit}" >/dev/null; then
  frente=$(git rev-list --count "$TRUNK..refs/heads/$BASE_PR")
  [ "$frente" -gt 0 ] && AVISO_TRUNK="a $BASE_PR local tem $frente commit(s) que não estão em $TRUNK. Os que estão nesta branch entram no PR de baixo (leva também); para tirá-los da stack, git push origin $BASE_PR antes."
elif [ "$TRUNK" = "$BASE_PR" ] && git remote get-url origin >/dev/null 2>&1; then
  AVISO_TRUNK="sem origin/$BASE_PR, comparei com a $BASE_PR local. Commit dela que não está no GitHub vai junto no PR de baixo sem aparecer aqui: git fetch origin $BASE_PR e rode de novo."
fi

# --- PHASES e slug -----------------------------------------------------------------------
if [ -z "$PHASES" ]; then
  run=""
  for d in $(ls -1dt .loop-logs/*/ 2>/dev/null || true); do [ -f "$d/run.tsv" ] && { run="$d/run.tsv"; break; }; done
  [ -z "$run" ] && [ -f .phases/state/run.tsv ] && run=.phases/state/run.tsv
  [ -n "$run" ] && PHASES=$(awk -F'\t' '$1=="META" && $2=="input" {print $3}' "$run")
  if [ -z "$PHASES" ]; then
    mapfile -t cand < <(git ls-tree -r --name-only HEAD | grep -E '^\.spec/features/[^/]+/PHASES\.md$' || true)
    [ "${#cand[@]}" -eq 1 ] && PHASES="${cand[0]}"
  fi
fi
PHASES_TXT=""
[ -n "$PHASES" ] && PHASES_TXT=$(git show "$MB:$PHASES" 2>/dev/null || cat "$PHASES" 2>/dev/null || true)
if [[ "$PHASES" =~ ^\.spec/features/([^/]+)/ ]]; then SLUG="${BASH_REMATCH[1]}"
else SLUG=$(git symbolic-ref --short -q HEAD || echo loop); SLUG="${SLUG##*/}"; fi
PREFIXO="${PREFIXO:-stack/$SLUG}"

secao() {  # secao <N>: o texto da "## Phase N:" do PHASES, sem o título
  awk -v n="$1" '
    $0 ~ "^## Phase " n ":" { dentro = 1; next }
    dentro && /^## / { exit }
    dentro { print }' <<< "$PHASES_TXT" | sed -e '/./,$!d'
}

# --- camadas ----------------------------------------------------------------------------
SHA=(); FASE=(); TIT=(); EXTRA=(); NOME=(); pend=""
declare -A USADO=()
for linha in "${LINHAS[@]}"; do
  h="${linha%%$'\t'*}"; s="${linha#*$'\t'}"
  if [[ "$s" =~ ^wip\(phase-([0-9]+)\) ]]; then
    echo "stack-pr: ${h:0:7} $s" >&2
    echo "A fase ${BASH_REMATCH[1]} foi reprovada e commitada como wip (--keep-going). Fase reprovada não vira PR: leia o desfecho (aula 6.2)." >&2
    exit 1
  fi
  if [[ "$s" =~ ^feat\(phase-([0-9]+)\):?[[:space:]]*(.*)$ ]]; then
    n="${BASH_REMATCH[1]}"; t="${BASH_REMATCH[2]:-fase $n}"
    nome="$PREFIXO/phase-$n"; k=2
    while [ -n "${USADO[$nome]:-}" ]; do nome="$PREFIXO/phase-$n-$k"; k=$((k + 1)); done
    USADO[$nome]=1
    SHA+=("$h"); FASE+=("$n"); TIT+=("$t"); EXTRA+=("$pend"); NOME+=("$nome"); pend=""
  else
    pend+="${h:0:7} $s"$'\n'
  fi
done
T="${#SHA[@]}"
[ "$T" -gt 0 ] || { echo "stack-pr: nenhum commit feat(phase-N) entre $TRUNK e HEAD. Nada para empilhar." >&2; exit 2; }

base_de() { if [ "$1" -eq 0 ]; then echo "$BASE_PR"; else echo "${NOME[$(( $1 - 1 ))]}"; fi; }
desde() { if [ "$1" -eq 0 ]; then echo "$MB"; else echo "${SHA[$(( $1 - 1 ))]}"; fi; }
titulo() { echo "$SLUG $(( $1 + 1 ))/$T: ${TIT[$1]}"; }

corpo() {  # corpo <i>: o corpo do PR da camada i
  local i="$1" n="${FASE[$1]}" sec
  echo "## Stack $SLUG: camada $(( i + 1 )) de $T"
  echo ""
  echo "Base: \`$(base_de "$i")\`. Merge de baixo para cima: o merge de uma camada leva junto as de baixo."
  echo ""
  echo "### O que a fase $n pedia (PHASES.md)"
  echo ""
  sec=$(secao "$n")
  if [ -n "$sec" ]; then echo "$sec"; else echo "(não achei a seção \"## Phase $n:\" em ${PHASES:-PHASES.md})"; fi
  echo ""
  echo "### Commits desta camada"
  echo ""
  [ -n "${EXTRA[$i]}" ] && sed '/^$/d; s/^\([0-9a-f]*\) /- `\1` /' <<< "${EXTRA[$i]}"
  echo "- \`${SHA[$i]:0:7}\` feat(phase-$n): ${TIT[$i]}"
  echo ""
  echo "### Arquivos"
  echo ""
  echo '```'
  git diff --stat "$(desde "$i")" "${SHA[$i]}"
  echo '```'
  echo ""
  echo "Onde olhar: \`.claude/scripts/revisa-loop.sh\` aponta os alertas por commit (um commit, uma camada)."
  echo "Revisado por uma pessoa. O merge é decisão humana."
}

# --- plano ----------------------------------------------------------------------------------
via=""; [ "$TRUNK" != "$BASE_PR" ] && via=", comparando com $TRUNK"
echo "Stack de $SLUG: $T camada(s) sobre $BASE_PR (desde $(git rev-parse --short "$MB")$via)"
[ -n "$PHASES" ] && echo "Plano: $PHASES"
[ -n "$AVISO_TRUNK" ] && echo "Atenção: $AVISO_TRUNK"
for i in "${!SHA[@]}"; do
  stat=$(git diff --shortstat "$(desde "$i")" "${SHA[$i]}" | sed 's/^ *//')
  echo "  $(( i + 1 )). ${NOME[$i]} -> ${SHA[$i]:0:7} feat(phase-${FASE[$i]}): ${TIT[$i]}"
  echo "     base: $(base_de "$i") · ${stat:-sem mudança}"
  [ -n "${EXTRA[$i]}" ] && sed '/^$/d; s/^/     leva também: /' <<< "${EXTRA[$i]}"
done
[ -n "$pend" ] && sed '/^$/d; s/^/  fora da stack (depois da última fase): /' <<< "$pend"

DRAFT="--draft"; [ "$PRONTO" -eq 1 ] && DRAFT=""
if [ "$CRIAR" -eq 0 ]; then
  echo ""
  echo "Comandos que o --criar roda:"
  for i in "${!SHA[@]}"; do echo "  git branch ${NOME[$i]} ${SHA[$i]:0:7}"; done
  echo "  git push --atomic -u origin ${NOME[*]}"
  for i in "${!SHA[@]}"; do
    echo "  gh pr create ${DRAFT:+$DRAFT }--base $(base_de "$i") --head ${NOME[$i]} --title \"$(titulo "$i")\" --body-file <corpo>"
  done
  echo "  gh stack link <os $T PRs, de baixo para cima>   (só com a extensão gh-stack)"
  extra=""; [ "$PRONTO" -eq 1 ] && extra=" --pronto"
  echo "Nada foi criado. Para criar: .claude/scripts/stack-pr.sh --criar$extra"
  exit 0
fi

# --- criar ----------------------------------------------------------------------------------
command -v gh >/dev/null || { echo "stack-pr: gh não instalado (GitHub CLI). Veja a aula 6.3." >&2; exit 2; }
git remote get-url origin >/dev/null 2>&1 || { echo "stack-pr: sem remote origin." >&2; exit 2; }
echo ""
for i in "${!SHA[@]}"; do
  b="${NOME[$i]}"
  if atual=$(git rev-parse -q --verify "refs/heads/$b"); then
    [ "$atual" = "${SHA[$i]}" ] || { echo "stack-pr: a branch $b já existe e aponta para outro commit. Apague (git branch -D $b) ou use --prefixo." >&2; exit 1; }
  else
    git branch "$b" "${SHA[$i]}"
  fi
done
git push --atomic -u origin "${NOME[@]}" || { echo "stack-pr: o push falhou; nenhum PR foi aberto." >&2; exit 1; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
NUMS=(); URLS=()
for i in "${!SHA[@]}"; do
  b="${NOME[$i]}"
  url=$(gh pr list --head "$b" --state open --json url --jq '.[0].url // ""' 2>/dev/null || true)
  if [ -z "$url" ]; then
    corpo "$i" > "$TMP/corpo-$i.md"
    # shellcheck disable=SC2086
    url=$(gh pr create $DRAFT --base "$(base_de "$i")" --head "$b" --title "$(titulo "$i")" --body-file "$TMP/corpo-$i.md" | tail -n 1) ||
      { echo "stack-pr: gh pr create falhou na camada $(( i + 1 )) ($b)." >&2; exit 1; }
  fi
  URLS+=("$url"); NUMS+=("${url##*/}")
  echo "  $(( i + 1 ))/$T $url  ($b -> $(base_de "$i"))"
done

echo ""
if gh extension list 2>/dev/null | grep -qE '(^|[[:space:]/])gh-stack([[:space:]]|$)'; then
  if gh stack link --base "$BASE_PR" "${NUMS[@]}"; then
    echo "Stack ligada no GitHub (gh stack link)."
  else
    echo "gh stack link falhou. Abra ${URLS[0]} e use o botão Preview stack."
  fi
else
  echo "Para ligar a stack: abra ${URLS[0]} e clique em Preview stack (o GitHub reconhece a cadeia)."
  echo "Ou instale a extensão (gh extension install github/gh-stack) e rode: gh stack link ${NUMS[*]}"
fi
echo "Revise de baixo para cima. Merge: no PR do topo, Merge stack. Nenhum merge foi feito aqui."
[ -n "$DRAFT" ] && echo "Os PRs estão em rascunho: depois de revisar, Ready for review (ou gh pr ready <n>) em cada um."
exit 0
