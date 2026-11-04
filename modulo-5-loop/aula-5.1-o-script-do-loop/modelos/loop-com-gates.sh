#!/usr/bin/env bash
# loop-com-gates.sh · aula 5.1 · o núcleo com os dois gates da receita da aula:
# árvore limpa antes de começar e um avaliador depois da Prova verde.
# Uso: TESTE="cmd" ./loop-com-gates.sh PHASES.md · TENTATIVAS (padrão 3), MODELO_AVALIADOR (sonnet).
# ENGINE (padrão claude) troca só o binário: outro CLI precisa aceitar as flags do claude.
set -u
DOC="${1:?uso: TESTE=\"cmd\" ./loop-com-gates.sh PHASES.md}"
ENGINE="${ENGINE:-claude}"
TESTE="${TESTE:?defina TESTE com o comando da Prova}"
TENTATIVAS="${TENTATIVAS:-3}"
MODELO="${MODELO_AVALIADOR:-sonnet}"

# Gate da árvore: coisa sem commitar entraria no commit da primeira fase.
if [ -n "$(git status --porcelain)" ]; then
  echo "árvore suja: commite, guarde no stash ou apague o que for descartável"
  git status --short
  exit 1
fi
TMP=$(mktemp -d)

# 1. Quebra as fases: um arquivo por "## Phase N: título"; outro "## " encerra a fase.
awk -v d="$TMP" '/^## Phase [0-9]+: /{n++; f=sprintf("%s/fase-%02d.md", d, n); print > f; next}
                 /^## /{f=""} f{print > f}' "$DOC"

for fase in "$TMP"/fase-*.md; do
  num=$(head -1 "$fase" | sed -E 's/^## Phase ([0-9]+):.*/\1/')
  titulo=$(head -1 "$fase" | sed -E 's/^## Phase [0-9]+: //')
  tasks=$(grep -cE '^[[:space:]]*- \[[ xX]\]' "$fase")
  motivo=""
  for ((t = 1; t <= TENTATIVAS; t++)); do
    echo "fase $num, tentativa $t/$TENTATIVAS"
    # 2. Sessão nova, com a fase (e a causa da falha anterior) no prompt.
    prompt="Implemente a fase abaixo. Rode os testes antes de terminar.
$motivo
$(cat "$fase")"
    "$ENGINE" -p "$prompt" --dangerously-skip-permissions < /dev/null > "$TMP/sessao-$num-$t.log" 2>&1
    # 3. Gate do teste: a Prova roda fora da sessão. Vermelho: a causa real vai junto.
    if ! bash -c "$TESTE" > "$TMP/prova.log" 2>&1 < /dev/null; then
      motivo="## Motivo da falha (teste)
$(tail -n 40 "$TMP/prova.log")"
      continue
    fi
    # 4. Gate do avaliador: outra sessão, só leitura (--tools não tira MCP: o deny tira), task por task.
    if [ "$tasks" -gt 0 ]; then
      aval="$TMP/avaliador-$num-$t.log"
      "$ENGINE" -p "RALPH_VERIFY
Você é o avaliador. Não edite nenhum arquivo. Para cada task da fase abaixo,
na ordem, confira o critério de aceite no código e responda uma linha por task:
TASK <n>: DONE   ou   TASK <n>: INCOMPLETE: o que falta. Na dúvida, INCOMPLETE.
Arquivos que a sessão alterou (git status):
$(git status --short)

$(cat "$fase")" --model "$MODELO" --tools "Read,Glob,Grep" --disallowedTools "mcp__*" < /dev/null > "$aval" 2>&1
      feitas=$(grep -cE '^[[:space:]]*TASK [0-9]+: DONE' "$aval")
      if [ "$feitas" -ne "$tasks" ]; then
        motivo="## Motivo da falha (avaliador: $feitas de $tasks tasks prontas)
$(grep -E '^[[:space:]]*TASK [0-9]+: INCOMPLETE' "$aval")"
        continue
      fi
    fi
    # 5. Os dois gates verdes: commit da fase.
    git add -A && { git diff --cached --quiet || git commit -qm "feat(phase-$num): $titulo"; }
    continue 2
  done
  # 6. Esgotou: para e diz onde.
  echo "travou na fase $num"
  exit 1
done
echo "terminou"
