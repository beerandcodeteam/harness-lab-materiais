#!/usr/bin/env bash
# confere.sh · plugin feature-alvo · Harness Lab, aula 1.5
#
# Confere se o FEATURE-ALVO.md está pronto para seguir para o Módulo 4.
# Só lê. Não altera nada. Funciona no bash 3.2 do macOS, sem jq.
#
#   confere.sh                      confere ./FEATURE-ALVO.md
#   confere.sh caminho/arquivo.md   confere outro arquivo
#
# Erro (o arquivo não está pronto):
#   - falta uma das 6 seções do modelo, ou ela está vazia;
#   - sobrou espaço do modelo (<...>) fora de `crases`;
#   - menos de 3 critérios de aceite, ou mais de 10 (aí não é pequena);
#   - alguma das cinco peneiras sem marcar.
# Aviso (vale olhar): 6 a 10 critérios, critério fora do formato "Quando ..., então ..."
# e palavra vaga num critério (rápido, melhor, amigável, adequado...).
# Os critérios no formato do Módulo 4 (- AC-01 ...) também contam.
# Sai com 0 se não há erro, 1 se há, 2 se o uso está errado.
set -uo pipefail

case "${1:-}" in
  -h | --help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
[ $# -le 1 ] || { echo "uso: $(basename "$0") [FEATURE-ALVO.md]" >&2; exit 2; }
arq="${1:-FEATURE-ALVO.md}"

if [ ! -f "$arq" ]; then
  echo "confere $arq"
  echo "  ERRO   arquivo não encontrado. Ele fica na raiz do repositório:"
  echo "         ~/harness-lab-materiais/instalar.sh 1.5 cria o modelo, ou rode /feature-alvo."
  echo "resultado: NÃO PASSA (1 erro, 0 avisos)"
  exit 1
fi

saida=$(awk '
function aparar(s) { sub(/\r$/, "", s); sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function msg(t, s) { n_msg++; tipo[n_msg] = t; texto[n_msg] = s }
function fecha_item() {
  if (item != "") { n_crit++; crit[n_crit] = item; crit_rascunho[n_crit] = item_rascunho }
  item = ""
}
BEGIN {
  pedidas = "Descrição|Por que é pequena|Critérios de aceite|Como eu verificaria hoje, na mão|Riscos|Cinco peneiras"
  n_ped = split(pedidas, ped, "|")
  n_vagas = split("rápido|rápida|rápidos|rápidas|bom|boa|bons|boas|melhor|melhores|melhorar|melhore|melhorado|melhorada|bonito|bonita|bonitos|bonitas|amigável|amigáveis|adequado|adequada|adequadamente|intuitivo|intuitiva|eficiente|eficientemente|idealmente|corretamente|direito|possível", vaga, "|")
}
{
  linha = $0; sub(/\r$/, "", linha)
  if (linha ~ /^```/) { em_bloco = !em_bloco; next }
  if (em_bloco) { if (sec != "") conteudo[sec]++; next }

  if (linha ~ /^# / && !titulo) { titulo = 1; next }
  if (linha ~ /^## /) {
    fecha_item()
    sec = aparar(substr(linha, 4))
    if (sec ~ /^Critérios de aceite/) sec = "Critérios de aceite"
    vista[sec] = NR
    next
  }

  sem_codigo = linha
  gsub(/`[^`]*`/, "", sem_codigo)
  if (sem_codigo ~ /<[^>]+>/) {
    trecho = sem_codigo; sub(/^[ \t]+/, "", trecho)
    if (length(trecho) > 70) trecho = substr(trecho, 1, 67) "..."
    msg("ERRO", "linha " NR ": espaço do modelo sobrando: " trecho)
  }

  if (aparar(linha) != "" && sec != "") conteudo[sec]++

  if (sec == "Critérios de aceite") {
    if (linha ~ /^[-*] \[[ xX]\] /) { fecha_item(); item = linha; item_rascunho = 1 }
    else if (linha ~ /^[-*] AC-[0-9]+/) { fecha_item(); item = linha; item_rascunho = 0 }
    else if (linha ~ /^[ \t]+[^ \t]/ && item != "") { item = item " " aparar(linha) }
    else if (aparar(linha) != "") fecha_item()
  }
  if (sec == "Cinco peneiras") {
    if (linha ~ /^[-*] \[[xX]\] /) n_marc++
    else if (linha ~ /^[-*] \[ \] /) { n_vazia++; vazias[n_vazia] = aparar(substr(linha, 7)) }
  }
}
END {
  fecha_item()
  faltam = ""
  for (i = 1; i <= n_ped; i++) {
    s = ped[i]
    if (!(s in vista)) faltam = faltam (faltam == "" ? "" : ", ") s
    else if (conteudo[s] + 0 == 0) msg("ERRO", "seção vazia: " s)
  }
  if (faltam != "") msg("ERRO", "faltam seções do modelo: " faltam)
  else ok["secoes"] = 1
  if (!titulo) msg("aviso", "sem o título # Feature-alvo na primeira linha")

  if ("Critérios de aceite" in vista) {
    if (n_crit < 3) msg("ERRO", "critérios de aceite: " n_crit + 0 ". A aula pede de 3 a 5.")
    else if (n_crit > 10) msg("ERRO", "critérios de aceite: " n_crit ". Com mais de 10, ela não é pequena: corte.")
    else if (n_crit > 5) msg("aviso", "critérios de aceite: " n_crit ". A aula pede de 3 a 5: confira se ainda é pequena.")
    else ok["crit"] = n_crit
    for (i = 1; i <= n_crit; i++) {
      c = tolower(crit[i])
      if (crit_rascunho[i] && (c !~ /quando/ || c !~ /ent(ã|Ã)o/))
        msg("aviso", "critério " i " fora do formato Quando ..., então ...")
      for (j = 1; j <= n_vagas; j++) {
        if (c ~ ("(^|[^[:alnum:]])" vaga[j] "([^[:alnum:]]|$)")) {
          msg("aviso", "critério " i ": palavra vaga \"" vaga[j] "\". Troque por número ou texto exato.")
          break
        }
      }
    }
  }
  if ("Cinco peneiras" in vista) {
    if (n_marc + n_vazia < 5) msg("ERRO", "cinco peneiras: achei " n_marc + n_vazia " de 5 linhas - [ ] ou - [x]")
    for (i = 1; i <= n_vazia; i++) msg("ERRO", "peneira sem marcar: " vazias[i])
    if (n_marc + 0 >= 5 && n_vazia + 0 == 0) ok["pen"] = 1
  }

  if (ok["secoes"]) print "ok\tseções: as 6 do modelo"
  if (ok["crit"]) print "ok\tcritérios de aceite: " ok["crit"]
  if (ok["pen"]) print "ok\tcinco peneiras marcadas"
  for (i = 1; i <= n_msg; i++) print tipo[i] "\t" texto[i]
}
' "$arq")

erros=0; avisos=0
echo "confere $arq"
while IFS="$(printf '\t')" read -r t s; do
  [ -n "$t" ] || continue
  case "$t" in
    ERRO) erros=$((erros + 1)); printf '  %-6s %s\n' ERRO "$s" ;;
    aviso) avisos=$((avisos + 1)); printf '  %-6s %s\n' aviso "$s" ;;
    *) printf '  %-6s %s\n' "$t" "$s" ;;
  esac
done <<EOF
$saida
EOF

pl() { [ "$1" -eq 1 ] && printf '%s %s' "$1" "$2" || printf '%s %s' "$1" "$3"; }
if [ "$erros" -eq 0 ]; then
  echo "resultado: ok ($(pl "$erros" erro erros), $(pl "$avisos" aviso avisos))"
  exit 0
fi
echo "resultado: NÃO PASSA ($(pl "$erros" erro erros), $(pl "$avisos" aviso avisos))"
exit 1
