#!/usr/bin/env bash
# verificar.sh · aula 5.3 · roda no ~/projeto da sandbox, depois dos comandos do material.
# Prova que o aviso funciona sem gastar token e sem rede externa: um servidor falso em
# 127.0.0.1 faz o papel da Evolution API, do Telegram e do Discord; um "claude" falso faz
# o papel das sessões do ralph; um "codex" falso garante que o Codex nunca roda.
set -euo pipefail

n=0
ok() { n=$((n + 1)); printf '  ok  %s\n' "$1"; }
erro() { printf 'FALHOU: %s\n' "$1" >&2; exit 1; }
AULA="$HOME/harness-lab-materiais/modulo-5-loop/aula-5.3-avisa-quando-termina-ou-trava"
S=.claude/scripts
TMPDIR=$(mktemp -d)
export TMPDIR
pids=()
trap 'for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done' EXIT

# ------------------------------------------------------------------ instalação
for f in ralph.sh aviso-env.sh aviso.sh vigia.sh loop.sh confere-phases.sh shim/claude; do
  [ -x "$S/$f" ] || erro "$S/$f não instalado ou sem chmod +x"
  bash -n "$S/$f" || erro "sintaxe de $S/$f"
  cmp -s "$S/$f" "$AULA/projeto/$S/$f" || erro "$S/$f diferente do da aula"
done
cmp -s "$S/.gitignore" "$AULA/projeto/$S/.gitignore" || erro "$S/.gitignore não instalado"
git ls-files --error-unmatch "$S/ralph.sh" "$S/aviso-env.sh" "$S/vigia.sh" "$S/.gitignore" >/dev/null 2>&1 ||
  erro "os scripts deviam estar commitados (o loop.sh exige árvore limpa)"
ok "7 scripts e o .gitignore instalados, com chmod +x, iguais aos da aula e commitados"

# ------------------------------------------------------------------ segredo fora do repositório
E="$HOME/.config/harness-lab/aviso.env"
[ -f "$E" ] || erro "$E não existe"
[ "$(stat -c %a "$E")" = 600 ] || erro "$E devia ter chmod 600"
[ -L "$S/.env" ] && [ "$(readlink -f "$S/.env")" = "$(readlink -f "$E")" ] || erro "$S/.env devia ser um link para $E"
git check-ignore -q "$S/.env" || erro "$S/.env não está ignorado pelo git"
[ -z "$(git status --porcelain)" ] || erro "árvore suja depois dos comandos: $(git status --porcelain | head -3)"
! grep -qE '^[A-Z_]+=.+' "$AULA/modelos/aviso.env.exemplo" || erro "o modelo do aviso.env não pode vir preenchido"
ok "aviso.env em ~/.config com 600, link .claude/scripts/.env ignorado pelo git, árvore limpa"

# ------------------------------------------------------------------ passo 4 com um .env que já existe
# O bloco do passo 4, como está no PDF (lido do comandos.json), num projeto onde o aluno já
# criou o .env como na aula: ele vira o aviso.env, não some. Rodar de novo não muda nada, e
# noutro projeto com .env próprio nada é tocado. HOME separado, para não mexer no da sandbox.
bloco="$TMPDIR/passo4.sh"
python3 - "$AULA/teste/comandos.json" > "$bloco" <<'PY'
import json, sys
bl = [b for b in json.load(open(sys.argv[1]))["blocos"]
      if any("aviso.env.exemplo" in l for l in b["linhas"])]
assert len(bl) == 1, f"esperava 1 bloco do aviso.env no comandos.json, achei {len(bl)}"
assert any(l.startswith("[ -e ") for l in bl[0]["linhas"]), "comandos.json velho: rode validar.py --exportar"
print("set -euo pipefail")
print("\n".join(bl[0]["linhas"]))
PY
H4="$TMPDIR/home4"; mkdir -p "$H4"; ln -s "$HOME/harness-lab-materiais" "$H4/harness-lab-materiais"
E4="$H4/.config/harness-lab/aviso.env"
passo4() { ( cd "$1" && HOME="$H4" bash "$bloco" ) > /dev/null || erro "o bloco do passo 4 falhou em $1"; }
P4="$TMPDIR/p4a"; mkdir -p "$P4/$S"; cp "$S/.gitignore" "$P4/$S/"; git -C "$P4" init -q
printf 'EVOLUTION_API_URL=https://evo.exemplo\nAUTHENTICATION_API_KEY=segredo-do-aluno\nEVOLUTION_INSTANCE=inst\n' > "$P4/$S/.env"
passo4 "$P4"
grep -qx 'AUTHENTICATION_API_KEY=segredo-do-aluno' "$E4" || erro "o .env que o aluno já tinha devia virar o aviso.env"
[ -L "$P4/$S/.env" ] && [ "$(readlink -f "$P4/$S/.env")" = "$(readlink -f "$E4")" ] || erro "o .env antigo devia virar link para o aviso.env"
[ "$(stat -c %a "$E4")" = 600 ] || erro "o aviso.env movido devia ter chmod 600"
antes=$(sha256sum < "$E4")
passo4 "$P4"
[ "$(sha256sum < "$E4")" = "$antes" ] && [ -L "$P4/$S/.env" ] || erro "rodar o passo 4 de novo mudou o aviso.env ou o link"
P4="$TMPDIR/p4b"; mkdir -p "$P4/$S"; cp "$S/.gitignore" "$P4/$S/"; git -C "$P4" init -q
printf 'X=do-outro-projeto\n' > "$P4/$S/.env"
passo4 "$P4"
[ ! -L "$P4/$S/.env" ] && grep -qx 'X=do-outro-projeto' "$P4/$S/.env" || erro "o .env próprio de outro projeto não podia ser tocado"
[ "$(sha256sum < "$E4")" = "$antes" ] || erro "o aviso.env não podia mudar ao ligar outro projeto"
ok "passo 4 com o .env da aula já criado: vira o aviso.env; rodar de novo e outro projeto não apagam nada"

# ------------------------------------------------------------------ servidor falso
porta_arq="$TMPDIR/porta"; pedidos="$TMPDIR/pedidos.jsonl"
python3 - "$porta_arq" "$pedidos" <<'PY' &
import json, sys, urllib.parse
from http.server import BaseHTTPRequestHandler, HTTPServer
porta_arq, pedidos = sys.argv[1], sys.argv[2]
class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def responde(self, code, obj):
        b = json.dumps(obj).encode()
        self.send_response(code); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)
    def do_GET(self):  # Evolution: o número dono da instância
        if self.path.startswith("/instance/fetchInstances") and self.headers.get("apikey") == "chave-teste":
            return self.responde(200, [{"name": "inst", "ownerJid": "5511900000000@s.whatsapp.net"}])
        self.responde(401, {"error": "apikey"})
    def do_POST(self):
        bruto = self.rfile.read(int(self.headers.get("Content-Length", 0))).decode()
        if "json" in (self.headers.get("Content-Type") or ""):
            corpo = json.loads(bruto)          # JSON inválido derruba o teste
        else:
            corpo = {k: v[0] for k, v in urllib.parse.parse_qs(bruto).items()}
        with open(pedidos, "a") as f:
            f.write(json.dumps({"path": self.path, "apikey": self.headers.get("apikey"), "corpo": corpo},
                               ensure_ascii=False) + "\n")
        if self.path.startswith("/message/") and self.headers.get("apikey") != "chave-teste":
            return self.responde(401, {"error": "apikey"})
        self.responde(201, {"ok": True})
s = HTTPServer(("127.0.0.1", 0), H)
open(porta_arq, "w").write(str(s.server_port))
s.serve_forever()
PY
pids+=($!)
for _ in $(seq 50); do [ -s "$porta_arq" ] && break; sleep 0.1; done
[ -s "$porta_arq" ] || erro "servidor falso não subiu"
URL="http://127.0.0.1:$(cat "$porta_arq")"
limpa() { : > "$pedidos"; }
# confere CAMINHO CORPO_JSON: exatamente um pedido, com esse caminho e esse corpo
confere() {
  python3 - "$pedidos" "$1" "$2" <<'PY'
import json, sys
p = [json.loads(l) for l in open(sys.argv[1])]
assert len(p) == 1, f"esperava 1 pedido, vieram {len(p)}: {p}"
assert p[0]["path"] == sys.argv[2], p[0]
assert p[0]["corpo"] == json.loads(sys.argv[3]), p[0]
PY
}

# ------------------------------------------------------------------ aviso-env.sh
# Numa cópia, para não tocar no aviso.env do aluno. O .env com CRLF, aspas e export, como
# o que quebrou a URL na gravação.
mkdir -p "$TMPDIR/s"; cp "$S/aviso-env.sh" "$S/aviso.sh" "$TMPDIR/s/"
AE="$TMPDIR/s/aviso-env.sh"
printf 'EVOLUTION_API_URL=%s/\r\nexport AUTHENTICATION_API_KEY="chave-teste"\r\nEVOLUTION_INSTANCE=inst\r\nEVOLUTION_NUMBER=\r\n' \
  "$URL" > "$TMPDIR/s/.env"
limpa
saida=$(AVISO_DRY=1 bash "$AE" "teste")
grep -qF '$AUTHENTICATION_API_KEY' <<<"$saida" || erro "AVISO_DRY devia mostrar o nome da variável: $saida"
! grep -q 'chave-teste' <<<"$saida" || erro "AVISO_DRY mostrou o segredo"
[ ! -s "$pedidos" ] || erro "AVISO_DRY não pode mandar nada"
ok "aviso-env.sh com AVISO_DRY=1: o curl com \$AUTHENTICATION_API_KEY, sem o segredo e sem mandar"

msg='loop blog: falhou: F1 "Cadastro", gate 3; ação, vírgula'
limpa; bash "$AE" "$msg"
confere /message/sendText/inst "$(jq -nc --arg t "$msg" '{number: "5511900000000", text: $t}')"
ok "aviso-env.sh: WhatsApp pela Evolution, número da instância, texto com aspas e acento intactos"

limpa; EVOLUTION_NUMBER=5511988887777 bash "$AE" "oi"
confere /message/sendText/inst '{"number": "5511988887777", "text": "oi"}'
ok "variável do ambiente ganha do arquivo (EVOLUTION_NUMBER)"

sed -i 's#^EVOLUTION_API_URL=.*#EVOLUTION_API_URL=http://127.0.0.1:9#' "$TMPDIR/s/.env"
err=$(EVOLUTION_NUMBER=55 bash "$AE" "oi" 2>&1 >/dev/null) || erro "aviso-env.sh não pode falhar"
grep -q 'HTTP 000' <<<"$err" || erro "Evolution fora do ar devia avisar no stderr: $err"
ok "Evolution fora do ar: avisa no stderr e sai com 0 (o loop segue)"

printf 'TELEGRAM_TOKEN=123:abc\nTELEGRAM_CHAT_ID=42\n' > "$TMPDIR/s/.env"
limpa; TELEGRAM_API="$URL" bash "$AE" "loop blog: terminou 1/1 fases."
confere /bot123:abc/sendMessage '{"chat_id": "42", "text": "loop blog: terminou 1/1 fases."}'
[ -z "${TELEGRAM_TOKEN:-}" ] || erro "o token não podia estar no ambiente do teste"
ok "sem Evolution: o aviso.sh manda pelo Telegram com o token lido do arquivo"

printf 'SLACK_WEBHOOK_URL=%s/api/webhooks/1/abc/slack\n' "$URL" > "$TMPDIR/s/.env"
limpa; bash "$AE" "travou? sessão quieta"
confere /api/webhooks/1/abc/slack '{"text": "travou? sessão quieta"}'
ok "Discord pelo endpoint compatível com o Slack (URL com /slack, JSON {text})"

: > "$TMPDIR/s/.env"
[ "$(AVISO_DRY=1 bash "$AE" "oi")" = "local: oi" ] || erro "sem canal devia cair na notificação local"
ok "sem canal nenhum: notificação local"

# ------------------------------------------------------------------ ralph.sh da aula
# O ralph de julho chama o claude com --output-format json (implementação) e texto (juiz).
mkdir -p "$TMPDIR/bin"
cat > "$TMPDIR/bin/claude" <<'SH'
#!/usr/bin/env bash
[ -t 0 ] || cat > /dev/null
prompt=""
while [ $# -gt 0 ]; do
  case "$1" in -p|--print) prompt="${2:-}"; shift 2 ;; --output-format|--model|--allowedTools) shift 2 ;; *) shift ;; esac
done
if [ "${prompt%%$'\n'*}" = "RALPH_VERIFY" ]; then
  t=$(grep -cE '^[[:space:]]*- \[[ xX]\]' <<<"$prompt" || true)
  for ((i = 1; i <= t; i++)); do
    if [ "${MOTOR_CENARIO:-ok}" = incompleta ]; then echo "TASK $i: INCOMPLETE: falta o teste"; else echo "TASK $i: DONE"; fi
  done
  exit 0
fi
fase=$(grep -oE 'Phase [0-9]+' <<<"$prompt" | head -1 | grep -oE '[0-9]+')
mkdir -p src; echo ok > "src/fase-${fase:-x}.txt"
echo '{"type":"result","subtype":"success","is_error":false,"result":"motor falso"}'
SH
printf '#!/usr/bin/env bash\necho "codex falso: este teste nunca roda o Codex" >&2\nexit 97\n' > "$TMPDIR/bin/codex"
chmod +x "$TMPDIR/bin/claude" "$TMPDIR/bin/codex"
printf 'EVOLUTION_API_URL=%s\nAUTHENTICATION_API_KEY=chave-teste\nEVOLUTION_INSTANCE=inst\n' "$URL" > "$TMPDIR/evo.env"

R="$TMPDIR/r"
novo_repo() {  # $1 = com-gitignore | sem-gitignore
  rm -rf "$R"; mkdir -p "$R/.claude/scripts" "$R/.spec/features/agenda"
  cp "$S/ralph.sh" "$R/.claude/scripts/"
  [ "$1" = sem-gitignore ] || cp "$S/.gitignore" "$R/.claude/scripts/"
  printf '# Phases: agenda\n\n## Phase 1: Modelo de evento\n\n- [ ] T01: cria src/fase-1.txt\n      Acceptance criteria: existe.\n      Testes: test.sh\n\n## Phase 2: Exportar .ics\n\n- [ ] T02: cria src/fase-2.txt\n      Acceptance criteria: existe.\n      Testes: test.sh\n' \
    > "$R/.spec/features/agenda/PHASES.md"
  printf '#!/usr/bin/env bash\n! grep -rqs quebrado src/\n' > "$R/test.sh"
  ( cd "$R" && git init -q -b feat/agenda && git add -A && git commit -qm inicio )
  ln -s "$TMPDIR/evo.env" "$R/.claude/scripts/.env"     # o mesmo arranjo do PDF: link para fora
}
roda() {
  ( cd "$R" && PATH="$TMPDIR/bin:$PATH" bash .claude/scripts/ralph.sh --engine claude --test-cmd "bash test.sh" \
      "$@" .spec/features/agenda/PHASES.md ) > "$TMPDIR/ralph.out" 2>&1
}
textos() { python3 -c 'import json,sys; [print(json.loads(l)["corpo"]["text"].replace("\n", " / ")) for l in open(sys.argv[1])]' "$pedidos"; }

novo_repo com-gitignore; limpa
roda || { tail -20 "$TMPDIR/ralph.out" >&2; erro "ralph.sh falhou no run verde"; }
textos > "$TMPDIR/msgs"
[ "$(wc -l < "$TMPDIR/msgs")" = 8 ] || { cat "$TMPDIR/msgs" >&2; erro "esperava 8 mensagens num run verde de 2 fases"; }
i=0
for e in "feature iniciada" "fase iniciada" "gates verdes" "fase concluida" "fase iniciada" "gates verdes" "fase concluida" "feature COMPLETA"; do
  i=$((i + 1)); sed -n "${i}p" "$TMPDIR/msgs" | grep -qF "$e" || erro "mensagem $i devia ser '$e': $(sed -n "${i}p" "$TMPDIR/msgs")"
done
grep -qF 'Feature: agenda' "$TMPDIR/msgs" && grep -qF 'Fases: 2 pendentes de 2' "$TMPDIR/msgs" || erro "a 1a mensagem devia trazer a feature e as fases"
[ "$(python3 -c 'import json,sys; print({json.loads(l)["corpo"]["number"] for l in open(sys.argv[1])})' "$pedidos")" = "{'5511900000000'}" ] ||
  erro "sem EVOLUTION_NUMBER, o destino devia ser o número da instância"
[ "$(git -C "$R" log --oneline | wc -l)" = 3 ] || erro "o ralph devia fazer um commit por fase"
ok "ralph.sh da aula: run verde de 2 fases manda 8 mensagens na ordem e faz 2 commits"

novo_repo com-gitignore; limpa
if MOTOR_CENARIO=incompleta roda --max-cycles 2; then erro "o ralph devia falhar com o juiz dizendo INCOMPLETE"; fi
textos > "$TMPDIR/msgs"
[ "$(grep -c 'gate vermelho' "$TMPDIR/msgs")" = 2 ] || erro "esperava 2 avisos de gate vermelho"
grep -q 'TASK 1: INCOMPLETE' "$TMPDIR/msgs" || erro "o gate vermelho devia trazer a causa"
grep -q 'fase FALHOU' "$TMPDIR/msgs" && grep -q 'feature terminou com falhas' "$TMPDIR/msgs" || erro "faltou o aviso de falha"
ok "ralph.sh da aula: gate vermelho com a causa, fase que falhou e feature com falhas também avisam"

novo_repo com-gitignore; limpa
RALPH_NOTIFY=off roda || erro "ralph.sh falhou com RALPH_NOTIFY=off"
[ ! -s "$pedidos" ] || erro "RALPH_NOTIFY=off não podia mandar nada"
ok "RALPH_NOTIFY=off: o run roda e nenhuma mensagem sai"

printf 'EVOLUTION_API_URL=http://127.0.0.1:9\nAUTHENTICATION_API_KEY=chave-teste\nEVOLUTION_INSTANCE=inst\nEVOLUTION_NUMBER=55\n' > "$TMPDIR/evo.env"
novo_repo com-gitignore
roda || erro "com a Evolution fora do ar o run tinha de seguir"
grep -q 'Falha ao enviar notificacao WhatsApp (HTTP 000)' "$TMPDIR/ralph.out" || erro "faltou o aviso de falha de envio no log"
[ "$(git -C "$R" log --oneline | wc -l)" = 3 ] || erro "com a Evolution fora do ar as fases tinham de ser commitadas"
ok "Evolution fora do ar: o run termina, commita e só avisa no log"

novo_repo sem-gitignore
if roda; then erro "sem o .gitignore, o .env devia sujar a árvore e o ralph recusar"; fi
grep -q 'Arvore de trabalho suja' "$TMPDIR/ralph.out" && grep -q '.claude/scripts/.env' "$TMPDIR/ralph.out" ||
  erro "esperava o ralph recusar a árvore suja com o .env"
ok "sem o .claude/scripts/.gitignore, o .env suja a árvore e o ralph se recusa a rodar"

# ------------------------------------------------------------------ vigia.sh
cap="$TMPDIR/captura.sh"; avisos="$TMPDIR/avisos.txt"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "%s"\n' "$avisos" > "$cap"; chmod +x "$cap"

V="$TMPDIR/v1"; mkdir -p "$V/.phases/state"; cp "$AULA/modelos/run-morto.tsv" "$V/.phases/state/run.tsv"
: > "$avisos"
LOOP_INICIO=0 AVISO_CMD="$cap" timeout 20 "$PWD/$S/vigia.sh" "$V" || erro "o vigia devia sair sozinho com o PID morto"
grep -qF 'loop demo: morto? o ralph (PID 4194304) sumiu com status running na fase 1.' "$avisos" ||
  erro "vigia sem o aviso de PID morto: $(cat "$avisos")"
ok "vigia.sh com modelos/run-morto.tsv: avisa 'morto?' e sai"

V="$TMPDIR/v2"; mkdir -p "$V/.phases/state" "$V/.phases/logs"
sleep 300 & vivo=$!; pids+=("$vivo")
printf 'META\tproject\tdemo\nMETA\tstatus\trunning\nMETA\tstarted\t%s\nMETA\tpid\t%s\nMETA\tphase_cur\t1\nMETA\tcycle\t1\nMETA\tgate\t\n' \
  "$(date +%s)" "$vivo" > "$V/.phases/state/run.tsv"
touch -d '-2 minutes' "$V/.phases/logs/phase-01.cycle-1.log"
: > "$avisos"
LOOP_INICIO=0 LOOP_QUIETO=1m LOOP_VIGIA_S=1 AVISO_CMD="$cap" timeout 4 "$PWD/$S/vigia.sh" "$V" || true
[ "$(grep -c 'travou? sessão quieta há 2 min na fase 1 (ciclo 1).' "$avisos")" = 1 ] ||
  erro "vigia devia avisar 'travou?' uma vez só: $(cat "$avisos")"
kill "$vivo" 2>/dev/null || true
ok "vigia.sh: log da sessão parado além do LOOP_QUIETO vira um 'travou?', uma vez só"

# ------------------------------------------------------------------ ENSAIO
out=$(bash "$S/confere-phases.sh" "$AULA/modelos/ENSAIO-AVISO.md" 2>&1) || { echo "$out" >&2; erro "ENSAIO-AVISO.md não passa no confere-phases.sh"; }
ok "modelos/ENSAIO-AVISO.md passa no confere-phases.sh"

echo "verificar.sh: $n grupos de checagem passaram."
