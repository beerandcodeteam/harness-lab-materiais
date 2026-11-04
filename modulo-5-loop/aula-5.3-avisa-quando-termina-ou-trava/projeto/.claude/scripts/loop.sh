#!/usr/bin/env bash
# loop.sh · aulas 5.1, 5.2 e 5.3 · o único jeito de rodar o loop no curso
#
# Uso, na raiz do repositório, numa branch de trabalho:
#   .claude/scripts/loop.sh --checa .spec/features/<slug>/PHASES.md   só confere (zero token)
#   .claude/scripts/loop.sh .spec/features/<slug>/PHASES.md           confere e roda
#
# O motor é o ralph.sh do bc-harness, do jeito que o plugin instalou: sem editar
# e sem copiar para o repositório. Tudo que este script acrescenta funciona por
# fora (pré-voo, shim no PATH, leitura do .phases/state/run.tsv, aviso, log).
#
# Seções (cada aula acrescenta a sua):
#   [5.1] pré-voo mínimo, a chamada do ralph, cópia do log e resumo.txt
#   [5.2] pré-voo completo, shim de tempo e gasto no PATH, MAX_CICLOS, camadas.txt
#   [5.3] vigia em segundo plano, aviso no fim, Ctrl-C avisa "interrompido", LOOP_PR
#
# Variáveis:
#   MAX_CICLOS       ciclos por fase (padrão 3)                                 [5.2]
#   LOOP_TIMEOUT     teto de tempo por sessão, no formato do timeout (40m)        [5.2]
#   LOOP_BUDGET_USD  --max-budget-usd por sessão (5). Estimativa do cliente       [5.2]
#   LOOP_TEST_CMD    comando da Prova; sem ele, detecta na ordem do ralph         [5.1]
#   LOOP_ACEITO_API  1 = aceito rodar com credencial de API (cobra por uso)       [5.1]
#   LOOP_SEM_ACEITE  1 = roda sem o hook guarda-aceite (não recomendado)          [5.2]
#   LOOP_PAINEL      1 = --dashboard do ralph (padrão: 1 se a saída é terminal)   [5.1]
#   LOOP_QUIETO, LOOP_VIGIA_S  ver vigia.sh                                     [5.3]
#   LOOP_PR          1 = push e PR em rascunho quando entrega (desligado)         [5.3]
#   AVISO_CMD        troca o aviso.sh (os testes usam)                            [5.3]
#   RALPH_SH, CLAUDE_REAL  caminhos, se a busca automática não achar
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
checa=false; phases=""
while [ $# -gt 0 ]; do
  case "$1" in
    --checa)   checa=true; shift ;;
    -h|--help) sed -n 2,28p "$0"; exit 0 ;;
    -*)        echo "opção desconhecida: $1" >&2; exit 64 ;;
    *)         phases="$1"; shift ;;
  esac
done
[ -n "$phases" ] || { echo "uso: loop.sh [--checa] PHASES.md" >&2; exit 64; }

MAX_CICLOS="${MAX_CICLOS:-3}"
export LOOP_TIMEOUT="${LOOP_TIMEOUT:-40m}" LOOP_BUDGET_USD="${LOOP_BUDGET_USD:-5}"

erros=0
nao() { echo "  NÃO  $*"; erros=$((erros + 1)); }
ok()  { echo "  ok   $*"; }
avisa() {
  if [ -n "${AVISO_CMD:-}" ]; then $AVISO_CMD "$1" || true
  else bash "$DIR/aviso.sh" "$1" || true; fi
}
meta() { awk -F'\t' -v k="$1" '$1=="META" && $2==k {print $3}' .phases/state/run.tsv 2>/dev/null; }

echo "pré-voo"

# ==== [5.1] pré-voo mínimo ========================================================
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  nao "fora de um repositório git"; exit 1
fi
[ "$(pwd -P)" = "$(cd "$(git rev-parse --show-toplevel)" && pwd -P)" ] || { nao "rode na raiz do repositório"; exit 1; }
[ -f "$phases" ] && ok "fases: $phases" || nao "arquivo de fases não existe: $phases"

# Credencial que passa na frente da assinatura: no -p, a chave é usada sempre que existe.
api=""
for v in CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_VERTEX CLAUDE_CODE_USE_FOUNDRY ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY; do
  val="${!v:-}"
  [ -n "$val" ] && [ "$val" != 0 ] && api+="$v "
done
for f in "$HOME/.claude/settings.json" .claude/settings.json .claude/settings.local.json; do
  [ -f "$f" ] && grep -q '"apiKeyHelper"' "$f" && api+="apiKeyHelper($f) "
done
if [ -n "$api" ] && [ "${LOOP_ACEITO_API:-0}" != 1 ]; then
  nao "credencial de API no ambiente: ${api% }. O loop cobraria por API, não pela assinatura. Limpe, ou LOOP_ACEITO_API=1 se é isso mesmo."
elif [ -n "$api" ]; then
  ok "credencial de API aceita (LOOP_ACEITO_API=1): ${api% }"
else
  ok "nenhuma credencial de API: o loop usa o login da assinatura"
fi

# O ralph do plugin, o mais novo do cache. Sem copiar para a raiz (sujaria a árvore).
RALPH="${RALPH_SH:-$(ls -d "$HOME"/.claude/plugins/cache/beer-and-code/bc-harness/*/scripts/ralph.sh 2>/dev/null | sort -V | tail -1)}"
[ -n "$RALPH" ] && [ -f "$RALPH" ] && ok "ralph: $RALPH" \
  || nao "ralph.sh do bc-harness não encontrado. Instale o plugin (aula 3.4) ou aponte RALPH_SH."

# O claude de verdade, resolvido antes de o shim entrar no PATH.
CLAUDE_REAL="${CLAUDE_REAL:-$(command -v claude || true)}"
if [ -z "$CLAUDE_REAL" ] || [ "$CLAUDE_REAL" -ef "$DIR/shim/claude" ]; then
  nao "claude não encontrado no PATH (ou só o shim). Instale o Claude Code ou aponte CLAUDE_REAL."
else
  ok "claude: $CLAUDE_REAL"
fi

# A Prova: sem comando de teste, não tem loop. Mesma ordem de detecção do ralph.
teste="${LOOP_TEST_CMD:-}"; origem="LOOP_TEST_CMD"
if [ -z "$teste" ] && [ -n "${RALPH_TEST_CMD:-}" ]; then
  nao "RALPH_TEST_CMD exportada ($RALPH_TEST_CMD): ela vence a detecção em qualquer projeto. Limpe, ou use LOOP_TEST_CMD."
fi
sail=""
if [ -f artisan ] && { [ -x vendor/bin/sail ] || { [ -f composer.json ] && grep -qF 'laravel/sail' composer.json; }; }; then sail="vendor/bin/sail"; fi
if [ -z "$teste" ]; then
  origem="detectado"
  if [ -n "$sail" ]; then teste="$sail test"
  elif [ -f composer.json ] && grep -qE '"test"[[:space:]]*:' composer.json; then teste="composer test"
  elif [ -f artisan ]; then teste="php artisan test"
  elif [ -f package.json ] && grep -qE '"test"[[:space:]]*:' package.json; then teste="npm test"
  elif [ -f pytest.ini ] || { [ -f pyproject.toml ] && grep -qF '[tool.pytest' pyproject.toml; }; then teste="pytest"
  elif [ -f go.mod ]; then teste="go test ./..."
  elif [ -f Cargo.toml ]; then teste="cargo test"
  fi
fi
if [ -z "$teste" ]; then
  nao "nenhum comando de teste. Sem Prova, não tem loop: o ralph rodaria só com o juiz. Defina LOOP_TEST_CMD."
else
  primeiro="${teste%% *}"
  if [[ "$primeiro" == */* ]] && [ ! -x "$primeiro" ]; then nao "comando de teste '$teste': '$primeiro' não existe ou não é executável"
  elif [[ "$primeiro" != */* ]] && ! command -v "$primeiro" >/dev/null 2>&1; then nao "comando de teste '$teste': '$primeiro' não está no PATH"
  elif [ "$(basename -- "$primeiro")" = sail ] && ! "$primeiro" ps 2>/dev/null | grep -qiE '(^|[[:space:]])(Up|running)([[:space:]]|$)'; then
    nao "comando de teste '$teste': containers do Sail parados. Suba com '$primeiro up -d'."
  else
    ok "Prova: $teste ($origem)"
  fi
fi

# ==== [5.2] pré-voo completo ======================================================
branch="$(git symbolic-ref --short -q HEAD || true)"
case "$branch" in
  "")          nao "HEAD solto: rode numa branch de trabalho" ;;
  main|master) nao "branch $branch: o loop commita sozinho. Crie uma branch de trabalho (git switch -c ...)." ;;
  *)           ok "branch: $branch" ;;
esac

# O diagnóstico da 1.1 a salvo: o ralph sugere 'git clean -fd' quando uma fase falha.
for p in .diagnostico-operador diagnostico-operador.md; do
  [ -e "$p" ] || continue
  if [ -n "$(git ls-files -- "$p" | head -1)" ] || git check-ignore -q "$p"; then
    ok "diagnóstico a salvo: $p"
  else
    nao "$p está fora do git e do exclude: um 'git clean -fd' apaga. Commite, ou: echo '/$p' >> \"\$(git rev-parse --git-path info/exclude)\""
  fi
done

sujos="$(git status --porcelain)"
if [ -n "$sujos" ]; then
  nao "árvore suja: o ralph commita com 'git add -A' e engoliria isto:"
  printf '%s\n' "$sujos" | head -5 | sed 's/^/         /'
else
  ok "árvore limpa"
fi

conf="$(bash "$DIR/confere-phases.sh" "$phases" 2>&1)"; rc_conf=$?
resumo_conf="$(tail -2 <<<"$conf" | head -1)"
if [ "$rc_conf" -eq 0 ]; then
  ok "confere-phases: $resumo_conf"
else
  nao "o PHASES não passa no confere-phases.sh:"
  grep -E '^ERRO' <<<"$conf" | head -8 | sed 's/^/         /'
fi

aceite_arqs=()
if [ "${LOOP_SEM_ACEITE:-0}" = 1 ]; then
  ok "hook dos testes de aceite DESLIGADO (LOOP_SEM_ACEITE=1)"
else
  if [ -f .claude/hooks/guarda-aceite.py ] && grep -qs 'guarda-aceite' .claude/settings.json .claude/settings.local.json; then
    ok "hook guarda-aceite.py registrado"
  else
    nao "hook guarda-aceite.py não está em .claude/hooks/ ou não está registrado no .claude/settings.json (aula 4.2)"
  fi
  if [ -f .claude/aceite.txt ]; then
    while IFS= read -r l; do
      l="${l%%#*}"; l="${l//[[:space:]]/}"
      [ -n "$l" ] || continue
      shopt -s nullglob; achou=( $l ); shopt -u nullglob
      [ ${#achou[@]} -gt 0 ] || nao "o aceite.txt lista '$l' e o arquivo não existe"
      aceite_arqs+=("${achou[@]}")
    done < .claude/aceite.txt
  fi
  [ ${#aceite_arqs[@]} -gt 0 ] && ok "testes de aceite: ${#aceite_arqs[@]} arquivo(s) em .claude/aceite.txt" \
    || nao ".claude/aceite.txt ausente ou vazio: o hook não guarda nada"
fi

[[ "$MAX_CICLOS" =~ ^[1-9][0-9]*$ ]] && ok "freios: MAX_CICLOS=$MAX_CICLOS, LOOP_TIMEOUT=$LOOP_TIMEOUT, LOOP_BUDGET_USD=$LOOP_BUDGET_USD por sessão" \
  || nao "MAX_CICLOS inválido: $MAX_CICLOS"
command -v timeout >/dev/null 2>&1 || nao "comando 'timeout' não existe (macOS: brew install coreutils e um alias para gtimeout)"
[ -x "$DIR/shim/claude" ] || nao "shim não encontrado ou sem chmod +x: $DIR/shim/claude"

camadas() {
  local n f
  echo "Camadas do harness · $(date '+%d/%m/%Y %H:%M') · $(basename "$(pwd)") · branch ${branch:-?}"
  echo "Regra"
  for f in CLAUDE.md AGENTS.md; do
    [ -f "$f" ] && echo "  $f: $(wc -l < "$f") linhas" || echo "  $f: ausente"
  done
  n=$(ls .claude/skills/*/SKILL.md 2>/dev/null | wc -l); echo "  skills do projeto: $n"
  echo "Trava"
  for f in .claude/settings.json .claude/settings.local.json; do
    [ -f "$f" ] || continue
    if command -v jq >/dev/null 2>&1; then
      echo "  hooks em $f: $(jq -r '[.hooks // {} | to_entries[] | "\(.key) \([.value[]?.hooks // [] | length] | add // 0)"] | join(", ")' "$f" 2>/dev/null)"
    else
      echo "  hooks em $f: (jq ausente, não contado)"
    fi
  done
  echo "  guarda-aceite: $([ "${LOOP_SEM_ACEITE:-0}" = 1 ] && echo DESLIGADO || echo ligado)"
  echo "Prova"
  echo "  comando de teste: ${teste:-(nenhum)} ($origem)"
  f="$(dirname -- "$phases")/SPEC.md"; [ -f "$f" ] && echo "  SPEC: $f" || echo "  SPEC: ausente ao lado do PHASES"
  if [ ${#aceite_arqs[@]} -gt 0 ]; then
    n=$(cat "${aceite_arqs[@]}" 2>/dev/null | grep -cE -- '->[[:space:]]*todo\(|\b(test|it|describe)\.skip\(|@pytest\.mark\.skip' || true)
    echo "  testes de aceite: ${#aceite_arqs[@]} arquivo(s), $n marcador(es) de pendente"
  fi
  echo "Loop"
  echo "  PHASES: $phases ($resumo_conf)"
  n=$(grep -cE '^## Phase [0-9]+: ' "$phases" 2>/dev/null || echo 0)
  echo "  freios: MAX_CICLOS=$MAX_CICLOS, LOOP_TIMEOUT=$LOOP_TIMEOUT, LOOP_BUDGET_USD=$LOOP_BUDGET_USD por sessão"
  echo "  pior caso: $n fase(s) x $MAX_CICLOS ciclos x 2 sessões = $((n * MAX_CICLOS * 2)) sessões"
  if [ -n "${TELEGRAM_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then f=telegram
  elif [ -n "${SLACK_WEBHOOK_URL:-}" ]; then f=slack
  elif [ -n "${AVISO_WEBHOOK:-}" ]; then f=webhook
  else f=local; fi
  echo "  aviso: $f$([ -n "${AVISO_CMD:-}" ] && echo " (AVISO_CMD)")"
  echo "  ralph: ${RALPH:-?}"
}

if [ "$erros" -gt 0 ]; then
  echo "pré-voo: $erros problema(s). Nada rodou, nenhum token gasto."
  exit 1
fi
echo
camadas_tmp="$(mktemp)"
camadas > "$camadas_tmp"; cat "$camadas_tmp"
if $checa; then
  rm -f "$camadas_tmp"
  echo; echo "pré-voo ok. Para rodar: $0 $phases"
  exit 0
fi

# ==== [5.1] a chamada =============================================================
# --git-path, não --git-dir: numa git worktree o exclude que vale é o do repositório principal.
# O /.phases/ também: o ralph grava o dele pelo --git-dir e, numa worktree, commitaria o .phases.
exclude="$(git rev-parse --git-path info/exclude)"; mkdir -p "$(dirname -- "$exclude")"
for p in /.loop-logs/ /.phases/; do grep -qxF "$p" "$exclude" 2>/dev/null || echo "$p" >> "$exclude"; done
tmp=".loop-logs/.atual"; rm -rf "$tmp"; mkdir -p "$tmp"
mv "$camadas_tmp" "$tmp/camadas.txt"
inicio=$(date +%s); base=$(git rev-parse HEAD)

# [5.2] o shim na frente do PATH: toda sessão do ralph passa por ele.
export CLAUDE_REAL
export PATH="$DIR/shim:$PATH"

# [5.3] o vigia em segundo plano e o Ctrl-C que avisa.
LOOP_INICIO="$inicio" LOOP_PID=$$ VIGIA_SO_TRAVOU=1 bash "$DIR/vigia.sh" . &
vigia=$!
interrompido=0
trap 'interrompido=1' INT TERM HUP

painel="${LOOP_PAINEL:-}"; [ -n "$painel" ] || { [ -t 1 ] && painel=1 || painel=0; }
args=(--engine claude --max-cycles "$MAX_CICLOS" --test-cmd "$teste")   # sem --engine claude, o ralph usa o codex
echo; echo "loop: $phases · $(date '+%d/%m/%Y %H:%M:%S')"
if [ "$painel" = 1 ]; then
  env -u RALPH_TEST_CMD bash "$RALPH" "${args[@]}" --dashboard "$phases"; rc=$?
else
  env -u RALPH_TEST_CMD bash "$RALPH" "${args[@]}" "$phases" 2>&1 | tee "$tmp/ralph.log"; rc=${PIPESTATUS[0]}
fi

kill "$vigia" 2>/dev/null; wait "$vigia" 2>/dev/null
trap - INT TERM HUP

# ==== [5.1] o fim: copia o log antes que o próximo run apague o .phases ===========
novo=false
started="$(meta started)"
[[ "$started" =~ ^[0-9]+$ ]] && [ "$started" -ge "$inicio" ] && novo=true
if $novo; then run="$(meta run)"; else run="abortado-$(date '+%m%d-%H%M%S')"; fi
dest=".loop-logs/$run"
rm -rf "$dest"; mv "$tmp" "$dest"
if $novo; then
  # -p mantém a hora de cada arquivo: o /diagnostico-operador depois (aula 6.3) mede a janela do run por ela.
  cp -p .phases/state/run.tsv "$dest/"
  cp -rp .phases/logs .phases/prompts "$dest/" 2>/dev/null
  cp -p .phases/manifest.txt "$dest/" 2>/dev/null
  [ -f .phases/logs/ralph.log ] && cp -p .phases/logs/ralph.log "$dest/ralph.log"
fi

S="$dest/run.tsv"
desfecho="ABORTOU ANTES DE COMEÇAR"; total="?"; feitas=0; projeto="$(basename "$(pwd)")"
fase_f=""; titulo_f=""; ciclo_f=""; gate_f=""; causa=""; arq_causa=""
if $novo; then
  st="$(meta status)"; total="$(meta phase_total)"; projeto="$(meta project)"
  feitas=$(awk -F'\t' '$1=="PHASE" && $3=="done"' "$S" | wc -l)
  falhas=$(awk -F'\t' '$1=="PHASE" && $3=="failed"' "$S" | wc -l)
  rodando=$(awk -F'\t' '$1=="PHASE" && $3=="running"' "$S" | wc -l)
  pid="$(meta pid)"
  case "$st" in
    finished) desfecho="ENTREGOU" ;;
    waiting)  desfecho="ESPERANDO LIMITE" ;;
    running)  kill -0 "$pid" 2>/dev/null && desfecho="RODANDO" || desfecho="MORTO" ;;
    failed)   if [ "$falhas" -gt 0 ]; then desfecho="FALHOU"; else desfecho="INTERROMPIDO"; fi ;;
  esac
  [ "$interrompido" = 1 ] && [ "$desfecho" != ENTREGOU ] && desfecho="INTERROMPIDO"
  linha="$(awk -F'\t' '$1=="PHASE" && $3=="failed" {print; exit}' "$S")"
  [ -n "$linha" ] || linha="$(awk -F'\t' '$1=="PHASE" && $3=="running" {print; exit}' "$S")"
  if [ -n "$linha" ]; then
    IFS=$'\t' read -r _ fase_f _ ciclo_f gates titulo_f <<<"$linha"
    read -r -a g <<<"$gates"
    for i in 0 1 2 3; do [ "${g[$i]:-}" = fail ] && { gate_f="$i"; break; }; done
    nn=$(printf '%02d' "$fase_f")
    case "$gate_f" in
      0) arq_causa="$dest/logs/phase-$nn.cycle-$ciclo_f.log" ;;
      2) arq_causa="$dest/logs/phase-$nn.test-$ciclo_f.log" ;;
      3) arq_causa="$dest/logs/phase-$nn.verify-$ciclo_f.log"
         causa="$(grep -m1 -E 'TASK [0-9]+: INCOMPLETE' "$arq_causa" 2>/dev/null || true)" ;;
    esac
    [ -n "$causa" ] || causa="$(meta last_error)"
    causa="${causa% Ultimas linhas do output:}"; causa="${causa% Saida:}"
  fi
fi

{
  echo "loop.sh · resumo do run"
  echo "projeto:   $projeto"
  echo "run:       $run"
  echo "fases:     $phases"
  echo "branch:    ${branch:-?} (base $(git rev-parse --short "$base"))"
  if $novo; then
    fim="$(meta ended)"; [[ "$fim" =~ ^[0-9]+$ ]] || fim=$(date +%s)
    echo "início:    $(date -d "@$started" '+%d/%m/%Y %H:%M:%S' 2>/dev/null || echo "$started")"
    echo "duração:   $(( (fim - started) / 60 )) min $(( (fim - started) % 60 )) s"
  fi
  echo "exit do ralph: $rc"
  echo "desfecho:  $desfecho"
  echo "fases feitas: $feitas/$total"
  if $novo; then
    awk -F'\t' '$1=="PHASE" {printf "  F%s %-8s ciclo %s  gates %-24s %s\n", $2, $3, $4, $5, $6}' "$S"
  fi
  if [ -n "$fase_f" ]; then
    echo "onde parou: F$fase_f ($titulo_f), ciclo $ciclo_f/$MAX_CICLOS${gate_f:+, gate $gate_f}"
    [ -n "$causa" ] && echo "causa:     $causa"
    [ -n "$arq_causa" ] && echo "arquivo da causa: $arq_causa"
  fi
  echo "commits do run:"
  git log --oneline "$base..HEAD" | sed 's/^/  /'
  echo "freios:    MAX_CICLOS=$MAX_CICLOS, LOOP_TIMEOUT=$LOOP_TIMEOUT, LOOP_BUDGET_USD=$LOOP_BUDGET_USD"
  echo "Prova:     $teste"
} > "$dest/resumo.txt"
echo; cat "$dest/resumo.txt"; echo "log: $dest/"

# ==== [5.3] o aviso do fim ========================================================
case "$desfecho" in
  ENTREGOU)     msg="terminou $feitas/$total fases. Branch $branch. Log: $dest/" ;;
  FALHOU)       msg="falhou: F$fase_f ($titulo_f), gate ${gate_f:-?}, ciclo $ciclo_f/$MAX_CICLOS. $causa" ;;
  INTERROMPIDO) msg="interrompido na fase ${fase_f:-?} (Ctrl-C ou terminal fechado). $feitas/$total fases feitas." ;;
  MORTO)        msg="morto na fase ${fase_f:-?}: o ralph sumiu sem fechar o estado." ;;
  *)            msg="o ralph parou antes de começar (exit $rc). Veja $dest/ralph.log" ;;
esac
avisa "loop $projeto: $msg"

if [ "${LOOP_PR:-0}" = 1 ] && [ "$desfecho" = ENTREGOU ]; then
  echo "LOOP_PR=1: push de $branch e PR em rascunho (o push pode disparar o CI do repositório)"
  git push -u origin "$branch" && \
    gh pr create --draft --head "$branch" --title "loop: $(basename "$(dirname -- "$phases")")" --body-file "$dest/resumo.txt" \
    || echo "LOOP_PR: push ou PR falhou; o trabalho está commitado na branch $branch"
fi
exit "$rc"
