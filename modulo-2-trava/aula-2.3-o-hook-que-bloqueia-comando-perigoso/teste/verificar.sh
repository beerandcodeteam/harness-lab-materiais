#!/usr/bin/env bash
# verificar.sh · aula 2.3 · roda no ~/projeto da sandbox, depois dos comandos do material.
# Prova que os hooks foram instalados e respondem certo a JSON falso, igual ao que o
# Claude Code manda. O Jev é testado contra um servidor falso local (JEV_GUARD_URL):
# nenhuma chamada à API real da TypeSafe sai daqui.
set -euo pipefail

H=.claude/hooks
n=0
ok() { n=$((n + 1)); printf '  ok  %s\n' "$1"; }
erro() { printf 'FALHOU: %s\n' "$1" >&2; exit 1; }

# ------------------------------------------------------------------ instalação
for f in guard-destructive.py guard-jev.py protege-env.sh log-comandos.sh; do
  [ -f "$H/$f" ] || erro "$H/$f não instalado"
done
[ -x "$H/protege-env.sh" ] && [ -x "$H/log-comandos.sh" ] || erro "os .sh precisam de chmod +x"
python3 -m py_compile "$H/guard-destructive.py" "$H/guard-jev.py"
bash -n "$H/protege-env.sh" && bash -n "$H/log-comandos.sh"
S=.claude/settings.json
jq -e '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[]
       | select((.command | test("guard-destructive.py")) and .onFailure == "block")' "$S" >/dev/null ||
  erro "guard-destructive.py sem PreToolUse Bash com onFailure block"
jq -e '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[]
       | select((.command | test("guard-jev.py")) and (has("onFailure") | not))' "$S" >/dev/null ||
  erro "guard-jev.py devia estar ligado sem onFailure (falha aberto)"
jq -e '.hooks.PreToolUse[] | select(.matcher == "Read|Edit|Write") | .hooks[]
       | select(.command | test("protege-env.sh"))' "$S" >/dev/null || erro "protege-env.sh não ligado"
for ev in PostToolUse PostToolUseFailure; do
  jq -e --arg ev "$ev" '.hooks[$ev][] | select(.matcher == "Bash") | .hooks[]
       | select(.command | test("log-comandos.sh"))' "$S" >/dev/null || erro "log-comandos.sh fora do $ev"
done
jq -e '.permissions.deny | index("Read(./.env)")' "$S" >/dev/null || erro "sem permissions.deny Read(./.env)"
jq -e '.permissions.allow | index("Bash(git status)")' "$S" >/dev/null ||
  erro "o instalar.sh apagou a permissão que o projeto já tinha"
ok "4 hooks instalados, settings somado ao do projeto (o allow antigo ficou)"

export CLAUDE_PROJECT_DIR="$PWD"
TMPDIR=$(mktemp -d)
export TMPDIR
bash_json() { jq -nc --arg c "$1" --arg d "$PWD" '{hook_event_name: "PreToolUse", tool_name: "Bash",
  tool_input: {command: $c}, cwd: $d}'; }
# decisao HOOK COMANDO → deny | ask | libera
decisao() {
  local saida
  saida=$(bash_json "$2" | python3 "$H/$1")
  if [ -z "$saida" ]; then echo libera; return; fi
  jq -r '.hookSpecificOutput.permissionDecision // "libera"' <<<"$saida"
}

# ------------------------------------------------------------------ guard-destructive.py
printf 'rascunho que só existe aqui\n' > rascunho.txt          # untracked: o git não devolve
mkdir -p node_modules/pacote && printf 'x\n' > node_modules/pacote/i.js
for c in 'php artisan migrate:fresh --seed' './vendor/bin/sail artisan migrate:fresh' \
         'php artisan db:wipe' 'php artisan migrate --force' 'rails db:reset' \
         'npx prisma migrate reset' 'python manage.py flush' 'git reset --hard HEAD~1' \
         'git push origin main --force' 'git checkout -- app' 'git clean -fd' \
         'docker compose down -v' 'ssh deploy@servidor' 'rsync -a . deploy@servidor:/srv' \
         'mysql -e "DROP TABLE users"' 'rm rascunho.txt' 'git status && rm -f rascunho.txt' \
         'echo $(rm rascunho.txt)' 'bash -c "rm rascunho.txt"' 'rm -rf /' 'rm -rf ~' \
         'cat .env.production'; do
  [ "$(decisao guard-destructive.py "$c")" = deny ] || erro "guard-destructive deixou passar: $c"
done
ok "guard-destructive barra banco, git, docker, produção e rm do que o git não devolve"
for c in 'php artisan migrate' 'php artisan migrate:status' 'npm test' 'git status' \
         'git push origin main' 'git checkout -b nova' 'rm -rf node_modules' 'rm README.md' \
         'npx prisma migrate dev' 'ls -la'; do
  [ "$(decisao guard-destructive.py "$c")" = libera ] || erro "guard-destructive barrou o inofensivo: $c"
done
ok "guard-destructive libera o inofensivo (migrate, testes, push normal, node_modules, arquivo no git)"
[ -f rascunho.txt ] || erro "o hook não pode apagar nada"
saida=$(printf 'isto não é JSON' | python3 "$H/guard-destructive.py")
[ "$(jq -r .hookSpecificOutput.permissionDecision <<<"$saida")" = deny ] || erro "entrada inválida devia negar"
python3 "$H/guard-destructive.py" --eval 'php artisan migrate:fresh' | grep -q '^bloqueia' ||
  erro "--eval não bloqueou migrate:fresh"
ok "guard-destructive falha fechado e tem o modo --eval"

# ------------------------------------------------------------------ guard-jev.py
saida=$(bash_json 'php artisan migrate:fresh' | env -u TYPESAFE_API_KEY python3 "$H/guard-jev.py")
[ -z "$saida" ] || erro "sem TYPESAFE_API_KEY o guard-jev devia sair calado: $saida"
ok "guard-jev sem chave: sai calado e deixa o guard de regras trabalhar"

# Servidor falso da TypeSafe: migrate:fresh → destroys_database_data alto; rm -rf storage → ask; resto baixo.
porta_arq="$TMPDIR/porta"; pedidos="$TMPDIR/pedidos.log"
python3 - "$porta_arq" "$pedidos" <<'PY' &
import json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer
porta_arq, pedidos = sys.argv[1], sys.argv[2]
class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_POST(self):
        corpo = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        cmd = corpo["state"]["command"]
        open(pedidos, "a").write(cmd + "\n")
        assert self.headers["Authorization"] == "Bearer chave-de-teste"
        assert set(corpo["questions"]) == {"deletes_unrecoverable_files", "destroys_database_data",
                                           "discards_git_work", "touches_production", "damage_severity"}
        db = 0.97 if "fresh" in cmd else 0.05
        arq = 0.7 if "storage" in cmd else 0.05
        r = {"model": "jev-falso", "answers": {
            "deletes_unrecoverable_files": {"type": "noul", "noul": arq},
            "destroys_database_data": {"type": "noul", "noul": db},
            "discards_git_work": {"type": "noul", "noul": 0.02},
            "touches_production": {"type": "noul", "noul": 0.01},
            "damage_severity": {"type": "score", "score": 0.4}}}
        b = json.dumps(r).encode()
        self.send_response(200); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)
s = HTTPServer(("127.0.0.1", 0), H)
open(porta_arq, "w").write(str(s.server_port))
s.serve_forever()
PY
srv=$!
trap 'kill $srv 2>/dev/null || true' EXIT
for _ in $(seq 50); do [ -s "$porta_arq" ] && break; sleep 0.1; done
[ -s "$porta_arq" ] || erro "servidor falso não subiu"
export TYPESAFE_API_KEY=chave-de-teste JEV_GUARD_URL="http://127.0.0.1:$(cat "$porta_arq")/v1/systemone"
[ "$(decisao guard-jev.py 'php artisan migrate:fresh')" = deny ] || erro "guard-jev não negou com noul 0.97"
[ "$(decisao guard-jev.py 'rm -rf storage/app')" = ask ] || erro "guard-jev não perguntou com noul 0.7"
[ "$(decisao guard-jev.py 'npm test')" = libera ] || erro "guard-jev barrou com noul baixo"
: > "$pedidos"
[ "$(decisao guard-jev.py 'git status && ls -la')" = libera ] || erro "leitura devia passar"
[ ! -s "$pedidos" ] || erro "comando só de leitura não devia chamar o Jev"
ok "guard-jev: noul alto nega, médio pergunta, baixo libera; leitura nem chama a API"
grep -q '"decision": "deny"' "$TMPDIR/claude-jev-guard.jsonl" || erro "decisão não foi para o log de calibração"
kill $srv 2>/dev/null || true
export JEV_GUARD_URL="http://127.0.0.1:9/v1/systemone"
saida=$(bash_json 'php artisan migrate:fresh' | python3 "$H/guard-jev.py")
jq -e '.systemMessage | test("indisponível")' <<<"$saida" >/dev/null || erro "API fora do ar devia avisar"
jq -e 'has("hookSpecificOutput") | not' <<<"$saida" >/dev/null || erro "API fora do ar devia liberar"
unset TYPESAFE_API_KEY JEV_GUARD_URL
ok "guard-jev com a API fora do ar: libera e avisa você (falha aberto, de propósito)"

# ------------------------------------------------------------------ protege-env.sh
arq_json() { jq -nc --arg t "$1" --arg f "$PWD/$2" '{tool_name: $t, tool_input: {file_path: $f}}'; }
for par in 'Read .env' 'Edit .env' 'Write .env.production'; do
  set -- $par
  saida=$(arq_json "$1" "$2" | "$H/protege-env.sh")
  [ "$(jq -r .hookSpecificOutput.permissionDecision <<<"$saida")" = deny ] || erro "protege-env liberou $par"
done
[ -z "$(arq_json Read .env.example | "$H/protege-env.sh")" ] || erro ".env.example devia passar"
[ -z "$(arq_json Edit app/config.php | "$H/protege-env.sh")" ] || erro "arquivo comum devia passar"
ok "protege-env: Read, Edit e Write no .env negados; .env.example e código liberados"

# ------------------------------------------------------------------ log-comandos.sh
rm -f .claude/logs/comandos.jsonl
jq -nc '{hook_event_name: "PostToolUse", tool_input: {command: "npm test"}, cwd: "/p"}' | "$H/log-comandos.sh"
jq -nc '{hook_event_name: "PostToolUseFailure", tool_input: {command: "ls nada"},
  cwd: "/p", error: "Exit code 2\nls: cannot access"}' | "$H/log-comandos.sh"
[ "$(jq -r .status .claude/logs/comandos.jsonl | tr '\n' ' ')" = "ok falhou " ] || erro "log sem ok e falhou"
[ "$(jq -r 'select(.status == "falhou") | .erro' .claude/logs/comandos.jsonl)" = "Exit code 2" ] ||
  erro "log sem a primeira linha do erro"
git check-ignore -q .claude/logs/comandos.jsonl || erro ".claude/logs/ devia ficar fora do git"
ok "log-comandos: uma linha por comando, ok e falhou, fora do git"

echo "verificar.sh: $n grupos de checagem passaram."
