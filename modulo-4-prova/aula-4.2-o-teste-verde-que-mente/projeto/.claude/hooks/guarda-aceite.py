#!/usr/bin/env python3
"""guarda-aceite.py · aula 4.2 · hook PreToolUse (matcher: Edit|Write|MultiEdit)

O agente não reescreve o juiz. Os testes de aceite listados em
.claude/aceite.txt só aceitam uma edição: tirar o marcador de pendente
(Pest ->todo(), Jest/Vitest .skip, linha @pytest.mark.skip). Qualquer outra
mudança nesses arquivos, e Write sobre um arquivo que já existe, volta com
exit 2 e o motivo para o modelo. É o mesmo contrato do hook que bloqueia da
aula 2.3; muda só o alvo.

.claude/aceite.txt: um caminho por linha, relativo à raiz do projeto. Aceita
curinga (tests/Feature/Cadastro*Test.php). Linha com # é comentário.

Limite: a regra casa com a chamada de ferramenta, não com a intenção. Um
script rodado pelo Bash que abre o arquivo passa por fora deste hook.
"""
import fnmatch
import json
import os
import re
import sys

# Marcadores de pendente que o agente pode tirar.
MARCADORES = [
    (re.compile(r"\s*->\s*todo\((?:[^()]|\([^()]*\))*\)"), ""),                   # Pest: ->todo() e ->todo('motivo')
    (re.compile(r"\b(test|it|describe)\.skip(?=\s*\()"), r"\1"),                  # Jest/Vitest: test.skip( -> test(
    (re.compile(r"(?m)^[ \t]*@pytest\.mark\.skip\b(?:\([^\n]*\))?[ \t]*(?:\r?\n|$)"), ""),  # pytest: a linha do decorator
]


def tira_marcadores(texto):
    for marcador, troca in MARCADORES:
        texto = marcador.sub(troca, texto)
    return texto


def normaliza(texto):
    return "\n".join(linha.rstrip() for linha in texto.strip().splitlines())


def so_tirou_marcador(antes, depois):
    """True se 'depois' é 'antes' sem os marcadores de pendente, e algum marcador saiu."""
    sem_marcador = tira_marcadores(antes)
    return sem_marcador != antes and normaliza(sem_marcador) == normaliza(depois)


def protegidos(raiz):
    lista = os.path.join(raiz, ".claude", "aceite.txt")
    try:
        with open(lista, encoding="utf-8") as arq:
            return [l.strip() for l in arq if l.strip() and not l.strip().startswith("#")]
    except OSError:
        return []


def bloqueia(motivo):
    print(motivo, file=sys.stderr)
    sys.exit(2)


def main():
    try:
        entrada = json.load(sys.stdin)
    except json.JSONDecodeError:
        bloqueia("guarda-aceite: entrada do hook não é JSON; bloqueando por segurança.")

    ferramenta = entrada.get("tool_name", "")
    dados = entrada.get("tool_input") or {}
    caminho = dados.get("file_path") or ""
    if ferramenta not in ("Edit", "Write", "MultiEdit") or not caminho:
        sys.exit(0)

    raiz = os.environ.get("CLAUDE_PROJECT_DIR") or entrada.get("cwd") or os.getcwd()
    absoluto = caminho if os.path.isabs(caminho) else os.path.join(raiz, caminho)
    relativo = os.path.relpath(os.path.normpath(absoluto), os.path.normpath(raiz))

    if not any(fnmatch.fnmatch(relativo, padrao) for padrao in protegidos(raiz)):
        sys.exit(0)

    regra = (f"{relativo} é teste de aceite (.claude/aceite.txt). A única edição permitida é tirar o "
             "marcador de pendente (->todo(), .skip, @pytest.mark.skip). Se o teste está errado, "
             "pare e explique o motivo; não mude o teste para bater com o código.")

    if ferramenta == "Write":
        if os.path.exists(absoluto):
            bloqueia(f"Bloqueado: Write sobrescreve {relativo} inteiro. {regra}")
        sys.exit(0)  # criar o arquivo pela primeira vez é permitido

    edicoes = dados.get("edits") if ferramenta == "MultiEdit" else [dados]
    for edicao in edicoes or []:
        if not so_tirou_marcador(edicao.get("old_string", ""), edicao.get("new_string", "")):
            bloqueia(f"Bloqueado: essa edição muda o teste, não só o marcador. {regra}")

    sys.exit(0)


if __name__ == "__main__":
    main()
