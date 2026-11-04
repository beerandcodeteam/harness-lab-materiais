#!/usr/bin/env bash
# ensaio.sh · aula 6.3 · os scripts da revisão num repositório de treino, antes do seu
#
# Uso: bash ensaio.sh [<pasta vazia ou inexistente>]
#   Monta, numa pasta temporária (ou na que você passar), um repositório que parece
#   o seu depois do loop: a feature de exemplo do curso (agenda .ics) em duas
#   fases, os commits feat(phase-N) numa branch, os testes de aceite com ->todo()
#   e a pasta .loop-logs/<run>/ que o loop.sh deixa. Depois roda, em ordem:
#   desfecho.sh, revisa-loop.sh, revisa-loop.sh --corpo-pr, stack-pr.sh (só o
#   plano) e pacote-prova.sh.
#
# Zero token, zero rede: não chama o Claude, não faz push, não abre PR.
# Os scripts vêm de SCRIPTS (padrão: o projeto/.claude/scripts/ desta aula).
# A fase 2 traz um arquivo fora do "Arquivos:" de propósito, para o revisa-loop.sh
# ter um alerta para mostrar.
set -euo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="${SCRIPTS:-$(cd "$AQUI/../../projeto/.claude/scripts" && pwd)}"
GUARDA="${GUARDA:-$AQUI/guarda-aceite.py}"
TEMP=""
if [ -n "${1:-}" ]; then R="$1"; else TEMP=$(mktemp -d); R="$TEMP/repo-de-treino"; fi
[ ! -e "$R" ] || [ -z "$(ls -A "$R" 2>/dev/null)" ] || { echo "ensaio: $R não está vazia" >&2; exit 2; }
for s in desfecho confere-aceite revisa-loop pacote-prova stack-pr; do
  [ -f "$SCRIPTS/$s.sh" ] || { echo "ensaio: falta $SCRIPTS/$s.sh" >&2; exit 2; }
done
[ -f "$GUARDA" ] || { echo "ensaio: falta o hook $GUARDA" >&2; exit 2; }

passo() { printf '\n==== %s\n' "$*"; }
g() { git -C "$R" "$@"; }

# --- o repositório antes do loop ----------------------------------------------------------
mkdir -p "$R"
g init -q -b main
g config user.email "aluno@harness-lab"
g config user.name "Aluno"
g config commit.gpgsign false
echo "# Blog de treino" > "$R/README.md"
g add -A
g commit -q -m "chore: início"

mkdir -p "$R/.claude/hooks" "$R/.claude/scripts" "$R/.spec/features/agenda-ics" "$R/tests/Feature" "$R/routes"
cp "$GUARDA" "$R/.claude/hooks/guarda-aceite.py"
for s in desfecho confere-aceite revisa-loop pacote-prova stack-pr; do cp "$SCRIPTS/$s.sh" "$R/.claude/scripts/"; done
chmod +x "$R"/.claude/scripts/*.sh
echo "tests/Feature/AgendaIcsTest.php" > "$R/.claude/aceite.txt"
echo "<?php // rotas" > "$R/routes/web.php"
cat > "$R/tests/Feature/AgendaIcsTest.php" <<'EOF'
<?php

test('AC-02 a rota entrega text/calendar', function () {
    $this->get('/eventos/imersao/agenda.ics')->assertHeader('Content-Type', 'text/calendar; charset=utf-8');
})->todo();

test('AC-03 DTEND é exclusivo', function () {
    expect(ics())->toContain('DTEND;VALUE=DATE:20261201');
})->todo();
EOF
cat > "$R/.spec/features/agenda-ics/PHASES.md" <<'EOF'
# Phases: agenda-ics

## Phase 1: Gerador do texto do .ics

- [ ] T01: Classe que monta o texto do .ics de dia inteiro
      Arquivos: `app/Support/AgendaIcs.php` (novo)
      Acceptance criteria: evento de 28/11 a 30/11 gera DTEND;VALUE=DATE:20261201 (AC-03).
      Testes: `tests/Feature/AgendaIcsTest.php`: AC-03.

## Phase 2: Rota que entrega o arquivo

- [ ] T02: Rota GET /eventos/{event:slug}/agenda.ics
      Arquivos: `routes/web.php`, `app/Http/Controllers/AgendaIcsController.php` (novo)
      Acceptance criteria: evento futuro responde 200 com text/calendar (AC-02).
      Testes: `tests/Feature/AgendaIcsTest.php`: AC-02.
EOF
g add -A
g commit -q -m "plan: agenda-ics"

# --- o loop: uma branch, um commit por fase ------------------------------------------------
INICIO=$(( $(date +%s) - 900 ))
g switch -q -c feat/agenda-ics
mkdir -p "$R/app/Support" "$R/app/Http/Controllers" "$R/config"
echo "<?php class AgendaIcs { /* VCALENDAR, VEVENT, DTEND exclusivo */ }" > "$R/app/Support/AgendaIcs.php"
sed -i '/AC-03/,/todo/ s/})->todo();/});/' "$R/tests/Feature/AgendaIcsTest.php"
g add -A
g commit -q -m "feat(phase-1): Gerador do texto do .ics"
echo "<?php class AgendaIcsController {}" > "$R/app/Http/Controllers/AgendaIcsController.php"
echo "Route::get('/eventos/{event:slug}/agenda.ics', AgendaIcsController::class);" >> "$R/routes/web.php"
echo "<?php return ['fuso' => 'America/Sao_Paulo'];" > "$R/config/agenda.php"
sed -i 's/})->todo();/});/' "$R/tests/Feature/AgendaIcsTest.php"
g add -A
g commit -q -m "feat(phase-2): Rota que entrega o arquivo"

# --- o que o loop.sh deixa em .loop-logs/<run>/ ------------------------------------------------
RUN="run-$(date +%m%d-%H%M%S)"
L="$R/.loop-logs/$RUN"
mkdir -p "$L/logs" "$L/prompts"
echo "/.loop-logs/" >> "$R/.git/info/exclude"
{
  printf 'META\tproject\trepo-de-treino\nMETA\trun\t%s\nMETA\tengine\tclaude\n' "$RUN"
  printf 'META\tstatus\tfinished\nMETA\tstarted\t%s\nMETA\tended\t%s\n' "$INICIO" "$(date +%s)"
  printf 'META\tphase_total\t2\nMETA\tinput\t.spec/features/agenda-ics/PHASES.md\n'
  printf 'META\ttest_cmd\tvendor/bin/sail test\nMETA\tcycle_max\t3\nMETA\tpid\t1\n'
  printf 'PHASE\t1\tdone\t1\tpass pass pass pass\tGerador do texto do .ics\n'
  printf 'TASK\t1\t1\tcomplete\tT01 Classe que monta o texto do .ics\n'
  printf 'PHASE\t2\tdone\t1\tpass pass pass pass\tRota que entrega o arquivo\n'
  printf 'TASK\t2\t1\tcomplete\tT02 Rota GET agenda.ics\n'
} > "$L/run.tsv"
echo "sessão da fase 1 (log de treino)" > "$L/logs/phase-01.cycle-1.log"
echo "sessão da fase 2 (log de treino)" > "$L/logs/phase-02.cycle-1.log"
echo "prompt da fase 1 (trecho da SPEC)" > "$L/prompts/phase-01.cycle-1.txt"
printf 'loop.sh · resumo do run\ndesfecho:  ENTREGOU\nfases feitas: 2/2\n' > "$L/resumo.txt"
printf 'Trava: hooks ligados\nRegra: CLAUDE.md\nProva: vendor/bin/sail test, aceite com guarda-aceite.py\nLoop: MAX_CICLOS=3\n' > "$L/camadas.txt"

cd "$R"
passo "1. desfecho.sh .loop-logs/$RUN/ (aula 6.2): entregou ou não"
.claude/scripts/desfecho.sh ".loop-logs/$RUN/" || echo "(exit $?)"

passo "2. revisa-loop.sh: onde o risco mora, commit por commit"
.claude/scripts/revisa-loop.sh || echo "(exit $?: há alerta para decidir)"

passo "3. revisa-loop.sh --corpo-pr: o rascunho do corpo do PR (início)"
corpo=$(.claude/scripts/revisa-loop.sh --corpo-pr)
sed -n '1,24p' <<< "$corpo"

passo "4. stack-pr.sh: o plano da stack, uma camada por fase (sem --criar, nada muda)"
.claude/scripts/stack-pr.sh

passo "5. pacote-prova.sh: o log do run num arquivo só"
.claude/scripts/pacote-prova.sh

echo ""
echo "Ensaio em: $R"
echo "Seu repositório não foi tocado."
[ -n "$TEMP" ] && echo "Para jogar fora: rm -rf $TEMP"
exit 0
