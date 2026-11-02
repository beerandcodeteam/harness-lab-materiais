#!/usr/bin/env python3
"""Diagnóstico do Operador · Harness Lab.

Mede QUEM fez cada parte do trabalho: você (Operador) ou o trilho (harness).
Só leitura no histórico do Claude Code; escreve apenas em .diagnostico-operador/
e diagnostico-operador.md na raiz do repositório.

Uso:
  medir.py antes   [--dias 30] [--max 300]   # sessões interativas (dia 0)
  medir.py depois  [--logs .phases/logs]     # execução do loop (dia 7)
  medir.py fechar  antes|depois              # junta a classificação feita pelo agente
  medir.py comparar                          # tabela antes x depois
  medir.py listar  testou repetiu [--de antes] # mensagens de um papel (aula 1.3)
  medir.py projetos [--dias 30]              # onde há sessões, se você não está num repo
"""
import argparse
import datetime as dt
import glob
import json
import os
import re
import statistics
import subprocess
import sys

PAPEIS = ["testou", "retomou", "aprovou", "repetiu"]  # toques de operador
CAMADAS = PAPEIS  # nome antigo, mantido por compatibilidade
NEUTRAS = ["pedido", "outro"]
OUT = ".diagnostico-operador"
IGNORAR = re.compile(r"^\s*(<(command-|local-command|bash-|task-notification)|\[Request interrupted|/[\w:-]+\s*$)")
GAP_ATIVO = 15 * 60  # pausas maiores que isso não contam como tempo ativo
GAP_TRECHO = 60 * 60  # agente parado por mais que isso: o trecho autônomo acabou ali (sessão ociosa)


# ---------- util ----------

def ts(s):
    try:
        return dt.datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()
    except Exception:
        return None


def iso(t):
    return dt.datetime.fromtimestamp(t).strftime("%Y-%m-%d %H:%M")


def minutos(seg):
    return round(seg / 60, 1)


def texto(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return " ".join(c.get("text", "") for c in content if isinstance(c, dict) and c.get("type") == "text")
    return ""


def raiz_repo():
    try:
        return subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True,
                                       stderr=subprocess.DEVNULL).strip()
    except Exception:
        return os.getcwd()


def base_projetos():
    return os.path.join(os.environ.get("CLAUDE_CONFIG_DIR", os.path.expanduser("~/.claude")), "projects")


def cwd_da_pasta(d):
    """Diretório em que as sessões desta pasta foram abertas (campo cwd do .jsonl mais novo)."""
    for f in sorted(glob.glob(os.path.join(d, "*.jsonl")), key=os.path.getmtime, reverse=True)[:3]:
        try:
            with open(f, encoding="utf-8", errors="replace") as fh:
                for i, linha in enumerate(fh):
                    if i > 200:
                        break
                    if '"cwd"' not in linha:
                        continue
                    try:
                        c = json.loads(linha).get("cwd")
                    except Exception:
                        continue
                    if c:
                        return c
        except OSError:
            continue
    return None


def pertence(cwd, repo):
    """cwd é o repo, uma subpasta dele ou o mesmo repo aberto pelo outro lado do WSL (/mnt/c/...)."""
    cwd, repo = cwd.rstrip("/"), repo.rstrip("/")
    if cwd == repo or cwd.startswith(repo + "/"):
        return True
    um_lado_mnt = cwd.startswith("/mnt/") != repo.startswith("/mnt/")
    return um_lado_mnt and os.path.basename(cwd) == os.path.basename(repo)


def pastas_sessao(repo):
    chave = re.sub(r"[^a-zA-Z0-9]", "-", repo)
    achadas = []
    for d in sorted(glob.glob(os.path.join(base_projetos(), "*"))):
        if not os.path.isdir(d):
            continue
        c = cwd_da_pasta(d)
        if (c and pertence(c, repo)) or (not c and os.path.basename(d) == chave):
            achadas.append(d)
    return achadas


def commits(repo, ini, fim):
    try:
        out = subprocess.check_output(
            ["git", "-C", repo, "log", "--all", "--oneline", f"--since=@{int(ini)}", f"--until=@{int(fim)}"],
            text=True, stderr=subprocess.DEVNULL)
        return len([l for l in out.splitlines() if l.strip()])
    except Exception:
        return None


def ler_sessoes(pastas, ini=None, fim=None):
    """Devolve {sessao: [eventos]} com eventos (t, tipo, extra). tipo: H (humano), A (agente), X (interrupção)."""
    sessoes, vistos = {}, set()
    for p in pastas:
        for f in glob.glob(os.path.join(p, "*.jsonl")):
            if ini and os.path.getmtime(f) < ini:
                continue
            for linha in open(f, encoding="utf-8", errors="replace"):
                try:
                    e = json.loads(linha)
                except Exception:
                    continue
                t = ts(e.get("timestamp", "")) if e.get("timestamp") else None
                if t is None or (ini and t < ini) or (fim and t > fim):
                    continue
                if e.get("entrypoint") == "sdk-cli":  # claude -p / loop: não é você digitando
                    continue
                sid = e.get("sessionId") or os.path.basename(f)
                ev = sessoes.setdefault(sid, [])
                if e.get("type") == "assistant":
                    tools = [c for c in (e.get("message", {}).get("content") or [])
                             if isinstance(c, dict) and c.get("type") == "tool_use"]
                    ev.append((t, "A", len(tools)))
                elif e.get("type") == "user" and not e.get("isMeta") and not e.get("isCompactSummary"):
                    tx = texto(e.get("message", {}).get("content"))
                    if not tx.strip():
                        continue  # retorno de ferramenta
                    if "[Request interrupted" in tx:
                        ev.append((t, "X", None))
                        continue
                    if IGNORAR.match(tx):
                        continue
                    k = (e.get("timestamp"), tx[:200])
                    if k in vistos:  # /compact e resume regravam mensagens antigas
                        continue
                    vistos.add(k)
                    ev.append((t, "H", tx))
    for ev in sessoes.values():
        ev.sort(key=lambda x: x[0])
    return {k: v for k, v in sessoes.items() if any(x[1] == "H" for x in v)}


def trechos_autonomos(sessoes):
    """Para cada mensagem sua: quanto tempo o agente trabalhou até precisar de você de novo."""
    trechos, tools_por_toque = [], []
    for ev in sessoes.values():
        idx = [i for i, x in enumerate(ev) if x[1] == "H"]
        for j, i in enumerate(idx):
            prox = idx[j + 1] if j + 1 < len(idx) else len(ev)
            ag, ult = [], ev[i][0]
            for x in ev[i + 1:prox]:
                if x[0] - ult > GAP_TRECHO:
                    break  # horas sem evento: sessão aberta e parada, não é trabalho do agente
                ult = x[0]
                if x[1] == "A":
                    ag.append(x)
            if ag:
                trechos.append(ag[-1][0] - ev[i][0])
                tools_por_toque.append(sum(x[2] for x in ag))
    return trechos, tools_por_toque


def tempo_ativo(sessoes):
    total = 0
    for ev in sessoes.values():
        for a, b in zip(ev, ev[1:]):
            g = b[0] - a[0]
            if g < GAP_ATIVO:
                total += g
    return total


def salvar_mensagens(nome, sessoes, maximo):
    msgs = sorted((x[0], x[2]) for ev in sessoes.values() for x in ev if x[1] == "H")
    total = len(msgs)
    amostra = msgs[-maximo:] if maximo and total > maximo else msgs
    os.makedirs(OUT, exist_ok=True)
    with open(f"{OUT}/{nome}-mensagens.jsonl", "w", encoding="utf-8") as f:
        for i, (t, tx) in enumerate(amostra):
            f.write(json.dumps({"id": i, "quando": iso(t), "texto": re.sub(r"\s+", " ", tx)[:400]},
                               ensure_ascii=False) + "\n")
    return total, len(amostra)


def gravar(nome, dados):
    os.makedirs(OUT, exist_ok=True)
    with open(f"{OUT}/{nome}.json", "w", encoding="utf-8") as f:
        json.dump(dados, f, ensure_ascii=False, indent=2)


def carregar(nome):
    p = f"{OUT}/{nome}.json"
    if not os.path.exists(p):
        sys.exit(f"Falta {p}. Rode primeiro: medir.py {nome}")
    return json.load(open(p, encoding="utf-8"))


# ---------- modos ----------

def interativa(f):
    """Falso para sessões de claude -p e de scripts (entrypoint sdk-cli)."""
    try:
        with open(f, encoding="utf-8", errors="replace") as fh:
            for i, linha in enumerate(fh):
                if i > 50:
                    break
                if '"entrypoint"' in linha:
                    try:
                        return json.loads(linha).get("entrypoint") != "sdk-cli"
                    except Exception:
                        continue
    except OSError:
        return False
    return True


def cmd_projetos(a):
    """Lista onde você abriu o Claude Code nos últimos N dias, do mais usado para o menos usado."""
    corte = dt.datetime.now().timestamp() - a.dias * 86400
    lin = []
    for d in glob.glob(os.path.join(base_projetos(), "*")):
        fs = [f for f in glob.glob(os.path.join(d, "*.jsonl"))
              if os.path.getmtime(f) >= corte and interativa(f)]
        if not fs:
            continue
        c = cwd_da_pasta(d) or os.path.basename(d)
        lin.append((len(fs), max(map(os.path.getmtime, fs)), c))
    if not lin:
        sys.exit(f"Nenhuma sessão do Claude Code nos últimos {a.dias} dias em {base_projetos()}.")
    print(f"{'sessões':>7}  {'último uso':16}  pasta")
    for n, t, c in sorted(lin, reverse=True)[:a.max]:
        print(f"{n:>7}  {iso(t):16}  {c}")
    print("\nEscolha uma pasta e rode: medir.py --repo <pasta> antes")


def cmd_antes(a):
    repo = a.repo
    pastas = pastas_sessao(repo)
    if not pastas:
        sys.exit(f"Nenhuma sessão do Claude Code aberta em {repo} (nem em subpastas) "
                 "em ~/.claude/projects/. Veja onde há sessões com: medir.py projetos")
    fim = dt.datetime.now().timestamp()
    ini = fim - a.dias * 86400
    sessoes = ler_sessoes(pastas, ini, fim)
    trechos, tools = trechos_autonomos(sessoes)
    total, amostra = salvar_mensagens("antes", sessoes, a.max)
    todas = [x[0] for ev in sessoes.values() for x in ev]
    dados = {
        "modo": "antes", "repo": repo, "medido_em": iso(fim), "dias": a.dias,
        "janela": [iso(min(todas)), iso(max(todas))] if todas else None,
        "pastas_sessao": pastas, "sessoes": len(sessoes),
        "mensagens_suas": total, "mensagens_classificadas": amostra,
        "interrupcoes": sum(1 for ev in sessoes.values() for x in ev if x[1] == "X"),
        "tempo_ativo_min": minutos(tempo_ativo(sessoes)),
        "maior_trecho_autonomo_min": minutos(max(trechos)) if trechos else 0,
        "trecho_autonomo_mediano_min": minutos(statistics.median(trechos)) if trechos else 0,
        "acoes_do_agente_por_toque": round(statistics.mean(tools), 1) if tools else 0,
        "entregas_commits": a.entregas if a.entregas is not None else commits(repo, ini, fim),
    }
    gravar("antes", dados)
    imprimir(dados)
    print(f"\nPróximo passo: classificar {amostra} mensagens em {OUT}/antes-mensagens.jsonl "
          f"e gravar {OUT}/antes-classes.jsonl; depois `medir.py fechar antes`.")


def cmd_depois(a):
    repo = a.repo
    a.logs = os.path.join(repo, a.logs)
    logs = glob.glob(os.path.join(a.logs, "*.log"))
    if not logs:
        sys.exit(f"Nenhum log de loop em {a.logs}/. O loop já rodou neste repositório?")
    execucoes, ini, fim = [], None, None
    for f in logs:
        mt = os.path.getmtime(f)
        res = None
        for linha in open(f, encoding="utf-8", errors="replace"):
            if '"type":"result"' in linha:
                try:
                    res = json.loads(linha)
                except Exception:
                    pass
        dur = (res or {}).get("duration_ms", 0) / 1000
        comeco = mt - dur
        ini = comeco if ini is None else min(ini, comeco)
        fim = mt if fim is None else max(fim, mt)
        if res:
            execucoes.append({"arquivo": os.path.basename(f), "turnos": res.get("num_turns", 0),
                              "seg": dur, "custo": res.get("total_cost_usd") or 0})
    ini, fim = (ts(a.desde) or ini), (ts(a.ate) or fim)
    rl = os.path.join(a.logs, "ralph.log")
    txt = re.sub(r"\x1b\[[0-9;]*m", "", open(rl, encoding="utf-8", errors="replace").read()) if os.path.exists(rl) else ""
    fases_log = len(re.findall(r"COMPLETA", txt))
    fases_arq = len({m.group(1) for f in logs if (m := re.match(r"phase-(\d+)", os.path.basename(f)))})
    gates_vermelhos = len(re.findall(r"vermelho", txt, re.I))
    if not txt:  # ralph.sh antigo sem ralph.log: verificações reprovadas
        gates_vermelhos = sum(1 for f in logs if re.search(r"verify", f) and
                              re.search(r"FAIL|INCOMPLET|vermelho", open(f, errors="replace").read(), re.I))
    ciclos = len(re.findall(r"Ciclo de corre", txt, re.I)) or max(
        0, len([e for e in execucoes if "cycle" in e["arquivo"]]) - fases_arq)

    pastas = pastas_sessao(repo)
    sessoes = ler_sessoes(pastas, ini, fim) if pastas else {}
    humanas = sorted(x[0] for ev in sessoes.values() for x in ev if x[1] == "H")
    marcos = [ini] + humanas + [fim]
    gaps = [b - a_ for a_, b in zip(marcos, marcos[1:])]
    total, amostra = salvar_mensagens("depois", sessoes, 300)
    dados = {
        "modo": "depois", "repo": repo, "medido_em": iso(dt.datetime.now().timestamp()),
        "janela": [iso(ini), iso(fim)], "logs": a.logs, "pastas_sessao": pastas,
        "fases_entregues": fases_log or fases_arq,
        "execucoes_do_agente": len(execucoes),
        "turnos_do_agente": sum(e["turnos"] for e in execucoes),
        "tempo_do_loop_min": minutos(fim - ini),
        "tempo_agente_trabalhando_min": minutos(sum(e["seg"] for e in execucoes)),
        "custo_usd": round(sum(e["custo"] for e in execucoes), 2),
        "gates_vermelhos": gates_vermelhos,
        "ciclos_de_correcao": ciclos,
        "mensagens_suas": total, "mensagens_classificadas": amostra,
        "maior_trecho_autonomo_min": minutos(max(gaps)),
        "trecho_autonomo_mediano_min": minutos(statistics.median(gaps)),
        "entregas_commits": a.entregas if a.entregas is not None else commits(repo, ini, fim),
    }
    gravar("depois", dados)
    imprimir(dados)
    if amostra:
        print(f"\nPróximo passo: classificar {amostra} mensagens em {OUT}/depois-mensagens.jsonl "
              f"e gravar {OUT}/depois-classes.jsonl; depois `medir.py fechar depois`.")
    else:
        print("\nNenhuma mensagem sua durante o loop. Rode `medir.py fechar depois`.")


def cmd_fechar(a):
    dados = carregar(a.qual)
    contagem = {c: 0 for c in CAMADAS + NEUTRAS}
    exemplos = {c: [] for c in CAMADAS}
    msgs = {}
    p_msgs = f"{OUT}/{a.qual}-mensagens.jsonl"
    if os.path.exists(p_msgs):
        msgs = {m["id"]: m["texto"] for m in map(json.loads, open(p_msgs, encoding="utf-8"))}
    p = f"{OUT}/{a.qual}-classes.jsonl"
    if dados["mensagens_classificadas"]:
        if not os.path.exists(p):
            sys.exit(f"Falta {p} (uma linha por mensagem: {{\"id\": 0, \"papel\": \"testou\"}}).")
        for linha in open(p, encoding="utf-8"):
            if not linha.strip():
                continue
            c = json.loads(linha)
            cam = c.get("papel") or c.get("camada") or "outro"
            cam = cam if cam in contagem else "outro"
            contagem[cam] += 1
            if cam in exemplos and len(exemplos[cam]) < 3 and c.get("id") in msgs:
                exemplos[cam].append(msgs[c["id"]][:90])
    fator = dados["mensagens_suas"] / dados["mensagens_classificadas"] if dados["mensagens_classificadas"] else 1
    dados["papeis"] = contagem
    dados["toques_de_operador"] = round(sum(contagem[c] for c in CAMADAS) * fator)
    ent = dados.get("entregas_commits")
    dados["toques_por_entrega"] = round(dados["toques_de_operador"] / ent, 1) if ent else None
    dados["exemplos"] = exemplos
    gravar(a.qual, dados)
    escrever_md(dados)
    imprimir(dados)


def cmd_listar(a):
    p_msgs, p_cls = f"{OUT}/{a.de}-mensagens.jsonl", f"{OUT}/{a.de}-classes.jsonl"
    if not (os.path.exists(p_msgs) and os.path.exists(p_cls)):
        sys.exit(f"Falta {p_msgs} ou {p_cls}. Rode /diagnostico-operador {a.de} primeiro.")
    msgs = {m["id"]: m for m in map(json.loads, open(p_msgs, encoding="utf-8"))}
    for linha in open(p_cls, encoding="utf-8"):
        if not linha.strip():
            continue
        c = json.loads(linha)
        pap = c.get("papel") or c.get("camada")
        if pap in a.papeis and c.get("id") in msgs:
            m = msgs[c["id"]]
            print(f"{m['quando']}  [{pap}]  {m['texto'][:160]}")


def cmd_comparar(_):
    A, D = carregar("antes"), carregar("depois")

    def v(d, k, suf=""):
        x = d.get(k)
        return "-" if x is None else f"{x}{suf}"

    def cam(d, c):
        return d.get("papeis", {}).get(c, "-")

    linhas = [
        ("Toques de operador por entrega", v(A, "toques_por_entrega"), v(D, "toques_por_entrega")),
        ("Trecho autônomo típico (mediana)", v(A, "trecho_autonomo_mediano_min", " min"),
         v(D, "trecho_autonomo_mediano_min", " min")),
        ("Maior trecho autônomo", v(A, "maior_trecho_autonomo_min", " min"), v(D, "maior_trecho_autonomo_min", " min")),
        ("Quem testou e achou o erro: você", cam(A, "testou"), cam(D, "testou")),
        ("Quem testou e achou o erro: o gate", "0", v(D, "gates_vermelhos")),
        ("Quem retomou: você", cam(A, "retomou"), cam(D, "retomou")),
        ("Quem retomou: o loop (fases encadeadas)", "0", v(D, "fases_entregues")),
        ("Aprovações suas", cam(A, "aprovou"), cam(D, "aprovou")),
        ("Contexto repetido por você", cam(A, "repetiu"), cam(D, "repetiu")),
        ("Entregas (commits na janela)", v(A, "entregas_commits"), v(D, "entregas_commits")),
    ]
    tab = ["| Métrica | Antes (Operador) | Depois (harness) |", "|---|---|---|"]
    tab += [f"| {a} | {b} | {c} |" for a, b, c in linhas]
    md = "\n".join(tab)
    print(md)
    with open("diagnostico-operador.md", "a", encoding="utf-8") as f:
        f.write(f"\n## Antes x depois (medido em {iso(dt.datetime.now().timestamp())})\n\n{md}\n")


# ---------- saída ----------

def imprimir(d):
    pular = {"exemplos", "pastas_sessao", "repo"}
    for k, x in d.items():
        if k not in pular:
            print(f"{k:32} {x}")
    if d.get("pastas_sessao"):
        print("pastas de sessão lidas:")
        for p in d["pastas_sessao"]:
            print("  ", p)


def escrever_md(d):
    c = d.get("papeis", {})
    tit = "Antes · Operador (sessões interativas)" if d["modo"] == "antes" else "Depois · harness (execução do loop)"
    l = [f"\n## {tit} · medido em {d['medido_em']}", ""]
    if d["modo"] == "antes":
        l += [f"- Janela: {d['janela'][0]} a {d['janela'][1]} ({d['sessoes']} sessões, {d['tempo_ativo_min']} min ativos)" if d.get("janela") else "- Janela: vazia"]
    else:
        l += [f"- Janela do loop: {d['janela'][0]} a {d['janela'][1]} · {d['fases_entregues']} fases · "
              f"{d['tempo_do_loop_min']} min · US$ {d['custo_usd']}",
              f"- Gates vermelhos: {d['gates_vermelhos']} · ciclos de correção: {d['ciclos_de_correcao']}"]
    l += [f"- Mensagens suas: {d['mensagens_suas']} · toques de operador: {d['toques_de_operador']}"
          f" · entregas: {d.get('entregas_commits')} · toques por entrega: {d.get('toques_por_entrega')}",
          f"- Trecho autônomo típico: {d.get('trecho_autonomo_mediano_min')} min · maior: {d['maior_trecho_autonomo_min']} min",
          f"- Você testou e avisou: {c.get('testou', 0)} · retomou ou cobrou status: {c.get('retomou', 0)}"
          f" · aprovou: {c.get('aprovou', 0)} · repetiu contexto: {c.get('repetiu', 0)}",
          f"- Pedidos de trabalho novo: {c.get('pedido', 0)} · outros: {c.get('outro', 0)}"]
    for cam, ex in d.get("exemplos", {}).items():
        for e in ex:
            l.append(f"  - {cam}: \"{e}\"")
    with open("diagnostico-operador.md", "a", encoding="utf-8") as f:
        f.write("\n".join(l) + "\n")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--repo", help="raiz do repositório medido (padrão: git root do diretório atual)")
    p.add_argument("--saida", help="onde gravar .diagnostico-operador/ e o .md (padrão: raiz do repositório)")
    s = p.add_subparsers(dest="modo", required=True)
    x = s.add_parser("antes")
    x.add_argument("--dias", type=int, default=30)
    x.add_argument("--max", type=int, default=300, help="máximo de mensagens para classificar (as mais recentes)")
    x.add_argument("--entregas", type=int, help="nº de entregas na janela, se o repo não usa git")
    x.set_defaults(f=cmd_antes)
    x = s.add_parser("depois")
    x.add_argument("--logs", default=".phases/logs")
    x.add_argument("--desde", help="início da janela (ISO), se não quiser usar a dos logs")
    x.add_argument("--ate", help="fim da janela (ISO)")
    x.add_argument("--entregas", type=int, help="nº de entregas, se não quiser contar commits")
    x.set_defaults(f=cmd_depois)
    x = s.add_parser("fechar")
    x.add_argument("qual", choices=["antes", "depois"])
    x.set_defaults(f=cmd_fechar)
    s.add_parser("comparar").set_defaults(f=cmd_comparar)
    x = s.add_parser("projetos")
    x.add_argument("--dias", type=int, default=30)
    x.add_argument("--max", type=int, default=15)
    x.set_defaults(f=cmd_projetos)
    x = s.add_parser("listar")
    x.add_argument("papeis", nargs="+", choices=PAPEIS + ["pedido", "outro"])
    x.add_argument("--de", choices=["antes", "depois"], default="antes")
    x.set_defaults(f=cmd_listar)
    a = p.parse_args()
    a.repo = os.path.abspath(a.repo) if a.repo else raiz_repo()
    os.makedirs(a.saida or a.repo, exist_ok=True)
    os.chdir(a.saida or a.repo)
    a.f(a)


if __name__ == "__main__":
    main()
