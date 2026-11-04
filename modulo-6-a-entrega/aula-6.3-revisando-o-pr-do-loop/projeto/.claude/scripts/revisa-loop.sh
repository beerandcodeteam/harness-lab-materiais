#!/usr/bin/env bash
# revisa-loop.sh · aula 6.3 · aponta onde olhar no PR do loop (não aprova nada)
#
# Uso: .claude/scripts/revisa-loop.sh [--base <ref>] [--phases <PHASES.md>] [--run <.loop-logs/run>] [--corpo-pr]
#   --base      commit de antes do loop. Padrão: o pai do primeiro commit
#               feat(phase-N) ou wip(phase-N) do branch (desde a main, se existir)
#   --phases    o PHASES.md que o loop rodou. Padrão: o META input do run.tsv
#               mais novo (.loop-logs/*/ ou .phases/state/), senão o único
#               .spec/features/*/PHASES.md. É lido como estava na base.
#   --run       pasta do .loop-logs/<run>/ (resumo.txt, camadas.txt, run.tsv). Padrão: a mais nova
#   --corpo-pr  imprime o rascunho do corpo do PR em markdown (e sai com 0)
#
# Os seis lugares onde o risco mora num PR de agente:
#   1. arquivo fora do "Arquivos:" (e do "Testes:") da fase no PHASES
#   2. plano ou regra mexidos: .spec/, CLAUDE.md, AGENTS.md, .claude/
#   3. teste de aceite além do marcador (roda o confere-aceite.sh)
#   4. lixo e segredo do git add -A: *.log, *.sql, *.dump, .env*, *.pem, mais de 1 MB
#   5. serviço de fora: lembra a fumaça real se o projeto tem teste de integração
#   6. a suíte inteira, rodada por você (lembrete)
# Mais: commit wip(phase-N) = fase reprovada com --keep-going.
#
# Exit: 0 sem alerta · 1 com alerta · 2 erro de uso. Só lê; não roda teste.
set -euo pipefail

BASE=""; PHASES=""; RUNDIR=""; CORPO=0
while [ $# -gt 0 ]; do
  case "$1" in
    --base) BASE="${2:?}"; shift 2 ;;
    --phases) PHASES="${2:?}"; shift 2 ;;
    --run) RUNDIR="${2:?}"; shift 2 ;;
    --corpo-pr) CORPO=1; shift ;;
    -h|--help) sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
    *) echo "opção desconhecida: $1" >&2; exit 2 ;;
  esac
done

RAIZ=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "revisa-loop: rode dentro do repositório" >&2; exit 2; }
cd "$RAIZ"
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIMITE_BYTES=$((1024 * 1024))

# --- commits do loop e base ------------------------------------------------------
INTERVALO="HEAD"
for principal in main master; do
  if git rev-parse -q --verify "$principal" >/dev/null && [ "$(git rev-parse "$principal")" != "$(git rev-parse HEAD)" ]; then
    INTERVALO="$(git merge-base "$principal" HEAD)..HEAD"; break
  fi
done
mapfile -t COMMITS < <(git log --reverse --format='%H%x09%ct%x09%s' "$INTERVALO" | awk -F'\t' '$3 ~ /^(feat|wip)\(phase-[0-9]+\)/')
if [ -z "$BASE" ]; then
  [ "${#COMMITS[@]}" -gt 0 ] || { echo "revisa-loop: nenhum commit feat(phase-N) ou wip(phase-N) em $INTERVALO. Passe --base." >&2; exit 2; }
  BASE=$(git rev-parse "${COMMITS[0]%%$'\t'*}^")
else
  BASE=$(git rev-parse --verify -q "$BASE^{commit}") || { echo "revisa-loop: base inválida" >&2; exit 2; }
  mapfile -t COMMITS < <(git log --reverse --format='%H%x09%ct%x09%s' "$BASE..HEAD" | awk -F'\t' '$3 ~ /^(feat|wip)\(phase-[0-9]+\)/')
fi

# --- run, resumo e PHASES ----------------------------------------------------------
if [ -z "$RUNDIR" ] && [ -d .loop-logs ]; then
  RUNDIR=$(ls -1dt .loop-logs/*/ 2>/dev/null | while read -r d; do [ -f "$d/run.tsv" ] && { echo "$d"; break; }; done || true)
  RUNDIR="${RUNDIR%/}"
fi
RUNTSV=""
if [ -n "$RUNDIR" ] && [ -f "$RUNDIR/run.tsv" ]; then RUNTSV="$RUNDIR/run.tsv"
elif [ -f .phases/state/run.tsv ]; then RUNTSV=".phases/state/run.tsv"; fi
meta() { [ -n "$RUNTSV" ] && awk -F'\t' -v k="$1" '$1=="META" && $2==k {print $3}' "$RUNTSV" || true; }
INICIO=$(meta started)

if [ -z "$PHASES" ]; then
  PHASES=$(meta input)
  if [ -z "$PHASES" ]; then
    mapfile -t cand < <(git ls-tree -r --name-only "$BASE" | grep -E '^\.spec/features/[^/]+/PHASES\.md$' || true)
    [ "${#cand[@]}" -eq 1 ] && PHASES="${cand[0]}"
  fi
fi
PHASES_TXT=""
if [ -n "$PHASES" ]; then
  PHASES_TXT=$(git show "$BASE:$PHASES" 2>/dev/null || cat "$PHASES" 2>/dev/null || true)
fi

# Caminhos declarados por fase: "N<TAB>padrão", das linhas Arquivos: e Testes:.
declare -A PLANO=()
if [ -n "$PHASES_TXT" ]; then
  while IFS=$'\t' read -r n p; do PLANO[$n]+="$p"$'\n'; done < <(
    awk '
      /^## Phase [0-9]+:/ { split($3, a, ":"); fase = a[1]; next }
      /^## / { fase = ""; next }
      fase != "" && /(Arquivos?|Testes?):/ {
        linha = $0
        while (match(linha, /`[^`]+`/)) {
          p = substr(linha, RSTART + 1, RLENGTH - 2)
          linha = substr(linha, RSTART + RLENGTH)
          gsub(/<[^>]*>/, "*", p)
          if (p ~ /[\/.]/ && p !~ / /) print fase "\t" p
        }
      }' <<< "$PHASES_TXT")
fi
no_plano() {  # no_plano <fase> <arquivo> -> 0 se casa com algum padrão da fase
  local f="$1" a="$2" p
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    # shellcheck disable=SC2053
    [[ "$a" == $p ]] && return 0
    [[ "$p" == */ && "$a" == "$p"* ]] && return 0
  done <<< "${PLANO[$f]:-}"
  return 1
}
fase_dona() {  # outra fase que declara o arquivo
  local a="$1" f
  for f in "${!PLANO[@]}"; do no_plano "$f" "$a" && { echo "$f"; return; }; done
  return 0
}

suspeito() {  # suspeito <commit> <arquivo> -> motivo ou vazio
  local c="$1" a="$2" nome tam
  nome=$(basename "$a")
  case "$nome" in
    *.log|*.sql|*.dump|*.pem|*.key|*.p12|.env|.env.*) echo "arquivo suspeito ($nome)"; return ;;
  esac
  tam=$(git cat-file -s "$c:$a" 2>/dev/null || echo 0)
  [ "$tam" -gt "$LIMITE_BYTES" ] && echo "maior que 1 MB ($((tam / 1024)) KB)"
  return 0
}

ALERTAS=()
alerta() { ALERTAS+=("$1"); }
RELATORIO=""
diga() { RELATORIO+="$1"$'\n'; }

diga "Base $(git rev-parse --short "$BASE") ($(git log -1 --format='%s' "$BASE" | cut -c1-60)) -> HEAD $(git rev-parse --short HEAD)"
diga "Plano: ${PHASES:-(não achei o PHASES.md; sem conferência de Arquivos:)}"
[ -n "$RUNDIR" ] && diga "Run: $RUNDIR"
diga ""
diga "Commits do loop:"
anterior="$INICIO"
for linha in "${COMMITS[@]}"; do
  IFS=$'\t' read -r h ct s <<< "$linha"
  fase=$(sed -E 's/^(feat|wip)\(phase-([0-9]+)\).*/\2/' <<< "$s")
  if [ -n "$anterior" ] && [ "$anterior" -le "$ct" ]; then
    dur=$(( (ct - anterior) / 60 )); dur="${dur} min"
  else
    dur="?"
  fi
  anterior="$ct"
  diga "  ${h:0:7} $(date -d "@$ct" '+%H:%M') (+$dur) $s"
  [[ "$s" == wip* ]] && alerta "${h:0:7} $s: fase $fase reprovada e commitada como wip (--keep-going). O código dela não passou nos gates."
  while IFS=$'\t' read -r st a outro; do
    [ -n "$st" ] || continue
    [[ "$st" == R* ]] && a="$outro"
    diga "      $st $a"
    [[ "$st" == D* ]] && continue
    motivo=$(suspeito "$h" "$a")
    if [ -n "$motivo" ]; then
      alerta "${h:0:7} $a: $motivo. git add -A pega tudo que não está no .gitignore."
      continue
    fi
    case "$a" in
      .spec/*|CLAUDE.md|*/CLAUDE.md|AGENTS.md|*/AGENTS.md|.claude/*)
        alerta "${h:0:7} $a: plano ou regra mexidos pelo loop. Leia o diff; mudar o PHASES zera o progresso no próximo run."
        continue ;;
    esac
    if [ -n "$PHASES_TXT" ] && ! no_plano "$fase" "$a"; then
      dona=$(fase_dona "$a")
      if [ -n "$dona" ]; then
        alerta "${h:0:7} $a: fora do Arquivos: da fase $fase (é da fase $dona: escopo antecipado)."
      else
        alerta "${h:0:7} $a: fora do Arquivos: da fase $fase. Por que ele precisou disso?"
      fi
    fi
  done < <(git diff-tree --no-commit-id --name-status -r -M "$h")
done
[ "${#COMMITS[@]}" -eq 0 ] && diga "  (nenhum commit de fase depois da base)"
diga ""

# --- testes de aceite ---------------------------------------------------------------
ACEITE_SAIDA=""
if git cat-file -e "$BASE:.claude/aceite.txt" 2>/dev/null; then
  rc=0
  ACEITE_SAIDA=$(bash "$AQUI/confere-aceite.sh" "$BASE" 2>&1) || rc=$?
  diga "Testes de aceite (confere-aceite.sh):"
  diga "$(sed 's/^/  /' <<< "$ACEITE_SAIDA")"
  if [ "$rc" -eq 1 ]; then
    alerta "Teste de aceite mudou além do marcador (confere-aceite.sh acima)."
  elif [ "$rc" -ne 0 ]; then
    alerta "confere-aceite.sh não conseguiu conferir (exit $rc). Confira os testes de aceite à mão."
  fi
else
  diga "Testes de aceite: a base não tem .claude/aceite.txt; nada a conferir."
fi
diga ""

# --- lembretes ----------------------------------------------------------------------
INTEGRACAO=$( {
  ls -d tests/Integration tests/integration tests/Smoke tests/smoke tests/e2e tests/Browser 2>/dev/null || true
  grep -rlsiE "group\(['\"](integration|integracao|smoke|fumaca|external)['\"]|@group (integration|smoke)|mark\.(integration|smoke)" tests 2>/dev/null | head -n 3 || true
  grep -sliE '<group>(integration|smoke)' phpunit.xml phpunit.xml.dist 2>/dev/null || true
} | sort -u | tr '\n' ' ')
diga "Lembretes:"
diga "  Rode a suíte inteira você mesmo, fora do loop."
if [ -n "$INTEGRACAO" ]; then
  diga "  O projeto tem teste de integração ou fumaça ($INTEGRACAO): a fumaça real (aula 4.2) não roda no gate 2. Rode."
else
  diga "  A feature encosta em serviço de fora? Rode a fumaça real da 4.2 antes do merge."
fi

# --- saída ----------------------------------------------------------------------------
if [ "$CORPO" -eq 1 ]; then
  slug=$(sed -E 's#^\.spec/features/([^/]+)/.*#\1#' <<< "${PHASES:-feature}")
  echo "## $slug: entregue pelo loop"
  echo ""
  echo "### Resumo do run"
  echo '```'
  if [ -n "$RUNDIR" ] && [ -f "$RUNDIR/resumo.txt" ]; then cat "$RUNDIR/resumo.txt"
  elif [ -x "$AQUI/desfecho.sh" ] && [ -n "$RUNTSV" ]; then bash "$AQUI/desfecho.sh" "$RUNTSV" 2>&1 | sed -n '1,/^Fases:/p' | sed '$d' || true
  else echo "(sem resumo.txt: rode pelo loop.sh, que grava .loop-logs/<run>/resumo.txt)"; fi
  echo '```'
  echo ""
  echo "### Camadas do harness neste repositório"
  echo '```'
  if [ -n "$RUNDIR" ] && [ -f "$RUNDIR/camadas.txt" ]; then cat "$RUNDIR/camadas.txt"; else echo "(sem camadas.txt: é o loop.sh --checa que escreve)"; fi
  echo '```'
  echo ""
  echo "### Commits"
  for linha in "${COMMITS[@]}"; do IFS=$'\t' read -r h ct s <<< "$linha"; echo "- \`${h:0:7}\` $s"; done
  echo ""
  echo "### Alertas da revisão e decisões"
  if [ "${#ALERTAS[@]}" -eq 0 ]; then echo "Nenhum alerta do revisa-loop.sh."; fi
  for a in "${ALERTAS[@]}"; do echo "- $a"; echo "  - Decisão: "; done
  echo ""
  echo "### Riscos e o que conferi fora do loop"
  echo "- Suíte inteira rodada por mim: "
  echo "- Fumaça real (serviço de fora ou fluxo na mão): "
  echo "- O pacote da prova (log do loop) vai anexado: prova-<run>.tar.gz"
  echo ""
  echo "Revisado por uma pessoa. O merge é decisão humana."
  exit 0
fi

printf '%s' "$RELATORIO"
echo ""
if [ "${#ALERTAS[@]}" -eq 0 ]; then
  echo "Nenhum alerta. Bata o olho no diff e siga para os lembretes."
  exit 0
fi
echo "${#ALERTAS[@]} alerta(s). Decida cada um em voz alta (corrigir, aceitar com motivo, ou voltar para a camada):"
i=0
for a in "${ALERTAS[@]}"; do i=$((i + 1)); echo "  $i. $a"; done
exit 1
