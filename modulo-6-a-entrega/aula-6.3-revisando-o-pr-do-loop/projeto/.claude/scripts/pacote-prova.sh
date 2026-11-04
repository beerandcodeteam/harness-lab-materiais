#!/usr/bin/env bash
# pacote-prova.sh · aula 6.3 · o log do loop num arquivo só, entregue ou não
#
# Uso: .claude/scripts/pacote-prova.sh [<.loop-logs/run>] [--base <ref>] [--comparar <arquivo>] [-o <saida.tar.gz>]
#   <.loop-logs/run>  padrão: a pasta mais nova de .loop-logs/
#   --base            commit de antes do loop, para o git log e o diff --stat
#                     (padrão: o pai do primeiro commit feat(phase-N) ou wip(phase-N))
#   --comparar        a saída do /diagnostico-operador comparar (padrão: diagnostico-operador.md na raiz, se existir)
#   -o                padrão: .loop-logs/prova-<run>.tar.gz (fora do git, como o resto do .loop-logs)
#
# Junta no pacote:
#   loop-logs/        a cópia do .phases que o loop.sh guardou (run.tsv, logs, prompts, resumo.txt, camadas.txt)
#   desfecho.txt      a saída do desfecho.sh (ENTREGOU, FALHOU, ...)
#   git-log.txt       os commits do branch desde a base e o diff --stat
#   comparar.md       o antes e depois do /diagnostico-operador, se existir
#   LEIA-ME.txt       o que é cada arquivo
# Nunca entram: .env, .env.*, *.pem, *.key, *.p12, id_rsa*, id_ed25519*.
# Vale nos dois desfechos: entregou, vai anexado ao PR; não entregou, mostra o
# que não entregou e por quê. Os prompts levam trechos da sua SPEC: leia antes
# de mandar para alguém.
#
# Exit: 0 pacote gerado · 2 erro de uso. Requer tar, gzip e git.
set -euo pipefail

RUNDIR=""; BASE=""; COMPARAR=""; SAIDA=""
while [ $# -gt 0 ]; do
  case "$1" in
    --base) BASE="${2:?}"; shift 2 ;;
    --comparar) COMPARAR="${2:?}"; shift 2 ;;
    -o) SAIDA="${2:?}"; shift 2 ;;
    -h|--help) sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
    -*) echo "opção desconhecida: $1" >&2; exit 2 ;;
    *) RUNDIR="$1"; shift ;;
  esac
done

RAIZ=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "pacote-prova: rode dentro do repositório" >&2; exit 2; }
cd "$RAIZ"
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$RUNDIR" ]; then
  # a mais nova que tem run.tsv (o loop.sh guarda "abortado-..." sem run.tsv quando o preflight barra)
  RUNDIR=$(ls -1dt .loop-logs/*/ 2>/dev/null | while read -r d; do [ -f "$d/run.tsv" ] && { echo "$d"; break; }; done || true)
  [ -n "$RUNDIR" ] || { echo "pacote-prova: nenhuma pasta com run.tsv em .loop-logs/. O loop.sh guarda o .phases ali no fim de cada run." >&2; exit 2; }
fi
RUNDIR="${RUNDIR%/}"
[ -d "$RUNDIR" ] || { echo "pacote-prova: $RUNDIR não existe" >&2; exit 2; }
RUN=""
[ -f "$RUNDIR/run.tsv" ] && RUN=$(awk -F'\t' '$1=="META" && $2=="run" {print $3}' "$RUNDIR/run.tsv")
RUN="${RUN:-$(basename "$RUNDIR")}"
SAIDA="${SAIDA:-.loop-logs/prova-$RUN.tar.gz}"
[ -n "$COMPARAR" ] || { [ -f diagnostico-operador.md ] && COMPARAR=diagnostico-operador.md; } || true

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
P="$TMP/prova-$RUN"
mkdir -p "$P/loop-logs"

PROIBIDOS=(--exclude='.env' --exclude='.env.*' --exclude='*.pem' --exclude='*.key' --exclude='*.p12'
           --exclude='id_rsa*' --exclude='id_ed25519*')
tar -C "$RUNDIR" "${PROIBIDOS[@]}" -cf - . | tar -C "$P/loop-logs" -xf -

# desfecho
rc=0
if [ -f "$RUNDIR/run.tsv" ]; then
  bash "$AQUI/desfecho.sh" "$RUNDIR" > "$P/desfecho.txt" 2>&1 || rc=$?
else
  echo "DESFECHO: ABORTOU ANTES DE COMEÇAR (sem run.tsv: o ralph não chegou a rodar; veja resumo.txt e ralph.log)" > "$P/desfecho.txt"
fi
DESFECHO=$(sed -n 's/^DESFECHO: //p' "$P/desfecho.txt" | head -n 1)

# git log do branch
if [ -z "$BASE" ]; then
  intervalo=HEAD
  for principal in main master; do  # commits de fase antigos da main não contam
    if git rev-parse -q --verify "$principal" >/dev/null && [ "$(git rev-parse "$principal")" != "$(git rev-parse HEAD)" ]; then
      intervalo="$(git merge-base "$principal" HEAD)..HEAD"; break
    fi
  done
  primeiro=$(git log --reverse --format='%H %s' "$intervalo" | awk '$2 ~ /^(feat|wip)\(phase-[0-9]+\)/ {print $1; exit}')
  [ -n "$primeiro" ] && BASE=$(git rev-parse "$primeiro^")
fi
{
  echo "Branch: $(git rev-parse --abbrev-ref HEAD) · HEAD $(git rev-parse --short HEAD)"
  if [ -n "$BASE" ]; then
    echo "Base: $(git rev-parse --short "$BASE") $(git log -1 --format='%s' "$BASE")"
    echo ""
    git log --format='%h %ad %s' --date=format:'%d/%m %H:%M' "$BASE..HEAD"
    echo ""
    git diff --stat "$BASE" HEAD
  else
    echo "Nenhum commit feat(phase-N) no branch: o loop não commitou nenhuma fase."
    echo ""
    git log --format='%h %ad %s' --date=format:'%d/%m %H:%M' -n 15
  fi
} > "$P/git-log.txt" 2>&1

[ -n "$COMPARAR" ] && [ -f "$COMPARAR" ] && cp "$COMPARAR" "$P/comparar.md"

cat > "$P/LEIA-ME.txt" <<EOF
Pacote da prova · run $RUN · gerado em $(date '+%d/%m/%Y %H:%M') pelo pacote-prova.sh
Desfecho: ${DESFECHO:-?} (exit do desfecho.sh: $rc)

desfecho.txt  o que aconteceu e, se falhou, o gate, o arquivo da causa e a camada provável
git-log.txt   os commits do loop e o tamanho do diff
loop-logs/    a cópia do .phases do run: run.tsv (estado), logs/ (sessões, testes, juiz), prompts/
comparar.md   o antes e depois do /diagnostico-operador (se existir)
Fora do pacote de propósito: .env, .env.*, *.pem, *.key, *.p12, chaves ssh.
EOF

mkdir -p "$(dirname "$SAIDA")"
tar -C "$TMP" -czf "$SAIDA" "prova-$RUN"

# Defesa em profundidade: confere a lista final.
if tar -tzf "$SAIDA" | grep -qE '(^|/)(\.env(\..*)?|[^/]*\.pem|[^/]*\.key|[^/]*\.p12|id_rsa[^/]*|id_ed25519[^/]*)$'; then
  rm -f "$SAIDA"
  echo "pacote-prova: um arquivo proibido entrou no pacote; apaguei o pacote. Isto é bug do script." >&2
  exit 2
fi

echo "Pacote: $SAIDA ($(du -h "$SAIDA" | cut -f1))"
echo "Desfecho: ${DESFECHO:-?}"
echo "Entrou:"
tar -tzf "$SAIDA" | grep -v '/$' | sed "s#^prova-$RUN/#  #" | awk 'NR <= 25 { print } END { if (NR > 25) print "  ... e mais " NR - 25 " arquivo(s)" }'

# Aviso, não bloqueio: padrões comuns de token no que vai sair.
SUSPEITOS=$(grep -rlE 'sk-ant-[A-Za-z0-9_-]{10,}|gh[pousr]_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|[0-9]{8,10}:[A-Za-z0-9_-]{35}' "$P" 2>/dev/null | sed "s#^$P/#  #" || true)
if [ -n "$SUSPEITOS" ]; then
  echo "Atenção: parece haver token nestes arquivos. Confira antes de mandar o pacote:"
  echo "$SUSPEITOS"
fi
echo "Entregou: anexe ao PR e cole resumo.txt e camadas.txt no corpo. Não entregou: guarde com o desfecho."
