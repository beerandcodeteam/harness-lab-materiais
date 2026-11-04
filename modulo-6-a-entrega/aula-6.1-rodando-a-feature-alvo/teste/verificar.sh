#!/usr/bin/env bash
# verificar.sh · aula 6.1 · roda no ~/projeto da sandbox, depois dos comandos do material.
# Prova que o projeto ficou pronto para soltar o loop e que o disparo funciona,
# sem gastar token: o "claude" do disparo é o motor falso de teste/motor-falso/
# (o mesmo do Módulo 5). O ralph é o de verdade, do plugin bc-harness instalado.
#   1. branch da feature, árvore limpa, kit do loop igual ao do repositório; 4.3 e 4.2 iguais à origem
#   2. __pycache__ e o diagnóstico da 1.1 não sujam a árvore, nem numa git worktree
#   3. plugins; o aviso da 5.3: segredos fora do repositório, link ignorado, sem vazar o token
#   4. o --checa passa aqui e reprova cada problema que a aula e o material citam
#   5. o ralph da aula 5.3 para na árvore suja, como no vídeo; o ralph sem --engine usa o codex
#   6. o loop.sh dispara de ponta a ponta: 5 fases, 5 commits feat(phase-N), log em .loop-logs/
set -euo pipefail

n=0
ok() { n=$((n + 1)); printf '  ok  %s\n' "$1"; }
erro() { printf 'FALHOU: %s\n' "$1" >&2; exit 1; }
AULA="$HOME/harness-lab-materiais/modulo-6-a-entrega/aula-6.1-rodando-a-feature-alvo"
P=.spec/features/post-view-counter/PHASES.md
TMP=$(mktemp -d)
for v in ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_VERTEX \
         CLAUDE_CODE_USE_FOUNDRY RALPH_TEST_CMD TELEGRAM_TOKEN TELEGRAM_CHAT_ID SLACK_WEBHOOK_URL AVISO_WEBHOOK; do
  unset "$v"
done

# Pasta com o claude falso (e um codex falso), sem espaço no caminho. Fica na frente do PATH
# sempre que um ralph roda aqui: nenhuma sessão de verdade, nenhum token.
B="$TMP/bin"; mkdir -p "$B"
cp "$AULA/teste/motor-falso/claude" "$B/claude"; chmod +x "$B/claude"
printf '#!/usr/bin/env bash\necho "codex $*" | head -c 200 >> "%s/codex.log"; echo >> "%s/codex.log"; exit 1\n' "$TMP" "$TMP" > "$B/codex"
chmod +x "$B/codex"
FALSO="PATH=$B:$PATH"

# ------------------------------------------------------------------ 1. branch, árvore e kit
[ "$(git branch --show-current)" = "feat/post-view-counter" ] || erro "a branch devia ser feat/post-view-counter"
[ -z "$(git status --porcelain)" ] || { git status --short >&2; erro "árvore suja depois dos comandos do material"; }
ok "branch feat/post-view-counter e árvore limpa"

for f in loop.sh aviso.sh vigia.sh confere-phases.sh shim/claude; do
  [ -x ".claude/scripts/$f" ] || erro ".claude/scripts/$f não instalado ou sem chmod +x"
  cmp -s ".claude/scripts/$f" "$AULA/projeto/.claude/scripts/$f" || erro "$f diferente do repositório"
  bash -n ".claude/scripts/$f" || erro "sintaxe de $f"
  git ls-files --error-unmatch ".claude/scripts/$f" >/dev/null 2>&1 || erro "$f não foi commitado"
done
ok "kit do loop: 5 arquivos instalados, executáveis, commitados e iguais ao repositório"

A53="$HOME/harness-lab-materiais/modulo-5-loop/aula-5.3-avisa-quando-termina-ou-trava"
for f in ralph.sh aviso-env.sh .gitignore; do
  [ -f ".claude/scripts/$f" ] || erro "a aula 5.3 não instalou .claude/scripts/$f"
  cmp -s ".claude/scripts/$f" "$A53/projeto/.claude/scripts/$f" || erro "$f diferente do da aula 5.3"
  git ls-files --error-unmatch ".claude/scripts/$f" >/dev/null 2>&1 || erro "$f não foi commitado"
done
ok "aula 5.3 instalada e commitada: ralph.sh da gravação, aviso-env.sh e .gitignore"

A43="$HOME/harness-lab-materiais/modulo-4-prova/aula-4.3-spec-com-criterio-de-aceite"
for f in commands/plan.md agents/specifier.md agents/clarifier.md agents/planner.md scripts/confere-phases.sh; do
  cmp -s ".claude/$f" "$A43/projeto/.claude/$f" || erro ".claude/$f diferente do da aula 4.3"
  git ls-files --error-unmatch ".claude/$f" >/dev/null 2>&1 || erro ".claude/$f não está no git"
done
A42="$HOME/harness-lab-materiais/modulo-4-prova/aula-4.2-o-teste-verde-que-mente"
for f in hooks/guarda-aceite.py aceite.exemplo.txt; do
  cmp -s ".claude/$f" "$A42/projeto/.claude/$f" || erro ".claude/$f diferente do da aula 4.2"
  git ls-files --error-unmatch ".claude/$f" >/dev/null 2>&1 || erro ".claude/$f não foi commitado"
done
grep -qxF 'tests/Feature/Blog/PostViewAceiteTest.php' .claude/aceite.txt || erro "o cp do exemplo sobrescreveu o aceite.txt"
! grep -q 'CadastroEmailDuplicadoTest' .claude/aceite.txt || erro "o aceite.txt ficou com os caminhos do exemplo"
ok "4.3 (/plan e os três agentes) e 4.2 (hook, exemplo) iguais à origem e commitados; o aceite.txt existente ficou intacto"

# ------------------------------------------------------------------ 2. o que suja a árvore
grep -qxF '__pycache__/' .gitignore || erro "__pycache__/ não está no .gitignore"
mkdir -p .claude/hooks/__pycache__
echo x > .claude/hooks/__pycache__/guard-destructive.cpython-314.pyc
[ -z "$(git status --porcelain)" ] || erro "um .pyc em .claude/hooks/__pycache__/ sujou a árvore"
rm -rf .claude/hooks/__pycache__
grep -qxF '/.diagnostico-operador/' .git/info/exclude || erro "/.diagnostico-operador/ fora do exclude"
grep -qxF '/diagnostico-operador.md' .git/info/exclude || erro "/diagnostico-operador.md fora do exclude"
mkdir -p .diagnostico-operador; echo '{}' > .diagnostico-operador/antes.json; echo '# antes' > diagnostico-operador.md
[ -z "$(git status --porcelain)" ] || erro "o diagnóstico da 1.1 sujou a árvore"
git check-ignore -q .claude/scripts/.env || erro ".claude/scripts/.env (o .env do ralph da 5.3) não é ignorado"
grep -qxF '/.loop-logs/' .git/info/exclude || erro "/.loop-logs/ fora do exclude antes do run"
ok "__pycache__/, o diagnóstico da 1.1, o .loop-logs e o .env do ralph ficam fora do git"

# O X do passo 5 numa git worktree, onde o .git é um arquivo: cai no exclude comum.
git worktree add -q "$TMP/wt" -b wt-teste
x=$(cd "$TMP/wt" && git rev-parse --git-path info/exclude)
[ "$x" -ef .git/info/exclude ] || erro "na worktree, --git-path info/exclude devia ser o exclude comum ($x)"
mkdir -p "$TMP/wt/.diagnostico-operador"; echo '{}' > "$TMP/wt/.diagnostico-operador/antes.json"
[ -z "$(git -C "$TMP/wt" status --porcelain)" ] || erro "na worktree, o diagnóstico sujou a árvore"
git worktree remove --force "$TMP/wt"; git branch -q -D wt-teste
ok "numa git worktree, o exclude do passo 5 vale (git rev-parse --git-path)"

# ------------------------------------------------------------------ 3. plugins e aviso
lista=$(claude plugin list 2>&1)
grep -q 'bc-harness@beer-and-code' <<<"$lista" || { echo "$lista" >&2; erro "bc-harness não aparece em claude plugin list"; }
for p in boostify feature-alvo enxuto; do
  grep -q "$p@harness-lab" <<<"$lista" || { echo "$lista" >&2; erro "$p não aparece em claude plugin list"; }
done
W=$(ls -dv "$HOME"/.claude/plugins/cache/beer-and-code/bc-harness/*/scripts | tail -1)
[ -f "$W/ralph.sh" ] && [ -f "$W/ralph-watch.sh" ] || erro "ralph.sh ou ralph-watch.sh fora do cache do plugin"
ok "plugins bc-harness, boostify, feature-alvo e enxuto instalados; ralph.sh e ralph-watch.sh em $(basename "$(dirname "$W")")"

E="$HOME/.config/harness-lab/aviso.env"
[ -f "$E" ] || erro "aviso.env não foi criado em ~/.config/harness-lab/"
[ "$(stat -c %a "$E")" = 600 ] || erro "aviso.env devia ter chmod 600"
[ -L .claude/scripts/.env ] && [ "$(readlink .claude/scripts/.env)" = "$E" ] || erro ".claude/scripts/.env devia ser o link para $E"
git check-ignore -q .claude/scripts/.env || erro "o link .claude/scripts/.env não é ignorado"
out=$(AVISO_DRY=1 .claude/scripts/aviso-env.sh "teste vazio")
grep -q 'teste vazio' <<<"$out" || erro "aviso-env.sh sem canal devia cair no aviso local"
out=$(TELEGRAM_TOKEN=segredo-123 TELEGRAM_CHAT_ID=42 AVISO_DRY=1 .claude/scripts/aviso-env.sh "teste")
grep -q 'sendMessage' <<<"$out" || erro "aviso-env.sh com Telegram não montou o sendMessage"
! grep -q 'segredo-123' <<<"$out" || erro "aviso-env.sh mostrou o token do Telegram"
out=$(EVOLUTION_API_URL=http://evo.invalido AUTHENTICATION_API_KEY=chave-456 EVOLUTION_INSTANCE=bc \
      EVOLUTION_NUMBER=5511999999999 AVISO_DRY=1 .claude/scripts/aviso-env.sh "teste")
grep -q 'message/sendText' <<<"$out" || erro "aviso-env.sh com a Evolution não montou o sendText"
! grep -q 'chave-456' <<<"$out" || erro "aviso-env.sh mostrou a chave da Evolution"
ok "aviso: segredos em ~/.config/harness-lab/aviso.env (600), link ignorado, Telegram e WhatsApp sem vazar o token"

# ------------------------------------------------------------------ 4. o --checa
out=$(.claude/scripts/loop.sh --checa "$P" 2>&1) || { echo "$out" >&2; erro "--checa devia passar no projeto pronto"; }
grep -q 'pré-voo ok' <<<"$out" || erro "--checa sem 'pré-voo ok'"
grep -q 'pior caso: 5 fase(s) x 3 ciclos x 2 sessões = 30 sessões' <<<"$out" || erro "--checa sem a conta do pior caso"
[ ! -d .phases ] || erro "o --checa criou .phases/ (devia só conferir)"
ok "--checa: pré-voo ok, pior caso de 30 sessões, nada rodou"

C="$TMP/clone"
novo_clone() {
  rm -rf "$C"; git clone -q "$HOME/projeto" "$C"
  cp .git/info/exclude "$C/.git/info/exclude"
}
reprova() {   # reprova "descrição" "trecho esperado" [VAR=valor ...]
  local d="$1" t="$2"; shift 2
  local rc=0 s
  s=$(cd "$C" && env "$@" .claude/scripts/loop.sh --checa "$P" 2>&1) || rc=$?
  [ "$rc" = 1 ] || { echo "$s" >&2; erro "--checa devia reprovar ($d), veio exit $rc"; }
  grep -qF -- "$t" <<<"$s" || { echo "$s" >&2; erro "--checa sem '$t' ($d)"; }
  grep -q 'Nada rodou, nenhum token gasto' <<<"$s" || erro "--checa sem 'nenhum token gasto' ($d)"
  [ ! -d "$C/.phases" ] || erro "o ralph rodou ($d)"
}
novo_clone
git -C "$C" switch -q -c main
reprova "na main" "branch main: o loop commita sozinho"
git -C "$C" switch -q feat/post-view-counter
echo rascunho > "$C/rascunho.txt"
reprova "árvore suja" "?? rascunho.txt"
rm "$C/rascunho.txt"
reprova "credencial de API" "credencial de API no ambiente: ANTHROPIC_API_KEY" ANTHROPIC_API_KEY=sk-teste
reprova "Sail parado" "containers do Sail parados" SAIL_FALSO_PARADO=1
reprova "RALPH_TEST_CMD" "RALPH_TEST_CMD exportada" RALPH_TEST_CMD=vendor/bin/sail
grep -v diagnostico "$C/.git/info/exclude" > "$TMP/ex"; cp "$TMP/ex" "$C/.git/info/exclude"
mkdir -p "$C/.diagnostico-operador"; echo '{}' > "$C/.diagnostico-operador/antes.json"
reprova "diagnóstico fora do exclude" ".diagnostico-operador está fora do git e do exclude"
ok "--checa reprova main, árvore suja, chave de API, Sail parado, RALPH_TEST_CMD e diagnóstico solto"

# ------------------------------------------------------------------ 5. os dois ralphs direto
R53=.claude/scripts/ralph.sh
[ -x "$R53" ] || erro "o ralph da aula 5.3 não foi instalado em $R53"
bash -n "$R53" || erro "sintaxe do ralph da 5.3"
git ls-files --error-unmatch "$R53" >/dev/null 2>&1 || erro "o ralph da 5.3 não foi commitado"
novo_clone
echo rascunho > "$C/rascunho.txt"
rc=0; s=$(cd "$C" && env "$FALSO" RALPH_NOTIFY=off timeout 60 ./.claude/scripts/ralph.sh --engine claude "$P" 2>&1) || rc=$?
[ "$rc" = 1 ] || { echo "$s" >&2; erro "o ralph da 5.3 devia parar na árvore suja (exit $rc)"; }
grep -q 'Formato do input OK (5 fases declaradas)' <<<"$s" || erro "ralph da 5.3 sem 'Formato do input OK'"
grep -q 'Arvore de trabalho suja' <<<"$s" || erro "ralph da 5.3 sem 'Arvore de trabalho suja'"
grep -q 'rascunho.txt' <<<"$s" || erro "ralph da 5.3 não listou o arquivo solto"
[ ! -f "$C/.git/motor-falso/implementacoes" ] || erro "o ralph da 5.3 abriu sessão com a árvore suja"
ok "ralph da 5.3, igual ao vídeo: formato ok, árvore suja, lista o arquivo e para (exit 1)"

novo_clone
[ "$(env "$FALSO" bash -c 'command -v codex')" = "$B/codex" ] || erro "o codex falso não está na frente do PATH"
rc=0; s=$(cd "$C" && env "$FALSO" RALPH_MAX_CYCLES=1 timeout 60 bash "$W/ralph.sh" "$P" 2>&1) || rc=$?
grep -q 'Pre-checks OK (engine: codex' <<<"$s" || { echo "$s" >&2; erro "sem --engine o ralph devia escolher o codex"; }
grep -q 'codex exec' "$TMP/codex.log" || erro "o ralph sem --engine não chamou o codex"
ok "ralph do plugin sem --engine claude: engine codex (o falso foi chamado, exit $rc)"

# ------------------------------------------------------------------ 6. o disparo, com o motor falso
printf '#!/usr/bin/env bash\necho "$1" >> "%s/avisos.txt"\n' "$TMP" > "$TMP/grava.sh"; chmod +x "$TMP/grava.sh"
rc=0
env "$FALSO" AVISO_CMD="$TMP/grava.sh" LOOP_VIGIA_S=1 LOOP_PAINEL=0 \
  timeout 300 .claude/scripts/loop.sh "$P" > "$TMP/run.txt" 2>&1 || rc=$?
[ "$rc" = 0 ] || { tail -40 "$TMP/run.txt" >&2; erro "o loop.sh com o motor falso saiu com $rc"; }
fases=$(git log --format=%s | grep -c '^feat(phase-' || true)
[ "$fases" = 5 ] || erro "esperava 5 commits feat(phase-N), veio $fases"
git log --format=%s -1 | grep -qx 'feat(phase-5): Verificação transversal' || erro "último commit devia ser a fase 5"
git log --format=%s | grep -qx 'feat(phase-1): Storage e configuração' || erro "sem o commit da fase 1"
d=$(ls -d .loop-logs/run-* | head -1)
[ -n "$d" ] && [ -f "$d/resumo.txt" ] && [ -f "$d/run.tsv" ] && [ -f "$d/camadas.txt" ] || erro "log do run não foi copiado para .loop-logs/"
grep -qE 'desfecho: +ENTREGOU' "$d/resumo.txt" || erro "resumo.txt sem ENTREGOU"
grep -qE 'fases feitas: +5/5' "$d/resumo.txt" || erro "resumo.txt sem 5/5"
grep -q 'Gate 2 — comando de teste (--test-cmd): vendor/bin/sail test' "$TMP/run.txt" || erro "o loop não passou a Prova do Sail"
grep -q 'Pre-checks OK (engine: claude' "$TMP/run.txt" || erro "o loop.sh não chamou o ralph com --engine claude"
grep -q 'terminou 5/5 fases' "$TMP/avisos.txt" || erro "o aviso do fim não saiu"
[ -z "$(git status --porcelain)" ] || { git status --short >&2; erro "árvore suja depois do run"; }
grep -qxF '/.loop-logs/' .git/info/exclude || erro ".loop-logs fora do exclude"
painel=$(RALPH_WATCH_COLS=140 bash "$W/ralph-watch.sh" --once --no-color .)
grep -q 'Concluído' <<<"$painel" || erro "painel sem 'Concluído'"
grep -q 'G0 ✓ G1 ✓ G2 ✓ G3 ✓' <<<"$painel" || erro "painel sem os 4 gates verdes"
ok "loop.sh com o motor falso: ENTREGOU 5/5, 5 commits feat(phase-N), log em $d, aviso do fim, painel Concluído"

# ------------------------------------------------------------------ modelos
for f in antes-de-soltar.md pedidos.md; do
  [ -s "$AULA/modelos/$f" ] || erro "modelos/$f faltando"
done
grep -q 'Let Claude run without you' "$AULA/modelos/antes-de-soltar.md" || erro "antes-de-soltar.md sem a fonte das cinco perguntas"
grep -q 'loop.sh --checa' "$AULA/modelos/pedidos.md" || erro "pedidos.md sem o pedido do --checa"
ok "modelos/: antes-de-soltar.md e pedidos.md"

rm -rf .diagnostico-operador diagnostico-operador.md "$TMP"
echo "verificar.sh: $n grupos de checagem passaram."
