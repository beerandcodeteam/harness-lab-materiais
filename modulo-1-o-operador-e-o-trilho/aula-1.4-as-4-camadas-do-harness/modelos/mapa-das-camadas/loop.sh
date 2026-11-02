#!/usr/bin/env bash
# loop.sh · Loop · esboço da aula 1.4. Você monta o seu, linha a linha, no Módulo 5.
#
#   ./loop.sh tarefas.md
#
# Para cada linha "- [ ]" da lista: abre uma sessão nova (claude -p), deixa a Prova
# decidir (o comando de teste), faz commit e marca [x]. Até 3 tentativas por tarefa.
# Não deu: avisa que travou e para. Acabou a lista: avisa que terminou.
#
# Troque a Prova pela da sua stack: TESTE="npm test" ./loop.sh tarefas.md
set -uo pipefail

lista="${1:-tarefas.md}"
TESTE="${TESTE:-./vendor/bin/pest}"
TENTATIVAS="${TENTATIVAS:-3}"
[ -f "$lista" ] || { echo "loop: não achei $lista" >&2; exit 2; }

proxima() { grep -m1 '^- \[ \] ' "$lista" | sed 's/^- \[ \] //'; }

marcar_feita() {   # troca "- [ ]" por "- [x]" só na primeira linha igual à tarefa
  awk -v t="- [ ] $1" '!f && $0 == t { sub(/^- \[ \]/, "- [x]"); f = 1 } { print }' \
    "$lista" > "$lista.tmp" && mv "$lista.tmp" "$lista"
}

avisar() {
  echo "loop: $1"
  command -v notify-send >/dev/null 2>&1 && notify-send "loop" "$1" 2>/dev/null
  return 0
}

while tarefa=$(proxima) && [ -n "$tarefa" ]; do
  feito=0
  for tentativa in $(seq 1 "$TENTATIVAS"); do
    echo "loop: tarefa \"$tarefa\", tentativa $tentativa de $TENTATIVAS"
    # Sessão nova: a pilha da tarefa 2 não carrega nada da tarefa 1.
    # Sem --permission-mode, o claude -p nega toda edição que pediria aprovação.
    # Sem --bare: o --bare pula CLAUDE.md e hooks, e o loop rodaria sem Regra e sem Trava.
    claude -p "Implemente só esta tarefa: $tarefa. Siga o CLAUDE.md. Não faça commit." \
      --permission-mode acceptEdits --allowedTools "Bash($TESTE *)"

    if $TESTE; then                       # a Prova decide, não o modelo
      marcar_feita "$tarefa"
      git add -A && git commit -qm "$tarefa"
      feito=1
      break
    fi
  done
  [ "$feito" = 1 ] || { avisar "travou em: $tarefa"; exit 1; }
done
avisar "terminou"
