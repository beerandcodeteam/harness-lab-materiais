#!/usr/bin/env bash
# testes/lib.sh · funções comuns dos testes do Módulo 5 (carregar com "source")
#
# EXEMPLOS = pasta exemplos/; BASE = onde os repositórios temporários nascem
# (M5_TESTE_DIR, ou uma pasta do mktemp). Nada aqui chama o claude de verdade:
# o "claude" do PATH é o motor-falso/claude, copiado para uma pasta sem espaço.

EXEMPLOS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -n "${M5_TESTE_DIR:-}" ]; then mkdir -p "$M5_TESTE_DIR"; BASE="$(mktemp -d "$M5_TESTE_DIR/run.XXXX")"
else BASE="$(mktemp -d)"; fi

PASSOU=0; FALHOU=0
VERDE='\033[0;32m'; VERMELHO='\033[0;31m'; AMARELO='\033[1;33m'; SEM='\033[0m'
passa() { PASSOU=$((PASSOU + 1)); echo -e "  ${VERDE}ok${SEM}    $1"; }
falha() { FALHOU=$((FALHOU + 1)); echo -e "  ${VERMELHO}FALHOU${SEM} $1"; }
caso()  { echo -e "\n${AMARELO}== $1${SEM}"; }
igual()  { if [ "$1" = "$2" ]; then passa "$3"; else falha "$3 (esperado '$1', veio '$2')"; fi; }
contem() { if grep -qF -- "$2" "$1" 2>/dev/null; then passa "$3"; else falha "$3 (não achou '$2' em $(basename "$1"))"; fi; }
tem()    { if grep -qiE -- "$2" "$1" 2>/dev/null; then passa "$3"; else falha "$3 (não achou /$2/ em $(basename "$1"))"; fi; }   # regex, sem diferenciar maiúscula
naocontem() { if grep -qF -- "$2" "$1" 2>/dev/null; then falha "$3 (achou '$2')"; else passa "$3"; fi; }
placar() {
  echo
  if [ "$FALHOU" -eq 0 ]; then echo -e "${VERDE}$1: $PASSOU passaram${SEM}"; return 0; fi
  echo -e "${VERMELHO}$1: $FALHOU falharam, $PASSOU passaram${SEM}"; return 1
}

# Motor falso numa pasta sem espaço no caminho (o "claude" do PATH nos testes).
BIN="$BASE/bin"; mkdir -p "$BIN"
cp "$EXEMPLOS/motor-falso/claude" "$BIN/claude"; chmod +x "$BIN/claude"

# test.sh do repositório de exemplo: a Prova reprova se alguma fase escreveu "quebrado".
escreve_prova() {
  cat > "$1/test.sh" <<'PROVA'
#!/usr/bin/env bash
# Prova do repositório de exemplo: cada src/fase-N.txt precisa dizer "ok".
falhas=0
for f in src/fase-*.txt; do
  [ -e "$f" ] || continue
  if [ "$(cat "$f")" != ok ]; then echo "FALHOU: $f diz '$(cat "$f")', esperado 'ok'"; falhas=1; fi
done
[ "$falhas" -eq 0 ] && echo "todos verdes"
exit "$falhas"
PROVA
  chmod +x "$1/test.sh"
}

# PHASES de duas fases no formato do planner, PLAN com as mesmas tasks.
escreve_phases() {
  local d="$1"; mkdir -p "$d/.spec/features/exemplo"
  cat > "$d/.spec/features/exemplo/PHASES.md" <<'FASES'
# Phases: exemplo

## Phase 1: Primeira fase

Antes de implementar, leia:
1. `.spec/features/exemplo/SPEC.md`

- [ ] T01: Escrever src/fase-1.txt e ativar AC-01
      Arquivos: `src/fase-1.txt`, `tests/aceite.sh`
      Acceptance criteria: src/fase-1.txt diz ok; AC-01 roda sem pendente.
      Testes: `test.sh`: a Prova inteira.

## Phase 2: Segunda fase

- [ ] T02: Escrever src/fase-2.txt e ativar AC-02
      Arquivos: `src/fase-2.txt`, `tests/aceite.sh`
      Acceptance criteria: src/fase-2.txt diz ok; AC-02 roda sem pendente.
      Testes: `test.sh`: a Prova inteira.
FASES
  printf '# Plan\n\n### T01: fase 1\n### T02: fase 2\n' > "$d/.spec/features/exemplo/PLAN.md"
  printf '# Spec\n\nRF-01: as duas fases dizem ok.\n' > "$d/.spec/features/exemplo/SPEC.md"
  printf '# Feature-alvo\n\n- AC-01 a fase 1 diz ok.\n- AC-02 a fase 2 diz ok.\n' > "$d/FEATURE-ALVO.md"
}

# Repositório de exemplo completo: git, branch de trabalho, Prova, fases, a Trava
# da 4.2 (hook registrado e aceite.txt) e os scripts do Módulo 5 em .claude/scripts/.
# novo_repo <pasta> [loop.sh alternativo]
novo_repo() {
  local d="$1" loop="${2:-$EXEMPLOS/.claude/scripts/loop.sh}"
  rm -rf "$d"; mkdir -p "$d"
  (
    cd "$d" || exit 1
    git init -q -b main
    git config user.email "teste@harness.lab"; git config user.name "Teste Harness Lab"
    escreve_prova .
    escreve_phases .
    mkdir -p tests .claude/hooks .claude/scripts
    printf '#!/usr/bin/env bash\n# AC-01 e AC-02 (aceite do exemplo)\nexit 0\n' > tests/aceite.sh
    printf '# testes de aceite\ntests/aceite.sh\n' > .claude/aceite.txt
    printf '#!/usr/bin/env python3\n# stub do guarda-aceite.py da 4.2 (o loop só confere que existe e está registrado)\n' > .claude/hooks/guarda-aceite.py
    cat > .claude/settings.json <<'JSON'
{"hooks":{"PreToolUse":[{"matcher":"Edit|Write|MultiEdit","hooks":[{"type":"command","command":"python3 \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/guarda-aceite.py"}]}]}}
JSON
    cp -r "$EXEMPLOS/.claude/scripts/." .claude/scripts/
    cp "$loop" .claude/scripts/loop.sh
    [ -z "${SHIM:-}" ] || cp "$SHIM" .claude/scripts/shim/claude    # SHIM=caminho testa outro shim
    chmod +x .claude/scripts/*.sh .claude/scripts/shim/claude test.sh
    git add -A; git commit -qm "chore: repositório de exemplo"
    git switch -q -c feat/exemplo
  )
}

# Ambiente limpo para o loop.sh: HOME falso (sem apiKeyHelper do usuário), sem
# credencial de API, motor falso no PATH, ralph do cache, Prova do exemplo.
RALPH_DO_CACHE="${RALPH_SH:-$(ls -d "$HOME"/.claude/plugins/cache/beer-and-code/bc-harness/*/scripts/ralph.sh 2>/dev/null | sort -V | tail -1)}"
HOME_FALSO="$BASE/home"; mkdir -p "$HOME_FALSO"
ambiente() {
  env -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN -u CLAUDE_CODE_USE_BEDROCK -u CLAUDE_CODE_USE_VERTEX \
      -u CLAUDE_CODE_USE_FOUNDRY -u RALPH_TEST_CMD -u RALPH_MAX_CYCLES -u RALPH_VERIFY -u RALPH_VERIFY_MODEL \
      -u TELEGRAM_TOKEN -u TELEGRAM_CHAT_ID -u SLACK_WEBHOOK_URL -u AVISO_WEBHOOK -u CLAUDECODE \
      HOME="$HOME_FALSO" PATH="$BIN:$PATH" RALPH_SH="$RALPH_DO_CACHE" LOOP_TEST_CMD="./test.sh" LOOP_PAINEL=0 "$@"
}
