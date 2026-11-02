#!/usr/bin/env bash
# quality-gate.sh · Harness Lab · aula 2.2 · o hook que roda lint e teste
#
# Um script, dois modos, um para cada evento (veja .claude/settings.json):
#   quality-gate.sh post-edit   PostToolUse (Edit|Write): confere o arquivo que o Claude
#                               acabou de editar (sintaxe e estilo) e anota o arquivo.
#   quality-gate.sh stop        Stop: no fim da resposta, confere de novo os arquivos
#                               anotados e roda os testes ligados a eles.
#
# Como o Claude Code lê a resposta deste script:
#   exit 0               tudo certo, ou nada para conferir
#   exit 2 + stderr      problema no código: a mensagem vai para o modelo corrigir
#   exit 0 + JSON        problema no ambiente (Sail parado, config quebrada, demora):
#                        avisa o modelo e você, sem bloquear, para não virar loop
#
# Stacks: PHP (php -l, Pint, Pest ou PHPUnit, no host ou no Sail), JS e TS (ESLint,
# Vitest ou Jest), Python (ruff, pytest). Ferramenta que o projeto não tem é pulada.
# Precisa de jq. Roda no bash 3.2 do macOS. Teste sem o Claude Code:
#   echo '{"tool_input":{"file_path":"'"$PWD"'/app/X.php"}}' | .claude/hooks/quality-gate.sh post-edit
set -uo pipefail

# ---- Ajustes: mude aqui ou ponha a variável na frente do "command" no settings.json ----
ESTILO="${QG_ESTILO:-acusa}"                # acusa: só confere o estilo, como na aula
                                            # corrige: formata sozinho e segue
TESTE_NA_EDICAO="${QG_TESTE_NA_EDICAO:-0}"  # 1: roda o teste ligado também a cada edição
SAIL="${QG_SAIL:-auto}"                     # auto: usa o Sail se houver vendor/bin/sail
                                            # e um compose do Sail | sim | nao
LIMITE_EDICAO="${QG_LIMITE_EDICAO:-100}"    # prazo do post-edit inteiro, em segundos
                                            # (abaixo do timeout de 120 do settings.json)
LIMITE_STOP="${QG_LIMITE_STOP:-540}"        # prazo do stop inteiro (timeout de 600)
MAX_TESTES="${QG_MAX_TESTES:-15}"           # arquivos de teste por rodada, no máximo

command -v jq >/dev/null 2>&1 || {
  echo "quality-gate: instale o jq (apt install jq, ou brew install jq)" >&2
  exit 1   # erro que não bloqueia: você vê o aviso, o modelo segue
}

modo="${1:-}"
entrada=$(cat)
campo() { jq -r "$1 // empty" <<<"$entrada" 2>/dev/null; }

proj="${CLAUDE_PROJECT_DIR:-$PWD}"
proj=$(cd "$proj" 2>/dev/null && pwd -P) || exit 0
sessao=$(campo .session_id)
sessao="${sessao:-manual}"
pasta_estado="${TMPDIR:-/tmp}"
pasta_estado="${pasta_estado%/}/claude-quality-gate"
anotados="$pasta_estado/$(printf '%s' "$sessao" | tr -c 'A-Za-z0-9._-' '_').txt"

# Sem .pyc do hook: duas edições no mesmo segundo não reaproveitam bytecode velho.
export PYTHONDONTWRITEBYTECODE=1

NL=$'\n'
TAB=$'\t'
erros=""
avisos=""
sem_teste=""
LIMITE="$LIMITE_EDICAO"
falha() { erros+="## $1${NL}$2${NL}${NL}"; }
aviso() { avisos+="- $1${NL}"; }

# Saída que indica ambiente fora do ar, e não código errado.
RE_AMBIENTE='Sail is not running|Docker( or Podman)? is not running|Cannot connect to the Docker daemon|SQLSTATE\[HY000\] \[2002\]|Connection refused|could not find driver'

sem_cor() { sed $'s/\033\\[[0-9;]*[A-Za-z]//g'; }

# O prazo vale para o hook inteiro, não para cada comando: SECONDS conta desde o início do
# script, e cada comando só ganha o tempo que sobrou. Assim a soma nunca passa do timeout do
# settings.json, que cancelaria o hook e descartaria a saída sem avisar ninguém.
resta() { echo $((LIMITE - SECONDS)); }

com_limite() {   # com_limite SEGUNDOS comando...  (sai com 124 se estourar o tempo)
  local s="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then timeout "$s" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$s" "$@"   # macOS: brew install coreutils
  else "$@"; fi   # sem timeout: o prazo ainda vale entre um comando e outro, mas nada é interrompido
}

# confere ROTULO "CÓDIGOS OK" "CÓDIGOS DE AMBIENTE" comando...
# Roda dentro do prazo e classifica a saída. Devolve 0 (ok), 1 (código) ou 2 (ambiente).
confere() {
  local rotulo="$1" oks=" $2 " amb=" $3 126 127 " saida rc linha s
  shift 3
  s=$(resta)
  if [ "$s" -lt 1 ]; then
    aviso "$rotulo não rodou: o prazo de ${LIMITE}s do hook acabou antes (não é erro do código)"
    return 2
  fi
  saida=$(com_limite "$s" "$@" 2>&1)
  rc=$?
  saida=$(sem_cor <<<"$saida")
  case "$oks" in *" $rc "*) return 0 ;; esac
  if [ "$rc" = 124 ]; then
    aviso "$rotulo estourou o prazo de ${LIMITE}s do hook e foi interrompido (não é erro do código)"
    return 2
  fi
  linha=$(grep -m1 -E "$RE_AMBIENTE" <<<"$saida")
  if [ -z "$linha" ]; then
    case "$amb" in
      *" $rc "*) linha=$(grep . <<<"$saida" | head -3 | tr '\n' ' '); linha="${linha:-saiu com $rc}" ;;
    esac
  fi
  if [ -n "$linha" ]; then
    aviso "$rotulo não rodou: ${linha:0:240}"
    return 2
  fi
  falha "$rotulo" "$(tail -n 30 <<<"$saida")"
  return 1
}

stack_de() {
  case "$1" in
    *.blade.php) ;;                                   # template: php -l não ajuda
    *.php) echo php ;;
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.mts|*.cts) echo js ;;
    *.py) echo py ;;
  esac
}

marcadores() {
  case "$1" in
    php) echo composer.json ;;
    js) echo package.json ;;
    py) echo pyproject.toml setup.cfg setup.py pytest.ini tox.ini ;;
  esac
}

ignorado() {   # pastas que não são código seu
  case "/$1" in
    */vendor/*|*/node_modules/*|*/storage/*|*/bootstrap/cache/*|*/.claude/*|\
    */.venv/*|*/venv/*|*/dist/*|*/build/*|*/__pycache__/*) return 0 ;;
  esac
  return 1
}

# raiz_de ARQUIVO MARCADOR...: sobe da pasta do arquivo até achar o marcador da stack,
# sem passar da raiz do projeto. Resolve monorepo (backend/ e frontend/) e worktree.
raiz_de() {
  local d m
  d=$(dirname "$1")
  shift
  while :; do
    for m in "$@"; do [ -e "$d/$m" ] && { printf '%s\n' "$d"; return; }; done
    { [ "$d" = "$proj" ] || [ "$d" = / ]; } && break
    d=$(dirname "$d")
  done
  printf '%s\n' "$proj"
}

anota() {   # anota RAIZ STACK ARQUIVO: guarda para o stop
  local linha="$1$TAB$2$TAB$3"
  mkdir -p "$pasta_estado" 2>/dev/null || return 0
  grep -qxF -- "$linha" "$anotados" 2>/dev/null || printf '%s\n' "$linha" >>"$anotados"
}

# ---------------------------------------------------------------- PHP
usa_sail() {
  case "$SAIL" in sim) return 0 ;; nao) return 1 ;; esac
  [ -x vendor/bin/sail ] || return 1
  grep -qs sail compose.yaml compose.yml docker-compose.yml docker-compose.yaml
}

prepara_php() {   # tudo de PHP roda no mesmo lugar: no Sail, se o projeto usa, ou no host
  if usa_sail; then PHP=(vendor/bin/sail php); onde=" (no Sail)"
  else PHP=(php); onde=""; fi
  TESTE=""
  if [ -f vendor/bin/pest ]; then TESTE=vendor/bin/pest
  elif [ -f vendor/bin/phpunit ]; then TESTE=vendor/bin/phpunit; fi
}

confere_php() {   # confere_php ARQUIVO
  prepara_php
  confere "php -l $1$onde" "0" "" "${PHP[@]}" -l "$1"
  [ $? = 0 ] || return 0
  [ -f vendor/bin/pint ] || return 0
  if [ "$ESTILO" = corrige ]; then
    [ "$(resta)" -ge 1 ] && com_limite "$(resta)" "${PHP[@]}" vendor/bin/pint -q "$1" >/dev/null 2>&1
  else
    confere "pint --test $1$onde" "0" "" "${PHP[@]}" vendor/bin/pint --test "$1"
    [ $? = 1 ] && erros+="Para corrigir o estilo: ${PHP[*]} vendor/bin/pint $1${NL}${NL}"
  fi
  return 0
}

testes_php() {   # o próprio teste, o <Classe>Test.php e os testes que fazem "use" da classe
  local nome base ns
  nome=$(basename "$1")
  base="${nome%.php}"
  case "$nome" in *Test.php) echo "$1"; return 0 ;; esac
  [ -d tests ] || return 0
  find tests -type f -name "${base}Test.php" 2>/dev/null
  ns=$(sed -n 's/^namespace[[:space:]]\{1,\}\([^;[:space:]]*\).*/\1/p' "$1" | head -1)
  [ -n "$ns" ] && grep -rlF --include='*Test.php' "use $ns\\$base;" tests 2>/dev/null
  return 0
}

roda_testes_php() {
  prepara_php
  [ -n "$TESTE" ] || return 0
  confere "$(basename "$TESTE") $*$onde" "0" "" "${PHP[@]}" "$TESTE" "$@"
  return 0
}

# ---------------------------------------------------------------- JS e TS
acha_bin() {   # acha_bin NOME: node_modules/.bin/NOME aqui ou acima (workspaces sobem os binários)
  local d="$PWD"
  while :; do
    [ -x "$d/node_modules/.bin/$1" ] && { printf '%s\n' "$d/node_modules/.bin/$1"; return 0; }
    { [ "$d" = "$proj" ] || [ "$d" = / ]; } && return 1
    d=$(dirname "$d")
  done
}

confere_js() {
  local eslint
  eslint=$(acha_bin eslint) || return 0
  if [ "$ESTILO" = corrige ]; then
    confere "eslint --fix $1" "0" "2" "$eslint" --fix "$1"
  else
    confere "eslint $1" "0" "2" "$eslint" "$1"
    [ $? = 1 ] && erros+="Parte disso sai sozinho com: npx eslint --fix $1${NL}${NL}"
  fi
  return 0
}

runner_js() {   # o runner que o projeto usa: pelo script "test", pela config, ou o que existir
  local script
  script=$(jq -r '.scripts.test // ""' package.json 2>/dev/null)
  case "$script" in
    *vitest*) acha_bin vitest && return 0 ;;
    *jest*) acha_bin jest && return 0 ;;
  esac
  if ls vitest.config.* vite.config.* >/dev/null 2>&1; then acha_bin vitest && return 0; fi
  if ls jest.config.* >/dev/null 2>&1 || jq -e .jest package.json >/dev/null 2>&1; then
    acha_bin jest && return 0
  fi
  acha_bin vitest || acha_bin jest
}

roda_testes_js() {   # o runner acha os testes pelos imports
  local bin
  bin=$(runner_js) || return 0
  case "$bin" in
    */vitest) confere "vitest related $*" "0" "" "$bin" related --run "$@" ;;
    */jest) confere "jest --findRelatedTests $*" "0" "" "$bin" --findRelatedTests --passWithNoTests "$@" ;;
  esac
  return 0
}

# ---------------------------------------------------------------- Python
py_bin() {   # py_bin NOME: prefere o da .venv do projeto
  local v
  for v in "$PWD/.venv" "$PWD/venv" "$proj/.venv" "$proj/venv"; do
    [ -x "$v/bin/$1" ] && { printf '%s\n' "$v/bin/$1"; return 0; }
  done
  command -v "$1" 2>/dev/null
}

confere_py() {
  local ruff py
  ruff=$(py_bin ruff)
  if [ -n "$ruff" ]; then
    if [ "$ESTILO" = corrige ]; then confere "ruff check --fix $1" "0" "2" "$ruff" check --fix "$1"
    else confere "ruff check $1" "0" "2" "$ruff" check "$1"; fi
    return 0
  fi
  py=$(py_bin python3) || py=$(py_bin python) || return 0
  confere "sintaxe python $1" "0" "" "$py" -c \
    'import ast,sys; ast.parse(open(sys.argv[1],"rb").read(), sys.argv[1])' "$1"
  return 0
}

testes_py() {
  local nome base
  nome=$(basename "$1")
  base="${nome%.py}"
  case "$nome" in test_*.py|*_test.py) echo "$1"; return 0 ;; esac
  find . -type f \( -name "test_${base}.py" -o -name "${base}_test.py" \) \
    -not -path './.venv/*' -not -path './venv/*' -not -path '*/node_modules/*' 2>/dev/null |
    sed 's|^\./||'
}

roda_testes_py() {
  local pytest
  pytest=$(py_bin pytest) || return 0
  [ -n "$pytest" ] || return 0
  confere "pytest $*" "0 5" "3 4" "$pytest" -q "$@"   # 5: nenhum teste coletado
  return 0
}

# ---------------------------------------------------------------- comum
testa_grupo() {   # testa_grupo STACK ARQUIVO...  (na raiz da stack)
  local stack="$1" lista="" a t
  shift
  if [ "$stack" = js ]; then roda_testes_js "$@"; return 0; fi
  for a in "$@"; do lista+="$("testes_$stack" "$a")${NL}"; done
  lista=$(printf '%s' "$lista" | grep . | sort -u | head -n "$MAX_TESTES")
  if [ -z "$lista" ]; then sem_teste+=" $*"; return 0; fi
  set --
  while IFS= read -r t; do set -- "$@" "$t"; done <<<"$lista"
  "roda_testes_$stack" "$@"
}

responde() {   # responde EVENTO
  if [ -n "$erros" ]; then
    {
      echo "quality-gate ($1): achei problema no código. Corrija antes de seguir:"
      echo
      printf '%s' "$erros"
      [ -z "$avisos" ] || printf 'Além disso, parte da checagem não rodou:\n%s' "$avisos"
    } >&2
    exit 2
  fi
  if [ -n "$avisos" ]; then
    local msg="quality-gate ($1): parte da checagem não rodou por causa do ambiente, não do código:${NL}${avisos}"
    if [ "$1" = PostToolUse ]; then
      jq -nc --arg m "$msg" '{systemMessage: $m,
        hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $m}}'
    else
      jq -nc --arg m "$msg" '{systemMessage: $m}'   # no Stop, só você vê: não reabre a conversa
    fi
  fi
  exit 0
}

post_edit() {
  local arquivo d stack raiz rel
  arquivo=$(campo .tool_input.file_path)
  [ -n "$arquivo" ] && [ -f "$arquivo" ] || exit 0
  d=$(cd "$(dirname "$arquivo")" 2>/dev/null && pwd -P) || exit 0
  arquivo="$d/$(basename "$arquivo")"
  case "$arquivo" in "$proj"/*) ;; *) exit 0 ;; esac   # fora do projeto: não é com a gente
  stack=$(stack_de "$arquivo")
  [ -n "$stack" ] || exit 0
  ignorado "${arquivo#"$proj"/}" && exit 0
  # shellcheck disable=SC2046
  raiz=$(raiz_de "$arquivo" $(marcadores "$stack"))
  cd "$raiz" || exit 0
  rel="${arquivo#"$raiz"/}"
  anota "$raiz" "$stack" "$rel"
  "confere_$stack" "$rel"
  if [ "$TESTE_NA_EDICAO" = 1 ] && [ -z "$erros" ] && [ -z "$avisos" ]; then
    testa_grupo "$stack" "$rel"
  fi
  responde PostToolUse
}

stop() {
  local ativo grupos raiz stack rels a antes
  [ -s "$anotados" ] || exit 0
  LIMITE="$LIMITE_STOP"
  ativo=$(campo .stop_hook_active)
  grupos=$(cut -f1,2 "$anotados" | sort -u)
  while IFS="$TAB" read -r raiz stack; do
    [ -n "$raiz" ] && [ -d "$raiz" ] && cd "$raiz" || continue
    rels=$(awk -F'\t' -v r="$raiz" -v s="$stack" '$1 == r && $2 == s { print $3 }' "$anotados" | sort -u)
    set --
    while IFS= read -r a; do [ -n "$a" ] && [ -f "$a" ] && set -- "$@" "$a"; done <<<"$rels"
    [ $# -gt 0 ] || continue
    antes="$erros"
    for a in "$@"; do "confere_$stack" "$a"; done
    [ "$erros" = "$antes" ] && testa_grupo "$stack" "$@"   # código quebrado: nem testa
  done <<<"$grupos"

  if [ -n "$erros" ] && [ "$ativo" = true ]; then
    # Já bloqueou uma vez nesta resposta e ainda falha: libera e conta para você, sem loop.
    jq -nc --arg m "quality-gate (Stop): ainda falha depois de uma volta de correção. Liberei o fim da resposta para não entrar em loop.${NL}${NL}${erros}" '{systemMessage: $m}'
    exit 0
  fi
  [ -n "$erros" ] && responde Stop   # a lista fica: a próxima resposta confere de novo
  rm -f "$anotados"
  [ -n "$avisos" ] && responde Stop
  if [ -n "$sem_teste" ]; then
    jq -nc --arg m "quality-gate (Stop): lint ok. Nenhum teste ligado a:$sem_teste" '{systemMessage: $m}'
  fi
  exit 0
}

case "$modo" in
  post-edit) post_edit ;;
  stop) stop ;;
  *) echo "uso: quality-gate.sh post-edit|stop  (lê o JSON do hook no stdin)" >&2; exit 1 ;;
esac
