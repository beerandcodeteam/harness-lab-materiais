#!/usr/bin/env bash
# verificar.sh · aula 6.2 · roda no ~/projeto da sandbox, depois dos comandos do material.
# Prova que o desfecho.sh instalado é o da aula e diz o desfecho certo em cada estado de run
# (os oito fixtures, o .phases/ e o .loop-logs/ do projeto falso), que cruza fases e commits
# num repositório de verdade, que avisa quando o ralph não grava run.tsv, que a leitura à mão
# do material acha a causa, e que o /diagnostico-operador depois mede o run sem sujar o git.
set -euo pipefail

n=0
ok() { n=$((n + 1)); printf '  ok  %s\n' "$1"; }
erro() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" | head -40 >&2; exit 1; }
AULA="$HOME/harness-lab-materiais/modulo-6-a-entrega/aula-6.2-os-3-desfechos"
F="$AULA/modelos/fixtures"
D="$PWD/.claude/scripts/desfecho.sh"
T=$(mktemp -d)
VIVOS=()
trap 'for p in "${VIVOS[@]}"; do kill "$p" 2>/dev/null || true; done; rm -rf "$T"' EXIT

roda() { RC=0; SAIDA=$("$@" 2>&1) || RC=$?; }
# confere <descrição> <exit esperado> <texto que precisa aparecer>...
confere() {
  local desc="$1" esp="$2" t; shift 2
  [ "$RC" = "$esp" ] || erro "$desc: exit esperado $esp, veio $RC" "$SAIDA"
  for t in "$@"; do grep -qF -- "$t" <<<"$SAIDA" || erro "$desc: não achou '$t'" "$SAIDA"; done
}
nao_tem() { grep -qF -- "$2" <<<"$SAIDA" && erro "$1: apareceu '$2'" "$SAIDA"; return 0; }
com_pid() { sed -E $'s/^(META\tpid\t).*/\\1'"$2"'/' "$1" > "$3"; }
pid_morto() { bash -c 'exit 0' & local p=$!; wait "$p"; echo "$p"; }
ralph_vivo() { bash -c 'exec -a ralph.sh sleep 60' >/dev/null 2>&1 & VIVO=$!; VIVOS+=("$VIVO"); sleep 0.3; }
G() { git -c user.email=aluno@harness.lab -c user.name=Aluno "$@"; }

# ------------------------------------------------------------------ instalação
[ -x "$D" ] || erro ".claude/scripts/desfecho.sh não instalado ou sem chmod +x"
cmp -s "$D" "$AULA/projeto/.claude/scripts/desfecho.sh" || erro "desfecho.sh instalado difere do da aula"
bash -n "$D"
for m in pedidos-por-camada.md ler-o-run-a-mao.md fixtures/README.md; do
  [ -s "$AULA/modelos/$m" ] || erro "modelos/$m não existe"
done
[ "$(find "$F" -maxdepth 1 \( -name 'run-*.tsv' -o -name 'run-*' -type d \) | wc -l)" -eq 8 ] || erro "esperava 8 fixtures"
ok "desfecho.sh instalado, executável e igual ao da aula; modelos/ com os 8 fixtures"

# ------------------------------------------------------------------ os desfechos, nos fixtures
roda bash "$D" "$F/run-entregou.tsv"
confere "entregou (real)" 0 "DESFECHO: ENTREGOU 4/4" "duração 13m 08s"
[ "$(grep -c 'já implementada' <<<"$SAIDA")" -eq 3 ] || erro "entregou: esperava 3 fases já implementadas" "$SAIDA"
nao_tem "entregou" "ALERTA"
roda bash "$D" "$F/run-falhou-g3/"
confere "falhou no gate 3" 20 "DESFECHO: FALHOU" "Gate que reprovou: G3" "phase-01.verify-3.log" \
  "TASK 1: INCOMPLETE" "Camada provável: Prova" "traz a causa do ciclo 2, não a final"
roda bash "$D" "$F/run-falhou-g2/"
confere "falhou no gate 2" 20 "Gate que reprovou: G2" "phase-01.test-3.log" "AC-03 DTEND é exclusivo"
roda bash "$D" "$F/run-falhou-g0/"
confere "falhou no gate 0" 20 "Gate que reprovou: G0" "sem a linha de resultado" "Camada provável: Loop"
roda bash "$D" "$F/run-interrompido.tsv"
confere "interrompido" 21 "DESFECHO: INTERROMPIDO" "Sem causa no log"
nao_tem "interrompido" "Gate que reprovou"
ok "fixtures: ENTREGOU 0, FALHOU 20 (G3, G2, G0 com arquivo e camada), INTERROMPIDO 21"

com_pid "$F/run-morto.tsv" "$(pid_morto)" "$T/morto.tsv"
roda bash "$D" "$T/morto.tsv"
confere "morto" 22 "DESFECHO: MORTO" "não existe" "Em execução\" para sempre"
ralph_vivo; com_pid "$F/run-morto.tsv" "$VIVO" "$T/rodando.tsv"
roda bash "$D" "$T/rodando.tsv"
confere "rodando" 10 "DESFECHO: RODANDO" "Está rodando agora"
ralph_vivo; com_pid "$F/run-esperando.tsv" "$VIVO" "$T/esperando.tsv"
roda bash "$D" "$T/esperando.tsv"
confere "esperando o limite" 11 "DESFECHO: ESPERANDO LIMITE" "sem gastar ciclo"
com_pid "$F/run-esperando.tsv" "$(pid_morto)" "$T/esperando-morto.tsv"
roda bash "$D" "$T/esperando-morto.tsv"
confere "morto na espera" 22 "DESFECHO: MORTO" "durante a espera"
sleep 60 >/dev/null 2>&1 & VIVOS+=("$!")
com_pid "$F/run-morto.tsv" "$!" "$T/reaproveitado.tsv"
roda bash "$D" "$T/reaproveitado.tsv"
confere "PID de outro programa" 22 "DESFECHO: MORTO" "é outro programa"
ok "o PID decide: RODANDO 10, ESPERANDO LIMITE 11, MORTO 22 (inexistente, na espera, reaproveitado)"

# ------------------------------------------------------------------ no projeto do aluno
roda "$D"
confere "sem argumento, o .phases/ do projeto" 20 "DESFECHO: FALHOU" "$PWD/.phases/state/run.tsv" "verify-3.log"
R=$(ls -td .loop-logs/run-*/ | head -1)
roda "$D" "$R"
confere "a cópia do loop.sh em .loop-logs/" 20 "DESFECHO: FALHOU" "/.loop-logs/run-1103-115511/run.tsv"
nao_tem ".loop-logs" "ALERTA"
ok "no projeto: lê o .phases/ sem argumento e a cópia em .loop-logs/<run>/"

# ------------------------------------------------------------------ fases x commits, git de verdade
X="$T/repo"; mkdir -p "$X/.phases/state" "$X/src"
G init -q -b feat/agenda "$X"; echo inicio > "$X/README.md"; G -C "$X" add -A; G -C "$X" commit -qm "spec: agenda"
awk -F'\t' -v OFS='\t' -v s="$(( $(date +%s) - 120 ))" '$1=="META" && $2=="started" {$3=s} {print}' \
  "$F/run-sem-commit.tsv" > "$X/.phases/state/run.tsv"
echo '/.phases/' >> "$X/.git/info/exclude"
echo um > "$X/src/fase1.txt"; G -C "$X" add -A; G -C "$X" commit -qm "feat(phase-1): Gerador do texto do .ics"
echo dois > "$X/src/fase2.txt"; G -C "$X" add -A
roda "$D" "$X/.phases"
confere "pre-commit que recusou" 0 "DESFECHO: ENTREGOU 2/2" "commit" "feat(phase-1)" "ALERTA" "1 alerta(s) de fase sem commit" "Há mudanças staged"
G -C "$X" commit -qm "feat(phase-2): Rota que entrega o arquivo"
roda "$D" "$X/.phases"
confere "as duas fases com commit" 0 "feat(phase-2)"
nao_tem "as duas fases com commit" "ALERTA"
ok "cruza fases e commits: fase verde sem commit vira alerta, com o trabalho staged; com commit, não"

# ------------------------------------------------------------------ ralph sem run.tsv
Y="$T/sem-estado"; mkdir -p "$Y/.phases/logs"; G init -q "$Y"
cp "$F/run-falhou-g3/logs/"*.log "$Y/.phases/logs/"
roda bash -c "cd '$Y' && '$D'"
confere "ralph que não grava estado" 2 "não achei" "run.tsv"
ok "ralph sem .phases/state/run.tsv: exit 2 com a mensagem (o material manda ler à mão)"

# ------------------------------------------------------------------ leitura à mão (modelos/ler-o-run-a-mao.md)
grep -h "INCOMPLETE" .phases/logs/*.verify-*.log | grep -qF "TASK 1: INCOMPLETE" || erro "grep INCOMPLETE não achou a causa"
grep -A6 "Motivo da falha" .phases/prompts/phase-01.cycle-3.txt | grep -qF "TASK 1: INCOMPLETE" || erro "Motivo da falha não achado"
[ "$(ls -t .phases/logs | wc -l)" -eq 9 ] || erro "ls dos logs"
out=$(pgrep -af "[r]alph.sh" || echo "nenhum ralph vivo"); [ -n "$out" ] || erro "pgrep"
Z="$T/copia"; G init -q "$Z"; cp -r .phases "$Z/"
( cd "$Z"
  X=$(git rev-parse --git-path info/exclude)
  grep -qxF '/.loop-logs/' "$X" || echo '/.loop-logs/' >> "$X"
  mkdir -p .loop-logs
  cp -rp .phases ".loop-logs/manual-$(date +%m%d-%H%M)"
  [ -f .loop-logs/manual-*/state/run.tsv ] || exit 1
  [ -z "$(git status --porcelain -- .loop-logs)" ] || exit 1 ) || erro "cópia do .phases/ para .loop-logs/ ignorado"
ok "leitura à mão: causa no verify log, Motivo da falha no prompt, cópia em .loop-logs/ fora do git"

# ------------------------------------------------------------------ /diagnostico-operador depois
lista=$(claude plugin list 2>&1)
grep -q 'diagnostico-operador@harness-lab' <<<"$lista" || erro "diagnostico-operador não aparece em claude plugin list" "$lista"
M=$(find "$HOME/.claude/plugins/cache" -type f -path '*diagnostico-operador*/scripts/medir.py' | head -1)
[ -n "$M" ] || erro "medir.py do diagnostico-operador não encontrado no cache"
grep -qxF '/.diagnostico-operador/' "$(git rev-parse --git-path info/exclude)" || erro "o material manda pôr /.diagnostico-operador/ no exclude"
roda python3 "$M" depois
confere "depois no .phases/logs" 0 "gates_vermelhos" "ciclos_de_correcao"
grep -E '^gates_vermelhos +3$' <<<"$SAIDA" >/dev/null || erro "esperava 3 gates vermelhos no fixture" "$SAIDA"
roda python3 "$M" depois --logs "${R%/}/logs"
confere "depois no .loop-logs" 0 "run-1103-115511/logs"
[ -z "$(git status --porcelain)" ] || erro "a medição sujou a árvore (o pré-voo do próximo loop reprovaria)" "$(git status --short)"
ok "/diagnostico-operador depois: plugin instalado, mede o .phases/ e o .loop-logs/, árvore limpa"

echo "verificar.sh: $n grupos de checagem passaram."
