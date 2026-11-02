#!/usr/bin/env python3
"""
guard-destructive.py · Harness Lab · aula 2.3 · PreToolUse (matcher: Bash)

O guard de regras que o Claude Code escreveu na aula, revisado e testado.
Lê o comando que o modelo quer rodar, quebra em pedaços (; && || | $( ) bash -c)
e bloqueia (permissionDecision "deny") o que destrói trabalho ou toca produção:

  - Banco: artisan migrate:fresh/reset/refresh/rollback, db:wipe, --env=production,
    migrate --force; rails db:drop/reset/purge; prisma migrate reset; manage.py flush;
    DROP/TRUNCATE/DELETE sem WHERE dentro de mysql, psql, sqlite3 ou tinker.
  - Git: reset --hard, clean -f, checkout -- / checkout . / restore, stash drop/clear,
    push --force (inclusive --force-with-lease), branch -D, rm -f, filter-branch.
  - Docker: compose down -v / --volumes, volume rm/prune, system prune.
  - Produção: ssh, scp, sftp, rsync remoto, deploy.sh, mysql/psql em host remoto,
    .env.production, e os hosts e caminhos que você puser em PROD_HOSTS e PROD_PATHS.
  - Arquivos: rm, unlink, shred, truncate, find -delete em qualquer coisa que o git
    não consegue devolver (untracked, ignorado, modificado) ou que está fora do projeto.
    Exceções regeneráveis: vendor, node_modules, build, caches, /tmp (SAFE_PROJECT_PREFIXES).

Falha FECHADO: se o próprio script quebrar, ele nega o comando. No settings.json,
"onFailure": "block" cobre o caso de o python3 nem iniciar.
O motivo do deny vai para o modelo. Se o comando for mesmo necessário, rode você,
no terminal ou com `! comando` dentro do Claude Code.

Testar um comando sem abrir o Claude Code:
  python3 .claude/hooks/guard-destructive.py --eval 'php artisan migrate:fresh'
"""

import glob
import json
import os
import re
import shlex
import subprocess
import sys

PROJECT_DIR = os.path.realpath(os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd())
HOME = os.path.realpath(os.path.expanduser("~"))

# ------------------------------------------------------------- ajuste ao seu projeto
# Domínios de produção: curl/wget com escrita (POST, PUT, PATCH, DELETE) contra eles é barrado.
# Exemplo: PROD_HOSTS = ["minhaempresa.com.br", "api.minhaempresa.com.br"]
PROD_HOSTS = [h for h in os.environ.get("GUARD_PROD_HOSTS", "").split(",") if h.strip()]
# Caminhos que só existem no servidor de produção: qualquer comando que os cite é barrado.
# Exemplo: PROD_PATHS = ["/srv/app-producao"]
PROD_PATHS = [p for p in os.environ.get("GUARD_PROD_PATHS", "").split(",") if p.strip()]

# Pastas que se regeneram (dependências, build, cache): apagar está liberado.
SAFE_PROJECT_PREFIXES = [
    # PHP / Laravel
    "vendor",
    "public/build",
    "public/hot",
    "bootstrap/cache",
    "storage/framework/cache",
    "storage/framework/views",
    "storage/framework/sessions",
    "storage/framework/testing",
    "storage/logs",
    "storage/pail",
    ".phpunit.cache",
    ".phpunit.result.cache",
    # JS / TS
    "node_modules",
    "dist",
    "build",
    ".next",
    ".nuxt",
    "coverage",
    # Python
    "__pycache__",
    ".pytest_cache",
    ".ruff_cache",
    ".mypy_cache",
    # Rails
    "tmp",
    "log",
]
SAFE_ABS_PREFIXES = ["/tmp", os.path.realpath(os.environ.get("TMPDIR", "/tmp"))]
# ------------------------------------------------------------------------------------

PROD_DOMAIN = re.compile("|".join(r"\b" + re.escape(h.strip()) + r"\b" for h in PROD_HOSTS), re.I) if PROD_HOSTS else None

WRAPPERS = {"sudo", "env", "nohup", "time", "command", "exec", "nice", "ionice", "timeout", "stdbuf"}
SEPARATORS = {";", "&&", "||", "|", "&", "\n", "(", ")", "|&"}
REDIRECTS = {">", ">>", "<", "<<", "<<<", ">&", "<&", ">|", "&>"}

DANGEROUS_ARTISAN = re.compile(r"^(migrate:(fresh|reset|refresh|rollback)|db:wipe)$")
SQL_DANGER = re.compile(
    r"\b(drop\s+(database|schema|table|view)\b|truncate\s+(table\s+)?[`\w]"
    r"|delete\s+from\s+[`\w.]+\s*(;|$|[\"'])|alter\s+table\s+\S+\s+drop\b)",
    re.I | re.M,
)
TINKER_DANGER = re.compile(
    r"(::truncate\(|->truncate\(|Schema::(drop|dropIfExists|dropAllTables)|forceDelete\("
    r"|->delete\(\)|::query\(\)->delete|Storage::[^;]*->(delete|deleteDirectory)\("
    r"|File::(delete|deleteDirectory|cleanDirectory)\(|DB::statement\(\s*['\"]\s*(drop|truncate))",
    re.I,
)


class Blocked(Exception):
    pass


def block(reason):
    raise Blocked(reason)


# ---------------------------------------------------------------- tokenizing


def strip_heredocs(text):
    """Remove heredoc bodies from the command, returning (command, bodies)."""
    lines = text.split("\n")
    out, bodies = [], []
    i = 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        delims = re.findall(r"<<-?\s*['\"]?([A-Za-z_][A-Za-z0-9_]*)['\"]?", line)
        i += 1
        for delim in delims:
            body = []
            while i < len(lines) and lines[i].strip() != delim:
                body.append(lines[i])
                i += 1
            i += 1
            bodies.append("\n".join(body))
    return "\n".join(out), bodies


def tokenize(text):
    lexer = shlex.shlex(text, posix=True, punctuation_chars="();<>|&\n")
    lexer.whitespace = " \t\r"
    lexer.whitespace_split = True
    lexer.commenters = ""
    try:
        return list(lexer)
    except ValueError:
        return text.split()


def split_segments(tokens):
    segments, current = [], []
    for tok in tokens:
        if tok in SEPARATORS:
            if current:
                segments.append(current)
            current = []
        else:
            current.append(tok)
    if current:
        segments.append(current)
    return segments


def strip_wrappers(seg):
    seg = list(seg)
    while seg:
        head = os.path.basename(seg[0])
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", seg[0]):
            seg.pop(0)
        elif head in WRAPPERS:
            seg.pop(0)
            while seg and seg[0].startswith("-"):
                seg.pop(0)
            if head == "timeout" and seg and re.match(r"^\d", seg[0]):
                seg.pop(0)
        else:
            break
    return seg


def drop_redirects(seg):
    """Return (args without redirections, redirection targets)."""
    args, targets = [], []
    skip = False
    for tok in seg:
        if skip:
            targets.append(tok)
            skip = False
        elif tok in REDIRECTS:
            skip = True
        else:
            args.append(tok)
    return args, targets


# ---------------------------------------------------------------- file checks


def rel_to_project(path):
    try:
        rel = os.path.relpath(path, PROJECT_DIR)
    except ValueError:
        return None
    if rel == ".." or rel.startswith("../"):
        return None
    return rel


def is_safe_path(abspath):
    rel = rel_to_project(abspath)
    if rel is not None:  # dentro do projeto: só as pastas que se regeneram
        return any(rel == p or rel.startswith(p + "/") for p in SAFE_PROJECT_PREFIXES)
    for prefix in SAFE_ABS_PREFIXES:
        if abspath == prefix or abspath.startswith(prefix.rstrip("/") + "/"):
            return abspath != prefix
    return False


def git_unsafe_entries(abspath):
    """Entries under abspath that git cannot restore (untracked, ignored, modified)."""
    try:
        out = subprocess.run(
            ["git", "-C", PROJECT_DIR, "status", "--porcelain", "--ignored", "--untracked-files=all", "--", abspath],
            capture_output=True,
            text=True,
            timeout=10,
        )
    except Exception:
        return ["(git status falhou)"]
    if out.returncode != 0:
        return ["(git status falhou)"]
    return [line for line in out.stdout.splitlines() if line.strip()]


def check_delete_target(raw, cwd, verb):
    if re.search(r"[$`]", raw):
        block(f"`{verb} {raw}`: alvo com variável/substituição não pode ser verificado.")
    expanded = os.path.expanduser(raw)
    candidate = expanded if os.path.isabs(expanded) else os.path.join(cwd, expanded)
    if any(ch in raw for ch in "*?["):
        matches = glob.glob(candidate, recursive=True)
        if not matches:
            return
        for m in matches:
            check_delete_path(os.path.realpath(m) if not os.path.islink(m) else os.path.abspath(m), raw, verb)
        return
    path = os.path.abspath(candidate)
    if not os.path.islink(path):
        path = os.path.realpath(path)
    check_delete_path(path, raw, verb)


def check_delete_path(path, raw, verb):
    critical = {"/", HOME, PROJECT_DIR, os.path.dirname(PROJECT_DIR)}
    if path in critical or path.rstrip("/") in critical:
        block(f"`{verb} {raw}` apaga diretório crítico ({path}).")
    if path == os.path.join(PROJECT_DIR, ".git") or path.startswith(os.path.join(PROJECT_DIR, ".git") + "/"):
        block(f"`{verb} {raw}` mexe no .git.")
    if is_safe_path(path):
        return
    if not os.path.lexists(path):
        return
    rel = rel_to_project(path)
    if rel is None:
        block(f"`{verb} {raw}` apaga algo fora do projeto ({path}).")
    unsafe = git_unsafe_entries(path)
    if unsafe:
        preview = "\n".join("    " + u for u in unsafe[:10])
        more = f"\n    ... +{len(unsafe) - 10}" if len(unsafe) > 10 else ""
        block(
            f"`{verb} {raw}` apagaria conteúdo que o git NÃO consegue restaurar "
            f"(untracked/ignorado/modificado):\n{preview}{more}"
        )


def delete_args(args):
    """Non-option args of rm-like commands (handles `--`)."""
    targets, end_opts = [], False
    for a in args:
        if not end_opts and a == "--":
            end_opts = True
        elif not end_opts and a.startswith("-") and a != "-":
            continue
        else:
            targets.append(a)
    return targets


# ---------------------------------------------------------------- rules


def check_git(args):
    i = 1
    while i < len(args) and args[i].startswith("-"):
        i += 2 if args[i] in ("-C", "-c") else 1
    if i >= len(args):
        return
    sub, rest = args[i], args[i + 1 :]
    flags = " ".join(rest)
    if sub == "reset" and ("--hard" in rest or "--merge" in rest or "--keep" in rest):
        block("`git reset --hard` descarta mudanças não commitadas.")
    if sub == "clean" and any(re.match(r"^-[a-zA-Z]*f", a) or a == "--force" for a in rest):
        block("`git clean -f` apaga arquivos untracked.")
    if sub == "checkout" and ("--" in rest or "." in rest or "-f" in rest or "--force" in rest):
        block("`git checkout -- <path>`/`checkout .`/`-f` descarta mudanças locais.")
    if sub == "restore" and not ("--staged" in rest and "--worktree" not in rest and "-W" not in rest):
        block("`git restore` descarta mudanças locais do working tree.")
    if sub == "stash" and rest and rest[0] in ("drop", "clear"):
        block("`git stash drop/clear` apaga stashes.")
    if sub == "push" and re.search(r"(^|\s)(-f|--force|--force-with-lease|--mirror|--delete|-d)(\s|=|$)|(^|\s)\+\S", flags):
        block("`git push --force/--delete` reescreve/apaga histórico remoto.")
    if sub == "branch" and re.search(r"(^|\s)(-D|--delete\s+--force|-df|-fd)(\s|$)", flags):
        block("`git branch -D` apaga branch sem checar merge.")
    if sub == "rm" and re.search(r"(^|\s)(-f|--force|-rf|-fr)(\s|$)", flags):
        block("`git rm -f` apaga arquivos com mudanças não commitadas.")
    if sub in ("filter-branch", "filter-repo") or (sub == "reflog" and "expire" in rest) or (sub == "update-ref" and "-d" in rest):
        block(f"`git {sub}` reescreve/apaga histórico.")
    if sub == "gc" and "--prune=now" in flags:
        block("`git gc --prune=now` apaga objetos irrecuperáveis.")


def check_artisan(args):
    nomes = [os.path.basename(a) for a in args]
    if "artisan" in nomes:
        idx = nomes.index("artisan")
    elif os.path.basename(args[0]) == "sail" and len(args) > 1 and args[1] == "art":
        idx = 1
    else:
        return
    rest = args[idx + 1 :]
    sub = next((a for a in rest if not a.startswith("-")), "")
    if DANGEROUS_ARTISAN.match(sub):
        block(f"`artisan {sub}` apaga/reverte o banco.")
    joined = " ".join(rest)
    if re.search(r"--env[= ]\s*prod", joined, re.I):
        block("artisan com `--env=production`.")
    if sub == "migrate" and "--force" in rest:
        block("`artisan migrate --force` é para produção; local não precisa de --force.")


def check_docker(args):
    cmd = os.path.basename(args[0])
    joined = " ".join(args)
    is_compose = cmd in ("docker-compose", "sail") or (cmd == "docker" and len(args) > 1 and args[1] == "compose")
    if is_compose and re.search(r"\bdown\b", joined) and re.search(r"(^|\s)(-v|--volumes)(\s|$)", joined):
        block("`down -v` apaga os volumes (banco MySQL/Redis locais).")
    if cmd == "docker" and re.search(r"\bvolume\s+(rm|prune)\b|\bsystem\s+prune\b", joined):
        block("`docker volume rm/prune` / `system prune` apaga volumes/dados.")


def check_stack_db(args):
    """O equivalente do migrate:fresh em outras stacks."""
    cmd = os.path.basename(args[0])
    joined = " ".join(args)
    if cmd in ("rails", "rake", "bin/rails") or args[0].endswith("bin/rails"):
        if re.search(r"\bdb:(drop|reset|purge|schema:load|truncate_all|rollback)\b", joined):
            block("Este comando do Rails apaga ou reverte o banco. Use `rails db:migrate`.")
    if "prisma" in args and re.search(r"\bmigrate\s+reset\b|--force-reset|--accept-data-loss", joined):
        block("Este comando do Prisma apaga o banco. Use `npx prisma migrate dev`.")
    if "manage.py" in joined and re.search(r"\b(flush|reset_db|sqlflush)\b", joined):
        block("Este comando do Django apaga os dados do banco. Use `python manage.py migrate`.")


def check_production(args, segment_text):
    cmd = os.path.basename(args[0])
    if cmd in ("ssh", "scp", "sftp", "mosh", "ssh-copy-id"):
        block(f"`{cmd}`: acesso a servidor remoto (produção) só com o humano no comando.")
    if cmd == "rsync" and any(re.match(r"^[^/\s]*[^/\s:]:", a) or a.startswith("rsync://") for a in args[1:]):
        block("`rsync` remoto: acesso a servidor só com o humano no comando.")
    if cmd == "gcloud" and "ssh" in args:
        block("`gcloud ... ssh`: acesso a servidor só com o humano no comando.")
    if cmd == "aws" and len(args) > 1 and args[1] in ("s3", "s3api") and not (len(args) > 2 and args[2] in ("ls",)):
        block("`aws s3` com escrita ou remoção mexe em bucket que pode ser de produção.")
    if cmd in ("mysql", "mariadb", "mysqldump", "psql", "pg_dump") or (cmd == "sail" and len(args) > 1 and args[1] in ("mysql", "psql")):
        m = re.search(r"(?:-h\s*|--host[= ])(\S+)", segment_text)
        if m and m.group(1) not in ("localhost", "127.0.0.1", "mysql", "pgsql", "db", "::1"):
            block(f"`{cmd}` conectando em host remoto ({m.group(1)}).")
    if any(a.endswith("deploy.sh") for a in args[:3]):
        block("`deploy.sh` é o deploy de produção.")
    if re.search(r"\.env\.prod(uction)?\b", segment_text) or any(p in segment_text for p in PROD_PATHS):
        block("O comando cita caminho ou configuração de produção.")
    if PROD_DOMAIN and cmd in ("curl", "wget", "http", "https", "xh") and PROD_DOMAIN.search(segment_text):
        if re.search(r"(-X|--request)\s*(POST|PUT|PATCH|DELETE)|(^|\s)(-d|--data\S*|-F|--form|--post-\w+|--method)(\s|=)|\s(POST|PUT|PATCH|DELETE)\s", segment_text, re.I):
            block("Request de escrita contra o domínio de produção.")


def check_file_deletion(args, cwd):
    cmd = os.path.basename(args[0])
    if cmd in ("rm", "unlink", "shred", "srm"):
        if cmd == "shred":
            block("`shred` destrói arquivos de forma irrecuperável.")
        for t in delete_args(args[1:]):
            check_delete_target(t, cwd, cmd)
    elif cmd == "truncate":
        it = iter(args[1:])
        targets = []
        for a in it:
            if a in ("-s", "--size", "-r", "--reference"):
                next(it, None)
            elif not a.startswith("-"):
                targets.append(a)
        for t in targets:
            check_delete_target(t, cwd, cmd)
    elif cmd == "find" and any(a in ("-delete",) for a in args) or (cmd == "find" and "-exec" in args and any(os.path.basename(a) in ("rm", "shred", "unlink") for a in args)):
        roots = []
        for a in args[1:]:
            if a.startswith("-") or a in ("!", "("):
                break
            roots.append(a)
        for r in roots or ["."]:
            check_delete_target(r, cwd, "find -delete")
    elif cmd == "xargs" and any(os.path.basename(a) in ("rm", "shred", "unlink") for a in args[1:]):
        block("`xargs rm`: alvos não podem ser verificados antes; liste e apague explicitamente.")
    elif cmd == "mv":
        targets = delete_args(args[1:])
        if targets:
            dest = targets[-1]
            if dest == "/dev/null":
                block("`mv ... /dev/null` destrói arquivos.")


def check_segment(seg, cwd, state):
    args, _redirects = drop_redirects(strip_wrappers(seg))
    if not args:
        return cwd
    cmd = os.path.basename(args[0])
    text = " ".join(args)

    if cmd == "cd":
        target = args[1] if len(args) > 1 else HOME
        target = os.path.expanduser(target)
        return os.path.realpath(target if os.path.isabs(target) else os.path.join(cwd, target))

    if cmd in ("bash", "sh", "zsh", "dash") and "-c" in args:
        idx = args.index("-c")
        if idx + 1 < len(args):
            check_command(args[idx + 1], cwd, state)
    if cmd == "eval":
        check_command(" ".join(args[1:]), cwd, state)
    if cmd in ("bash", "sh", "zsh") and len(args) > 1 and not args[1].startswith("-") and args[1].endswith("deploy.sh"):
        block("`deploy.sh` é o deploy de produção.")

    if cmd in ("mysql", "mariadb", "psql", "sqlite3") or "tinker" in args or "mysql" in args[:3] or "db" in args[:4]:
        state["sql_context"] = True

    if cmd == "git":
        check_git(args)
    check_artisan(args)
    check_stack_db(args)
    check_docker(args)
    check_production(args, text)
    check_file_deletion(args, cwd)

    # docker compose exec / sail exec: re-check the inner command.
    if (cmd == "docker" and "exec" in args) or (cmd == "sail" and len(args) > 1 and args[1] == "exec"):
        idx = args.index("exec") + 1
        while idx < len(args) and args[idx].startswith("-"):
            idx += 1
        if idx + 1 < len(args):
            check_segment(args[idx + 1 :], cwd, state)
    return cwd


def check_command(command, cwd, state):
    body_free, bodies = strip_heredocs(command)
    state["texts"].append(command)
    for inner in re.findall(r"\$\(([^()]*)\)", body_free) + re.findall(r"`([^`]*)`", body_free):
        check_command(inner, cwd, state)
    for seg in split_segments(tokenize(body_free)):
        cwd = check_segment(seg, cwd, state)
    return cwd


def evaluate(command, cwd):
    state = {"sql_context": False, "texts": []}
    check_command(command, cwd, state)
    if state["sql_context"]:
        full = "\n".join(state["texts"])
        if SQL_DANGER.search(full):
            block("SQL destrutivo (DROP/TRUNCATE/DELETE sem WHERE/ALTER ... DROP).")
        if TINKER_DANGER.search(full):
            block("Código destrutivo em tinker (truncate/delete em massa/drop/Storage delete).")


MOTIVO = (
    "BLOQUEADO pelo guard-destructive: {}\n"
    "Não tente contornar (outra sintaxe, script, subshell). Explique ao humano o que você quer "
    "fazer e por quê. Se ele concordar, ele mesmo roda o comando."
)


def decide(command, cwd):
    """None se libera, ou o motivo do bloqueio."""
    try:
        evaluate(command, cwd)
    except Blocked as exc:
        return MOTIVO.format(exc)
    except Exception as exc:  # falha fechado: na dúvida, nega
        return f"guard-destructive falhou ao analisar o comando ({exc!r}). Peça ao humano para rodar."
    return None


def main():
    if len(sys.argv) >= 3 and sys.argv[1] == "--eval":
        motivo = decide(sys.argv[2], os.getcwd())
        print("libera" if motivo is None else "bloqueia: " + motivo.splitlines()[0])
        return 0
    try:
        payload = json.load(sys.stdin)
    except Exception:
        payload = None
    if not isinstance(payload, dict):
        motivo = "guard-destructive recebeu uma entrada que não é JSON. Bloqueado por segurança."
    elif payload.get("tool_name") not in (None, "Bash"):
        return 0
    else:
        command = (payload.get("tool_input") or {}).get("command") or ""
        motivo = decide(command, payload.get("cwd") or PROJECT_DIR)
    if motivo:
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": motivo,
            }
        }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
