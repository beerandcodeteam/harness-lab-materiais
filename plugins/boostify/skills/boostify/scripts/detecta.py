#!/usr/bin/env python3
"""boostify · detecção da stack (só leitura, só biblioteca padrão).

Uso: python3 detecta.py [raiz-do-projeto]
Saída: JSON no stdout com o que dá para afirmar olhando os arquivos.
Nunca executa nada do projeto e nunca escreve arquivo.
"""
import json
import os
import re
import sys
from pathlib import Path

RAIZ = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()

# Pacotes que merecem regra por versão. Chave = nome no manifesto, valor = rótulo.
CONHECIDOS = {
    "js": {
        "next": "Next.js", "react": "React", "vue": "Vue", "nuxt": "Nuxt", "svelte": "Svelte",
        "@sveltejs/kit": "SvelteKit", "astro": "Astro", "@angular/core": "Angular",
        "express": "Express", "fastify": "Fastify", "@nestjs/core": "NestJS", "hono": "Hono",
        "react-router": "React Router", "@remix-run/react": "Remix", "vite": "Vite",
        "typescript": "TypeScript", "tailwindcss": "Tailwind CSS", "prisma": "Prisma",
        "@prisma/client": "Prisma Client", "drizzle-orm": "Drizzle", "typeorm": "TypeORM",
        "sequelize": "Sequelize", "mongoose": "Mongoose", "zod": "Zod",
        "@tanstack/react-query": "TanStack Query", "react-native": "React Native", "expo": "Expo",
        "electron": "Electron", "vitest": "Vitest", "jest": "Jest", "@playwright/test": "Playwright",
        "cypress": "Cypress", "eslint": "ESLint", "@biomejs/biome": "Biome", "prettier": "Prettier",
    },
    "py": {
        "django": "Django", "flask": "Flask", "fastapi": "FastAPI", "pydantic": "Pydantic",
        "sqlalchemy": "SQLAlchemy", "alembic": "Alembic", "celery": "Celery", "pytest": "pytest",
        "ruff": "Ruff", "black": "Black", "mypy": "mypy", "pandas": "pandas", "polars": "Polars",
        "langchain": "LangChain", "anthropic": "Anthropic SDK", "streamlit": "Streamlit",
        "torch": "PyTorch", "transformers": "Transformers", "numpy": "NumPy",
    },
    "rb": {
        "rails": "Rails", "rspec-rails": "RSpec", "rubocop": "RuboCop", "sidekiq": "Sidekiq",
        "hotwire-rails": "Hotwire", "turbo-rails": "Turbo", "devise": "Devise",
    },
    "go": {
        "github.com/gin-gonic/gin": "Gin", "github.com/labstack/echo/v4": "Echo",
        "github.com/gofiber/fiber/v2": "Fiber", "github.com/go-chi/chi/v5": "chi",
        "gorm.io/gorm": "GORM", "github.com/jackc/pgx/v5": "pgx",
    },
    "rs": {
        "axum": "Axum", "actix-web": "Actix Web", "tokio": "Tokio", "serde": "Serde",
        "sqlx": "SQLx", "diesel": "Diesel", "leptos": "Leptos",
    },
    "php": {
        "symfony/framework-bundle": "Symfony", "slim/slim": "Slim", "phpunit/phpunit": "PHPUnit",
        "pestphp/pest": "Pest", "laravel/framework": "Laravel",
    },
    "ex": {"phoenix": "Phoenix", "ecto": "Ecto", "phoenix_live_view": "LiveView"},
}


def ler(p):
    try:
        return (RAIZ / p).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None


def existe(p):
    return (RAIZ / p).exists()


def maior(v):
    m = re.search(r"(\d+)(?:\.(\d+))?", v or "")
    if not m:
        return None
    # 0.x: quem quebra é a versão menor (0.115 -> 0.116 pode mudar API)
    return f"0.{m.group(2)}" if m.group(1) == "0" and m.group(2) else m.group(1)


saida = {
    "raiz": str(RAIZ),
    "linguagens": [],
    "gerenciador": None,
    "pacotes": [],          # {nome, rotulo, versao, origem}
    "scripts": {},          # nome -> comando (package.json, composer)
    "tarefas": [],          # alvos de Makefile/justfile/Taskfile
    "ambiente": [],         # docker compose, devcontainer, versões fixadas
    "ci": [],               # comandos run: do CI (o jeito "oficial" de testar)
    "arquivos_agente": {},  # CLAUDE.md, AGENTS.md, bloco boostify, .ai/guidelines
    "laravel": False,
    "avisos": [],
}


def add_pacote(nome, rotulo, versao, origem):
    saida["pacotes"].append({"nome": nome, "rotulo": rotulo, "versao": versao,
                             "maior": maior(versao), "origem": origem})


# ---------- JavaScript / TypeScript ----------
def versao_lock_js(nome):
    """Versão travada no lockfile, para quando não há node_modules (clone novo, container)."""
    t = ler("package-lock.json")
    if t:
        try:
            v = json.loads(t).get("packages", {}).get(f"node_modules/{nome}", {}).get("version")
            if v:
                return v, "package-lock.json"
        except json.JSONDecodeError:
            pass
    t = ler("pnpm-lock.yaml")
    if t:
        n = re.escape(nome)
        # v9/v6: importers -> '.' -> dependencies -> nome: {specifier, version: 15.1.3(...)}
        m = re.search(rf"^\s+'?{n}'?:\n\s+specifier: [^\n]+\n\s+version: '?(\d[^\s('_\n]*)", t, re.M)
        # v5: dependencies: nome: 15.1.3
        m = m or re.search(rf"^  '?{n}'?: '?(\d[^\s('_\n]*)", t, re.M)
        if m:
            return m.group(1), "pnpm-lock.yaml"
    t = ler("yarn.lock")
    if t:
        n = re.escape(nome)
        m = re.search(rf'^"?{n}@[^\n]*:\n\s+version:? "?([^"\s]+)', t, re.M)
        if m:
            return m.group(1), "yarn.lock"
    return None


pkg_txt = ler("package.json")
if pkg_txt:
    saida["linguagens"].append("javascript")
    try:
        pkg = json.loads(pkg_txt)
    except json.JSONDecodeError:
        pkg = {}
        saida["avisos"].append("package.json ilegível")
    for lock, ger in (("pnpm-lock.yaml", "pnpm"), ("yarn.lock", "yarn"), ("bun.lockb", "bun"),
                      ("bun.lock", "bun"), ("package-lock.json", "npm")):
        if existe(lock):
            saida["gerenciador"] = ger
            break
    saida["gerenciador"] = saida["gerenciador"] or (pkg.get("packageManager", "").split("@")[0] or "npm")
    deps = {**pkg.get("dependencies", {}), **pkg.get("devDependencies", {})}
    if "typescript" in deps or existe("tsconfig.json"):
        saida["linguagens"].append("typescript")
    for nome, rot in CONHECIDOS["js"].items():
        if nome in deps:
            instalado = ler(f"node_modules/{nome}/package.json")
            versao, origem = deps[nome], "package.json (declarada)"
            if instalado:
                try:
                    versao, origem = json.loads(instalado).get("version", versao), "node_modules (instalada)"
                except json.JSONDecodeError:
                    pass
            else:
                travada = versao_lock_js(nome)
                if travada:
                    versao, origem = travada[0], f"{travada[1]} (instalada)"
            add_pacote(nome, rot, versao, origem)
    saida["scripts"].update({f"{saida['gerenciador']} run {k}": v for k, v in pkg.get("scripts", {}).items()})
    if pkg.get("workspaces") or existe("pnpm-workspace.yaml") or existe("turbo.json") or existe("nx.json"):
        saida["avisos"].append("monorepo: rode o boostify também em cada pacote que tem regra própria")

# ---------- Python ----------
py_fontes = {"pyproject.toml": ler("pyproject.toml"), "requirements.txt": ler("requirements.txt"),
             "Pipfile": ler("Pipfile")}
if any(py_fontes.values()):
    saida["linguagens"].append("python")
    for lock, ger in (("uv.lock", "uv"), ("poetry.lock", "poetry"), ("Pipfile.lock", "pipenv")):
        if existe(lock):
            saida["gerenciador"] = saida["gerenciador"] or ger
            break
    saida["gerenciador"] = saida["gerenciador"] or "pip"
    texto = "\n".join(t for t in py_fontes.values() if t).lower()
    trava = (ler("uv.lock") or ler("poetry.lock") or "").lower()
    for nome, rot in CONHECIDOS["py"].items():
        if re.search(rf'(^|["\s\[,]){re.escape(nome)}(\[[^\]]*\])?\s*([<>=~!^ ,"]|$)', texto, re.M):
            m = re.search(rf'name = "{re.escape(nome)}"\s*\nversion = "([^"]+)"', trava)
            if m:
                add_pacote(nome, rot, m.group(1), "lockfile (instalada)")
            else:
                d = re.search(rf'{re.escape(nome)}(?:\[[^\]]*\])?\s*([<>=~!^]=?\s*[\d.]+)', texto)
                add_pacote(nome, rot, d.group(1).strip() if d else "?", "manifesto (declarada)")

# ---------- Ruby ----------
gem_lock = ler("Gemfile.lock")
if ler("Gemfile"):
    saida["linguagens"].append("ruby")
    saida["gerenciador"] = saida["gerenciador"] or "bundler"
    for nome, rot in CONHECIDOS["rb"].items():
        m = re.search(rf"^    {re.escape(nome)} \(([^)]+)\)", gem_lock or "", re.M)
        if m:
            add_pacote(nome, rot, m.group(1), "Gemfile.lock (instalada)")

# ---------- Go ----------
gomod = ler("go.mod")
if gomod:
    saida["linguagens"].append("go")
    saida["gerenciador"] = saida["gerenciador"] or "go"
    m = re.search(r"^go (\S+)", gomod, re.M)
    if m:
        add_pacote("go", "Go", m.group(1), "go.mod (declarada)")
    for nome, rot in CONHECIDOS["go"].items():
        m = re.search(rf"{re.escape(nome)} (v\S+)", gomod)
        if m:
            add_pacote(nome, rot, m.group(1), "go.mod (instalada)")

# ---------- Rust ----------
cargo = ler("Cargo.toml")
if cargo:
    saida["linguagens"].append("rust")
    saida["gerenciador"] = saida["gerenciador"] or "cargo"
    trava = ler("Cargo.lock") or ""
    for nome, rot in CONHECIDOS["rs"].items():
        if re.search(rf"^{re.escape(nome)}\s*=", cargo, re.M):
            m = re.search(rf'name = "{re.escape(nome)}"\nversion = "([^"]+)"', trava)
            add_pacote(nome, rot, m.group(1) if m else "?", "Cargo.lock (instalada)" if m else "Cargo.toml (declarada)")

# ---------- PHP (fora do Laravel) ----------
comp = ler("composer.json")
if comp:
    saida["linguagens"].append("php")
    saida["gerenciador"] = saida["gerenciador"] or "composer"
    try:
        c = json.loads(comp)
    except json.JSONDecodeError:
        c = {}
    deps = {**c.get("require", {}), **c.get("require-dev", {})}
    lock = {}
    try:
        for p in json.loads(ler("composer.lock") or "{}").get("packages", []) + \
                 json.loads(ler("composer.lock") or "{}").get("packages-dev", []):
            lock[p["name"]] = p["version"].lstrip("v")
    except (json.JSONDecodeError, KeyError):
        pass
    for nome, rot in CONHECIDOS["php"].items():
        if nome in deps:
            add_pacote(nome, rot, lock.get(nome, deps[nome]), "composer.lock (instalada)" if nome in lock else "composer.json (declarada)")
    saida["laravel"] = "laravel/framework" in deps
    saida["scripts"].update({f"composer {k}": v for k, v in c.get("scripts", {}).items() if isinstance(v, str)})

# ---------- Elixir / .NET / Java (só identificação) ----------
mix = ler("mix.exs")
if mix:
    saida["linguagens"].append("elixir")
    for nome, rot in CONHECIDOS["ex"].items():
        m = re.search(rf'\{{:{nome},\s*"([^"]+)"', mix)
        if m:
            add_pacote(nome, rot, m.group(1), "mix.exs (declarada)")
if list(RAIZ.glob("*.csproj")) or list(RAIZ.glob("*.sln")):
    saida["linguagens"].append("dotnet")
    for proj in RAIZ.glob("*.csproj"):
        m = re.search(r"<TargetFramework>([^<]+)<", proj.read_text(errors="replace"))
        if m:
            add_pacote(proj.name, ".NET", m.group(1), proj.name)
for f, ger in (("pom.xml", "maven"), ("build.gradle", "gradle"), ("build.gradle.kts", "gradle")):
    t = ler(f)
    if t:
        saida["linguagens"].append("java/kotlin")
        saida["gerenciador"] = saida["gerenciador"] or ger
        m = re.search(r"spring-boot[^\n]*?(\d+\.\d+\.\d+)", t)
        if m:
            add_pacote("spring-boot", "Spring Boot", m.group(1), f)
        break

# ---------- Tarefas, ambiente, CI ----------
mk = ler("Makefile")
if mk:
    saida["tarefas"] += [f"make {a}" for a in re.findall(r"^([a-zA-Z][\w-]*):(?!=)", mk, re.M)][:25]
jf = ler("justfile") or ler("Justfile")
if jf:
    saida["tarefas"] += [f"just {a}" for a in re.findall(r"^([a-zA-Z][\w-]*)\s*[^:=\n]*:(?!=)", jf, re.M)][:25]
tf = ler("Taskfile.yml") or ler("Taskfile.yaml")
if tf:
    saida["tarefas"] += [f"task {a}" for a in re.findall(r"^  ([a-zA-Z][\w:-]*):\s*$", tf, re.M)][:25]

for f in ("docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml",
          ".devcontainer/devcontainer.json", "Dockerfile", ".nvmrc", ".node-version",
          ".python-version", ".tool-versions", "mise.toml", ".ruby-version", "rust-toolchain.toml"):
    t = ler(f)
    if t is not None:
        item = {"arquivo": f}
        if f in (".nvmrc", ".node-version", ".python-version", ".ruby-version"):
            item["versao"] = t.strip()
        if f.startswith(("docker-compose", "compose")):
            item["servicos"] = re.findall(r"^  ([a-zA-Z][\w-]*):\s*$", t, re.M)[:12]
        saida["ambiente"].append(item)

ci_dir = RAIZ / ".github" / "workflows"
for wf in sorted(ci_dir.glob("*.y*ml")) if ci_dir.exists() else []:
    for cmd in re.findall(r"^\s*-?\s*run:\s*(.+)$", wf.read_text(errors="replace"), re.M):
        cmd = cmd.strip().strip("|").strip()
        if cmd and cmd not in saida["ci"]:
            saida["ci"].append(cmd)
gl = ler(".gitlab-ci.yml")
if gl:
    saida["ci"] += [c.strip() for c in re.findall(r"^\s+- (.+)$", gl, re.M)][:20]
saida["ci"] = saida["ci"][:30]

# ---------- Arquivos de agente ----------
for f in ("CLAUDE.md", ".claude/CLAUDE.md", "AGENTS.md", "CLAUDE.local.md"):
    t = ler(f)
    if t is not None:
        saida["arquivos_agente"][f] = {
            "linhas": t.count("\n") + 1,
            "bloco_boostify": "<boostify-guidelines>" in t,
            "bloco_laravel_boost": "<laravel-boost-guidelines>" in t,
        }
g = RAIZ / ".ai" / "guidelines"
if g.exists():
    saida["arquivos_agente"][".ai/guidelines"] = sorted(str(p.relative_to(RAIZ)) for p in g.rglob("*.md"))
estado = ler(".ai/boostify.json")
if estado:
    try:
        saida["arquivos_agente"][".ai/boostify.json"] = json.loads(estado)
    except json.JSONDecodeError:
        saida["avisos"].append(".ai/boostify.json ilegível")
saida["arquivos_agente"]["skills_do_projeto"] = sorted(
    p.parent.name for p in (RAIZ / ".claude" / "skills").glob("*/SKILL.md")) if (RAIZ / ".claude" / "skills").exists() else []
mcp = ler(".mcp.json")
saida["arquivos_agente"]["mcp_projeto"] = sorted(json.loads(mcp).get("mcpServers", {}).keys()) if mcp else []

saida["linguagens"] = sorted(set(saida["linguagens"]))
if not saida["linguagens"]:
    saida["avisos"].append("nenhum manifesto reconhecido na raiz")
print(json.dumps(saida, ensure_ascii=False, indent=2))
