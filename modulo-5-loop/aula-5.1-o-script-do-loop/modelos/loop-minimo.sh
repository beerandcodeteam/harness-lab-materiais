#!/usr/bin/env bash
# loop-minimo.sh · aula 5.1 · o núcleo do loop. Uso: TESTE="cmd" ./loop-minimo.sh PHASES.md
# ENGINE (padrão claude), TESTE (obrigatório), TENTATIVAS (padrão 3).
set -u
DOC="${1:?uso: TESTE=\"cmd\" ./loop-minimo.sh PHASES.md}"
ENGINE="${ENGINE:-claude}"
TESTE="${TESTE:?defina TESTE com o comando da Prova}"
TENTATIVAS="${TENTATIVAS:-3}"
TMP=$(mktemp -d)

# 1. Quebra as fases: um arquivo por "## Phase N: título"; outro "## " encerra a fase.
awk -v d="$TMP" '/^## Phase [0-9]+: /{n++; f=sprintf("%s/fase-%02d.md", d, n); print > f; next}
                 /^## /{f=""} f{print > f}' "$DOC"

for fase in "$TMP"/fase-*.md; do
  num=$(head -1 "$fase" | sed -E 's/^## Phase ([0-9]+):.*/\1/')
  titulo=$(head -1 "$fase" | sed -E 's/^## Phase [0-9]+: //')
  motivo=""
  for ((t = 1; t <= TENTATIVAS; t++)); do
    echo "fase $num, tentativa $t/$TENTATIVAS"
    # 2. Sessão nova, com a fase (e a causa da falha anterior) no prompt.
    prompt="Implemente a fase abaixo. Rode os testes antes de terminar.
$motivo
$(cat "$fase")"
    "$ENGINE" -p "$prompt" --dangerously-skip-permissions < /dev/null > "$TMP/sessao-$num-$t.log" 2>&1
    # 3. A Prova roda fora da sessão. 4. Verde: commit da fase.
    if bash -c "$TESTE" > "$TMP/prova.log" 2>&1 < /dev/null; then
      git add -A && { git diff --cached --quiet || git commit -qm "feat(phase-$num): $titulo"; }
      continue 2
    fi
    # 5. Vermelho: a causa real vai para a próxima tentativa.
    motivo="## Motivo da falha
$(tail -n 40 "$TMP/prova.log")"
  done
  # 6. Esgotou: para e diz onde.
  echo "travou na fase $num"
  exit 1
done
echo "terminou"
