#!/usr/bin/env python3
"""schema_estrito.py · aula 4.2 · teste de contrato do schema que sai para o provedor.

No structured output em modo strict, a OpenAI exige que toda chave de
"properties" esteja em "required", em todo nível. Campo nullable continua
obrigatório: ele pode vir null, mas não pode faltar no "required".

Este script lê um JSON Schema (arquivo ou stdin), percorre todos os objetos,
inclusive os que estão dentro de "items" de array e de "anyOf", e lista o
caminho de cada chave que ficou fora do "required".

Uso:
  python3 -I schema_estrito.py schema.json
  php artisan tinker --execute '...' | python3 -I schema_estrito.py -

Aceita o schema puro ou o corpo da requisição inteiro: se achar
text.format.schema (Responses API) ou response_format.json_schema.schema
(Chat Completions), confere o schema que está lá dentro.

Saída: exit 0 se está tudo em "required"; exit 1 com a lista se não está;
exit 2 se a entrada não é JSON. Só biblioteca padrão.
"""
import json
import sys


def extrai_schema(doc):
    """Aceita schema puro ou o corpo da requisição para a OpenAI."""
    if isinstance(doc, dict):
        fmt = (doc.get("text") or {}).get("format") if isinstance(doc.get("text"), dict) else None
        if isinstance(fmt, dict) and isinstance(fmt.get("schema"), dict):
            return fmt["schema"]
        rf = doc.get("response_format")
        if isinstance(rf, dict) and isinstance(rf.get("json_schema"), dict):
            return rf["json_schema"].get("schema", rf["json_schema"])
    return doc


def fora_do_required(no, caminho=""):
    """Devolve a lista de caminhos (ex.: product.name) fora do required."""
    achados = []
    if not isinstance(no, dict):
        return achados

    props = no.get("properties")
    if isinstance(props, dict):
        required = set(no.get("required") or [])
        for chave, filho in props.items():
            atual = f"{caminho}.{chave}" if caminho else chave
            if chave not in required:
                achados.append(atual)
            achados += fora_do_required(filho, atual)

    itens = no.get("items")
    if isinstance(itens, dict):
        achados += fora_do_required(itens, f"{caminho}[]" if caminho else "[]")

    for ramo in no.get("anyOf") or []:
        achados += fora_do_required(ramo, caminho)

    return achados


def main(argv):
    origem = argv[1] if len(argv) > 1 else "-"
    try:
        texto = sys.stdin.read() if origem == "-" else open(origem, encoding="utf-8").read()
        doc = json.loads(texto)
    except (OSError, json.JSONDecodeError) as erro:
        print(f"schema_estrito: não consegui ler o JSON de {origem}: {erro}", file=sys.stderr)
        return 2

    achados = fora_do_required(extrai_schema(doc))
    if achados:
        print(f"{len(achados)} campo(s) fora do required (a OpenAI recusa em modo strict):")
        for caminho in achados:
            print(f"  {caminho} fora do required")
        return 1

    print("ok: toda chave de properties está no required, em todo nível")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
