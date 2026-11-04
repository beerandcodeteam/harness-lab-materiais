#!/usr/bin/env bash
# testa-loop-com-gates.sh · aula 5.1 · o juiz do loop com os dois gates, sem gastar token
#
# Uso: bash teste/testa-loop-com-gates.sh [caminho/do/loop-com-gates.sh]
#      (sem argumento, testa o de referência, ../loop-com-gates.sh)
#
# Mesmo método do testa-loop-minimo.sh: repositório git temporário com 2 fases,
# test.sh como Prova e o motor falso (motor-falso/claude) no lugar do claude.
# O motor reconhece o avaliador pela primeira linha do prompt, RALPH_VERIFY,
# e responde uma linha "TASK n: DONE|INCOMPLETE" por task da fase.
#   ok             2 commits feat(phase-N), "terminou", exit 0; o avaliador roda
#                  uma vez por fase e recebe as tasks e o git status
#   arvore-suja    um arquivo sem commit: exit 1 antes de qualquer sessão
#   incompleta     Prova verde e avaliador INCOMPLETE: nenhum commit, 3 tentativas,
#                  a 2a traz a linha INCOMPLETE em "Motivo da falha", "travou na fase 1"
#   falha-uma-vez  a fase 2 reprova na Prova e passa na 2a tentativa; o avaliador
#                  só roda com a Prova verde
#   nunca-passa    Prova sempre vermelha: exit 1, o avaliador nunca roda
# Procura o motor em ../motor-falso/ ou ../../motor-falso/ (ou MOTOR=caminho).
# A saída do script fica fora do repositório de teste (senão a árvore ficaria suja).
set -euo pipefail

aqui="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="$(cd "$(dirname "${1:-$aqui/../loop-com-gates.sh}")" && pwd)/$(basename "${1:-$aqui/../loop-com-gates.sh}")"
[ -f "$script" ] || { echo "não achei o script: $script" >&2; exit 2; }
motor="${MOTOR:-}"
for m in "$aqui/../motor-falso/claude" "$aqui/../../motor-falso/claude"; do
  [ -n "$motor" ] || { [ -f "$m" ] && motor="$m"; }
done
[ -n "$motor" ] || { echo "não achei o motor-falso/claude (defina MOTOR=caminho)" >&2; exit 2; }

base="$(mktemp -d)"
mkdir -p "$base/bin"; cp "$motor" "$base/bin/claude"; chmod +x "$base/bin/claude"

passou=0; falhou=0
passa() { passou=$((passou + 1)); echo "  ok     $1"; }
falha() { falhou=$((falhou + 1)); echo "  FALHOU $1"; }
confere() { if [ "$1" = "$2" ]; then passa "$3"; else falha "$3 (esperado '$1', veio '$2')"; fi; }
tem() { if grep -q -- "$2" "$1" 2>/dev/null; then passa "$3"; else falha "$3"; fi; }
naotem() { if grep -q -- "$2" "$1" 2>/dev/null; then falha "$3"; else passa "$3"; fi; }

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
saida() { echo "$base/saida-$1.txt"; }
roda() {  # roda <cenário> -> exit code; saída fora do repositório
  local rc=0
  MOTOR_CENARIO="$1" ENGINE="$base/bin/claude" TESTE="./test.sh" TENTATIVAS=3 \
    timeout 60 bash "$script" PHASES.md > "$(saida "$1")" 2>&1 || rc=$?
  echo "$rc"
}
commits_de_fase() { git log --pretty=%s | grep -c '^feat(phase-' || true; }
estado() { echo "$(git rev-parse --absolute-git-dir)/motor-falso"; }
conta() { cat "$(estado)/$1" 2>/dev/null || echo 0; }

echo "testando: $script"

echo "== ok"
repo ok
confere 0 "$(roda ok)" "exit 0"
confere 2 "$(commits_de_fase)" "2 commits de fase"
confere "feat(phase-2): Segunda fase" "$(git log -1 --pretty=%s)" "mensagem do último commit"
tem "$(saida ok)" terminou "imprimiu 'terminou'"
confere 2 "$(conta verificacoes)" "o avaliador rodou uma vez por fase"
tem "$(estado)/verificacao-1.txt" "T01: Escrever src/fase-1.txt" "o avaliador recebe as tasks da fase"
tem "$(estado)/verificacao-1.txt" "src/fase-1.txt" "o avaliador recebe o que a sessão alterou"
naotem "$(estado)/prompt-2.txt" "Open Questions" "a fase 2 não leva o '## Open Questions'"
confere "" "$(git status --porcelain)" "árvore limpa no fim"

echo "== arvore-suja"
repo arvore-suja
echo "rascunho que ninguém commitou" > rascunho.txt
confere 1 "$(roda arvore-suja)" "exit 1"
confere 0 "$(conta implementacoes)" "nenhuma sessão aberta"
tem "$(saida arvore-suja)" "suja" "disse que a árvore está suja"
[ -f rascunho.txt ] && passa "o arquivo sem commit ficou intacto" || falha "o arquivo sem commit ficou intacto"

echo "== incompleta"
repo incompleta
confere 1 "$(roda incompleta)" "exit 1"
confere 0 "$(commits_de_fase)" "nenhum commit: Prova verde não basta"
confere 3 "$(conta implementacoes)" "3 tentativas e para"
confere 3 "$(conta verificacoes)" "o avaliador rodou nas 3"
tem "$(estado)/prompt-2.txt" "Motivo da falha" "o prompt da 2a tentativa traz 'Motivo da falha'"
tem "$(estado)/prompt-2.txt" "TASK 1: INCOMPLETE" "a causa é a linha INCOMPLETE do avaliador"
tem "$(saida incompleta)" "travou na fase 1" "imprimiu 'travou na fase 1'"

echo "== falha-uma-vez"
repo falha-uma-vez
confere 0 "$(roda falha-uma-vez)" "exit 0"
confere 2 "$(commits_de_fase)" "2 commits de fase"
confere 3 "$(conta implementacoes)" "3 sessões: fase 1, fase 2, fase 2 de novo"
confere 2 "$(conta verificacoes)" "o avaliador não roda com a Prova vermelha"
tem "$(estado)/prompt-3.txt" "src/fase-2.txt diz 'quebrado'" "a causa é a saída real da Prova"

echo "== nunca-passa"
repo nunca-passa
confere 1 "$(roda nunca-passa)" "exit 1"
confere 0 "$(commits_de_fase)" "nenhum commit de fase"
confere 0 "$(conta verificacoes)" "o avaliador nunca rodou"
tem "$(saida nunca-passa)" "travou na fase 1" "imprimiu 'travou na fase 1'"

echo
echo "repositórios em: $base"
if [ "$falhou" -eq 0 ]; then echo "testa-loop-com-gates: $passou passaram"; exit 0; fi
echo "testa-loop-com-gates: $falhou falharam, $passou passaram"; exit 1
