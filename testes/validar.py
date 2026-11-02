#!/usr/bin/env python3
"""Executa, numa sandbox, os comandos que o material manda o aluno copiar.

Uso:
  python3 validar.py <material.html | comandos.json> --repo <árvore do harness-lab-materiais> [--manter]
  python3 validar.py <material.html> --repo <repo> --exportar   (grava <repo>/<modulo>/<aula>/teste/comandos.json)

Como funciona:
  - HOME falso em /tmp: nada toca o seu ~/.claude, o seu git nem os seus plugins.
  - O repositório (a árvore de trabalho, sem precisar de commit) vira um "GitHub" local:
    git clone https://github.com/beerandcodeteam/harness-lab-materiais e
    claude plugin marketplace add beerandcodeteam/harness-lab-materiais
    caem nessa cópia por url.insteadOf.
  - Pasta de teste da aula: <repo>/<modulo>/<aula>/teste/ (para .html) ou a pasta do comandos.json.
  - ~/projeto é o "repositório do aluno": cópia de teste/projeto/ se existir,
    senão uma pasta vazia. Vira repositório git com um commit.
  - Blocos executados na ordem do documento, o estado (arquivos) passa de um para o outro:
      shell, claude-cli  → bash -euo pipefail, em ~ (data-onde="home") ou ~/projeto (data-onde="projeto")
      sessao             → não executa; cada linha precisa ser um /comando que existe
                           (lista oficial + skills dos plugins do repositório + skills do projeto)
                           ou um pedido em texto começando com "> "
      stack              → não executa (precisa do projeto real do aluno); exige data-fonte
    data-teste="pula" num bloco shell/claude-cli: não executa, mas exige data-motivo e aparece no relatório.
  - No fim, se existir <pasta do material>/teste/verificar.sh, roda em ~/projeto com o mesmo HOME.
Sai com código 1 se algum bloco falhar.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

KIT = Path(__file__).resolve().parent
sys.path.insert(0, str(KIT))
import cmds  # noqa: E402

URL = "github.com/beerandcodeteam/harness-lab-materiais"


def sh(args, **kw):
    return subprocess.run(args, capture_output=True, text=True, **kw)


def main():
    if len(sys.argv) < 2 or "--repo" not in sys.argv:
        print(__doc__)
        sys.exit(2)
    mat = Path(sys.argv[1]).resolve()
    repo = Path(sys.argv[sys.argv.index("--repo") + 1]).resolve()
    manter = "--manter" in sys.argv
    if mat.suffix == ".json":
        bls = json.loads(mat.read_text(encoding="utf-8"))["blocos"]
        tdir = mat.parent
    else:
        texto = mat.read_text(encoding="utf-8")
        bls = cmds.blocos(texto)
        for b, a in zip(bls, re.findall(r'<div class="cmd"[^>]*>', texto)):
            b["motivo"] = dict(re.findall(r'data-([a-z-]+)="([^"]*)"', a)).get("motivo", "")
        aula = mat.parent.parent
        tdir = repo / aula.parent.name / aula.name / "teste"
        if "--exportar" in sys.argv:
            tdir.mkdir(parents=True, exist_ok=True)
            (tdir / "comandos.json").write_text(json.dumps(
                {"material": mat.name, "gerado_por": "_materiais/kit/validar.py --exportar", "blocos": bls},
                ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
            print(tdir / "comandos.json")
            sys.exit(0)
    motivos = [b.get("motivo", "") for b in bls]

    sbx = Path(tempfile.mkdtemp(prefix="hl-sbx-"))
    home, remoto = sbx / "home", sbx / "remoto"
    home.mkdir()
    shutil.copytree(repo, remoto, ignore=shutil.ignore_patterns(".git", "__pycache__", "*.pyc"))
    g = ["git", "-c", "user.email=sandbox@harness.lab", "-c", "user.name=sandbox"]
    sh(["git", "init", "-q", "-b", "main"], cwd=remoto)
    sh(["git", "add", "-A"], cwd=remoto)
    sh(g + ["commit", "-qm", "snapshot"], cwd=remoto)
    alvo = f"file://{remoto}"
    (home / ".gitconfig").write_text(
        "[user]\n\tname = Aluno\n\temail = aluno@harness.lab\n[init]\n\tdefaultBranch = main\n"
        f'[url "{alvo}"]\n'
        + "".join(f"\tinsteadOf = {p}\n" for p in (
            f"https://{URL}.git", f"https://{URL}", f"git@github.com:{URL.split('/', 1)[1]}.git",
            f"git@github.com:{URL.split('/', 1)[1]}", f"ssh://git@{URL}.git")),
        encoding="utf-8")

    proj = home / "projeto"
    fixture = tdir / "projeto"
    if fixture.is_dir():
        shutil.copytree(fixture, proj)
    else:
        proj.mkdir()
    env = {k: v for k, v in os.environ.items() if not k.startswith(("CLAUDE", "ANTHROPIC"))}
    env.update(HOME=str(home), TERM="dumb", GIT_TERMINAL_PROMPT="0", NO_COLOR="1")
    if not (proj / ".git").exists():
        sh(["git", "init", "-q"], cwd=proj, env=env)
        sh(["git", "add", "-A"], cwd=proj, env=env)
        sh(["git", "commit", "-qm", "inicio", "--allow-empty"], cwd=proj, env=env)

    permitidos = set((KIT / "comandos-sessao.txt").read_text().split())
    for sk in remoto.glob("plugins/*/skills/*/SKILL.md"):
        plugin, nome = sk.parts[-4], sk.parts[-2]
        permitidos |= {f"/{nome}", f"/{plugin}:{nome}"}
    for cmdf in remoto.glob("plugins/*/commands/*.md"):
        permitidos |= {f"/{cmdf.stem}", f"/{cmdf.parts[-3]}:{cmdf.stem}"}

    rel, falhou = [], False
    for i, b in enumerate(bls, 1):
        tag = f"#{i} {b['tipo']}"
        linhas = [l for l in b["linhas"] if l.strip()]
        if b["tipo"] in ("shell", "claude-cli"):
            if b.get("teste") == "pula":
                ok = bool(motivos[i - 1])
                rel.append({"bloco": tag, "status": "pulado", "motivo": motivos[i - 1] or "SEM data-motivo"})
                falhou |= not ok
                continue
            cwd = home if b["onde"] == "home" else proj
            script = "set -euo pipefail\n" + "\n".join(linhas) + "\n"
            try:
                r = subprocess.run(["bash", "--noprofile", "--norc", "-c", script], cwd=cwd, env=env,
                                   capture_output=True, text=True, timeout=300)
                ok, saida = r.returncode == 0, (r.stdout + r.stderr)[-1500:]
            except subprocess.TimeoutExpired:
                ok, saida = False, "timeout de 300 s"
            rel.append({"bloco": tag, "status": "ok" if ok else "FALHOU", "linhas": linhas,
                        **({} if ok else {"saida": saida})})
            falhou |= not ok
        elif b["tipo"] == "sessao":
            # skills do projeto que os blocos anteriores instalaram
            for sk in proj.glob(".claude/skills/*/SKILL.md"):
                permitidos.add(f"/{sk.parts[-2]}")
            ruins = []
            for l in linhas:
                s = l.strip()
                if s.startswith("#") or s.startswith("> "):
                    continue
                tok = s.split()[0]
                if not tok.startswith("/") or tok not in permitidos:
                    ruins.append(s)
            rel.append({"bloco": tag, "status": "ok" if not ruins else "FALHOU", "linhas": linhas,
                        **({"desconhecidos": ruins} if ruins else {})})
            falhou |= bool(ruins)
        elif b["tipo"] == "stack":
            rel.append({"bloco": tag, "status": "nao-executado", "fonte": b["fonte"], "linhas": linhas})
        else:
            rel.append({"bloco": tag, "status": "FALHOU", "erro": "data-tipo inválido"})
            falhou = True

    verif = tdir / "verificar.sh"
    if verif.exists():
        r = subprocess.run(["bash", str(verif)], cwd=proj, env=env, capture_output=True, text=True, timeout=600)
        ok = r.returncode == 0
        rel.append({"bloco": "teste/verificar.sh", "status": "ok" if ok else "FALHOU",
                    "saida": (r.stdout + r.stderr)[-2500:]})
        falhou |= not ok

    for x in rel:
        print(f"[{x['status']:>13}] {x['bloco']}", "" if x["status"] == "ok" else json.dumps(
            {k: v for k, v in x.items() if k not in ("bloco", "status")}, ensure_ascii=False)[:1800])
    print(("FALHOU" if falhou else "ok") + f" · sandbox: {sbx}")
    if not falhou and not manter:
        shutil.rmtree(sbx, ignore_errors=True)
    sys.exit(1 if falhou else 0)


if __name__ == "__main__":
    main()
