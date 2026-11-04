#!/usr/bin/env bash
# verificar.sh · aula 6.3 · roda no ~/projeto da sandbox, depois dos comandos do material.
# Prova que os seis scripts foram instalados iguais aos da aula (e aos da 6.2, quando ela
# está no repositório), e roda cada um num repositório fabricado que parece o do aluno
# depois do loop (o mesmo do modelos/ensaio/ensaio.sh): desfecho, revisa-loop com e sem
# alerta, confere-aceite pegando valor alterado, pacote-prova sem segredo, o stack-pr.sh
# criando branches e PRs empilhados contra um remoto local e um gh falso (com a origin/main
# como base), as receitas do material para o loop que rodou na main, e o loop-e-stack.sh
# com um loop.sh falso. Sem rede e sem token: nenhum gh de verdade, nenhum claude -p.
# No fim, o plugin diagnostico-operador.
set -euo pipefail

n=0
ok() { n=$((n + 1)); printf '  ok  %s\n' "$1"; }
erro() { printf 'FALHOU: %s\n' "$1" >&2; exit 1; }
AULA="$HOME/harness-lab-materiais/modulo-6-a-entrega/aula-6.3-revisando-o-pr-do-loop"
[ -d "$AULA" ] || erro "a aula 6.3 não está em $AULA"
PROJ="$PWD"
TMPDIR=$(mktemp -d)
export TMPDIR
tem() { grep -qF -- "$2" <<<"$1" || { printf '%s\n' "$1" | tail -n 40 >&2; erro "não achou: $2"; }; }
nao_tem() { ! grep -qF -- "$2" <<<"$1" || { printf '%s\n' "$1" | tail -n 40 >&2; erro "não devia aparecer: $2"; }; }
roda() { RC=0; SAIDA=$("$@" 2>&1) || RC=$?; }

# ------------------------------------------------------------------ instalação
S=.claude/scripts
for s in desfecho confere-aceite revisa-loop pacote-prova stack-pr loop-e-stack; do
  [ -x "$S/$s.sh" ] || erro "$S/$s.sh não instalado ou sem chmod +x"
  bash -n "$S/$s.sh"
  cmp -s "$S/$s.sh" "$AULA/projeto/$S/$s.sh" || erro "$s.sh diferente do da aula"
done
git -C "$PROJ" status --porcelain | grep -q '^?? .claude/' || erro "o instalar.sh devia ter criado .claude/ no projeto"
ok "seis scripts em .claude/scripts/, executáveis, iguais aos da aula"

compartilhados=0
for d in "$HOME"/harness-lab-materiais/modulo-6-a-entrega/aula-6.2-*/projeto/.claude/scripts; do
  [ -d "$d" ] || continue
  for f in "$d"/*.sh; do
    b=$(basename "$f")
    [ -f "$AULA/projeto/$S/$b" ] || continue
    cmp -s "$f" "$AULA/projeto/$S/$b" || erro "$b da 6.3 difere do da 6.2: instalar 6.2 e 6.3 daria .harness-lab-novo"
    compartilhados=$((compartilhados + 1))
  done
done
for f in "$HOME"/harness-lab-materiais/modulo-4-prova/aula-4.2-*/projeto/.claude/hooks/guarda-aceite.py; do
  [ -f "$f" ] || continue
  cmp -s "$f" "$AULA/modelos/ensaio/guarda-aceite.py" || erro "o guarda-aceite.py do ensaio difere do da 4.2"
done
ok "scripts compartilhados com a 6.2 com os mesmos bytes ($compartilhados conferidos) e o hook do ensaio igual ao da 4.2"

# ------------------------------------------------------------------ ensaio: o repositório depois do loop
R="$TMPDIR/ensaio/repo"
roda env SCRIPTS="$PROJ/$S" bash "$AULA/modelos/ensaio/ensaio.sh" "$R"
[ "$RC" = 0 ] || { echo "$SAIDA" >&2; erro "ensaio.sh saiu com $RC"; }
tem "$SAIDA" "DESFECHO: ENTREGOU 2/2 fases"
tem "$SAIDA" "commit "
tem "$SAIDA" "1 alerta(s)"
tem "$SAIDA" "config/agenda.php: fora do Arquivos: da fase 2"
tem "$SAIDA" "só marcador saiu (2 -> 0 pendente(s))"
tem "$SAIDA" "### Alertas da revisão e decisões"
tem "$SAIDA" "Stack de agenda-ics: 2 camada(s) sobre main"
tem "$SAIDA" "base: stack/agenda-ics/phase-1"
tem "$SAIDA" "Nada foi criado"
tem "$SAIDA" "Desfecho: ENTREGOU 2/2 fases"
[ -z "$(git -C "$R" for-each-ref 'refs/heads/stack/*')" ] || erro "stack-pr.sh sem --criar criou branch"
[ -z "$(git -C "$R" status --porcelain)" ] || erro "o ensaio deixou a árvore suja: $(git -C "$R" status --porcelain)"
ok "ensaio: ENTREGOU 2/2, 1 alerta (arquivo fora do plano), aceite só sem marcador, plano da stack, pacote"

PAC=$(ls "$R"/.loop-logs/prova-run-*.tar.gz)
lista=$(tar -tzf "$PAC")
for f in desfecho.txt git-log.txt LEIA-ME.txt loop-logs/run.tsv loop-logs/resumo.txt; do tem "$lista" "/$f"; done
ok "pacote-prova: desfecho, git log, LEIA-ME e a cópia do run no .tar.gz"

# ------------------------------------------------------------------ confere-aceite e revisa-loop pegam valor alterado
BASE=$(git -C "$R" rev-parse main)
git -C "$R" switch -q -c sujo "$BASE"
mkdir -p "$R/app/Support"
echo "<?php class AgendaIcs {}" > "$R/app/Support/AgendaIcs.php"
sed -i '/AC-03/,/todo/ s/})->todo();/});/; s/20261201/20261130/' "$R/tests/Feature/AgendaIcsTest.php"
git -C "$R" add -A
git -C "$R" commit -q -m "feat(phase-1): Gerador do texto do .ics"
roda bash -c "cd '$R' && .claude/scripts/confere-aceite.sh"
[ "$RC" = 1 ] || { echo "$SAIDA" >&2; erro "confere-aceite devia sair com 1 (veio $RC)"; }
tem "$SAIDA" "MUDOU    tests/Feature/AgendaIcsTest.php: mudou além do marcador"
roda bash -c "cd '$R' && .claude/scripts/revisa-loop.sh"
[ "$RC" = 1 ] || erro "revisa-loop devia sair com 1"
tem "$SAIDA" "Teste de aceite mudou além do marcador"
[ ! -d "$R/.claude/hooks/__pycache__" ] || erro "confere-aceite deixou __pycache__ em .claude/hooks/"
git -C "$R" switch -q feat/agenda-ics
ok "confere-aceite.sh: valor esperado alterado vira MUDOU (exit 1); revisa-loop.sh acusa; sem __pycache__"

# ------------------------------------------------------------------ pacote-prova não leva segredo
RUN=$(ls -d "$R"/.loop-logs/run-*/ | head -n 1)
printf 'APP_KEY=base64:segredo\n' > "$RUN/.env"
printf 'chave\n' > "$RUN/logs/deploy.pem"
printf 'token ghp_%s\n' "abcdefghijklmnopqrstuvwxyz0123" >> "$RUN/logs/phase-01.cycle-1.log"
roda bash -c "cd '$R' && .claude/scripts/pacote-prova.sh -o '$TMPDIR/prova.tar.gz'"
[ "$RC" = 0 ] || { echo "$SAIDA" >&2; erro "pacote-prova saiu com $RC"; }
lista=$(tar -tzf "$TMPDIR/prova.tar.gz")
nao_tem "$lista" ".env"
nao_tem "$lista" ".pem"
tem "$SAIDA" "parece haver token"
rm -f "$RUN/.env" "$RUN/logs/deploy.pem"
ok "pacote-prova.sh: .env e .pem ficam fora; token num log vira aviso"

# ------------------------------------------------------------------ stack-pr.sh --criar (remoto local + gh falso)
mkdir -p "$TMPDIR/bin" "$TMPDIR/gh"
cat > "$TMPDIR/bin/gh" <<'GH'
#!/usr/bin/env bash
# gh falso: registra a chamada e responde como o gh responderia
D="$GH_FALSO"
printf '%s\n' "$*" >> "$D/chamadas.log"
case "$1 $2" in
  "pr list")
    shift 2; head=""
    while [ $# -gt 0 ]; do [ "$1" = "--head" ] && head="$2"; shift; done
    awk -F'\t' -v h="$head" '$2 == h {print "https://github.com/aluno/projeto/pull/" $1; exit}' "$D/prs.tsv" 2>/dev/null || true ;;
  "pr create")
    shift 2; head=""; corpo=""
    while [ $# -gt 0 ]; do
      case "$1" in --head) head="$2" ;; --body-file) corpo="$2" ;; esac; shift
    done
    num=$(( $(wc -l < "$D/prs.tsv" 2>/dev/null || echo 0) + 1 ))
    printf '%s\t%s\n' "$num" "$head" >> "$D/prs.tsv"
    cp "$corpo" "$D/corpo-$num.md"
    echo "https://github.com/aluno/projeto/pull/$num" ;;
  "auth status") exit 0 ;;
  "extension list") [ -n "${GH_STACK:-}" ] && printf 'gh stack\tgithub/gh-stack\tv0.0.0\n'; exit 0 ;;
  "stack link") exit 0 ;;
  *) echo "gh falso: chamada inesperada: $*" >&2; exit 1 ;;
esac
GH
chmod +x "$TMPDIR/bin/gh"
export GH_FALSO="$TMPDIR/gh"
git init -q --bare "$TMPDIR/origin.git"
git -C "$R" remote add origin "$TMPDIR/origin.git"
git -C "$R" push -q origin main
P1=$(git -C "$R" rev-parse feat/agenda-ics~1)
P2=$(git -C "$R" rev-parse feat/agenda-ics)
SP() { roda env PATH="$TMPDIR/bin:$PATH" bash -c "cd '$R' && .claude/scripts/stack-pr.sh $*"; }

SP --criar
[ "$RC" = 0 ] || { echo "$SAIDA" >&2; erro "stack-pr.sh --criar saiu com $RC"; }
[ "$(git -C "$TMPDIR/origin.git" rev-parse stack/agenda-ics/phase-1)" = "$P1" ] ||
  erro "phase-1 no remoto não aponta para o commit da fase 1"
[ "$(git -C "$TMPDIR/origin.git" rev-parse stack/agenda-ics/phase-2)" = "$P2" ] || erro "phase-2 no remoto não aponta para o commit da fase 2"
C=$(cat "$GH_FALSO/chamadas.log")
tem "$C" "pr create --draft --base main --head stack/agenda-ics/phase-1 --title agenda-ics 1/2: Gerador do texto do .ics"
tem "$C" "pr create --draft --base stack/agenda-ics/phase-1 --head stack/agenda-ics/phase-2"
nao_tem "$C" "stack link"
tem "$SAIDA" "Preview stack"
tem "$(cat "$GH_FALSO/corpo-1.md")" "Classe que monta o texto do .ics de dia inteiro"
tem "$(cat "$GH_FALSO/corpo-1.md")" "camada 1 de 2"
tem "$(cat "$GH_FALSO/corpo-2.md")" "Rota GET /eventos/{event:slug}/agenda.ics"
nao_tem "$(cat "$GH_FALSO/corpo-2.md")" "Classe que monta o texto"
[ -z "$(git -C "$R" status --porcelain)" ] || erro "stack-pr.sh sujou a árvore"
[ "$(git -C "$R" symbolic-ref --short HEAD)" = feat/agenda-ics ] || erro "stack-pr.sh trocou de branch"
ok "stack-pr.sh --criar: uma branch por fase no remoto, PRs em rascunho encadeados, corpo com a fase do PHASES"

: > "$GH_FALSO/chamadas.log"
export GH_STACK=1
SP --criar
unset GH_STACK
[ "$RC" = 0 ] || { echo "$SAIDA" >&2; erro "segunda rodada saiu com $RC"; }
C=$(cat "$GH_FALSO/chamadas.log")
nao_tem "$C" "pr create"
tem "$C" "stack link --base main 1 2"
tem "$SAIDA" "Stack ligada no GitHub"
ok "rodar de novo reaproveita branches e PRs; com a extensão gh-stack, liga com gh stack link"

rm -rf "$GH_FALSO"; mkdir -p "$GH_FALSO"
SP --criar --pronto --prefixo outra
C=$(cat "$GH_FALSO/chamadas.log")
nao_tem "$C" "--draft"
tem "$C" "--head outra/phase-1"
git -C "$R" branch -f outra/phase-2 "$BASE"
SP --criar --prefixo outra
[ "$RC" = 1 ] || erro "branch existente com outro commit devia dar exit 1 (veio $RC)"
tem "$SAIDA" "já existe e aponta para outro commit"
ok "--pronto abre sem rascunho; --prefixo muda o nome; branch existente com outro commit: recusa"

# fase reprovada (wip) não vira PR
git -C "$R" switch -q -c com-wip feat/agenda-ics
echo "parcial" > "$R/app/parcial.txt"
git -C "$R" add -A
git -C "$R" commit -q -m "wip(phase-3): incomplete, see .phases/logs/"
SP
[ "$RC" = 1 ] || erro "wip(phase-N) devia dar exit 1 (veio $RC)"
tem "$SAIDA" "Fase reprovada não vira PR"
git -C "$R" switch -q feat/agenda-ics
ok "commit wip(phase-N): stack-pr.sh para e manda ler o desfecho"

# um commit na main local que não subiu (o do plano): com a origin/main, ele aparece no plano
git -C "$R" switch -q main
echo "nota do plano" > "$R/PLANO-LOCAL.md"
git -C "$R" add -A
git -C "$R" commit -q -m "plan: commit local que não subiu"
git -C "$R" switch -q -c feat/nova
mkdir -p "$R/app"
echo "<?php // nova" > "$R/app/Nova.php"
git -C "$R" add -A
git -C "$R" commit -q -m "feat(phase-1): Nova coisa"
SP
[ "$RC" = 0 ] || { echo "$SAIDA" >&2; erro "stack-pr.sh com commit local na main saiu com $RC"; }
tem "$SAIDA" "comparando com origin/main"
tem "$SAIDA" "leva também: "
tem "$SAIDA" "plan: commit local que não subiu"
tem "$SAIDA" "a main local tem 1 commit(s) que não estão em origin/main"
SP --trunk main
nao_tem "$SAIDA" "plan: commit local que não subiu"
git -C "$R" switch -q main
git -C "$R" reset -q --hard origin/main
git -C "$R" switch -q feat/agenda-ics
ok "commit da main local que não subiu: o plano compara com a origin/main e mostra em leva também"

# o loop commitou na própria main (como na gravação), com um commit sem relação no meio
git -C "$R" switch -q main
echo "doc solta" > "$R/NOTAS.md"
git -C "$R" add -A
git -C "$R" commit -q -m "docs: notas sem relação"
git -C "$R" cherry-pick "$P1" "$P2" >/dev/null
SP
[ "$RC" = 0 ] || { echo "$SAIDA" >&2; erro "na própria main, sem --trunk, saiu com $RC"; }
tem "$SAIDA" "Stack de agenda-ics: 2 camada(s) sobre main"
tem "$SAIDA" "comparando com origin/main"
tem "$SAIDA" "leva também: "
tem "$SAIDA" "docs: notas sem relação"
SP --trunk origin/main
[ "$RC" = 0 ] || { echo "$SAIDA" >&2; erro "--trunk origin/main saiu com $RC"; }
tem "$SAIDA" "docs: notas sem relação"
git -C "$R" update-ref -d refs/remotes/origin/main
SP
[ "$RC" = 2 ] || erro "na própria main, sem origin/main, devia dar exit 2 (veio $RC)"
tem "$SAIDA" "Passe --trunk <commit de antes do loop>"
git -C "$R" fetch -q origin
ok "loop na própria main: compara com a origin/main e mostra o commit sem relação; sem origin/main, pede --trunk"

# a receita do passo 6 (ralph na main): branch a partir da origin/main só com os commits do loop
F1=$(git -C "$R" rev-parse main~1)
F2=$(git -C "$R" rev-parse main)
git -C "$R" switch -q -c revisao-loop origin/main
git -C "$R" cherry-pick "$F1" "$F2" >/dev/null
roda bash -c "cd '$R' && .claude/scripts/revisa-loop.sh"
[ "$RC" = 1 ] || { echo "$SAIDA" >&2; erro "revisa-loop na revisao-loop devia achar 1 alerta (exit 1, veio $RC)"; }
tem "$SAIDA" "1 alerta(s)"
tem "$SAIDA" "config/agenda.php: fora do Arquivos: da fase 2"
nao_tem "$SAIDA" "NOTAS.md"
SP
[ "$RC" = 0 ] || { echo "$SAIDA" >&2; erro "stack-pr.sh na revisao-loop saiu com $RC"; }
nao_tem "$SAIDA" "leva também: "
tem "$SAIDA" "Stack de agenda-ics: 2 camada(s) sobre main"
git -C "$R" switch -q main
git -C "$R" reset -q --hard origin/main
git -C "$R" switch -q feat/agenda-ics
ok "receita do ralph na main: switch -c da origin/main + cherry-pick; revisa-loop e stack-pr sem opção"

# a receita do passo 9 (ralph.sh sem o loop.sh): sem .loop-logs/, o pacote pede a cópia manual
mkdir -p "$R/.phases/state"
cp "$RUN/run.tsv" "$R/.phases/state/"
cp -rp "$RUN/logs" "$RUN/prompts" "$R/.phases/"
mv "$R/.loop-logs" "$TMPDIR/loop-logs-guardado"
roda bash -c "cd '$R' && .claude/scripts/pacote-prova.sh"
[ "$RC" = 2 ] || erro "pacote-prova sem .loop-logs/ devia dar exit 2 (veio $RC)"
tem "$SAIDA" "nenhuma pasta com run.tsv em .loop-logs/"
roda bash -c "cd '$R' && mkdir -p .loop-logs/manual && cp -p .phases/state/run.tsv .loop-logs/manual/ && cp -rp .phases/logs .phases/prompts .loop-logs/manual/"
[ "$RC" = 0 ] || { echo "$SAIDA" >&2; erro "a cópia manual do .phases falhou"; }
[ "$(stat -c %Y "$R/.loop-logs/manual/logs/phase-01.cycle-1.log")" = "$(stat -c %Y "$R/.phases/logs/phase-01.cycle-1.log")" ] ||
  erro "cp -rp devia manter a hora dos logs (o medir.py monta a janela por ela)"
roda bash -c "cd '$R' && .claude/scripts/pacote-prova.sh"
[ "$RC" = 0 ] || { echo "$SAIDA" >&2; erro "pacote-prova depois da cópia manual saiu com $RC"; }
tem "$SAIDA" "Desfecho: ENTREGOU"
ls "$R"/.loop-logs/prova-run-*.tar.gz >/dev/null 2>&1 || erro "o pacote da cópia manual não saiu em .loop-logs/"
rm -rf "$R/.loop-logs" "$R/.phases"
mv "$TMPDIR/loop-logs-guardado" "$R/.loop-logs"
ok "receita do ralph.sh sem loop.sh: pacote-prova pede run.tsv; com a cópia manual (cp -rp), sai o pacote"

# ------------------------------------------------------------------ loop-e-stack.sh (loop.sh falso + gh falso)
export MODELO_RUN="$RUN"
cat > "$TMPDIR/loop-falso.sh" <<'L'
#!/usr/bin/env bash
# loop.sh falso: grava em .loop-logs/<run>/ o que o loop.sh grava no fim, com o desfecho pedido
echo "${LOOP_PR:-}" > "$GH_FALSO/loop-pr.txt"
if [ "$DESFECHO_FALSO" = aborta ]; then mkdir -p ".loop-logs/abortado-$(date +%s%N)"; exit 1; fi
run="run-falso-$DESFECHO_FALSO-$(date +%s%N)"
cp -rp "$MODELO_RUN" ".loop-logs/$run"
agora=$(date +%s)
sed -i "s/^META\tstarted\t.*/META\tstarted\t$agora/; s/^META\tended\t.*/META\tended\t$agora/; s/^META\trun\t.*/META\trun\t$run/" ".loop-logs/$run/run.tsv"
if [ "$DESFECHO_FALSO" = falhou ]; then
  sed -i 's/^META\tstatus\t.*/META\tstatus\tfailed/; s/^PHASE\t2\tdone\t1\tpass pass pass pass/PHASE\t2\tfailed\t3\tpass pass fail -/' ".loop-logs/$run/run.tsv"
fi
exit 0
L
chmod +x "$TMPDIR/loop-falso.sh"
LS() { roda env PATH="$TMPDIR/bin:$PATH" LOOP_SH="$TMPDIR/loop-falso.sh" LOOP_PR=1 DESFECHO_FALSO="$1" \
  bash -c "cd '$R' && '$PROJ/$S/loop-e-stack.sh' .spec/features/agenda-ics/PHASES.md --prefixo auto"; }
: > "$GH_FALSO/chamadas.log"
LS aborta
[ "$RC" = 1 ] || { echo "$SAIDA" >&2; erro "loop que não rodou devia dar exit 1 (veio $RC)"; }
tem "$SAIDA" "o loop não chegou a rodar"
sleep 1
LS falhou
[ "$RC" = 20 ] || { echo "$SAIDA" >&2; erro "loop que falhou devia sair com o exit do desfecho, 20 (veio $RC)"; }
tem "$SAIDA" "não entregou"
nao_tem "$(cat "$GH_FALSO/chamadas.log")" "pr create"
sleep 1
LS entregou
[ "$RC" = 0 ] || { echo "$SAIDA" >&2; erro "loop-e-stack.sh com o loop entregue saiu com $RC"; }
[ -z "$(cat "$GH_FALSO/loop-pr.txt")" ] || erro "o LOOP_PR devia chegar desligado ao loop.sh"
C=$(cat "$GH_FALSO/chamadas.log")
tem "$C" "pr create --draft --base main --head auto/phase-1"
tem "$C" "pr create --draft --base auto/phase-1 --head auto/phase-2"
tem "$SAIDA" "revisa-loop.sh: 1 alerta(s)"
novo=$(ls -dt "$R"/.loop-logs/run-falso-entregou-*/ | head -n 1)
grep -q "config/agenda.php: fora do Arquivos: da fase 2" "$novo/revisao.txt" || erro "revisao.txt sem o alerta do revisa-loop"
[ "$(git -C "$TMPDIR/origin.git" rev-parse auto/phase-2)" = "$P2" ] || erro "auto/phase-2 no remoto não aponta para a fase 2"
ok "loop-e-stack.sh: não rodou ou falhou, nenhum PR; entregou, revisao.txt e a stack em rascunho; LOOP_PR desligado"

# ------------------------------------------------------------------ modelos
for f in pedido-stack-pr.md pedido-pr-unico.md pull_request_template.md ensaio/ensaio.sh ensaio/guarda-aceite.py; do
  [ -s "$AULA/modelos/$f" ] || erro "modelos/$f não existe"
done
grep -q 'stack-pr.sh --criar' "$AULA/modelos/pedido-stack-pr.md" || erro "o pedido da stack não usa o stack-pr.sh"
grep -q 'revisa-loop.sh --corpo-pr' "$AULA/modelos/pedido-pr-unico.md" || erro "o pedido do PR único não usa o --corpo-pr"
ok "modelos: pedidos da stack e do PR único, template de PR, ensaio"

# ------------------------------------------------------------------ plugin do diagnóstico (passo do PDF)
claude plugin list | grep -q 'diagnostico-operador@harness-lab' || erro "diagnostico-operador@harness-lab não aparece em claude plugin list"
SK="$(find "$HOME/.claude/plugins" -path '*/cache/harness-lab/diagnostico-operador/*/skills/diagnostico-operador/SKILL.md' | head -n 1)"
[ -n "$SK" ] || erro "SKILL.md do diagnostico-operador não está no cache de plugins"
grep -q '^## depois' "$SK" && grep -q '^## comparar' "$SK" || erro "a skill instalada não tem os modos depois e comparar"
grep -q 'cmd_comparar\|def .*comparar' "$(dirname "$SK")/scripts/medir.py" || erro "medir.py sem o modo comparar"
ok "plugin diagnostico-operador instalado, com depois e comparar"

echo "verificar.sh: $n grupos de checagem passaram."
