#!/usr/bin/env bash
# confere-phases.sh · Módulo 5 · o PHASES.md cumpre o contrato com o loop?
#
# Uso, na raiz do repositório:
#   .claude/scripts/confere-phases.sh .spec/features/<slug>/PHASES.md
#   .claude/scripts/confere-phases.sh [--plan PLAN.md] [--aceite aceite.txt] [--feature FEATURE-ALVO.md] [--sem-aceite] PHASES.md
#
# Erro (exit 1):
#   - nenhum "## Phase N: título", ou "## Phase" fora desse formato (o ralph barra)
#   - numeração que não começa em 1 ou pula número
#   - outro "## " entre duas fases (o ralph corta a fase de cima ali, calado)
#   - task "- [ ]" sem "Acceptance criteria:" ou sem "Testes:" (gate 3 e gate 2)
#   - checkbox aninhado (o gate 3 conta como task a mais)
#   - número de tasks diferente do número de "### T" do PLAN.md
#   - com a checagem de aceite: um AC-NN do FEATURE-ALVO.md ou um arquivo do
#     .claude/aceite.txt que não aparece em nenhuma task
# Aviso (exit 0): uma fase só (tier light), fase com mais de 8 tasks (régua do
# curso), "## " antes da primeira fase ou depois da última, sub-linha com "-".
#
# Padrões: PLAN.md ao lado do PHASES.md; .claude/aceite.txt e FEATURE-ALVO.md
# na pasta atual. As duas comparações (PLAN e aceite) só rodam sozinhas quando
# o arquivo se chama PHASES.md: um ENSAIO.md com uma fase não cobre o plano.
set -uo pipefail

plan=""; aceite=""; feature=""; sem_aceite=false; phases=""
while [ $# -gt 0 ]; do
  case "$1" in
    --plan)       plan="${2:-}"; shift 2 ;;
    --aceite)     aceite="${2:-}"; shift 2 ;;
    --feature)    feature="${2:-}"; shift 2 ;;
    --sem-aceite) sem_aceite=true; shift ;;
    -h|--help)    sed -n 2,24p "$0"; exit 0 ;;
    -*)           echo "opção desconhecida: $1" >&2; exit 64 ;;
    *)            phases="$1"; shift ;;
  esac
done
[ -n "$phases" ] || { echo "uso: confere-phases.sh [opções] PHASES.md" >&2; exit 64; }
[ -f "$phases" ] || { echo "erro: $phases não existe" >&2; exit 1; }

erros=0; avisos=0
erro()  { echo "ERRO:  $*"; erros=$((erros + 1)); }
aviso() { echo "aviso: $*"; avisos=$((avisos + 1)); }

completo=false
[ "$(basename -- "$phases")" = "PHASES.md" ] && completo=true

# Uma passada no arquivo: fases, headings, tasks e o texto de cada task.
# Saída do awk, uma linha por achado: TIPO<TAB>dados.
analise=$(awk '
  BEGIN { fase = 0; ntask = 0; cerca = 0 }
  /^```/ { cerca = !cerca; if (ntask) corpo[ntask] = corpo[ntask] "\n" $0; next }
  cerca  { if (ntask) corpo[ntask] = corpo[ntask] "\n" $0; next }
  /^## Phase [0-9]+: / {
    match($0, /[0-9]+/); n = substr($0, RSTART, RLENGTH) + 0
    fase++; print "FASE\t" fase "\t" n "\t" NR; emtask = 0; next
  }
  /^## Phase/ { print "TORTO\t" NR "\t" $0; next }
  /^## / { print (fase ? "H2DEPOIS" : "H2ANTES") "\t" NR "\t" $0; emtask = 0; next }
  /^#/   { emtask = 0; next }
  /^[ \t]+- \[[ xX]\]/ && emtask { print "ANINHADO\t" NR "\t" $0; corpo[ntask] = corpo[ntask] "\n" $0; next }
  /^[ \t]*- \[[ xX]\]/ {
    ntask++; tfase[ntask] = fase; tlinha[ntask] = NR; corpo[ntask] = $0; emtask = 1; next
  }
  emtask && /^[ \t]+- / { print "SUBTRACO\t" NR "\t" $0 }
  emtask && /^[^ \t]/ && !/^$/ { emtask = 0 }
  emtask { corpo[ntask] = corpo[ntask] "\n" $0 }
  END {
    for (i = 1; i <= ntask; i++) {
      c = corpo[i]
      ac = (c ~ /Acceptance criteria:/) ? 1 : 0
      te = (c ~ /(Testes|Tests|Feature tests):/) ? 1 : 0
      gsub(/\n/, " ", c); gsub(/\t/, " ", c)
      print "TASK\t" i "\t" tfase[i] "\t" tlinha[i] "\t" ac "\t" te "\t" c
    }
  }
' "$phases")

nfases=$(awk -F'\t' '$1=="FASE"' <<<"$analise" | wc -l)
ntasks=$(awk -F'\t' '$1=="TASK"' <<<"$analise" | wc -l)

# Headings
if [ "$nfases" -eq 0 ]; then
  erro "nenhum heading '## Phase N: título'. O ralph não acha fase nenhuma."
fi
while IFS=$'\t' read -r _ linha texto; do
  erro "linha $linha: heading de fase fora do formato '## Phase N: título': $texto"
done < <(awk -F'\t' '$1=="TORTO"' <<<"$analise")
esperado=1
while IFS=$'\t' read -r _ ordem n linha; do
  if [ "$n" -ne "$esperado" ]; then
    erro "linha $linha: fase $n, esperada a fase $esperado (numeração contínua desde 1)."
  fi
  esperado=$((n + 1))
done < <(awk -F'\t' '$1=="FASE"' <<<"$analise")
while IFS=$'\t' read -r _ linha texto; do
  # Outro "## " entre duas fases corta a fase de cima; depois da última, só descarta o fim.
  if awk -F'\t' -v l="$linha" '$1=="FASE" && $4>l {achou=1} END{exit !achou}' <<<"$analise"; then
    erro "linha $linha: '$texto' entre duas fases. O ralph encerra a fase de cima aqui e o resto do texto dela some."
  else
    aviso "linha $linha: '$texto' depois da última fase. O ralph descarta daqui para baixo; se era parte da fase, sumiu."
  fi
done < <(awk -F'\t' '$1=="H2DEPOIS"' <<<"$analise")
while IFS=$'\t' read -r _ linha texto; do
  aviso "linha $linha: '$texto' antes da primeira fase. O ralph descarta esse trecho."
done < <(awk -F'\t' '$1=="H2ANTES"' <<<"$analise")

# Tasks
[ "$nfases" -gt 0 ] && [ "$ntasks" -eq 0 ] && erro "nenhuma task '- [ ]'. Sem task o gate 3 é pulado."
while IFS=$'\t' read -r _ linha texto; do
  erro "linha $linha: checkbox aninhado. O gate 3 conta como mais uma task: $texto"
done < <(awk -F'\t' '$1=="ANINHADO"' <<<"$analise")
nsub=$(awk -F'\t' '$1=="SUBTRACO"' <<<"$analise" | wc -l)
if [ "$nsub" -gt 0 ]; then
  aviso "$nsub sub-linha(s) de task começando com '-' (a primeira na linha $(awk -F'\t' '$1=="SUBTRACO"{print $2; exit}' <<<"$analise")). O planner escreve sem '-'."
fi
while IFS=$'\t' read -r _ i f linha ac te _; do
  [ "$ac" = 1 ] || erro "linha $linha: task $i da fase $f sem 'Acceptance criteria:'. O gate 3 confere a task por ele."
  [ "$te" = 1 ] || erro "linha $linha: task $i da fase $f sem 'Testes:'. Sem teste listado, o gate 2 não cobra a task."
done < <(awk -F'\t' '$1=="TASK"' <<<"$analise")

# Tamanho
if [ "$nfases" -eq 1 ]; then
  aviso "uma fase só (tier light). Se a feature tem dependência, corrija o tier para standard no checkpoint 1 do /plan."
fi
while read -r f qtd; do
  [ "$qtd" -gt 8 ] && aviso "a fase $f tem $qtd tasks. Mais de 8: quebre (régua do curso, cada fase roda numa sessão nova)."
done < <(awk -F'\t' '$1=="TASK"{c[$3]++} END{for (f in c) print f, c[f]}' <<<"$analise" | sort -n)

# PLAN.md: mesmo número de tasks
if [ -z "$plan" ] && $completo && [ -f "$(dirname -- "$phases")/PLAN.md" ]; then
  plan="$(dirname -- "$phases")/PLAN.md"
fi
if [ -n "$plan" ]; then
  if [ -f "$plan" ]; then
    nplan=$(grep -cE '^### T[0-9]' "$plan" || true)
    if [ "$nplan" -ne "$ntasks" ]; then
      erro "o PLAN tem $nplan tasks ('### T') e o PHASES tem $ntasks checkboxes. O PHASES é a vista 1:1 do PLAN: alguém editou um sem o outro."
    fi
  else
    erro "PLAN não encontrado: $plan"
  fi
elif $completo; then
  aviso "PLAN.md não está ao lado do PHASES: a contagem de tasks não foi conferida."
fi

# Testes de aceite: cada AC-NN e cada arquivo do aceite.txt numa task
if ! $sem_aceite; then
  if [ -z "$aceite" ] && [ -z "$feature" ] && $completo && [ -f .claude/aceite.txt ] && [ -f FEATURE-ALVO.md ]; then
    aceite=.claude/aceite.txt; feature=FEATURE-ALVO.md
  fi
  tasks_txt=$(awk -F'\t' '$1=="TASK"{print $7}' <<<"$analise")
  if [ -n "$feature" ]; then
    [ -f "$feature" ] || { erro "FEATURE-ALVO não encontrado: $feature"; feature=""; }
  fi
  if [ -n "$feature" ]; then
    while read -r ac; do
      [ -n "$ac" ] || continue
      grep -qE "(^|[^0-9A-Za-z])${ac}([^0-9]|$)" <<<"$tasks_txt" \
        || erro "$ac está no $(basename -- "$feature") e em nenhuma task. Quem vai fazer esse critério passar?"
    done < <(grep -oE 'AC-[0-9]+' "$feature" | sort -u)
  fi
  if [ -n "$aceite" ]; then
    if [ ! -f "$aceite" ]; then
      erro "lista de aceite não encontrada: $aceite"
    else
      while IFS= read -r arq; do
        arq="${arq%%#*}"; arq="${arq%"${arq##*[![:space:]]}"}"; arq="${arq#"${arq%%[![:space:]]*}"}"
        [ -n "$arq" ] || continue
        alvos=()
        if [[ "$arq" == *[\*\?\[]* ]]; then
          shopt -s nullglob; alvos=( $arq ); shopt -u nullglob
          [ ${#alvos[@]} -gt 0 ] || alvos=("$arq")
        else
          alvos=("$arq")
        fi
        for a in "${alvos[@]}"; do
          grep -qF -- "$a" <<<"$tasks_txt" \
            || erro "$a está no $(basename -- "$aceite") e em nenhuma task. Sem a task de ativação, ninguém tira o marcador."
        done
      done < "$aceite"
    fi
  fi
  if [ -z "$aceite" ] && [ -z "$feature" ] && $completo; then
    aviso "sem .claude/aceite.txt e FEATURE-ALVO.md na pasta atual: a cobertura dos testes de aceite não foi conferida."
  fi
fi

echo "fases: $nfases · tasks: $ntasks · erros: $erros · avisos: $avisos"
if [ "$erros" -gt 0 ]; then
  echo "resultado: NÃO PASSA. Corrija pelo /plan (re-delegue ao planner), não à mão."
  exit 1
fi
echo "resultado: ok"
exit 0
