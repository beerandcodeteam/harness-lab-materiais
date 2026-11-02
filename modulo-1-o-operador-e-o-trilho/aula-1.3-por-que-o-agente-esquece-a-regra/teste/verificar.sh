#!/usr/bin/env bash
# verificar.sh · aula 1.3 · roda no ~/projeto da sandbox (HOME falso), depois dos comandos do material.
# Prova que:
#   - o instalar.sh 1.3 pôs o correcoes.md (modelo vazio) na raiz do projeto;
#   - o plugin correcoes@harness-lab está instalado e a skill anotar tem frontmatter válido;
#   - o mensagens.sh do plugin lê um history.jsonl falso, no formato do Claude Code 2.1.316,
#     e lista só este projeto, só as últimas N sessões, sem /comandos, marcando as correções.
set -euo pipefail

n=0
ok() { n=$((n + 1)); printf '  ok  %s\n' "$1"; }
erro() { printf 'FALHOU: %s\n' "$1" >&2; exit 1; }

# ------------------------------------------------------------------ correcoes.md no projeto
[ -f correcoes.md ] || erro "correcoes.md não foi instalado na raiz do projeto"
grep -q '| # | Quando | O que você pediu | O que o agente fez | Como você corrigiu | Camada (aula 1.4) |' correcoes.md ||
  erro "correcoes.md sem as colunas da prática"
[ "$(grep -cE '^\| [1-5] \| \| \| \| \| \|$' correcoes.md)" = 5 ] || erro "correcoes.md devia ter 5 linhas vazias"
ok "correcoes.md na raiz: colunas da prática e 5 linhas para preencher"

# ------------------------------------------------------------------ plugin
claude plugin list 2>&1 | grep -q 'correcoes@harness-lab' || erro "correcoes@harness-lab não aparece em claude plugin list"
S=$(find "$HOME/.claude/plugins" -path '*correcoes*' -name SKILL.md -path '*skills/anotar/*' | head -1)
[ -n "$S" ] || erro "SKILL.md da skill anotar não encontrado no cache de plugins"
D=$(dirname "$S")
fm=$(awk 'NR==1 && $0=="---"{f=1; next} f && $0=="---"{exit} f' "$S")
grep -q '^name: anotar$' <<<"$fm" || erro "frontmatter sem name: anotar"
grep -q '^description: .\{40,\}' <<<"$fm" || erro "frontmatter sem description"
grep -q '^disable-model-invocation: true$' <<<"$fm" || erro "a skill devia ser só manual"
grep -q 'CLAUDE_SKILL_DIR}/scripts/mensagens.sh' "$S" || erro "a skill não chama o script pelo CLAUDE_SKILL_DIR"
[ -x "$D/scripts/mensagens.sh" ] || erro "mensagens.sh sem chmod +x no plugin instalado"
[ -f "$D/references/correcoes.md" ] || erro "modelo references/correcoes.md não veio no plugin"
cmp -s "$D/references/correcoes.md" correcoes.md || erro "o modelo do plugin e o do instalar.sh estão diferentes"
bash -n "$D/scripts/mensagens.sh"
ok "plugin instalado: skill anotar (manual), script executável e o mesmo modelo do projeto"

# ------------------------------------------------------------------ mensagens.sh com histórico falso
M="$D/scripts/mensagens.sh"
unset CLAUDE_PROJECT_DIR CLAUDE_CONFIG_DIR 2>/dev/null || true
H="$HOME/.claude/history.jsonl"
[ ! -e "$H" ] || mv "$H" "$H.antes"

out=$("$M")
grep -q 'Nenhum histórico' <<<"$out" || erro "sem histórico: devia avisar e sair com 0"
ok "sem history.jsonl: avisa e sai com 0"

P="$PWD"
linha() {   # linha SESSAO MINUTO TEXTO [PROJETO]
  jq -nc --arg s "$1" --argjson t "$((1793600000000 + $2 * 60000))" --arg d "$3" --arg p "${4:-$P}" \
    '{display: $d, pastedContents: {}, timestamp: $t, project: $p, sessionId: $s}'
}
{
  linha s1aaaaaa-0 1 "sessao um: crie a tela de login"
  linha s1aaaaaa-0 2 "não, era com Livewire"
  linha s2bbbbbb-0 10 "sessao dois: rode os testes"
  linha s3cccccc-0 20 "sessao tres: adicione o campo status no pedido"
  linha s3cccccc-0 21 "/context"
  linha s3cccccc-0 22 "Para tudo! Você rodou migrate:fresh e apagou o banco"
  linha s3cccccc-0 23 "$(printf 'agora corrija só a migration\ne mostre o diff')"
  linha s4dddddd-0 30 "sessao quatro: refatore o CarrinhoService"
  linha s4dddddd-0 31 "volta, você mudou a assinatura pública"
  linha s5eeeeee-0 40 "sessao cinco: escreva o teste do cupom"
  linha s6ffffff-0 50 "sessao seis: atualize o README para o novo deploy"
  linha s6ffffff-0 51 "eu disse para não mexer no .env"
  linha s7gggggg-0 60 "sessao sete: crie o endpoint de frete"
  linha s7gggggg-0 61 "de novo usando float para dinheiro? use centavos"
  linha s7gggggg-0 62 "pq fez isso sem me avisar"
  linha s9outro0-0 70 "não, isso é de outro projeto" /tmp/outro-projeto
  echo '{isto nao e json'
  linha s8hhhhhh-0 15 "pedido de uma subpasta do projeto" "$P/app"
} > "$H"

out=$("$M")
grep -q '^# 5 sessão(ões) deste projeto' <<<"$out" || { echo "$out" >&2; erro "devia mostrar as 5 sessões mais recentes"; }
! grep -q 'sessao um\|sessao dois\|não, era com Livewire\|subpasta' <<<"$out" || erro "mostrou sessão mais antiga que as 5 últimas"
! grep -q 'outro projeto' <<<"$out" || erro "misturou mensagem de outro projeto"
! grep -q '/context' <<<"$out" || erro "devia pular /comandos"
grep -q '^\* .*Para tudo! Você rodou migrate:fresh' <<<"$out" || erro "não marcou 'Para tudo!' como correção"
grep -q '^\* .*eu disse para não mexer no .env' <<<"$out" || erro "não marcou 'eu disse' como correção"
grep -q '^\* .*de novo usando float' <<<"$out" || erro "não marcou 'de novo' como correção"
grep -q '^\* .*volta, você mudou a assinatura' <<<"$out" || erro "não marcou 'volta' como correção"
grep -q '^\* .*pq fez isso' <<<"$out" || erro "não marcou 'pq' como correção"
grep -q '^  .*sessao tres: adicione o campo status' <<<"$out" || erro "devia mostrar o pedido anterior à correção"
! grep -q 'sessao cinco' <<<"$out" || erro "sem --todas, mensagem que não é correção nem pedido anterior devia sumir"
grep -q 'nenhuma com cara de correção' <<<"$out" || erro "sessão sem correção devia ter o aviso"
ok "últimas 5 sessões, só este projeto, sem /comandos, correções marcadas com o pedido anterior"

grep -q 'agora corrija só a migration e mostre o diff' <<<"$("$M" --todas)" || erro "--todas: mensagem de várias linhas devia virar uma"
grep -q 'sessao cinco' <<<"$("$M" --todas)" || erro "--todas devia mostrar todas as mensagens"
ok "--todas mostra tudo, com mensagem de várias linhas numa linha só"

out=$("$M" 2)
grep -q '^# 2 sessão(ões)' <<<"$out" && grep -q 'eu disse' <<<"$out" && grep -q 'endpoint de frete' <<<"$out" ||
  erro "com 2, devia mostrar as 2 últimas sessões"
! grep -q 'volta, você mudou' <<<"$out" || erro "com 2, mostrou sessão a mais"
grep -q 'subpasta' <<<"$("$M" 8 --todas)" || erro "sessão aberta numa subpasta do projeto devia entrar"
grep -q 'subpasta' <<<"$(cd app && "$M" 1 --todas)" ||
  erro "rodando de app/, devia achar a sessão aberta em app/"
grep -q 'sessao sete' <<<"$(cd "${TMPDIR:-/tmp}" && CLAUDE_PROJECT_DIR="$P" "$M" 3)" || erro "CLAUDE_PROJECT_DIR devia valer sobre a pasta atual"
ok "número de sessões, subpasta do projeto e CLAUDE_PROJECT_DIR"

V=$(mktemp -d)
grep -q 'Nenhuma mensagem deste projeto' <<<"$(cd "$V" && "$M")" || erro "pasta sem sessões devia avisar"
set +e; "$M" abc >/dev/null 2>&1; rc=$?; set -e
[ "$rc" = 2 ] || erro "argumento inválido devia sair com 2, saiu com $rc"
ok "pasta sem sessões avisa; argumento inválido sai com 2"

rm -f "$H"
[ ! -e "$H.antes" ] || mv "$H.antes" "$H"
echo "verificar.sh: $n grupos de checagem passaram."
