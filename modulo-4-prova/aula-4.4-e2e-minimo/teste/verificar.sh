#!/usr/bin/env bash
# verificar.sh · aula 4.4 · roda no ~/projeto da sandbox, depois dos comandos do material.
# Prova que o confere-e2e.py foi instalado, que o smoke do Laravel foi copiado e que o
# conferidor acerta cada caso que a aula e o material descrevem, em projetos falsos de
# Laravel, Node e Python (sem rede, sem navegador, sem rodar teste de verdade).
# Também roda os mesmos cp do PDF para Node e Python (pulados na sandbox, que é Laravel).
set -euo pipefail

n=0
ok() { n=$((n + 1)); printf '  ok  %s\n' "$1"; }
erro() { printf 'FALHOU: %s\n' "$1" >&2; exit 1; }
AULA="$HOME/harness-lab-materiais/modulo-4-prova/aula-4.4-e2e-minimo"
A="$AULA/modelos"
C="$PWD/.claude/scripts/confere-e2e.py"
TMPDIR=$(mktemp -d)
export TMPDIR
trap 'rm -rf "$TMPDIR"' EXIT

# roda PASTA [args...]: guarda rc e out (o conferidor sempre na raiz do projeto falso)
roda() {
  local d="$1"; shift
  set +e
  out=$(cd "$d" && env -u RALPH_TEST_CMD python3 "$C" "$@" 2>&1)
  rc=$?
  set -e
}
espera() {   # espera RC TEXTO DESCRIÇÃO
  if [ "$rc" != "$1" ] || ! grep -qF -- "$2" <<<"$out"; then
    echo "$out" >&2
    erro "$3 (esperado exit $1 com \"$2\", veio exit $rc)"
  fi
}
nao_tem() {   # nao_tem TEXTO DESCRIÇÃO
  if grep -qF -- "$1" <<<"$out"; then echo "$out" >&2; erro "$2"; fi
}
# novo NOME: pasta vazia para um projeto falso
novo() { local d="$TMPDIR/$1"; mkdir -p "$d"; echo "$d"; }

# ------------------------------------------------------------------ instalação
[ -x "$C" ] || erro ".claude/scripts/confere-e2e.py não instalado ou sem chmod +x"
cmp -s "$C" "$AULA/projeto/.claude/scripts/confere-e2e.py" || erro "confere-e2e.py diferente do da aula"
python3 -c 'import ast, sys; ast.parse(open(sys.argv[1], encoding="utf-8").read())' "$C"
grep -q 'startswith(".env")' "$C" || erro "o conferidor precisa recusar ler .env"
ok "confere-e2e.py instalado, executável, igual ao da aula e com a trava do .env"

cmp -s tests/Browser/SmokeTest.php "$A/pest-browser/SmokeTest.php" || erro "SmokeTest.php não copiado"
grep -qx 'tests/Browser/Screenshots' .gitignore && grep -qx 'tests/Browser/Traces' .gitignore ||
  erro ".gitignore sem as duas pastas do Pest browser"
! grep -v '^ *//' tests/Browser/SmokeTest.php | grep -q -- '->todo(' || erro "o smoke não pode nascer pendente"
ok "smoke do Pest browser copiado (ativo) e .gitignore com Screenshots e Traces"

# ------------------------------------------------------------------ o projeto da sandbox
roda "$PWD"
espera 0 "os E2E entram no comando do juiz" "projeto da sandbox"
espera 0 "tests/Browser/SmokeTest.php  ativo" "smoke listado como ativo"
espera 0 "comando do juiz: vendor/bin/sail test" "Sail detectado como o loop.sh detecta"
espera 0 "dentro do container do Sail" "aviso do navegador no container"
ok "no projeto da sandbox: exit 0, smoke ativo, Prova vendor/bin/sail test, aviso do container"

# ------------------------------------------------------------------ Laravel: os erros da aula
laravel() {   # laravel PASTA: projeto Laravel falso pronto, copiado da fixture desta sandbox
  cp -R "$PWD/." "$1/"
  rm -rf "$1/.git"
}
L=$(novo lar-sem-suite); laravel "$L"
sed -i.bak '/<testsuite name="Browser">/,/<\/testsuite>/d' "$L/phpunit.xml"
roda "$L"
espera 1 "No tests found." "tests/Browser fora do phpunit.xml"
L=$(novo lar-pest-in); laravel "$L"
sed -i.bak "s/->in('Feature', 'Browser')/->in('Feature')/" "$L/tests/Pest.php"
roda "$L"
espera 1 "Target class [config] does not exist." "tests/Browser fora do ->in() do Pest.php"
L=$(novo lar-sem-plugin); laravel "$L"
sed -i.bak '/pest-plugin-browser/d' "$L/composer.json"
roda "$L"
espera 1 "composer require pestphp/pest-plugin-browser --dev" "plugin fora do composer.json"
ok "Laravel: suíte sem Browser, Pest.php sem Browser e plugin faltando dão exit 1 com o motivo"

L=$(novo lar-pendente); laravel "$L"
rm "$L/tests/Browser/SmokeTest.php"
cp "$A/pest-browser/CadastroE2ETest.php" "$L/tests/Browser/"
roda "$L"
espera 0 "nenhum E2E ativo" "só E2E pendente"
espera 0 "CadastroE2ETest.php  AC-03  pendente" "ID e estado do E2E"
ok "Laravel: só o E2E pendente passa, mas avisa que nada abre o navegador"

L=$(novo lar-http); laravel "$L"
rm -rf "$L/tests/Browser"
cp "$A/laravel-http/CadastroApiE2ETest.php" "$A/laravel-http/CadastroHttpE2ETest.php" "$L/tests/Feature/"
roda "$L"
espera 0 "HTTP test do Laravel" "E2E pelo HTTP test"
espera 0 "CadastroApiE2ETest.php  AC-02  pendente" "API E2E listado"
nao_tem "Pest browser" "sem tests/Browser não há seção de Pest browser"
ok "Laravel só API: os dois HTTP E2E entram na Prova pelo tests/Feature"

L=$(novo lar-dusk); laravel "$L"
sed -i.bak 's#"pestphp/pest-plugin-browser": "^5.2",#"laravel/dusk": "^8.0",#' "$L/composer.json"
roda "$L"
espera 1 "Laravel Dusk" "tests/Browser do Dusk fora da Prova"
roda "$L" --test-cmd "vendor/bin/sail test && vendor/bin/sail artisan dusk"
espera 0 "roda o Dusk" "Prova com o comando do Dusk"
ok "Laravel com Dusk: fora da Prova dá exit 1 (e não pede o plugin do Pest); com o dusk no --test-cmd, passa"

L=$(novo lar-sem-gitignore); laravel "$L"
printf '/vendor\n' > "$L/.gitignore"
roda "$L"
espera 0 ".gitignore sem tests/Browser/Screenshots" "aviso do .gitignore"
ok "Laravel: .gitignore sem as pastas do Pest vira aviso"

# ------------------------------------------------------------------ Node (Playwright Test)
node_ok() {   # node_ok PASTA: os mesmos cp do PDF, mais o config e o Vitest separados
  mkdir -p "$1/tests/unit"
  (
    cd "$1"
    mkdir -p tests/e2e
    cp "$A/playwright/smoke.spec.ts" tests/e2e/
  )
  cp "$A/playwright/playwright.config.ts" "$A/playwright/vitest.config.ts" "$1/"
  printf "import { expect, test } from 'vitest';\ntest('x', () => expect(1).toBe(1));\n" > "$1/tests/unit/x.test.ts"
  cat > "$1/package.json" <<'JSON'
{"type": "module", "scripts": {"test": "vitest run && playwright test"},
 "devDependencies": {"vitest": "^4.1.12", "@playwright/test": "^1.64.1"}}
JSON
}
N=$(novo node-ok); node_ok "$N"
roda "$N"
espera 0 "os E2E entram no comando do juiz" "Node pronto"
espera 0 "chama o playwright test" "npm test chamando o Playwright"
nao_tem "o Vitest também pega" "Vitest separado não pode avisar"
nao_tem "vai tentar rodar" "testDir em tests/e2e não pode avisar"
nao_tem "Firefox ou WebKit" "o config do modelo tem um navegador só"
nao_tem "sem webServer" "o config do modelo sobe o app"
ok "Node: os cp do PDF, config e vitest.config.ts dos modelos: exit 0, sem aviso de Vitest, testDir nem navegador"

N=$(novo node-npm-init); node_ok "$N"
cat > "$N/playwright.config.ts" <<'TS'
import { defineConfig, devices } from '@playwright/test';
export default defineConfig({
  testDir: './tests/e2e',
  /* Configure projects for major browsers */
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
    { name: 'webkit', use: { ...devices['Desktop Safari'] } },
  ],
  /* Run your local dev server before starting the tests */
  // webServer: {
  //   command: 'npm run start',
  //   url: 'http://localhost:3000',
  // },
});
TS
printf "import { test, expect } from '@playwright/test';\n\ntest('has title', async ({ page }) => {\n  await page.goto('https://playwright.dev/');\n  await expect(page).toHaveTitle(/Playwright/);\n});\n" > "$N/tests/e2e/example.spec.ts"
roda "$N"
espera 0 "roda também Firefox ou WebKit" "config do npm init com três navegadores"
espera 0 "tests/e2e/example.spec.ts é o exemplo do npm init" "example.spec.ts do npm init"
espera 0 "sem webServer" "webServer só em comentário não conta"
ok "Node: config do npm init (três navegadores, webServer comentado) e o example.spec.ts viram aviso"

N=$(novo node-vitest); node_ok "$N"
rm "$N/vitest.config.ts"
sed -i.bak 's/"vitest run && playwright test"/"vitest run"/' "$N/package.json"
roda "$N"
espera 1 "não chama o playwright test" "npm test sem Playwright"
espera 1 "o Vitest também pega" "Vitest pegando o .spec.ts"
ok "Node: npm test sem Playwright dá exit 1; Vitest sem exclude vira aviso"

N=$(novo node-testdir); node_ok "$N"
sed -i.bak "s#testDir: './tests/e2e'#testDir: './tests'#" "$N/playwright.config.ts"
roda "$N"
espera 0 "vai tentar rodar tests/unit/x.test.ts" "testDir largo pegando teste do Vitest"
ok "Node: testDir largo avisa que o Playwright vai pegar o teste do Vitest"

N=$(novo node-encadeado); node_ok "$N"
cat > "$N/package.json" <<'JSON'
{"scripts": {"test": "npm run unit && npm run e2e", "unit": "vitest run", "e2e": "playwright test"},
 "devDependencies": {"vitest": "^4.1.12", "@playwright/test": "^1.64.1"}}
JSON
roda "$N"
espera 0 "chama o playwright test" "npm test que chama npm run e2e"
ok "Node: npm test encadeando npm run e2e conta"

N=$(novo laravel-e-node); laravel "$N"
mkdir -p "$N/tests/e2e"; cp "$A/playwright/smoke.spec.ts" "$N/tests/e2e/"
roda "$N"
espera 1 "ele não roda o Playwright" "Laravel com Playwright Node na Prova do Sail"
roda "$N" --test-cmd "vendor/bin/sail test && npx playwright test"
espera 0 "(--test-cmd)" "--test-cmd com os dois comandos"
ok "Laravel com Playwright Node: exit 1 na Prova detectada; --test-cmd com os dois (o mesmo do LOOP_TEST_CMD) resolve"

# ------------------------------------------------------------------ Python (pytest-playwright)
py_ok() {   # py_ok PASTA: o cp do PDF, o conftest.py que sobe o app, testpaths e a dependência
  (
    cd "$1"
    mkdir -p tests/e2e
    cp "$A/pytest-playwright/test_smoke_e2e.py" tests/e2e/
  )
  cp "$A/pytest-playwright/conftest.py" "$1/tests/e2e/"
  printf '[pytest]\ntestpaths = tests\n' > "$1/pytest.ini"
  printf 'pytest-playwright==0.10.0\n' > "$1/requirements-dev.txt"
}
P=$(novo py-ok); py_ok "$P"
roda "$P"
espera 0 "os E2E entram no comando do juiz" "Python pronto"
espera 0 "test_smoke_e2e.py  ativo" "smoke Python ativo"
espera 0 "tests/e2e/conftest.py define o base_url" "base_url vindo da fixture"
espera 0 "tests/e2e/conftest.py sobe o app para o pytest" "o pytest sobe o app"
nao_tem "AVISO" "Python pronto não devia ter aviso"
ok "Python: o cp do PDF, o conftest.py do modelo e testpaths: exit 0, sem aviso"

P=$(novo py-sem-ini); py_ok "$P"
rm "$P/pytest.ini"
roda "$P"
espera 1 "não roda o pytest" "sem pytest.ini o loop não acha o pytest"
P=$(novo py-testpaths); py_ok "$P"
printf '[pytest]\ntestpaths = tests/unit\n' > "$P/pytest.ini"
roda "$P"
espera 1 "não inclui tests/e2e/test_smoke_e2e.py" "testpaths sem a pasta do E2E"
P=$(novo py-pyproject); py_ok "$P"
rm "$P/pytest.ini" "$P/tests/e2e/conftest.py"
printf '[tool.pytest.ini_options]\ntestpaths = ["tests"]\naddopts = "--base-url http://localhost:8000"\n' > "$P/pyproject.toml"
roda "$P"
espera 0 "base_url configurado para o pytest-playwright" "pyproject.toml com [tool.pytest.ini_options]"
ok "Python: sem config do pytest e testpaths errado dão exit 1; pyproject.toml com base-url passa"

P=$(novo py-sem-servidor); py_ok "$P"
rm "$P/tests/e2e/conftest.py"
roda "$P"
espera 0 "sem base_url" "sem fixture nem base_url"
espera 0 "nenhum conftest.py sobe o app" "ninguém sobe o app no pytest"
printf '[pytest]\nbase_url = http://localhost:8000\ntestpaths = tests\n' > "$P/pytest.ini"
roda "$P"
espera 0 "base_url configurado para o pytest-playwright" "base_url no pytest.ini"
espera 0 "net::ERR_CONNECTION_REFUSED" "só o base_url no pytest.ini não sobe o app"
ok "Python: sem conftest.py que sobe o app, avisa (com ou sem base_url no pytest.ini)"

P=$(novo py-django); py_ok "$P"
cat > "$P/tests/e2e/conftest.py" <<'PY'
import os

import pytest

os.environ.setdefault("DJANGO_ALLOW_ASYNC_UNSAFE", "true")


@pytest.fixture(scope="session")
def base_url(live_server):
    return live_server.url
PY
roda "$P"
espera 0 "tests/e2e/conftest.py define o base_url" "Django: base_url do live_server"
nao_tem "nenhum conftest.py sobe o app" "o live_server do pytest-django sobe o app"
ok "Python com Django: o live_server do pytest-django conta como o app subindo no pytest"

# ------------------------------------------------------------------ nada e opção errada
V=$(novo vazio)
roda "$V"
espera 3 "Nenhum E2E encontrado" "projeto sem E2E"
roda "$PWD" --nao-existe
[ "$rc" = 64 ] || erro "opção desconhecida devia sair com 64 (veio $rc)"
ok "projeto sem E2E sai com 3; opção desconhecida, com 64"

# ------------------------------------------------------------------ modelos
for f in "$A"/*/*.py; do
  python3 -c 'import ast, sys; ast.parse(open(sys.argv[1], encoding="utf-8").read())' "$f" || erro "sintaxe: $f"
done
if command -v php >/dev/null; then
  for f in "$A"/*/*.php; do php -l "$f" >/dev/null || erro "sintaxe: $f"; done
  php_ok="php -l"
else
  php_ok="php ausente, pulado"
fi
for f in "$A"/playwright/*.spec.ts; do
  grep -q "from '@playwright/test'" "$f" || erro "$f sem import do @playwright/test"
done
grep -q "testDir: './tests/e2e'" "$A/playwright/playwright.config.ts" || erro "config sem testDir tests/e2e"
grep -q "webServer" "$A/playwright/playwright.config.ts" || erro "config sem webServer"
for f in "$A"/pest-browser/CadastroE2ETest.php "$A"/laravel-http/*.php "$A"/playwright/cadastro.spec.ts \
         "$A"/pytest-playwright/test_cadastro_e2e.py; do
  grep -Eq -- '->todo\(\)|test\.skip\(|@pytest\.mark\.skip' "$f" || erro "$(basename "$f") devia nascer pendente"
  grep -Eq 'AC-0[0-9]' "$f" || erro "$(basename "$f") sem o ID do critério"
done
for f in "$A"/pest-browser/SmokeTest.php "$A"/playwright/smoke.spec.ts "$A"/pytest-playwright/test_smoke_e2e.py; do
  ! grep -Ev '^ *(//|#)' "$f" | grep -Eq -- '->todo\(|test\.skip\(|@pytest\.mark\.skip' ||
    erro "$(basename "$f"): smoke não pode ser pendente"
done
grep -q '@pytest.fixture(scope="session")' "$A/pytest-playwright/conftest.py" ||
  erro "o conftest.py precisa do base_url com escopo de sessão (o pytest-playwright pede assim)"
for f in pedir-o-e2e.md pedir-o-ambiente.md; do [ -s "$A/$f" ] || erro "modelos/$f faltando"; done
ok "modelos: sintaxe Python e PHP ($php_ok), E2E pendentes com ID, smokes ativos, pedidos presentes"

echo "verificar.sh: $n grupos de checagem passaram."
