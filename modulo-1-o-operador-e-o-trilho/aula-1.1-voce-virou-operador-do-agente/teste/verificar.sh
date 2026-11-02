#!/usr/bin/env bash
# verificar.sh · aula 1.1 · roda no ~/projeto da sandbox, depois dos comandos do material.
# Prova que o plugin diagnostico-operador foi instalado pelo marketplace harness-lab e que o
# medir.py faz o ciclo inteiro (antes, fechar, listar, depois, comparar) num histórico falso
# criado por sessoes-falsas.py. A classificação, que na vida real é o agente que faz, aqui é fixa.
set -euo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
n=0
ok() { n=$((n + 1)); printf '  ok  %s\n' "$1"; }
erro() { printf 'FALHOU: %s\n' "$1" >&2; exit 1; }

# ------------------------------------------------------------------ instalação
claude plugin list | grep -q 'diagnostico-operador@harness-lab' ||
  erro "claude plugin list não mostra diagnostico-operador@harness-lab"
SK="$(find "$HOME/.claude/plugins" \
  -path '*/cache/harness-lab/diagnostico-operador/*/skills/diagnostico-operador/SKILL.md' | head -n 1)"
[ -n "$SK" ] || erro "SKILL.md do plugin não está em ~/.claude/plugins"
M="$(dirname "$SK")/scripts/medir.py"
[ -f "$M" ] || erro "scripts/medir.py não veio junto com a skill"
head -n 1 "$SK" | grep -qx -- '---' || erro "SKILL.md sem frontmatter"
grep -q '^name: diagnostico-operador$' "$SK" || erro "frontmatter sem name: diagnostico-operador"
grep -q '^disable-model-invocation: true$' "$SK" || erro "a skill devia ser só manual (/diagnostico-operador)"
grep -q 'CLAUDE_SKILL_DIR}/scripts/medir.py' "$SK" || erro "SKILL.md não aponta para o script do plugin"
python3 -m py_compile "$M"
ok "plugin instalado, skill com frontmatter válido, medir.py compila"

# ------------------------------------------------------------------ histórico falso
python3 "$AQUI/sessoes-falsas.py" "$PWD" >/dev/null
med() { python3 "$M" "$@"; }

out="$(cd "$HOME" && med projetos)"
grep -q "$PWD\$" <<<"$out" || erro "projetos não lista a raiz do projeto"
ok "projetos: lista onde há sessões (para quem roda fora de um repositório)"

out="$(med antes --entregas 5)"
J=.diagnostico-operador/antes.json
[ -f "$J" ] || erro "antes não gravou $J"
v() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d[sys.argv[2]])' "$J" "$1"; }
[ "$(v sessoes)" = 3 ] || erro "esperava 3 sessões (raiz, subpasta, WSL), veio $(v sessoes)"
[ "$(v mensagens_suas)" = 8 ] || erro "esperava 8 mensagens do aluno, veio $(v mensagens_suas)"
[ "$(v interrupcoes)" = 1 ] || erro "esperava 1 interrupção, veio $(v interrupcoes)"
grep -q 'outro-' <<<"$(v pastas_sessao)" && erro "pegou o projeto vizinho que só termina com o mesmo nome"
grep -q 'mnt-c' <<<"$(v pastas_sessao)" || erro "não pegou a cópia do repo aberta pelo /mnt/c"
grep -q 'mensagem do loop' .diagnostico-operador/antes-mensagens.jsonl &&
  erro "contou sessão de claude -p (sdk-cli) como mensagem do aluno"
grep -q '/clear' .diagnostico-operador/antes-mensagens.jsonl && erro "contou /clear como mensagem"
[ "$(v maior_trecho_autonomo_min)" = 50.0 ] || erro "maior trecho autônomo: $(v maior_trecho_autonomo_min)"
ok "antes: raiz + subpasta + /mnt/c, sem sdk-cli, sem /clear, sem o vizinho"

# a classificação que o agente faria, na ordem das mensagens (mais antiga primeiro)
i=0
for p in pedido testou retomou aprovou repetiu outro pedido retomou; do
  printf '{"id": %d, "papel": "%s"}\n' "$i" "$p"
  i=$((i + 1))
done > .diagnostico-operador/antes-classes.jsonl
med fechar antes >/dev/null
[ "$(v toques_de_operador)" = 5 ] || erro "toques de operador: $(v toques_de_operador), esperava 5"
[ "$(v toques_por_entrega)" = 1.0 ] || erro "toques por entrega: $(v toques_por_entrega)"
grep -q 'toques por entrega: 1.0' diagnostico-operador.md || erro "diagnostico-operador.md sem o resumo"
grep -q 'repetiu: "lembrando que aqui é Pest' diagnostico-operador.md || erro "md sem o exemplo de repetiu"
ok "fechar antes: 5 toques, 1.0 por entrega, exemplos no diagnostico-operador.md"

out="$(med listar testou repetiu)"
[ "$(wc -l <<<"$out")" -eq 2 ] && grep -q '\[testou\]' <<<"$out" || erro "listar testou repetiu: $out"
ok "listar testou repetiu: as 2 mensagens que a aula 1.3 usa"

# ------------------------------------------------------------------ dia 7 (loop falso)
mkdir -p .phases/logs
printf '{"type":"result","duration_ms":600000,"num_turns":12,"total_cost_usd":0.5}\n' \
  > .phases/logs/phase-01.log
printf 'fase 1 COMPLETA\n' > .phases/logs/ralph.log
med depois --entregas 1 >/dev/null
med fechar depois >/dev/null
tab="$(med comparar)"
grep -q '| Toques de operador por entrega | 1.0 |' <<<"$tab" || erro "comparar sem a linha de toques"
grep -q 'Antes x depois' diagnostico-operador.md || erro "comparar não gravou a tabela no md"
ok "depois + comparar: tabela antes x depois no diagnostico-operador.md"

echo "verificar.sh: $n grupos de checagem passaram."
