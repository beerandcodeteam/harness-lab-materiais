#!/usr/bin/env python3
"""Confere as skills de uma pasta: frontmatter, nome, descrição e o tamanho da lista.

Uso: python3 confere.py [pasta ...]        padrão: .claude/skills

Cada pasta pode ser uma pasta de skills (.claude/skills) ou a pasta de uma skill só.
Só lê arquivos. Só biblioteca padrão do Python 3.

ERRO  = o Claude Code vai carregar diferente do que você escreveu
AVISO = carrega, mas atrapalha a escolha do modelo
DICA  = melhora a chance de a skill disparar

YAML quebrado este script não pega: rode também claude plugin validate .claude/skills

Sai com 1 se achar algum ERRO.
Regras: code.claude.com/docs/en/skills e o guia de boas práticas de skills da Anthropic
(platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices).
"""
import re
import sys
from pathlib import Path

CORTE_LISTA = 1536   # description + when_to_use, por skill, na lista do Claude Code
LIMITE_SPEC = 1024   # description no padrão Agent Skills (claude.ai, API)
MAX_LINHAS = 500
LEQUE_BOM = 10       # a aula: "4, 5, no máximo 10"

CAMPOS = {
    "name", "description", "when_to_use", "argument-hint", "arguments",
    "disable-model-invocation", "user-invocable", "allowed-tools", "disallowed-tools",
    "model", "effort", "context", "agent", "background", "hooks", "paths", "shell",
    "metadata", "license", "compatibility",
}
PARECIDOS = {
    "when-to-use": "when_to_use", "whentouse": "when_to_use", "when_to_invoke": "when_to_use",
    "disable_model_invocation": "disable-model-invocation",
    "user_invocable": "user-invocable", "user-invokable": "user-invocable",
    "allowed_tools": "allowed-tools", "tools": "allowed-tools",
    "disallowed_tools": "disallowed-tools", "argument_hint": "argument-hint",
    "path": "paths", "globs": "paths",
}
VERDADE = {"true", "yes", "on", "1"}
PRIMEIRA_PESSOA = re.compile(
    r"\b(eu posso|posso te|posso ajudar|você pode usar|voce pode usar|i can|you can use)\b", re.I)
TEM_QUANDO = re.compile(
    r"\b(use quando|usar quando|quando|sempre que|pedido|ao (criar|editar|escrever|mexer)|"
    r"use when|when the user|when working|triggers?)\b", re.I)
PALAVRA = re.compile(r"[a-záéíóúâêôãõç0-9]{4,}", re.I)
BOM = "\ufeff"


def tamanho(desc, quando):
    """Caracteres que contam para o corte: description + espaço + when_to_use."""
    return len(desc) + (len(quando) + 1 if quando else 0)


def le_frontmatter(texto):
    """Devolve (campos, erro). Parser simples: chave: valor, aspas, | e >, listas."""
    linhas = texto.split("\n")
    if linhas[0].strip() != "---":
        return None, "o --- de abertura não está na primeira linha"
    try:
        fim = next(i for i in range(1, len(linhas)) if linhas[i].strip() == "---")
    except StopIteration:
        return None, "falta o --- que fecha o frontmatter"
    campos, chave, bloco = {}, None, []

    def fecha():
        if chave is not None:
            campos[chave] = " ".join(x.strip() for x in bloco if x.strip()).strip()

    for ln in linhas[1:fim]:
        m = re.match(r"^([A-Za-z_][\w-]*)\s*:(.*)$", ln)
        if m and not ln.startswith((" ", "\t")):
            fecha()
            chave, valor = m.group(1), m.group(2).strip()
            if valor in ("|", ">", "|-", ">-", "|+", ">+"):
                valor = ""
            if len(valor) >= 2 and valor[0] == valor[-1] and valor[0] in "\"'":
                valor = valor[1:-1]
            bloco = [valor]
        elif chave is not None:
            bloco.append(ln.strip().lstrip("- ").strip())
    fecha()
    return campos, None


def confere_skill(skill_md, msgs):
    nome_pasta = skill_md.parent.name
    texto = skill_md.read_text(encoding="utf-8", errors="replace").removeprefix(BOM)
    campos, erro = le_frontmatter(texto)
    if erro:
        msgs.append(("ERRO", nome_pasta, f"{erro}: o arquivo inteiro vira conteúdo, sem nome nem descrição."))
        return None
    nome = campos.get("name", nome_pasta)
    desc = campos.get("description", "")
    quando = campos.get("when_to_use", "")
    manual = campos.get("disable-model-invocation", "").lower() in VERDADE

    for k in campos:
        if k not in CAMPOS:
            certo = PARECIDOS.get(k.lower())
            extra = f" Você quis dizer {certo}?" if certo else ""
            msgs.append(("ERRO", nome, f"campo '{k}' não existe e é ignorado sem aviso.{extra}"))

    if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", nome) or len(nome) > 64:
        msgs.append(("AVISO", nome, "nome fora do padrão: só minúsculas, números e hífen, até 64 caracteres."))
    if re.search(r"claude|anthropic", nome):
        msgs.append(("AVISO", nome, "nome com 'claude' ou 'anthropic': palavra reservada no padrão Agent Skills."))

    if not desc:
        msgs.append(("ERRO", nome, "sem description: o modelo vê só a primeira linha do corpo para decidir."))
    elif not manual:   # com disable-model-invocation a descrição nem entra no contexto do modelo
        total = tamanho(desc, quando)
        if total > CORTE_LISTA:
            msgs.append(("ERRO", nome, f"description + when_to_use com {total} caracteres: a lista corta em "
                                       f"{CORTE_LISTA}. O fim some. Ponha o uso principal primeiro."))
        if len(desc) > LIMITE_SPEC:
            msgs.append(("AVISO", nome, f"description com {len(desc)} caracteres: passa de {LIMITE_SPEC}, "
                                        "o limite para subir a skill no claude.ai ou na API."))
        if len(desc) < 60 and not quando:
            msgs.append(("AVISO", nome, f"description curta ({len(desc)} caracteres) e sem when_to_use: "
                                        "diz o tema, não diz quando usar."))
        if PRIMEIRA_PESSOA.search(desc):
            msgs.append(("DICA", nome, "escreva na terceira pessoa (\"Cria...\", não \"Eu posso...\")."))
        if not quando and not TEM_QUANDO.search(desc):
            msgs.append(("DICA", nome, "falta o quando: um when_to_use com as palavras do pedido."))
        if "<" in desc + quando or ">" in desc + quando:
            msgs.append(("DICA", nome, "< e > aparecem como &lt; e &gt; na lista. Use [colchetes]."))

    linhas = texto.count("\n") + 1
    if linhas > MAX_LINHAS:
        msgs.append(("AVISO", nome, f"SKILL.md com {linhas} linhas: a doc pede menos de {MAX_LINHAS}. "
                                    "Mande o detalhe para arquivos ao lado."))
    return {"nome": nome, "desc": desc, "quando": quando, "manual": manual}


def acha(pasta):
    p = Path(pasta)
    if (p / "SKILL.md").is_file():
        return [p / "SKILL.md"]
    return sorted(x for x in p.glob("*/SKILL.md") if x.is_file())


def main():
    pastas = sys.argv[1:] or [".claude/skills"]
    if any(a in ("-h", "--help") for a in pastas):
        print(__doc__)
        return 0
    arquivos = []
    for pasta in pastas:
        if not Path(pasta).is_dir():
            print(f"confere: pasta não existe: {pasta}", file=sys.stderr)
            return 2
        arquivos += acha(pasta)
    if not arquivos:
        print(f"confere: nenhum */SKILL.md em {', '.join(pastas)}")
        return 0

    msgs, skills = [], []
    for a in arquivos:
        s = confere_skill(a, msgs)
        if s:
            skills.append(s)

    na_lista = [s for s in skills if not s["manual"]]
    for i, a in enumerate(na_lista):
        pa = set(PALAVRA.findall((a["desc"] + " " + a["quando"]).lower()))
        for b in na_lista[i + 1:]:
            pb = set(PALAVRA.findall((b["desc"] + " " + b["quando"]).lower()))
            if pa and pb and len(pa & pb) / len(pa | pb) >= 0.5:
                msgs.append(("AVISO", f"{a['nome']} e {b['nome']}",
                             "descrições muito parecidas: o modelo escolhe no chute. Junte numa."))

    for s in skills:
        if s["manual"]:
            print(f"  -     {s['nome']}: disable-model-invocation, fora da lista do modelo")
        else:
            t = tamanho(s["desc"], s["quando"])
            print(f"  lista {s['nome']}: {t} caracteres de description + when_to_use")
    chars = sum(tamanho(s["desc"], s["quando"]) for s in na_lista)
    print(f"{len(skills)} skill(s), {len(na_lista)} na lista do modelo, ~{chars} caracteres de descrição.")
    if len(na_lista) > LEQUE_BOM:
        msgs.append(("AVISO", "leque", f"{len(na_lista)} skills disputando a escolha do modelo. "
                                       "A aula sugere de 4 a 10. Veja /skill-doctor."))
    ordem = {"ERRO": 0, "AVISO": 1, "DICA": 2}
    for nivel, quem, texto in sorted(msgs, key=lambda m: ordem[m[0]]):
        print(f"{nivel:<5} {quem}: {texto}")
    erros = sum(1 for m in msgs if m[0] == "ERRO")
    print("confere: ok" if not erros else f"confere: {erros} erro(s)")
    return 1 if erros else 0


if __name__ == "__main__":
    sys.exit(main())
