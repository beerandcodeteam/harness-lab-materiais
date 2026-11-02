#!/usr/bin/env bash
# QUEBRADO DE PROPÓSITO · aula 2.4 · "loop infinito"
# Stop hook que manda o agente continuar SEMPRE, sem olhar o stop_hook_active.
# Toda vez que ele tenta encerrar, este hook devolve exit 2, ele volta a trabalhar,
# tenta encerrar de novo... O Claude Code corta depois de 8 continuações seguidas,
# mas até lá você queimou tempo e token. A versão certa é .claude/hooks/prova-no-stop.sh.
echo "Rode os testes mais uma vez antes de encerrar." >&2
exit 2
