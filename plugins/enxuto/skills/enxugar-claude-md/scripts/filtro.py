#!/usr/bin/env python3
"""filtro.py · Harness Lab, aula 3.1 · mede os arquivos de instrução e marca linhas suspeitas.

Uso:
  filtro.py [raiz do projeto] [--json]

O que faz (só lê, não altera nada):
  1. acha os arquivos que o Claude Code carrega como instrução: CLAUDE.md, .claude/CLAUDE.md,
     CLAUDE.local.md, AGENTS.md, CLAUDE.md de subpasta, .claude/rules/*.md e os @imports;
  2. conta as linhas que vão para o contexto (comentário HTML de bloco não conta: o Claude Code
     tira antes de mandar para o modelo);
  3. marca as linhas que parecem falso padrão da aula 3.1. A marca é suspeita, não sentença:
     a decisão é sempre a pergunta "o agente descobriria isso lendo o código?".

Só biblioteca padrão do Python 3.8+.
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

LIMITE_LINHAS = 200  # meta da doc oficial (página Memory): "target under 200 lines per CLAUDE.md file"
IGNORAR = {".git", "node_modules", "vendor", ".venv", "venv", "dist", "build", ".next",
           "storage", "target", "__pycache__", ".claude/worktrees"}

# categoria -> (para onde vai, regex). Ordem = prioridade (uma marca por linha).
REGRAS = [
    ("enfase", "ênfase em maiúscula: se ele erra mesmo assim, a linha é hook (Módulo 2)",
     re.compile(r"\b(IMPORTANTE|IMPORTANT|CRÍTICO|CRITICO|CRITICAL|OBRIGATÓRIO|OBRIGATORIO|"
                r"NUNCA|SEMPRE|JAMAIS|NEVER|ALWAYS|MUST)\b|!!")),
    ("sem-excecao", "regra sem exceção: hook, deny em permissions ou managed setting",
     re.compile(r"\b(nunca|jamais|proibido|never|do not ever)\b.{0,40}\b(rode|rodar|execute|"
                r"executar|use|usar|apague|apagar|commit|push|run|delete|drop|fresh|force)\b",
                re.I)),
    ("historia", "história de erro: reescreva como regra + jeito + porquê, numa linha",
     re.compile(r"\b(ontem|semana passada|mês passado|já deu problema|já aconteceu|deu ruim|"
                r"o agente quebrou|quebrou o|cuidado com|last time|yesterday)\b|"
                r"\b\d{1,2}/\d{1,2}(/\d{2,4})?\b|\bdia \d{1,2}\b", re.I)),
    ("generico", "conselho genérico: o modelo já tenta; escreva a prática específica ou corte",
     re.compile(r"(boas práticas|best practices|código limpo|clean code|\bSOLID\b|\bDRY\b|\bKISS\b|"
                r"código legível|readable code|bem organizado|well[- ]organized|seja cuidadoso|"
                r"be careful|escreva testes|write tests|siga os padrões|follow (the )?conventions)",
                re.I)),
    ("estilo", "estilo que o linter cobra: deixe para o hook de lint (aula 2.2)",
     re.compile(r"(\d+ espaços|\d+[- ]space|indenta|indent|aspas (simples|duplas)|"
                r"(single|double) quotes|ponto e vírgula|semicolon|PSR-?12|trailing comma|"
                r"vírgula no final|tamanho máximo de linha|max line length|camelCase|snake_case)",
                re.I)),
    ("framework", "aula do framework: ele já sabe; escreva só onde o projeto foge do padrão",
     re.compile(r"(\bMVC\b|app/Models|app/Http/Controllers|resources/views|src/components|"
                r"src/pages|app/controllers|app/models|routes/web\.php|"
                r"(o|the) (laravel|rails|django|next(\.js)?|react) (usa|uses|é|is)\b)", re.I)),
    ("arvore", "mapa de pastas: ele roda ls e grep; o mapa envelhece na primeira refatoração",
     re.compile(r"[├└│]──|^\s*[│├└]")),
]
IMPORT = re.compile(r"(?<![\w`])@((?:\.{0,2}/|~/)?[\w.\-/]+\.\w+|~/[\w.\-/]+)")


def git_ignorado(raiz, caminho):
    try:
        r = subprocess.run(["git", "-C", str(raiz), "check-ignore", "-q", str(caminho)],
                           capture_output=True, timeout=10)
        return r.returncode == 0
    except (OSError, subprocess.SubprocessError):
        return None


def junta_arvore(marcas):
    """Linhas seguidas de mapa de pastas viram uma marca só."""
    out = []
    for m in marcas:
        ant = out[-1] if out else None
        if (ant and m["categoria"] == "arvore" and ant["categoria"] == "arvore"
                and m["linha"] - ant.get("ate", ant["linha"]) <= 2):
            ant["ate"] = m["linha"]
            continue
        out.append(dict(m))
    for m in out:
        if "ate" in m:
            m["texto"] = f"mapa de pastas, linhas {m['linha']} a {m['ate']}"
    return out


def relativo(arq, raiz):
    try:
        return str(arq.relative_to(raiz))
    except ValueError:
        return str(arq)


def linhas_do_contexto(texto):
    """Devolve [(nº da linha, texto)] do que vai para o contexto.

    Comentário HTML de bloco (fora de bloco de código) sai; dentro de ``` fica."""
    out, em_codigo, em_comentario = [], False, False
    for n, l in enumerate(texto.splitlines(), 1):
        s = l.strip()
        if not em_comentario and s.startswith("```"):
            em_codigo = not em_codigo
            out.append((n, l, True))
            continue
        if em_codigo:
            out.append((n, l, True))
            continue
        if em_comentario:
            if "-->" in s:
                em_comentario = False
            continue
        if s.startswith("<!--"):
            if "-->" not in s:
                em_comentario = True
            continue
        out.append((n, l, False))
    return out


def analisa(arq, raiz):
    texto = arq.read_text(encoding="utf-8", errors="replace")
    ctx = linhas_do_contexto(texto)
    total = len(texto.splitlines())
    marcas, imports = [], []
    lista_numerada, inicio_lista = 0, 0
    for n, l, codigo in ctx:
        s = l.strip()
        if re.match(r"^\d+[.)]\s", s):
            if lista_numerada == 0:
                inicio_lista = n
            lista_numerada += 1
        elif s:
            if lista_numerada >= 8:
                marcas.append({"linha": inicio_lista, "categoria": "procedimento",
                               "destino": f"procedimento de {lista_numerada} passos: vira skill (aula 3.3)",
                               "texto": f"lista numerada de {lista_numerada} itens"})
            lista_numerada = 0
        if not s or re.match(r"^#{1,6}\s", s):
            continue
        if codigo:
            if re.search(r"[├└│]──", s):
                marcas.append({"linha": n, "categoria": "arvore", "destino": REGRAS[-1][1],
                               "texto": s[:100]})
            continue
        sem_code = re.sub(r"`[^`]*`", "", s)
        for m in IMPORT.finditer(sem_code):
            imports.append(m.group(1))
        for cat, destino, rx in REGRAS:
            if rx.search(sem_code if cat != "arvore" else s):
                marcas.append({"linha": n, "categoria": cat, "destino": destino, "texto": s[:100]})
                break
    if lista_numerada >= 8:
        marcas.append({"linha": inicio_lista, "categoria": "procedimento",
                       "destino": f"procedimento de {lista_numerada} passos: vira skill (aula 3.3)",
                       "texto": f"lista numerada de {lista_numerada} itens"})
    marcas.sort(key=lambda m: m["linha"])
    marcas = junta_arvore(marcas)
    return {
        "arquivo": relativo(arq, raiz),
        "linhas": total,
        "linhas_no_contexto": len(ctx),
        "caracteres": len(texto),
        "imports": imports,
        "marcas": marcas,
    }


def acha_arquivos(raiz):
    achados, avisos = [], []
    raiz_md = [p for p in (raiz / "CLAUDE.md", raiz / ".claude" / "CLAUDE.md") if p.is_file()]
    local = raiz / "CLAUDE.local.md"
    agents = raiz / "AGENTS.md"
    for p in raiz_md:
        achados.append((p, "raiz: carrega em toda sessão"))
    if local.is_file():
        achados.append((local, "pessoal: carrega em toda sessão, só para você"))
        if git_ignorado(raiz, local) is False:
            avisos.append("CLAUDE.local.md não está no .gitignore: é pessoal, não deveria ir para o repositório.")
    if agents.is_file():
        if raiz_md or local.is_file():
            avisos.append("AGENTS.md existe, mas com CLAUDE.md (ou CLAUDE.local.md) o Claude Code não lê o "
                          "AGENTS.md por padrão. Importe com @AGENTS.md se ele tem algo que vale.")
        else:
            achados.append((agents, "raiz: lido no lugar do CLAUDE.md (não há CLAUDE.md)"))
    if not raiz_md and not agents.is_file():
        avisos.append("Nenhum CLAUDE.md na raiz.")
    for dirpath, dirnames, filenames in os.walk(raiz):
        rel = Path(dirpath).relative_to(raiz)
        dirnames[:] = [d for d in dirnames
                       if d not in IGNORAR and str(rel / d) not in IGNORAR]
        if rel == Path("."):
            continue
        if rel.parts[0] == ".claude":
            continue
        for nome in ("CLAUDE.md", "CLAUDE.local.md"):
            if nome in filenames:
                achados.append((Path(dirpath) / nome, "subpasta: carrega quando ele mexe em arquivo dali"))
    regras = raiz / ".claude" / "rules"
    if regras.is_dir():
        for p in sorted(regras.rglob("*.md")):
            cab = p.read_text(encoding="utf-8", errors="replace")[:600]
            com_paths = re.match(r"---\s*\n(.*?\n)?---", cab, re.S) and re.search(r"^paths\s*:", cab, re.M)
            achados.append((p, "rule com paths: sob demanda" if com_paths else "rule sem paths: toda sessão"))
    return achados, avisos


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    raiz = Path(args[0] if args else ".").resolve()
    if not raiz.is_dir():
        print(f"pasta não encontrada: {raiz}", file=sys.stderr)
        sys.exit(2)
    achados, avisos = acha_arquivos(raiz)
    rel = []
    vistos = set()
    fila = list(achados)
    while fila:
        p, quando = fila.pop(0)
        p = p.resolve()
        if p in vistos or not p.is_file():
            continue
        vistos.add(p)
        r = analisa(p, raiz)
        r["quando_carrega"] = quando
        rel.append(r)
        for imp in r["imports"]:
            alvo = Path(os.path.expanduser(imp)) if imp.startswith("~") else (p.parent / imp)
            if alvo.is_file():
                fila.append((alvo, f"import de {r['arquivo']}: carrega junto, não economiza"))
            else:
                avisos.append(f"{r['arquivo']} importa @{imp}, que não existe.")
    sempre = [r for r in rel if "toda sessão" in r["quando_carrega"] or r["quando_carrega"].startswith(("raiz", "import"))]
    resumo = {
        "raiz": str(raiz),
        "linhas_no_contexto_toda_sessao": sum(r["linhas_no_contexto"] for r in sempre),
        "arquivos": rel,
        "avisos": avisos + [f"{r['arquivo']}: {r['linhas_no_contexto']} linhas no contexto (meta da doc: menos de {LIMITE_LINHAS})."
                            for r in rel if r["linhas_no_contexto"] >= LIMITE_LINHAS],
        "total_marcas": sum(len(r["marcas"]) for r in rel),
    }
    if "--json" in sys.argv:
        print(json.dumps(resumo, ensure_ascii=False, indent=1))
        return
    print(f"Arquivos de instrução em {raiz}\n")
    for r in rel:
        extra = "" if r["linhas"] == r["linhas_no_contexto"] else f" ({r['linhas']} no arquivo; comentário HTML não conta)"
        print(f"  {r['arquivo']}: {r['linhas_no_contexto']} linhas{extra} · {r['quando_carrega']}")
    print(f"\nEm toda sessão: {resumo['linhas_no_contexto_toda_sessao']} linhas.")
    for a in resumo["avisos"]:
        print(f"aviso: {a}")
    for r in rel:
        if not r["marcas"]:
            continue
        print(f"\n{r['arquivo']} · {len(r['marcas'])} linha(s) suspeita(s)")
        for m in r["marcas"]:
            print(f"  {m['linha']:>4}  [{m['categoria']}] {m['texto']}")
            print(f"        -> {m['destino']}")
    print(f"\n{resumo['total_marcas']} linha(s) marcada(s). Marca é suspeita: passe cada linha no filtro "
          "\"o agente descobriria isso lendo o código?\".")


if __name__ == "__main__":
    main()
