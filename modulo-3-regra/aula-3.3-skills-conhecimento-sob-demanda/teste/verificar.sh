#!/usr/bin/env bash
# verificar.sh · aula 3.3 · roda no ~/projeto da sandbox, depois dos comandos do material.
# Prova que a skill nova-migration foi instalada com frontmatter válido, que o prova.sh roda
# migrate, rollback e migrate na ordem (e para no erro e em produção), e que o plugin
# skill-gatilho está instalado e o conferidor dele acha os erros que o Claude Code ignora calado.
# O projeto falso (teste/projeto) é um Laravel de mentira: vendor/bin/sail é um stub que anota
# as chamadas em sail.log, não o Sail real.
set -euo pipefail

S=.claude/skills/nova-migration
P=$S/scripts/prova.sh
CONFERE=~/harness-lab-materiais/plugins/skill-gatilho/skills/descrever/scripts/confere.py
n=0
ok() { n=$((n + 1)); printf '  ok  %s\n' "$1"; }
erro() { printf 'FALHOU: %s\n' "$1" >&2; exit 1; }

# ------------------------------------------------------------------ instalação
for f in $S/SKILL.md $S/references/stacks.md; do [ -f "$f" ] || erro "$f não instalado"; done
[ -x "$P" ] || erro "$P não instalado ou sem chmod +x"
bash -n "$P"
[ "$(head -n 1 $S/SKILL.md)" = "---" ] || erro "o --- do frontmatter não está na primeira linha"
grep -q '^name: nova-migration$' $S/SKILL.md || erro "name não é nova-migration"
grep -q '^description: Cria ou altera tabela' $S/SKILL.md || erro "description diferente da aula"
grep -q '^when_to_use: ' $S/SKILL.md || erro "falta when_to_use"
grep -q 'prova.sh' $S/SKILL.md || erro "o SKILL.md não termina na checagem com o prova.sh"
[ -f .claude/skills/revisar-pr/SKILL.md ] || erro "o instalar.sh mexeu numa skill que o projeto já tinha"
ok "skill instalada, frontmatter na primeira linha, skill do projeto preservada"

claude plugin validate .claude/skills >/dev/null || erro "claude plugin validate .claude/skills falhou"
ok "claude plugin validate .claude/skills passa"

# ------------------------------------------------------------------ prova.sh
rm -f sail.log
out=$("$P" . --seco)
grep -q 'Laravel (Sail)' <<<"$out" || erro "--seco não detectou Laravel com Sail: $out"
[ ! -e sail.log ] || erro "--seco rodou alguma coisa"
ok "--seco detecta Laravel com Sail e não roda nada"

out=$("$P" .) || erro "prova.sh falhou no caminho feliz: $out"
grep -q '^prova: ok' <<<"$out" || erro "prova.sh não terminou com 'prova: ok': $out"
esperado=$'sail artisan migrate --no-interaction\nsail artisan migrate:rollback --step=1 --no-interaction\nsail artisan migrate --no-interaction'
[ "$(cat sail.log)" = "$esperado" ] || erro "ordem errada: $(cat sail.log)"
ok "prova.sh roda migrate, rollback --step=1 e migrate, nessa ordem"

rm -f sail.log
set +e
out=$(FALHA=migrate:rollback "$P" .)
rc=$?
set -e
[ "$rc" = 1 ] || erro "rollback falhando deveria dar exit 1, veio $rc"
grep -q 'FALHOU no passo 2 de 3' <<<"$out" || erro "não disse qual passo falhou: $out"
grep -q 'Duplicate column' <<<"$out" || erro "não mostrou o erro do banco: $out"
[ "$(wc -l < sail.log | tr -d ' ')" = 2 ] || erro "continuou depois do erro"
ok "rollback quebrado: exit 1, mostra o erro e para no passo 2"

d=$(mktemp -d)
cp -R . "$d/p"
rm -f "$d/p/sail.log"
printf 'APP_ENV=production\n' > "$d/p/.env"
set +e
out=$("$P" "$d/p")
rc=$?
set -e
[ "$rc" = 1 ] || erro "APP_ENV=production deveria dar exit 1, veio $rc"
[ ! -e "$d/p/sail.log" ] || erro "rodou migration com APP_ENV=production"
ok "APP_ENV=production: recusa sem rodar nada"

mkdir -p "$d/vazio"
set +e
"$P" "$d/vazio" >/dev/null 2>&1
rc=$?
set -e
[ "$rc" = 2 ] || erro "stack desconhecida deveria dar exit 2, veio $rc"
mkdir -p "$d/rails/bin"
printf '#!/bin/sh\necho "rails $*" >> rails.log\n' > "$d/rails/bin/rails"
chmod +x "$d/rails/bin/rails"
"$P" "$d/rails" >/dev/null || erro "prova.sh falhou no Rails falso"
grep -q 'db:rollback STEP=1' "$d/rails/rails.log" || erro "Rails sem db:rollback STEP=1"
ok "stack desconhecida: exit 2; Rails: db:migrate, db:rollback STEP=1, db:migrate"

# ------------------------------------------------------------------ plugin skill-gatilho
claude plugin list | grep -q 'skill-gatilho@harness-lab' || erro "plugin skill-gatilho não aparece em claude plugin list"
achou=$(find ~/.claude/plugins -path '*skill-gatilho*' -name SKILL.md -path '*descrever*' | head -n 1)
[ -n "$achou" ] || erro "SKILL.md da skill descrever não está no cache do plugin"
head -n 1 "$achou" | grep -qx -- '---' || erro "frontmatter da skill descrever fora da primeira linha"
ok "plugin skill-gatilho instalado, skill descrever no cache"

out=$(python3 -I "$CONFERE" .claude/skills) || erro "confere.py acusou erro nas skills instaladas: $out"
grep -q 'confere: ok' <<<"$out" || erro "confere.py não terminou com ok: $out"
grep -q 'lista nova-migration' <<<"$out" || erro "confere.py não listou a nova-migration"
ok "confere.py: skills do projeto sem erro"

mkdir -p "$d/sk/errada" "$d/sk/longa"
printf -- '---\nname: errada\ndescription: Faz deploy em staging. Use quando pedirem deploy.\nwhen-to-use: deploy\n---\nx\n' \
  > "$d/sk/errada/SKILL.md"
{ printf -- '---\nname: longa\ndescription: '; printf 'palavra %.0s' $(seq 1 220); printf '\n---\nx\n'; } > "$d/sk/longa/SKILL.md"
set +e
out=$(python3 -I "$CONFERE" "$d/sk")
rc=$?
set -e
[ "$rc" = 1 ] || erro "confere.py deveria sair com 1 nas skills quebradas, veio $rc"
grep -q "campo 'when-to-use'" <<<"$out" || erro "confere.py não pegou o when-to-use com hífen"
grep -q 'a lista corta em 1536' <<<"$out" || erro "confere.py não pegou a descrição acima de 1.536"
ok "confere.py pega campo com nome errado e descrição acima do corte"

rm -rf "$d" sail.log
echo "verificar.sh: $n checagens ok"
