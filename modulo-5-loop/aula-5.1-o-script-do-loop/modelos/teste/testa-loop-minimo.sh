#!/usr/bin/env bash
# testa-loop-minimo.sh · aula 5.1 · o juiz do núcleo, sem gastar token
#
# Uso: bash teste/testa-loop-minimo.sh [caminho/do/loop-minimo.sh]
#      (sem argumento, testa o de referência, ../loop-minimo.sh)
#
# Roda o script três vezes num repositório git temporário, com o motor falso
# (motor-falso/claude) no lugar do claude:
#   ok             2 fases, 2 commits feat(phase-N), "terminou", exit 0
#   falha-uma-vez  a fase 2 reprova na 1a tentativa e passa na 2a; o prompt da
#                  2a tentativa traz "Motivo da falha" com a saída da Prova
#   nunca-passa    exit 1, "travou na fase 1", nenhum commit de fase
# Procura o motor em ../motor-falso/ ou ../../motor-falso/ (ou MOTOR=caminho).
# Repositórios em M5_TESTE_DIR, se definido; senão numa pasta do mktemp.
set -euo pipefail

aqui="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="$(cd "$(dirname "${1:-$aqui/../loop-minimo.sh}")" && pwd)/$(basename "${1:-$aqui/../loop-minimo.sh}")"
[ -f "$script" ] || { echo "não achei o script: $script" >&2; exit 2; }
motor="${MOTOR:-}"
for m in "$aqui/../motor-falso/claude" "$aqui/../../motor-falso/claude"; do
  [ -n "$motor" ] || { [ -f "$m" ] && motor="$m"; }
done
[ -n "$motor" ] || { echo "não achei o motor-falso/claude (defina MOTOR=caminho)" >&2; exit 2; }

if [ -n "${M5_TESTE_DIR:-}" ]; then mkdir -p "$M5_TESTE_DIR"; base="$(mktemp -d "$M5_TESTE_DIR/nucleo.XXXX")"; else base="$(mktemp -d)"; fi
mkdir -p "$base/bin"; cp "$motor" "$base/bin/claude"; chmod +x "$base/bin/claude"

passou=0; falhou=0
passa() { passou=$((passou + 1)); echo "  ok     $1"; }
falha() { falhou=$((falhou + 1)); echo "  FALHOU $1"; }
confere() { if [ "$1" = "$2" ]; then passa "$3"; else falha "$3 (esperado '$1', veio '$2')"; fi; }

repo() {  # repositório com 2 fases e a Prova do exemplo
  local d="$base/$1"; rm -rf "$d"; mkdir -p "$d"; cd "$d"
  git init -q -b main; git config user.email t@harness.lab; git config user.name "Teste"
  cat > PHASES.md <<'FASES'
# Phases: exemplo

## Phase 1: Primeira fase

- [ ] T01: Escrever src/fase-1.txt
      Acceptance criteria: o arquivo diz ok.
      Testes: test.sh

## Phase 2: Segunda fase

- [ ] T02: Escrever src/fase-2.txt
      Acceptance criteria: o arquivo diz ok.
      Testes: test.sh

## Open Questions

- nenhuma (este trecho não pode ir para a fase 2)
FASES
  cat > test.sh <<'PROVA'
#!/usr/bin/env bash
falhas=0
for f in src/fase-*.txt; do
  [ -e "$f" ] || continue
  [ "$(cat "$f")" = ok ] || { echo "FALHOU: $f diz '$(cat "$f")', esperado 'ok'"; falhas=1; }
done
[ "$falhas" -eq 0 ] && echo "todos verdes"
exit "$falhas"
PROVA
  chmod +x test.sh; git add -A; git commit -qm "chore: exemplo"
}
roda() {  # roda <cenário> -> exit code; saída em saida.txt
  local rc=0
  MOTOR_CENARIO="$1" ENGINE="$base/bin/claude" TESTE="./test.sh" TENTATIVAS=3 \
    timeout 60 bash "$script" PHASES.md > saida.txt 2>&1 || rc=$?
  echo "$rc"
}
commits_de_fase() { git log --pretty=%s | grep -c '^feat(phase-' || true; }
estado() { echo "$(git rev-parse --absolute-git-dir)/motor-falso"; }

echo "testando: $script"

echo "== ok"
repo ok
confere 0 "$(roda ok)" "exit 0"
confere 2 "$(commits_de_fase)" "2 commits de fase"
confere "feat(phase-2): Segunda fase" "$(git log -1 --pretty=%s)" "mensagem do último commit"
grep -q terminou saida.txt && passa "imprimiu 'terminou'" || falha "imprimiu 'terminou'"
grep -q "Open Questions" "$(estado)/prompt-2.txt" && falha "a fase 2 não leva o '## Open Questions'" || passa "a fase 2 não leva o '## Open Questions'"

echo "== falha-uma-vez"
repo falha-uma-vez
confere 0 "$(roda falha-uma-vez)" "exit 0"
confere 2 "$(commits_de_fase)" "2 commits de fase (a tentativa vermelha não commita)"
confere 3 "$(cat "$(estado)/implementacoes")" "3 sessões: fase 1, fase 2, fase 2 de novo"
grep -q "Motivo da falha" "$(estado)/prompt-3.txt" && passa "o prompt da 2a tentativa traz 'Motivo da falha'" || falha "o prompt da 2a tentativa traz 'Motivo da falha'"
grep -q "src/fase-2.txt diz 'quebrado'" "$(estado)/prompt-3.txt" && passa "a causa é a saída real da Prova" || falha "a causa é a saída real da Prova"
grep -q "Motivo da falha" "$(estado)/prompt-2.txt" && falha "a 1a tentativa da fase 2 vem sem motivo" || passa "a 1a tentativa da fase 2 vem sem motivo"

echo "== nunca-passa"
repo nunca-passa
confere 1 "$(roda nunca-passa)" "exit 1"
confere 0 "$(commits_de_fase)" "nenhum commit de fase"
confere 3 "$(cat "$(estado)/implementacoes")" "3 tentativas e para"
grep -q "travou na fase 1" saida.txt && passa "imprimiu 'travou na fase 1'" || falha "imprimiu 'travou na fase 1'"

echo
echo "repositórios em: $base"
if [ "$falhou" -eq 0 ]; then echo "testa-loop-minimo: $passou passaram"; exit 0; fi
echo "testa-loop-minimo: $falhou falharam, $passou passaram"; exit 1
