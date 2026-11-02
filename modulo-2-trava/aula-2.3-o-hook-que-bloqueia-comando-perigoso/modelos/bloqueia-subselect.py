#!/usr/bin/env python3
"""
bloqueia-subselect.py · Harness Lab · aula 2.3 · modelo (não é instalado)

O caso do cliente contado no fim da aula: query escrita na mão, e o agente
insistia em subselect, que pesava no banco. A regra estava escrita, e mesmo
assim um subselect escapava de vez em quando. Com hook, não escapa.

PreToolUse com matcher "Edit|Write": olha o texto NOVO que o modelo quer
gravar (new_string no Edit, content no Write) e nega se achar um SELECT
dentro de parênteses, em arquivo de código ou .sql.

Para ligar, no .claude/settings.json, dentro de "PreToolUse":
  {
    "matcher": "Edit|Write",
    "hooks": [{ "type": "command",
                "command": "python3 \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/bloqueia-subselect.py",
                "timeout": 10 }]
  }

Testar sem abrir o Claude Code:
  python3 bloqueia-subselect.py --eval 'WHERE id IN (SELECT user_id FROM pedidos)'
"""
import json
import re
import sys

EXTENSOES = (".php", ".sql", ".js", ".ts", ".py", ".rb", ".go", ".java", ".cs")
# "(" seguido de SELECT: subquery em IN (...), EXISTS (...), FROM (...) ou coluna calculada.
SUBSELECT = re.compile(r"\(\s*select\b", re.I)

MOTIVO = (
    "Bloqueado pelo harness: o projeto não usa subselect em query escrita na mão "
    "(pesa no banco). Reescreva com JOIN, ou com duas queries no código. "
    "Se o subselect for mesmo necessário, explique ao humano e peça para ele escrever."
)


def tem_subselect(texto):
    return bool(SUBSELECT.search(texto or ""))


def main():
    if len(sys.argv) >= 3 and sys.argv[1] == "--eval":
        print("bloqueia" if tem_subselect(sys.argv[2]) else "libera")
        return 0
    try:
        entrada = json.load(sys.stdin)
    except Exception:
        return 0
    dados = entrada.get("tool_input") or {}
    arquivo = dados.get("file_path") or ""
    if not arquivo.lower().endswith(EXTENSOES):
        return 0
    novo = dados.get("new_string") or dados.get("content") or ""
    if tem_subselect(novo):
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": MOTIVO,
        }}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
