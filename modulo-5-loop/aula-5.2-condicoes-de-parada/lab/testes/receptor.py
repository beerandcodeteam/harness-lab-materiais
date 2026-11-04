#!/usr/bin/env python3
"""receptor.py · testes da aula 5.3 · um "Telegram/Slack/n8n" local, sem rede externa.

Uso: python3 -I receptor.py <arquivo-da-porta> <arquivo-de-saída>
Escuta em 127.0.0.1 numa porta livre, escreve a porta em <arquivo-da-porta> e
grava cada POST como uma linha JSON em <arquivo-de-saída>: caminho, tipo e corpo.
Responde 200 com {"ok": true}. Para com SIGTERM.
"""
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

porta_arq, saida_arq = sys.argv[1], sys.argv[2]


class Receptor(BaseHTTPRequestHandler):
    def do_POST(self):
        tamanho = int(self.headers.get("Content-Length") or 0)
        corpo = self.rfile.read(tamanho).decode("utf-8")
        with open(saida_arq, "a", encoding="utf-8") as saida:
            saida.write(json.dumps({"caminho": self.path,
                                    "tipo": self.headers.get("Content-Type", ""),
                                    "corpo": corpo}, ensure_ascii=False) + "\n")
        resposta = b'{"ok": true}'
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(resposta)))
        self.end_headers()
        self.wfile.write(resposta)

    def log_message(self, *args):
        pass


servidor = HTTPServer(("127.0.0.1", 0), Receptor)
with open(porta_arq, "w") as arq:
    arq.write(str(servidor.server_address[1]))
servidor.serve_forever()
