#!/usr/bin/env python3
"""
guard-jev.py · Harness Lab · aula 2.3 · PreToolUse (matcher: Bash)

O guard semântico da aula: pergunta ao Jev (modelo de decisão da TypeSafe) se o comando
é potencialmente destrutivo. Complementa o guard-destructive.py: as regras pegam o que
você previu, o Jev pega o que você não previu (a "vírgula escrita diferente").

Uma request por comando, com 4 Nouls (sim ou não, como probabilidade) e 1 Score
(severidade), respondidos em paralelo pelo Jev. A política fica aqui no código:
  deny  -> algum Noul >= DENY_NOUL ou severidade >= DENY_SEVERITY
  ask   -> algum Noul >= ASK_NOUL (o Claude Code pergunta para você)
  allow -> o resto (o fluxo normal de permissão segue)
Na calibração da aula, a severidade sozinha deu falso "ask" em comando comum
(migrate, git commit), então ela só reforça o deny.

Falha ABERTO de propósito: sem TYPESAFE_API_KEY, sem rede ou com timeout, o comando
segue só com o guard de regras. Por isso este hook NÃO leva "onFailure": "block".
Comandos claramente só de leitura (ls, cat, grep, git status/log/diff...) nem chamam o Jev.
Cada decisão vai para $TMPDIR/claude-jev-guard.jsonl, para você calibrar os limites.

Chave: TYPESAFE_API_KEY no "env" do ~/.claude/settings.json (nunca no settings do projeto).
Testar um comando:  python3 .claude/hooks/guard-jev.py --eval 'rm -rf storage'
"""

import importlib.util
import json
import os
import subprocess
import sys
import time
import urllib.request

API_URL = os.environ.get("JEV_GUARD_URL", "https://api.typesafe.ai/v1/systemone")
MODEL = os.environ.get("JEV_GUARD_MODEL", "jev-latest")
TIMEOUT_SECONDS = float(os.environ.get("JEV_GUARD_TIMEOUT", "8"))
PROJECT_DIR = os.path.realpath(os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd())
LOG_FILE = os.path.join(os.environ.get("TMPDIR", "/tmp"), "claude-jev-guard.jsonl")

DENY_NOUL = 0.85
ASK_NOUL = 0.6
DENY_SEVERITY = 2.6

# Descreva o SEU ambiente: o Jev julga melhor com contexto. Mantenha em inglês, como as perguntas.
ENVIRONMENT = os.environ.get("JEV_GUARD_AMBIENTE") or (
    "Local development machine for a web application. Dependencies, the local database and "
    "tests may run directly or inside Docker containers. The local database holds development "
    "data that took effort to build; tests run against a separate throwaway testing database. "
    "Production is a remote server reached over SSH and deployed by a script; it has its own "
    "database and cloud storage. Files listed in `uncommitted_files` exist only on this machine "
    "and cannot be restored from git."
)

QUESTIONS = {
    "deletes_unrecoverable_files": {
        "type": "noul",
        "instructions": (
            "Would running `command` delete, overwrite, empty, or move away files or directories "
            "that cannot be restored from git or easily regenerated?"
        ),
        "criteria": {
            "true": (
                "It removes or overwrites untracked or modified files (see `uncommitted_files`), "
                "secrets like .env, files outside the project, or user data."
            ),
            "false": (
                "It deletes nothing, or only files committed to git, dependency folders "
                "(vendor, node_modules), build output, caches, logs, or temporary files."
            ),
        },
    },
    "destroys_database_data": {
        "type": "noul",
        "instructions": (
            "Would running `command` drop, wipe, truncate, reset, roll back, or mass-delete data "
            "in the local development database or any other database?"
        ),
        "criteria": {
            "true": "It drops or empties tables or databases, rolls back migrations, or deletes many rows.",
            "false": "It only reads data, runs tests on the testing database, or applies new migrations forward.",
        },
    },
    "discards_git_work": {
        "type": "noul",
        "instructions": (
            "Would running `command` discard uncommitted git changes, delete branches or stashes, "
            "or rewrite or force-push git history?"
        ),
        "criteria": {
            "true": "It throws away work or history that git cannot easily bring back.",
            "false": "It inspects the repository, or adds commits, branches, or pushes without force.",
        },
    },
    "touches_production": {
        "type": "noul",
        "instructions": (
            "Does `command` access or change production: connect to a remote server, run the "
            "deploy, touch the production database or app directory, change shared cloud "
            "storage, or send a write request to the production website?"
        ),
        "criteria": {
            "true": "It reaches a remote or production system, or modifies shared production data.",
            "false": "It runs only against this local machine and its Docker containers, or only reads public pages.",
        },
    },
    "damage_severity": {
        "type": "score",
        "instructions": "What is the worst realistic outcome of running `command` in this environment?",
        "criteria": [
            "Harmless: it only reads, lists, searches, prints, or runs tests and builds.",
            "Easily undone: it changes local files or containers in ways git or a rebuild restores.",
            "Local loss: it can destroy uncommitted work, local secrets, or the local development database.",
            "Production or permanent loss: it affects production or shared remote data, or destroys data permanently.",
        ],
    },
}

READ_ONLY_COMMANDS = {
    "ls", "cat", "head", "tail", "less", "grep", "rg", "wc", "echo", "printf", "pwd", "which",
    "type", "jq", "file", "stat", "du", "df", "tree", "diff", "date", "whoami", "env", "uname",
    "sort", "uniq", "cut", "tr", "basename", "dirname", "realpath", "readlink", "true", "test",
}
READ_ONLY_GIT = {"status", "log", "diff", "show", "ls-files", "rev-parse", "blame", "remote", "describe", "shortlog"}
READ_ONLY_ARTISAN = {"test", "route:list", "about", "config:show", "list", "help", "model:show", "db:show", "db:table", "schedule:list"}


def load_rule_guard():
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "guard-destructive.py")
    spec = importlib.util.spec_from_file_location("guard_destructive", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def is_obviously_read_only(command):
    """True only when every segment is a known read-only command without redirects."""
    rules = load_rule_guard()
    if "$(" in command or "`" in command or "<<" in command:
        return False
    tokens = rules.tokenize(command)
    if any(t in (">", ">>", ">|", "&>") for t in tokens):
        return False
    for seg in rules.split_segments(tokens):
        args = rules.strip_wrappers(seg)
        if not args:
            continue
        cmd = os.path.basename(args[0])
        if cmd == "git":
            rest = [a for a in args[1:] if not a.startswith("-")]
            if not rest or rest[0] not in READ_ONLY_GIT:
                return False
        elif "artisan" in [os.path.basename(a) for a in args]:
            idx = [os.path.basename(a) for a in args].index("artisan")
            sub = next((a for a in args[idx + 1 :] if not a.startswith("-")), "")
            if sub not in READ_ONLY_ARTISAN:
                return False
        elif cmd == "find":
            if any(a in ("-delete", "-exec", "-execdir", "-ok") for a in args):
                return False
        elif cmd not in READ_ONLY_COMMANDS:
            return False
    return True


def uncommitted_files(limit=40):
    try:
        out = subprocess.run(
            ["git", "-C", PROJECT_DIR, "status", "--porcelain", "--ignored=matching", "--untracked-files=normal"],
            capture_output=True, text=True, timeout=5,
        )
        lines = [line for line in out.stdout.splitlines() if line.strip()]
        lines = [line for line in lines if not line.startswith("!! ") or line[3:].rstrip("/") in (".env", "auth.json", "secrets")]
        return lines[:limit]
    except Exception:
        return []


def ask_jev(command, cwd):
    api_key = os.environ.get("TYPESAFE_API_KEY")
    if not api_key:
        raise RuntimeError("TYPESAFE_API_KEY ausente")
    body = {
        "model": MODEL,
        "state": {
            "command": command,
            "working_directory": cwd,
            "environment": ENVIRONMENT,
            "uncommitted_files": uncommitted_files(),
        },
        "questions": QUESTIONS,
    }
    request = urllib.request.Request(
        API_URL,
        data=json.dumps(body).encode(),
        headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
        return json.load(response)


def decide(answers):
    nouls = {k: v["noul"] for k, v in answers.items() if v.get("type") == "noul"}
    severity = answers.get("damage_severity", {}).get("score", 0.0)
    top_name, top_value = max(nouls.items(), key=lambda kv: kv[1]) if nouls else ("", 0.0)
    summary = ", ".join(f"{k}={v:.2f}" for k, v in sorted(nouls.items(), key=lambda kv: -kv[1]))
    summary += f", severity={severity:.2f}/3"
    if top_value >= DENY_NOUL or severity >= DENY_SEVERITY:
        return "deny", summary
    if top_value >= ASK_NOUL:
        return "ask", summary
    return "allow", summary


def log(entry):
    try:
        with open(LOG_FILE, "a") as fh:
            fh.write(json.dumps(entry, ensure_ascii=False) + "\n")
    except Exception:
        pass


def emit(decision, reason):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": decision,
            "permissionDecisionReason": reason,
        }
    }, ensure_ascii=False))


def main():
    if len(sys.argv) >= 3 and sys.argv[1] == "--eval":
        command = sys.argv[2]
        read_only = is_obviously_read_only(command)
        if read_only:
            print(json.dumps({"command": command, "skipped": "read-only"}))
            return 0
        started = time.monotonic()
        try:
            response = ask_jev(command, PROJECT_DIR)
            decision, summary = decide(response["answers"])
        except Exception as exc:
            print(json.dumps({"command": command, "erro": repr(exc)}, ensure_ascii=False))
            return 1
        print(json.dumps({"command": command, "decision": decision, "summary": summary,
                          "ms": round((time.monotonic() - started) * 1000)}, ensure_ascii=False))
        return 0

    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0
    if not isinstance(payload, dict) or payload.get("tool_name") not in (None, "Bash"):
        return 0
    command = (payload.get("tool_input") or {}).get("command") or ""
    cwd = payload.get("cwd") or PROJECT_DIR
    if not command.strip() or is_obviously_read_only(command):
        return 0
    if not os.environ.get("TYPESAFE_API_KEY"):
        return 0  # sem chave, sem Jev: o guard de regras continua valendo

    started = time.monotonic()
    try:
        response = ask_jev(command, cwd)
        decision, summary = decide(response["answers"])
    except Exception as exc:  # falha aberto: rede, timeout, chave inválida, resposta estranha
        log({"ts": time.time(), "command": command, "error": repr(exc)})
        print(json.dumps({"systemMessage": f"guard-jev indisponível ({exc.__class__.__name__}); comando seguiu só com o guard de regras."}))
        return 0

    log({"ts": time.time(), "command": command, "decision": decision, "summary": summary,
         "model": response.get("model"), "ms": round((time.monotonic() - started) * 1000)})

    if decision == "deny":
        emit("deny", (
            f"BLOQUEADO pelo guard-jev (o Jev julgou o comando potencialmente destrutivo: {summary}).\n"
            "Não tente contornar. Explique ao humano o que você quer fazer e por quê. "
            "Se ele concordar, ele mesmo roda o comando."
        ))
    elif decision == "ask":
        emit("ask", f"guard-jev: comando possivelmente destrutivo ({summary}). Confirmar?")
    return 0


if __name__ == "__main__":
    sys.exit(main())
