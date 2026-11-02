#!/usr/bin/env python3
"""Cria um histórico falso do Claude Code em $HOME/.claude/projects/ para o verificar.sh.

Uso: sessoes-falsas.py <raiz do projeto>

Monta, com horários relativos a agora:
  - uma sessão interativa na raiz do projeto (7 mensagens do aluno, 1 interrupção);
  - uma sessão numa subpasta (app/), que conta como o mesmo projeto;
  - a cópia do mesmo repositório aberta pelo lado Windows do WSL (/mnt/c/...);
  - uma sessão de `claude -p` (entrypoint sdk-cli), que não conta;
  - um projeto vizinho cujo nome termina igual (outro-projeto), que não conta.
"""
import datetime as dt
import json
import os
import re
import sys

raiz = os.path.realpath(sys.argv[1])
base = os.path.join(os.environ["HOME"], ".claude", "projects")
agora = dt.datetime.now(dt.timezone.utc)


def quando(min_atras):
    return (agora - dt.timedelta(minutes=min_atras)).isoformat().replace("+00:00", "Z")


def sessao(cwd, sid, eventos, entrypoint="cli"):
    pasta = os.path.join(base, re.sub(r"[^a-zA-Z0-9]", "-", cwd))
    os.makedirs(pasta, exist_ok=True)
    with open(os.path.join(pasta, f"{sid}.jsonl"), "w", encoding="utf-8") as f:
        for tipo, min_atras, conteudo in eventos:
            e = {"type": tipo, "timestamp": quando(min_atras), "sessionId": sid, "cwd": cwd,
                 "entrypoint": entrypoint}
            if tipo == "user":
                e["message"] = {"role": "user", "content": conteudo}
            else:
                e["message"] = {"role": "assistant", "content": [
                    {"type": "text", "text": "ok"}] + [{"type": "tool_use", "name": "Bash"}] * conteudo}
            f.write(json.dumps(e, ensure_ascii=False) + "\n")


A = "assistant"
sessao(raiz, "s-raiz", [
    ("user", 300, "Cria o endpoint de exportar pedidos em CSV"),
    (A, 299, 3), (A, 290, 5),
    ("user", 289, "deu erro 500 quando eu abro /pedidos/exportar"),
    (A, 288, 2), (A, 285, 1),
    ("user", 284, "continua"),
    (A, 283, 4),
    ("user", 282, "[Request interrupted by user]"),
    ("user", 281, "pode rodar a migration"),
    (A, 280, 2),
    ("user", 279, "lembrando que aqui é Pest, não PHPUnit"),
    (A, 270, 6),
    ("user", 269, "/clear"),
    ("user", 268, [{"type": "tool_result", "content": "saida"}]),
    ("user", 267, "valeu, ficou bom"),
    (A, 266, 0),
])
sessao(os.path.join(raiz, "app"), "s-sub", [
    ("user", 200, "Adiciona filtro por data na exportação"),
    (A, 199, 2), (A, 150, 8),
])
sessao("/mnt/c/Users/aluno/" + os.path.basename(raiz), "s-wsl", [
    ("user", 100, "como estamos?"),
    (A, 99, 1),
])
sessao(raiz, "s-sdk", [("user", 50, "mensagem do loop, não do aluno"), (A, 49, 9)], entrypoint="sdk-cli")
sessao(os.path.join(os.path.dirname(raiz), "outro-" + os.path.basename(raiz)), "s-vizinho", [
    ("user", 40, "isto é de outro projeto"), (A, 39, 1),
])
print(base)
