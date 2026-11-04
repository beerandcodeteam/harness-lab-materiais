#!/usr/bin/env python3
"""confere-e2e.py · aula 4.4 · o seu E2E roda no comando do juiz?

Uso, na raiz do repositório:
  python3 .claude/scripts/confere-e2e.py
  python3 .claude/scripts/confere-e2e.py --test-cmd "<comando>"   (o mesmo --test-cmd do loop)

Acha os E2E do projeto (Pest browser em tests/Browser, HTTP test do Laravel com "E2E" no
nome do arquivo, Playwright Test e pytest-playwright), descobre o comando do juiz na mesma
ordem do qual-comando.sh da aula 4.1 e confere, só lendo arquivos, se cada E2E entra nesse
comando. Não roda teste nenhum e nunca lê o .env.

Saída: 0 = os E2E entram no comando do juiz (pode haver AVISO)
       1 = algum E2E fica fora do juiz ou quebra antes de testar (o motivo vem no ERRO)
       3 = nenhum E2E encontrado
"""
import configparser
import json
import os
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

PULA = {".git", "node_modules", "vendor", "storage", "venv", ".venv", "env", "__pycache__",
        "dist", "build", "coverage", "Screenshots", "Traces", "test-results",
        "playwright-report", ".pytest_cache", ".next", ".nuxt"}
JS_TESTE = re.compile(r".+\.(spec|test)\.(c|m)?[jt]sx?$")
PY_TESTE = re.compile(r"^(test_.+|.+_test)\.py$")
AC = re.compile(r"\bAC-\d+\b")
# conftest.py que sobe o app para o pytest-playwright (o equivalente do webServer do Node)
SOBE_APP = re.compile(r"\b(live_server|subprocess|Popen|uvicorn|gunicorn|xprocess|make_server|serve_forever)\b")

erros, avisos, invalidos = [], [], set()


def ler(caminho):
    if os.path.basename(caminho).startswith(".env"):
        return ""
    try:
        if os.path.getsize(caminho) > 2_000_000:
            return ""
        with open(caminho, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def _d(x):
    return x if isinstance(x, dict) else {}


def json_de(caminho):
    try:
        d = json.loads(ler(caminho) or "{}")
        return d if isinstance(d, dict) else {}
    except ValueError:
        if caminho not in invalidos:
            invalidos.add(caminho)
            aviso(f"{caminho} não é JSON válido: não deu para conferir")
        return {}


def arquivos():
    for raiz, dirs, nomes in os.walk("."):
        dirs[:] = [d for d in dirs if d not in PULA and not d.startswith(".")]
        for n in nomes:
            yield os.path.normpath(os.path.join(raiz, n))


def ok(msg):
    print(f"  ok     {msg}")


def erro(msg):
    erros.append(msg)
    print(f"  ERRO   {msg}")


def aviso(msg):
    avisos.append(msg)
    print(f"  AVISO  {msg}")


# ------------------------------------------------------------------ comando do juiz
def comando_do_juiz(flag):
    """Mesma ordem do qual-comando.sh (aula 4.1) e do gate 2 do ralph."""
    composer = ler("composer.json")
    if flag:
        return flag, "--test-cmd"
    if os.environ.get("RALPH_TEST_CMD"):
        return os.environ["RALPH_TEST_CMD"], "RALPH_TEST_CMD"
    if os.path.isfile("artisan") and (os.access("vendor/bin/sail", os.X_OK) or "laravel/sail" in composer):
        return "vendor/bin/sail test", "detectado: artisan + Laravel Sail"
    if re.search(r'"test"\s*:', composer):
        return "composer test", "detectado: composer.json com scripts.test"
    if os.path.isfile("artisan"):
        return "php artisan test", "detectado: artisan"
    if re.search(r'"test"\s*:', ler("package.json")):
        return "npm test", "detectado: package.json com scripts.test"
    if os.path.isfile("pytest.ini") or "[tool.pytest" in ler("pyproject.toml"):
        return "pytest", "detectado: pytest.ini ou [tool.pytest] no pyproject.toml"
    if os.path.isfile("go.mod"):
        return "go test ./...", "detectado: go.mod"
    if os.path.isfile("Cargo.toml"):
        return "cargo test", "detectado: Cargo.toml"
    return None, "nada detectado"


def partes(cmd):
    return [p.strip() for p in re.split(r"&&|\|\||;", cmd or "") if p.strip()]


def script_npm(nome, scripts, fundo=0):
    """Texto do script npm, seguindo 'npm run x' e parecidos até 3 níveis."""
    texto = str(scripts.get(nome, "") or "")
    if fundo >= 3:
        return texto
    for m in re.finditer(r"\b(?:npm|pnpm|yarn|bun)\s+(?:run\s+)?([\w:.-]+)", texto):
        if m.group(1) in scripts and m.group(1) != nome:
            texto += " " + script_npm(m.group(1), scripts, fundo + 1)
    return texto


def roda_php(cmd):
    if re.search(r"sail\s+(test|artisan\s+test|pest|php)|artisan\s+test|\bpest\b|\bphpunit\b", cmd or ""):
        return True
    if any(p == "composer test" for p in partes(cmd)):
        teste = _d(json_de("composer.json").get("scripts")).get("test", "")
        teste = " ".join(teste) if isinstance(teste, list) else str(teste)
        return bool(re.search(r"artisan\s+test|pest|phpunit", teste))
    return False


def roda_playwright(cmd):
    scripts = _d(json_de("package.json").get("scripts")) if os.path.isfile("package.json") else {}
    for p in partes(cmd):
        if "playwright test" in p:
            return True
        m = re.match(r"^(?:npm|pnpm|yarn|bun)\s+(?:run\s+)?(test|[\w:.-]+)$", p)
        if m and "playwright test" in script_npm(m.group(1), scripts):
            return True
    return False


def roda_pytest(cmd):
    return any(re.search(r"\bpytest\b", p) for p in partes(cmd))


# ------------------------------------------------------------------ PHP (Pest e Laravel)
def norm(d):
    d = (d or "").strip().replace("\\", "/")
    while d.startswith("./"):
        d = d[2:]
    return d.rstrip("/")


def phpunit_cobre(pasta):
    xml = next((x for x in ("phpunit.xml", "phpunit.xml.dist") if os.path.isfile(x)), None)
    if not xml:
        return False, "sem phpunit.xml"
    try:
        raiz = ET.fromstring(ler(xml))
    except ET.ParseError:
        return None, f"não consegui ler o {xml}"
    suites = []
    for s in raiz.iter("testsuite"):
        for d in s.findall("directory"):
            n = norm(d.text)
            if n in ("", ".") or pasta == n or pasta.startswith(n + "/"):
                suites.append(s.get("name", ""))
    if not suites:
        return False, f"{pasta} fora das <testsuite> do {xml}"
    padrao = raiz.get("defaultTestSuite")
    if padrao and not set(suites) & {x.strip() for x in padrao.split(",")}:
        return False, f"{xml} tem defaultTestSuite=\"{padrao}\", sem a suíte de {pasta}"
    return True, f"{pasta} está numa <testsuite> do {xml}"


def pest_in_cobre(sub):
    pest = ler("tests/Pest.php")
    if not pest:
        return False
    for m in re.finditer(r"->in\(([^)]*)\)", pest):
        if sub in m.group(1) or "__DIR__" in m.group(1):
            return True
    return False


def confere_php(e2e_browser, e2e_http, cmd, checa_juiz=True):
    composer = json_de("composer.json") if os.path.isfile("composer.json") else {}
    deps = {**_d(composer.get("require")), **_d(composer.get("require-dev"))}
    laravel = os.path.isfile("artisan")
    if checa_juiz:
        if roda_php(cmd):
            ok(f"o comando do juiz ({cmd}) roda o Pest")
        else:
            erro(f"o comando do juiz ({cmd or 'nenhum'}) não roda Pest nem PHPUnit: estes E2E ficam de fora")
    grupos = []
    if e2e_browser:
        grupos.append(("tests/Browser", "Browser"))
    for f in e2e_http:
        p = f.split(os.sep)
        if len(p) > 2 and p[0] == "tests":
            grupos.append(("tests/" + p[1], p[1]))
    for pasta, sub in dict.fromkeys(grupos):
        cobre, msg = phpunit_cobre(pasta)
        if cobre:
            ok(msg)
        elif cobre is None:
            aviso(msg)
        else:
            erro(msg + ": o juiz fica verde sem rodar o E2E (com --filter, \"No tests found.\")")
        if laravel:
            if pest_in_cobre(sub):
                ok(f"tests/Pest.php aplica o TestCase do Laravel em {sub}")
            elif os.path.isfile("tests/Pest.php") or sub == "Browser":
                erro(f"{pasta} fora do ->in() do tests/Pest.php: o teste roda sem o Laravel "
                     "(\"Target class [config] does not exist.\")")
    if not e2e_browser:
        return
    if "pestphp/pest-plugin-browser" in deps:
        ok("pestphp/pest-plugin-browser no composer.json")
    else:
        erro("pestphp/pest-plugin-browser fora do composer.json (composer require pestphp/pest-plugin-browser --dev)")
    pkg = json_de("package.json") if os.path.isfile("package.json") else {}
    npm = {**_d(pkg.get("dependencies")), **_d(pkg.get("devDependencies"))}
    if "playwright" in npm or "@playwright/test" in npm:
        ok("playwright no package.json")
    else:
        erro("playwright fora do package.json (npm install playwright@latest e npx playwright install)")
    ign = {norm(l.lstrip("/")) for l in ler(".gitignore").splitlines()}
    falta = [d for d in ("tests/Browser/Screenshots", "tests/Browser/Traces") if d not in ign]
    if falta:
        aviso(".gitignore sem " + " e ".join(falta) + " (o Pest grava screenshot quando falha)")
    else:
        ok(".gitignore com tests/Browser/Screenshots e tests/Browser/Traces")
    if (cmd or "").startswith("vendor/bin/sail"):
        aviso("o juiz roda dentro do container do Sail: o navegador precisa estar instalado lá. "
              "Prove com: vendor/bin/sail test --filter=Smoke")


def confere_dusk(cmd):
    """tests/Browser do Laravel Dusk: roda com o comando dusk do artisan, não com o test."""
    if re.search(r"\bdusk\b", cmd or ""):
        ok(f"o comando do juiz ({cmd}) roda o Dusk")
    else:
        erro(f"tests/Browser é do Laravel Dusk, que roda com o comando dusk do artisan, fora do comando "
             f"do juiz ({cmd or 'nenhum'}). Passe os dois ao loop com --test-cmd, ou use o Pest browser")


# ------------------------------------------------------------------ Node (Playwright Test)
def confere_playwright(e2e, todos_js, cmd):
    pkg = json_de("package.json") if os.path.isfile("package.json") else {}
    npm = {**_d(pkg.get("dependencies")), **_d(pkg.get("devDependencies"))}
    if roda_playwright(cmd):
        ok(f"o comando do juiz ({cmd}) chama o playwright test")
    elif cmd == "npm test" or (cmd or "").startswith(("npm ", "pnpm ", "yarn ", "bun ")):
        erro(f"o comando do juiz é {cmd} e o script test do package.json não chama o playwright test. "
             "Junte: \"test\": \"vitest run && playwright test\"")
    else:
        erro(f"o comando do juiz é {cmd or 'nenhum'} e ele não roda o Playwright. "
             "Passe os dois ao loop com --test-cmd ou RALPH_TEST_CMD")
    conf = next((c for c in ("playwright.config." + e for e in ("ts", "js", "mjs", "cjs", "mts", "cts"))
                 if os.path.isfile(c)), None)
    if not conf:
        aviso("sem playwright.config: sem baseURL nem webServer, o page.goto('/') não sabe onde está o app")
    else:
        texto = so_codigo(ler(conf), "js")   # o config do npm init traz o webServer comentado
        if "webServer" in texto:
            ok(f"{conf} sobe o app (webServer)")
        else:
            aviso(f"{conf} sem webServer: o app precisa estar de pé antes do juiz rodar")
        if re.search(r"(?i)firefox|webkit|safari", texto):
            aviso(f"{conf} roda também Firefox ou WebKit (o config do npm init): cada teste roda uma vez por "
                  "navegador e, sem eles instalados, cai em \"Executable doesn't exist\". Deixe um navegador "
                  "(modelos/playwright/playwright.config.ts)")
        m = re.search(r"testDir\s*:\s*['\"]([^'\"]+)['\"]", texto)
        base = norm(m.group(1)) if m else ""
        intrusos = [f for f in todos_js if f not in e2e and (base in ("", ".") or f.startswith(base + os.sep))]
        if intrusos:
            aviso(f"o Playwright vai tentar rodar {intrusos[0]}, que não é teste dele: "
                  "aponte o testDir do config para a pasta do E2E")
    for f in e2e:
        if "playwright.dev" in so_codigo(ler(f), "js"):
            aviso(f"{f} é o exemplo do npm init: abre playwright.dev, depende de internet e entra no juiz. Apague")
    if "vitest" in npm:
        confs = [ler(c) for c in os.listdir(".") if re.match(r"^vite(st)?\.config\.(c|m)?[jt]s$", c)]
        nomes = {os.path.basename(os.path.dirname(f)) for f in e2e} - {""}
        separado = any(("exclude" in t and any(n in t for n in nomes)) or
                       ("include" in t and not any(n in t for n in nomes)) for t in confs)
        if separado:
            ok("o Vitest tem include ou exclude separando a pasta do E2E")
        else:
            aviso(f"o Vitest também pega {e2e[0]} e quebra com \"test.skip() can only be called inside test\". "
                  "Tire a pasta do E2E do Vitest (exclude)")
    if shutil.which("node"):
        try:
            v = subprocess.run(["node", "--version"], capture_output=True, text=True, timeout=10).stdout
            maior = int(re.sub(r"[^0-9.]", "", v).split(".")[0])
            if maior < 22:
                aviso(f"Node {v.strip()}: o Playwright pede Node 22, 24 ou 26")
        except (OSError, ValueError, subprocess.SubprocessError):
            pass


# ------------------------------------------------------------------ Python (pytest-playwright)
def ini_pytest():
    """Junta as opções do pytest: pytest.ini, pyproject.toml, tox.ini, setup.cfg."""
    opcoes = {}
    for arq, secao in (("pytest.ini", "pytest"), ("tox.ini", "pytest"), ("setup.cfg", "tool:pytest")):
        if os.path.isfile(arq):
            cp = configparser.ConfigParser(interpolation=None)
            try:
                cp.read_string(ler(arq))
            except configparser.Error:
                continue
            if cp.has_section(secao):
                return dict(cp.items(secao))
    pyproject = ler("pyproject.toml")
    if pyproject:
        try:
            import tomllib
            d = _d(_d(tomllib.loads(pyproject).get("tool")).get("pytest"))
            d = _d(d.get("ini_options", d))
            opcoes = {k: (" ".join(v) if isinstance(v, list) else str(v)) for k, v in d.items()}
        except Exception:
            m = re.search(r"testpaths\s*=\s*\[([^\]]*)\]", pyproject)
            if m:
                opcoes["testpaths"] = " ".join(re.findall(r"['\"]([^'\"]+)['\"]", m.group(1)))
            if "base_url" in pyproject or "--base-url" in pyproject:
                opcoes["base_url"] = "?"
    return opcoes


def confere_pytest(e2e, cmd):
    if roda_pytest(cmd):
        ok(f"o comando do juiz ({cmd}) roda o pytest")
    else:
        erro(f"o comando do juiz é {cmd or 'nenhum'} e ele não roda o pytest. O loop só acha o pytest com "
             "pytest.ini ou [tool.pytest] no pyproject.toml; ou passe --test-cmd")
    opcoes = ini_pytest()
    caminhos = [norm(p) for p in opcoes.get("testpaths", "").split()]
    if caminhos:
        fora = [f for f in e2e if not any(c in ("", ".") or f.startswith(c + os.sep) for c in caminhos)]
        if fora:
            erro(f"testpaths do pytest ({' '.join(caminhos)}) não inclui {fora[0]}: o juiz não roda o E2E")
        else:
            ok("o testpaths do pytest inclui o E2E")
    conftests = {f: so_codigo(ler(f), "py") for f in arquivos() if os.path.basename(f) == "conftest.py"}
    fixture = next((f for f, t in conftests.items() if re.search(r"\bdef\s+base_url\s*\(", t)), None)
    sobe = next((f for f, t in conftests.items() if SOBE_APP.search(t)), None)
    if fixture:
        ok(f"{fixture} define o base_url")
    elif "base_url" in opcoes or "--base-url" in opcoes.get("addopts", ""):
        ok("base_url configurado para o pytest-playwright")
    elif any(re.search(r"goto\(\s*['\"]/", ler(f)) for f in e2e):
        aviso("sem base_url: page.goto('/...') não sabe o endereço. Defina a fixture base_url no conftest.py, "
              "junto com o app (modelos/pytest-playwright/conftest.py)")
    if sobe:
        ok(f"{sobe} sobe o app para o pytest")
    else:
        aviso("nenhum conftest.py sobe o app: o pytest-playwright não sobe servidor, e o juiz roda o E2E com o "
              "app fora do ar (net::ERR_CONNECTION_REFUSED) ou contra um app velho. Suba o app numa fixture de "
              "sessão (modelos/pytest-playwright/conftest.py) ou, no Django, use o live_server do pytest-django")
    deps = " ".join(ler(f) for f in os.listdir(".")
                    if re.match(r"^(requirements.*\.txt|pyproject\.toml|setup\.cfg|Pipfile)$", f))
    if "pytest-playwright" not in deps and "pytest_playwright" not in deps:
        aviso("pytest-playwright fora das dependências do projeto: o ambiente do juiz (CI, container) não vai ter")


# ------------------------------------------------------------------ principal
def so_codigo(texto, tipo):
    """Tira os comentários: marcador ou ID citado num comentário não conta."""
    if tipo == "py":
        texto = re.sub(r'(?s)""".*?"""|\'\'\'.*?\'\'\'', "", texto)
        return re.sub(r"(?m)^\s*#.*$", "", texto)
    texto = re.sub(r"(?s)/\*.*?\*/", "", texto)
    return re.sub(r"(?m)^\s*(//|#).*$", "", texto)


def estado(caminho, marcadores, tipo):
    texto = so_codigo(ler(caminho), tipo)
    ids = " ".join(dict.fromkeys(AC.findall(texto)))
    pend = any(re.search(m, texto) for m in marcadores)
    return ids, pend


def main():
    flag = None
    args = sys.argv[1:]
    while args:
        a = args.pop(0)
        if a == "--test-cmd" and args:
            flag = args.pop(0)
        elif a.startswith("--test-cmd="):
            flag = a.split("=", 1)[1]
        elif a in ("-h", "--help"):
            print(__doc__)
            return 0
        else:
            print(f"opção desconhecida: {a}", file=sys.stderr)
            return 64

    browser, http, pw, py, js = [], [], [], [], []
    for f in arquivos():
        nome = os.path.basename(f)
        partes_f = f.split(os.sep)
        if nome.endswith(".php") and partes_f[:2] == ["tests", "Browser"]:
            browser.append(f)
        elif nome.endswith("Test.php") and partes_f[0] == "tests" and "e2e" in nome.lower():
            http.append(f)
        elif JS_TESTE.match(nome):
            js.append(f)
            if "@playwright/test" in ler(f):
                pw.append(f)
        elif PY_TESTE.match(nome) and "playwright" in ler(f):
            py.append(f)

    cmd, origem = comando_do_juiz(flag)
    print(f"comando do juiz: {cmd or '(nenhum)'}  ({origem})")
    if not (browser or http or pw or py):
        print("\nNenhum E2E encontrado. Procurei: tests/Browser/*.php (Pest browser), tests/**/*E2E*Test.php")
        print("(HTTP test do Laravel), *.spec.ts e *.test.ts com @playwright/test, test_*.py com playwright.")
        return 3

    composer = json_de("composer.json") if os.path.isfile("composer.json") else {}
    deps = {**_d(composer.get("require")), **_d(composer.get("require-dev"))}
    dusk = "laravel/dusk" in deps and "pestphp/pest-plugin-browser" not in deps
    marcas = {"php": [r"->todo\(", r"->skip\("], "js": [r"\btest\.(skip|fixme)\(", r"describe\.skip\("],
              "py": [r"@pytest\.mark\.skip", r"\bpytest\.skip\("]}
    for titulo, lista, tipo, navegador in (("Pest browser", browser, "php", True),
                                           ("HTTP test do Laravel", http, "php", False),
                                           ("Playwright Test", pw, "js", True),
                                           ("pytest-playwright", py, "py", True)):
        if not lista:
            continue
        print(f"\n{'Laravel Dusk' if titulo == 'Pest browser' and dusk else titulo}")
        pendentes = 0
        for f in sorted(lista):
            ids, pend = estado(f, marcas[tipo], tipo)
            pendentes += pend
            print(f"  E2E    {f}{'  ' + ids if ids else ''}  {'pendente' if pend else 'ativo'}")
        if titulo == "Pest browser" and dusk:
            confere_dusk(cmd)
        elif titulo == "Pest browser":
            confere_php(browser, [], cmd)
        elif titulo == "HTTP test do Laravel":
            confere_php([], http, cmd, checa_juiz=not browser or dusk)
        elif titulo == "Playwright Test":
            confere_playwright(pw, js, cmd)
        elif titulo == "pytest-playwright":
            confere_pytest(py, cmd)
        if navegador and pendentes == len(lista):
            aviso("nenhum E2E ativo: teste pendente não abre o navegador, e o juiz fica verde mesmo sem "
                  "Chromium. Deixe um smoke ativo (modelos/ da aula 4.4)")

    print()
    if erros:
        print(f"resultado: {len(erros)} problema(s). O comando do juiz ainda não prova o fluxo.")
        return 1
    print(f"resultado: os E2E entram no comando do juiz ({len(avisos)} aviso(s)).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
