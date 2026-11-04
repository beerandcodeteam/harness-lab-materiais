#!/usr/bin/env bash
# testa-hooks.sh · Harness Lab · aula 2.4 · teste os hooks ANTES de confiar neles
#
#   bash testes/testa-hooks.sh          confere o settings e roda os casos em .claude/hooks
#   bash testes/testa-hooks.sh PASTA    roda só os casos, com os hooks de outra PASTA
#                                       (para provar que o teste pega um hook quebrado)
#
# Hook é um programa que recebe um JSON no stdin. Este script manda o mesmo JSON que o
# Claude Code manda e lê a resposta do jeito que o Claude Code lê:
#   exit 2                                   bloqueia
#   exit 0 + um objeto JSON e nada mais      vale o que o JSON decide (deny, ask, block)
#   exit 0 + texto ou nada                   libera
#   exit 0 + JSON quebrado                   json-invalido (no Claude Code: libera)
#   qualquer outro exit                      falhou(exit N) (no Claude Code: libera,
#                                            a não ser com "onFailure": "block")
#
# Parte 1, só sem PASTA: confere cada hook dos settings do projeto. Caminho que não
# existe, script sem chmod +x, caminho relativo, PreToolUse sem onFailure e Stop que
# ignora o stop_hook_active.
# Parte 2: os casos de testes/casos-hooks.sh. Edite os casos lá, não aqui.
#
# Sai com 0 se nada falhou (avisos não reprovam), 1 se algo falhou. Precisa de jq.
# Ajuste: TESTA_LIMITE=30 bash testes/testa-hooks.sh (segundos por hook, padrão 15).
set -uo pipefail

raiz="$(cd "$(dirname "$0")/.." && pwd)"
LIMITE="${TESTA_LIMITE:-15}"
command -v jq >/dev/null 2>&1 || {
  echo "testa-hooks: precisa de jq (apt install jq, ou brew install jq)" >&2
  exit 2
}

if [ -n "${1:-}" ]; then
  case "$1" in
    /*) pasta="$1" ;;
    *) pasta="$PWD/$1"; [ -d "$pasta" ] || pasta="$raiz/$1" ;;
  esac
  [ -d "$pasta" ] || { echo "testa-hooks: a pasta $1 não existe" >&2; exit 2; }
  pasta="$(cd "$pasta" && pwd)"
  confere_settings=0
else
  pasta="$raiz/.claude/hooks"
  confere_settings=1
fi
export CLAUDE_PROJECT_DIR="$raiz"

if [ -t 1 ]; then v=$'\033[32m'; r=$'\033[31m'; a=$'\033[33m'; f=$'\033[0m'
else v=""; r=""; a=""; f=""; fi
ok=0; ruim=0; avisos=0; pulados=0
linha() { local n=$((46 - ${#3})); [ "$n" -gt 0 ] || n=1; printf '  %s  %s%*s %s\n' "$1" "$2$3" "$n" "" "$4"; }
passou() { ok=$((ok + 1)); linha "$v✓$f" "" "$1" "$2"; }
falhou() { ruim=$((ruim + 1)); linha "$r✗$f" "" "$1" "$2"; }
avisou() { avisos=$((avisos + 1)); linha "$a!$f" "" "$1" "$2"; }

# Limite de tempo: timeout (Linux), gtimeout (macOS com coreutils) ou nenhum.
if command -v timeout >/dev/null 2>&1; then T=(timeout "$LIMITE")
elif command -v gtimeout >/dev/null 2>&1; then T=(gtimeout "$LIMITE")
else T=(); echo "${a}aviso${f}: sem timeout no sistema, um hook que trava vai travar o teste"; fi

# roda JSON PROGRAMA [ARGS...]: guarda saida (stdout) e codigo
roda() {
  local json="$1"
  shift
  saida=$(cd "$raiz" && printf '%s' "$json" | ${T[@]+"${T[@]}"} "$@" 2>/dev/null)
  codigo=$?
}

# JSON falso, com os campos que o Claude Code manda.
sessao="testa-hooks-$$"
bash_json() {   # bash_json 'COMANDO' [EVENTO]
  jq -nc --arg c "$1" --arg ev "${2:-PreToolUse}" --arg cwd "$raiz" --arg s "$sessao" \
    '{session_id: $s, cwd: $cwd, permission_mode: "default", hook_event_name: $ev,
      tool_name: "Bash", tool_input: {command: $c}}'
}
arq_json() {    # arq_json FERRAMENTA CAMINHO [EVENTO]   (caminho relativo = dentro do projeto)
  local p="$2"
  case "$p" in /*) ;; *) p="$raiz/$p" ;; esac
  jq -nc --arg t "$1" --arg p "$p" --arg ev "${3:-PreToolUse}" --arg cwd "$raiz" --arg s "$sessao" \
    '{session_id: $s, cwd: $cwd, permission_mode: "default", hook_event_name: $ev,
      tool_name: $t, tool_input: {file_path: $p}}'
}
stop_json() {   # stop_json true|false
  jq -nc --argjson a "$1" --arg cwd "$raiz" --arg s "$sessao" \
    '{session_id: $s, cwd: $cwd, hook_event_name: "Stop", stop_hook_active: $a,
      last_assistant_message: "Pronto."}'
}

# Lê a resposta do hook como o Claude Code lê (veja o topo do arquivo).
classifica() {
  local s="$1" c="$2" limpo d
  if [ "$c" = 124 ] && [ ${#T[@]} -gt 0 ]; then echo "travou(>${LIMITE}s)"; return; fi
  [ "$c" = 2 ] && { echo bloqueia; return; }
  [ "$c" = 0 ] || { echo "falhou(exit $c)"; return; }
  limpo=$(printf '%s' "$s" | tr -d '[:space:]')
  case "$limpo" in
    \{*\}) ;;
    *) echo libera; return ;;
  esac
  if [ "$(jq -s 'length == 1 and (.[0] | type) == "object"' <<<"$s" 2>/dev/null)" != true ]; then
    echo json-invalido; return
  fi
  d=$(jq -r '.hookSpecificOutput.permissionDecision // .decision // empty' <<<"$s")
  case "$d" in
    deny|block) echo bloqueia ;;
    ask) echo pergunta ;;
    *) echo libera ;;
  esac
}

caso() {   # caso "HOOK [args]" "descrição" JSON ESPERADO
  local spec="$1" desc="$2" json="$3" esperado="$4" nome resto hook obtido interp
  nome="${spec%% *}"
  resto=""
  [ "$nome" = "$spec" ] || resto="${spec#* }"
  hook="$pasta/$nome"
  if [ ! -e "$hook" ]; then
    pulados=$((pulados + 1))
    # avisa uma vez por hook, não uma vez por caso
    [ "$nome" = "${ultimo_pulado:-}" ] || linha "-" "" "$nome não existe" "casos pulados"
    ultimo_pulado="$nome"
    return
  fi
  # .sh e sem extensão rodam direto (sem chmod +x, falham como no Claude Code);
  # os outros, pelo interpretador, como o settings costuma chamar (python3 x.py)
  case "$nome" in
    *.py) interp=python3 ;; *.js|*.mjs|*.cjs) interp=node ;; *.rb) interp=ruby ;; *.php) interp=php ;;
    *) interp="" ;;
  esac
  # shellcheck disable=SC2086
  if [ -n "$interp" ]; then roda "$json" "$interp" "$hook" $resto
  else roda "$json" "$hook" $resto; fi
  obtido=$(classifica "$saida" "$codigo")
  if [ "$obtido" = "$esperado" ]; then passou "$desc" "$obtido"
  else falhou "$desc" "esperado $esperado, veio $obtido"; fi
}

# ------------------------------------------------------------------ parte 1: settings
# caminho_do_script COMANDO: o script que o comando chama (vazio se for um programa do PATH)
caminho_do_script() {
  # A raiz entra só depois de separar as palavras: caminho com espaço não quebra a conta.
  local c="$1" primeiro segundo m=$'\001'
  c="${c//\"\$CLAUDE_PROJECT_DIR\"/$m}"
  c="${c//\"\${CLAUDE_PROJECT_DIR\}\"/$m}"
  c="${c//\$\{CLAUDE_PROJECT_DIR\}/$m}"
  c="${c//\$CLAUDE_PROJECT_DIR/$m}"
  # tira VAR=valor da frente
  while [[ "$c" =~ ^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+(.*)$ ]]; do c="${BASH_REMATCH[1]}"; done
  primeiro="${c%% *}"; primeiro="${primeiro//\"/}"; primeiro="${primeiro//\'/}"
  segundo="${c#"${c%% *}"}"; segundo="${segundo# }"; segundo="${segundo%% *}"
  segundo="${segundo//\"/}"; segundo="${segundo//\'/}"
  primeiro="${primeiro//$m/$raiz}"; segundo="${segundo//$m/$raiz}"
  case "$(basename "$primeiro")" in
    bash|sh|zsh|node|python|python3|php|ruby|deno|bun) echo "interp $segundo" ;;
    *) echo "exec $primeiro" ;;
  esac
}

confere_hook() {   # confere_hook ARQUIVO_SETTINGS LINHA_JSON
  local s="$1" h="$2" ev m cmd onf asy args tipo script rot alvo
  ev=$(jq -r .ev <<<"$h"); m=$(jq -r .m <<<"$h"); cmd=$(jq -r .cmd <<<"$h")
  onf=$(jq -r .onf <<<"$h"); asy=$(jq -r .async <<<"$h"); args=$(jq -r .args <<<"$h")
  if [ "$args" != "null" ]; then   # exec form: "command" é o programa, "args" os argumentos
    read -r tipo script <<<"$(caminho_do_script "$cmd $(jq -r '.args[0] // ""' <<<"$h")")"
  else
    read -r tipo script <<<"$(caminho_do_script "$cmd")"
  fi
  rot="$ev${m:+ ($m)} $(basename "${script:-?}")"
  rot="${rot:0:46}"
  local avisos_antes="$avisos"

  if [[ "$script" != */* ]]; then
    if [ -n "$script" ] && ! command -v "$script" >/dev/null 2>&1; then
      falhou "$rot" "$script não está no PATH: o hook nunca roda"; return
    fi
  else
    case "$script" in /*) alvo="$script" ;; *) alvo="$raiz/$script" ;; esac
    case "$cmd $args" in
      *CLAUDE_PROJECT_DIR*|/*) ;;
      *) avisou "$rot" "caminho relativo: quebra quando o modelo dá cd. Use \"\$CLAUDE_PROJECT_DIR\"/..." ;;
    esac
    if [ ! -e "$alvo" ]; then falhou "$rot" "$script não existe: o hook nunca roda (e libera)"; return; fi
    if [ "$tipo" = exec ] && [ ! -x "$alvo" ]; then
      falhou "$rot" "sem chmod +x: não inicia (e libera)"; return
    fi
  fi

  case "$ev" in
    Stop|SubagentStop|TaskCompleted|TeammateIdle)
      [ "$onf" = null ] || avisou "$rot" "onFailure não tem efeito em $ev" ;;
    *) [ "$asy" = true ] && [ "$onf" != null ] && avisou "$rot" "onFailure não tem efeito em hook async" ;;
  esac
  if [ "$ev" = PreToolUse ] && [ "$onf" = null ] && [ "$asy" != true ]; then
    avisou "$rot" "sem onFailure: se quebrar, a ação segue"
  fi

  if [ "$ev" = Stop ] || [ "$ev" = SubagentStop ]; then
    if [ "$args" != null ]; then
      local -a av=()
      while IFS= read -r x; do av+=("${x//\$\{CLAUDE_PROJECT_DIR\}/$raiz}"); done < <(jq -r '.args[]' <<<"$h")
      roda "$(stop_json true)" "$cmd" ${av[@]+"${av[@]}"}
    else
      roda "$(stop_json true)" sh -c "$cmd"
    fi
    case "$codigo" in
      2) falhou "$rot" "ignora stop_hook_active: exit 2 de novo, loop" ;;
      124) avisou "$rot" "passou de ${LIMITE}s com stop_hook_active=true" ;;
      *) passou "$rot" "respeita stop_hook_active" ;;
    esac
    return
  fi
  [ "$avisos" != "$avisos_antes" ] || passou "$rot" "existe e inicia"
}

if [ "$confere_settings" = 1 ]; then
  echo "settings (hooks ligados neste projeto)"
  achou=0
  for s in .claude/settings.json .claude/settings.local.json; do
    [ -f "$raiz/$s" ] || continue
    achou=1
    if ! jq empty "$raiz/$s" 2>/dev/null; then falhou "$s" "JSON inválido: nenhum hook carrega"; continue; fi
    while IFS= read -r h; do
      [ -n "$h" ] && confere_hook "$s" "$h"
    done < <(jq -c '.hooks // {} | to_entries[] | .key as $ev | .value[]? | (.matcher // "") as $m
                    | .hooks[]? | select((.type // "command") == "command")
                    | {ev: $ev, m: $m, cmd: .command, args: (.args // null), onf: (.onFailure // null),
                       async: ((.async // false) or (.asyncRewake // false))}' "$raiz/$s")
  done
  [ "$achou" = 1 ] || echo "  (nenhum .claude/settings.json neste projeto)"
  echo
fi

# ------------------------------------------------------------------ parte 2: casos
casos="$raiz/testes/casos-hooks.sh"
if [ -f "$casos" ]; then
  echo "casos (hooks de ${pasta#"$raiz"/})"
  # shellcheck source=/dev/null
  . "$casos"
else
  echo "sem $casos: só a parte do settings rodou"
fi

echo
printf '%s passaram, %s falharam, %s avisos, %s pulados.\n' "$ok" "$ruim" "$avisos" "$pulados"
[ "$ruim" = 0 ]
