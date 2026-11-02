#!/usr/bin/env bash
# contexto-inicio.sh · aula 2.1 · SessionStart
# O que este script imprime no stdout entra na pilha do modelo antes do primeiro pedido.
# Escreva fatos, não ordens.
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
echo "Branch atual: $(git branch --show-current)."
echo "Últimos commits:"
git log --oneline -3 2>/dev/null | sed 's/^/  /'
if [ -f tarefas.md ]; then
  pendentes=$(grep -c '^- \[ \]' tarefas.md || true)
  proxima=$(grep -m1 '^- \[ \]' tarefas.md | sed 's/^- \[ \] //')
  echo "tarefas.md tem $pendentes tarefa(s) pendente(s). Próxima: $proxima"
fi
exit 0
