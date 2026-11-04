#!/usr/bin/env bash
# verificar.sh · aula 5.1 · roda no ~/projeto da sandbox, depois dos comandos do material.
# Prova que os scripts do loop foram instalados iguais aos da aula e commitados, que o
# ensaio com o motor falso rodou o ralph de verdade até o fim e foi desfeito, que o
# pré-voo recusa o que deve, que a armadilha do progresso existe (e o rm -rf .phases
# resolve), e que os dois juízes aprovam as referências e reprovam o que está errado,
# na pasta de ensaio, do jeito que o aluno roda. Nada aqui chama o claude de verdade.
set -euo pipefail

n=0
ok() { n=$((n + 1)); printf '  ok  %s\n' "$1"; }
erro() { printf 'FALHOU: %s\n' "$1" >&2; exit 1; }
AULA="$HOME/harness-lab-materiais/modulo-5-loop/aula-5.1-o-script-do-loop"
MOTOR="$AULA/modelos/motor-falso/claude"
S=.claude/scripts
P=.spec/features/agenda-ics/PHASES.md
TMPDIR=$(mktemp -d)
export TMPDIR

# ------------------------------------------------------------------ instalação
for f in loop.sh confere-phases.sh aviso.sh vigia.sh shim/claude; do
  [ -x "$S/$f" ] || erro "$S/$f não instalado ou sem chmod +x"
  cmp -s "$S/$f" "$AULA/projeto/$S/$f" || erro "$S/$f diferente do da aula"
done
for f in "$S"/*.sh "$S/shim/claude"; do bash -n "$f" || erro "sintaxe: $f"; done
git ls-files --error-unmatch "$S/loop.sh" "$S/shim/claude" >/dev/null 2>&1 || erro "os scripts não foram commitados"
[ "$(git log -1 --pretty=%s -- "$S")" = "harness: scripts do loop" ] || erro "commit dos scripts não encontrado"
[ "$(git branch --show-current)" = feat/agenda-ics ] || erro "devia estar de volta na branch da feature"
[ -z "$(git status --porcelain)" ] || erro "árvore suja depois do material: $(git status --short | head -3)"
ok "5 scripts instalados iguais aos da aula, executáveis e commitados na branch da feature"

# Outras aulas que instalam os mesmos caminhos: precisam ser iguais, senão o instalar.sh
# em sequência gera .harness-lab-novo no projeto do aluno.
REPO="$HOME/harness-lab-materiais"
for outro in "$REPO"/modulo-*/aula-*/projeto/.claude/scripts/{loop.sh,confere-phases.sh,aviso.sh,vigia.sh,shim/claude}; do
  [ -f "$outro" ] || continue
  case "$outro" in "$AULA"/*) continue ;; esac
  rel="${outro#*/projeto/}"
  cmp -s "$outro" "$AULA/projeto/$rel" || erro "$rel da aula $(basename "${outro%%/projeto/*}") difere do desta aula"
done
ok "os mesmos scripts instalados por outras aulas são iguais byte a byte"

lista=$(claude plugin list 2>&1)
grep -q 'bc-harness@beer-and-code' <<<"$lista" || { echo "$lista" >&2; erro "bc-harness não aparece em claude plugin list"; }
R=$(ls -d "$HOME"/.claude/plugins/cache/beer-and-code/bc-harness/*/scripts/ralph.sh 2>/dev/null | sort -V | tail -1)
[ -f "$R" ] || erro "ralph.sh não está no cache do plugin"
[ -f "$(dirname "$R")/test-ralph.sh" ] || erro "test-ralph.sh não está ao lado do ralph"
ok "bc-harness instalado, com ralph.sh e test-ralph.sh no cache"

# ------------------------------------------------------------------ o ensaio do material
! git show-ref --verify -q refs/heads/ensaio-motor-falso || erro "a branch ensaio-motor-falso devia ter sido apagada"
[ ! -e .phases ] || erro ".phases devia ter sido apagado depois do ensaio"
res=$(ls -d .loop-logs/run-*/ 2>/dev/null | head -1)resumo.txt
[ -f "$res" ] || erro "o ensaio não deixou .loop-logs/<run>/resumo.txt"
grep -q '^desfecho:  ENTREGOU' "$res" || { cat "$res" >&2; erro "o ensaio não entregou"; }
grep -q '^fases feitas: 2/2' "$res" || erro "o ensaio não fez as 2 fases"
[ "$(grep -c 'feat(phase-' "$res")" = 2 ] || erro "o resumo devia listar 2 commits feat(phase-N)"
grep -q 'Prova:     npm test' "$res" || erro "a Prova devia ser a detectada (npm test)"
git check-ignore -q .loop-logs/ || erro ".loop-logs/ devia estar no exclude do git (git rev-parse --git-path info/exclude)"
ok "ensaio com o motor falso: ENTREGOU 2/2, dois commits de fase, log fora do git, branch e .phases apagados"

# ------------------------------------------------------------------ pré-voo recusa (zero token)
recusa() {  # recusa ROTULO TRECHO comando...
  local rot="$1" trecho="$2" saida rc=0; shift 2
  saida=$("$@" 2>&1) || rc=$?
  [ "$rc" = 1 ] || { echo "$saida" >&2; erro "pré-voo devia sair com 1 ($rot), saiu com $rc"; }
  grep -q -- "$trecho" <<<"$saida" || { echo "$saida" >&2; erro "pré-voo sem '$trecho' ($rot)"; }
  grep -q 'Nada rodou, nenhum token gasto' <<<"$saida" || erro "pré-voo devia dizer que nada rodou ($rot)"
}
$S/loop.sh --checa "$P" > "$TMPDIR/checa.txt" 2>&1 || { cat "$TMPDIR/checa.txt" >&2; erro "--checa devia passar"; }
grep -q 'pré-voo ok' "$TMPDIR/checa.txt" || erro "--checa sem 'pré-voo ok'"
recusa "API" "credencial de API no ambiente: ANTHROPIC_API_KEY" env ANTHROPIC_API_KEY=teste $S/loop.sh --checa "$P"
echo '{"apiKeyHelper": "echo chave"}' > .claude/settings.local.json
recusa "apiKeyHelper" "apiKeyHelper(.claude/settings.local.json)" $S/loop.sh --checa "$P"
rm .claude/settings.local.json
recusa "sem ralph" "ralph.sh do bc-harness não encontrado" env RALPH_SH=/nao/existe $S/loop.sh --checa "$P"
echo "rascunho" > rascunho.txt
recusa "árvore suja" "árvore suja" $S/loop.sh --checa "$P"
rm rascunho.txt
git switch -q -c master
recusa "master" "branch master" $S/loop.sh --checa "$P"
git switch -q feat/agenda-ics && git branch -q -D master
recusa "sem Prova" "RALPH_TEST_CMD exportada" env RALPH_TEST_CMD=true $S/loop.sh --checa "$P"
ok "pré-voo recusa API, apiKeyHelper, ralph ausente, árvore suja, master e RALPH_TEST_CMD, sem rodar nada"

# ------------------------------------------------------------------ a armadilha do progresso
roda() { CLAUDE_REAL="$MOTOR" LOOP_PAINEL=0 $S/loop.sh "$P" > "$TMPDIR/$1.txt" 2>&1 || { cat "$TMPDIR/$1.txt" >&2; erro "loop.sh ($1)"; }; }
git switch -q -c ensaio-a; roda a
git switch -q feat/agenda-ics; git branch -q -D ensaio-a
git switch -q -c ensaio-b; sleep 1; roda b
grep -q 'ja completada' "$TMPDIR/b.txt" || erro "o segundo run devia pular as fases do ensaio"
grep -q '^desfecho:  ENTREGOU' "$TMPDIR/b.txt" || erro "o segundo run devia dizer ENTREGOU (é a armadilha)"
[ "$(git rev-list --count feat/agenda-ics..HEAD)" = 0 ] || erro "o segundo run não devia commitar"
rm -rf .phases; sleep 1; roda c
[ "$(git rev-list --count feat/agenda-ics..HEAD)" = 2 ] || erro "depois do rm -rf .phases devia commitar as 2 fases"
git switch -q feat/agenda-ics; git branch -q -D ensaio-b; rm -rf .phases
ok "progresso do ensaio faz o run seguinte pular tudo e dizer ENTREGOU; rm -rf .phases resolve"

# ------------------------------------------------------------------ núcleo e gates, na pasta de ensaio
cd "$HOME/harness-lab-sandbox"
[ -f teste/testa-loop-minimo.sh ] && [ -f teste/testa-loop-com-gates.sh ] && [ -x motor-falso/claude ] ||
  erro "a pasta de ensaio devia ter teste/ e motor-falso/"
[ -f pedido-nucleo.md ] && [ -f pedido-gates.md ] || erro "a pasta de ensaio devia ter os dois pedidos (passo 4)"
cp "$AULA/modelos/loop-minimo.sh" loop-minimo.sh
bash teste/testa-loop-minimo.sh > "$TMPDIR/nucleo.txt" 2>&1 || { tail -20 "$TMPDIR/nucleo.txt" >&2; erro "juiz do núcleo"; }
grep -q 'testa-loop-minimo: 15 passaram' "$TMPDIR/nucleo.txt" || erro "juiz do núcleo sem 15 passaram"
cp "$AULA/modelos/loop-com-gates.sh" loop-com-gates.sh
bash teste/testa-loop-com-gates.sh ./loop-com-gates.sh > "$TMPDIR/gates.txt" 2>&1 || { tail -20 "$TMPDIR/gates.txt" >&2; erro "juiz dos gates"; }
grep -q 'testa-loop-com-gates: 29 passaram' "$TMPDIR/gates.txt" || erro "juiz dos gates sem 29 passaram"
ok "os comandos do aluno na pasta de ensaio: núcleo 15 passaram, gates 29 passaram"

sed 's/^\$(tail -n 40 "\$TMP\/prova.log")"$/"/; s/^    motivo="## Motivo da falha$/    motivo="/' loop-minimo.sh > "$TMPDIR/sem-motivo.sh"
! grep -q 'Motivo da falha' "$TMPDIR/sem-motivo.sh" || erro "a variante sem motivo não foi gerada"
! bash teste/testa-loop-minimo.sh "$TMPDIR/sem-motivo.sh" > /dev/null 2>&1 || erro "o juiz do núcleo devia reprovar um script sem 'Motivo da falha'"
! bash teste/testa-loop-com-gates.sh ./loop-minimo.sh > /dev/null 2>&1 || erro "o juiz dos gates devia reprovar o núcleo sem gates"
! bash teste/testa-loop-minimo.sh ./loop-com-gates.sh > /dev/null 2>&1 || erro "o juiz do núcleo reprova script com gate de árvore (erro comum do material)"
ok "os juízes reprovam: núcleo sem a causa, núcleo sem gates, e o script com gates no juiz errado"

# ------------------------------------------------------------------ o que o PDF cita existe
for f in modelos/pedido-nucleo.md modelos/pedido-gates.md modelos/loop-minimo.sh modelos/loop-com-gates.sh \
         modelos/teste/testa-loop-minimo.sh modelos/teste/testa-loop-com-gates.sh modelos/motor-falso/claude \
         README.md material-de-apoio-aula-5.1.pdf; do
  [ -f "$AULA/$f" ] || erro "$f citado no material e ausente do repositório"
done
[ "$(wc -l < "$AULA/modelos/loop-minimo.sh")" = 39 ] || erro "o núcleo devia ter 39 linhas"
[ "$(wc -l < "$AULA/modelos/loop-com-gates.sh")" = 69 ] || erro "o loop com gates devia ter 69 linhas"
# O --tools não afeta MCP (cli-reference): sem o deny de mcp__*, o avaliador alcança o MCP do projeto.
for f in modelos/loop-com-gates.sh modelos/pedido-gates.md; do
  grep -qF -- '--tools "Read,Glob,Grep" --disallowedTools "mcp__*"' "$AULA/$f" || erro "$f: avaliador sem --disallowedTools \"mcp__*\""
done
! grep -q -- '--dangerously-skip-permissions' <(grep -A10 'RALPH_VERIFY' "$AULA/modelos/loop-com-gates.sh") || erro "o avaliador não pode rodar em bypass"
[ "$(wc -l < "$R")" = 1903 ] || echo "  aviso: o ralph.sh do cache não tem mais 1903 linhas; confira o número da seção 1"
ok "arquivos citados no PDF existem; 39 e 69 linhas; avaliador sem bypass e sem MCP"

echo "verificar.sh: $n grupos de checagem passaram."
