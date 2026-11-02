#!/usr/bin/env bash
# QUEBRADO DE PROPÓSITO · aula 2.4 · "hook que trava a sessão"
# PostToolUse que roda a suíte INTEIRA a cada edição. Aqui simulado com sleep.
# Hook síncrono segura a sessão até terminar, e o timeout padrão de um command hook é 600 s.
# Correções: rodar só o teste do arquivo (lint-e-teste.sh), pôr "timeout" no settings,
# ou rodar em segundo plano com "async": true quando o resultado pode chegar depois.
cat > /dev/null
sleep 45
exit 0
