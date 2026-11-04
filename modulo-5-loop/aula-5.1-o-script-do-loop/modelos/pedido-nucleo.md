# Pedido · aula 5.1 · o núcleo do loop, testado sem gastar token

A receita da aula em código: quebra o PHASES em fases, abre uma sessão headless por fase, roda a Prova fora da sessão, commita se passou e tenta de novo com a causa se falhou. Quem aprova o script é o juiz com o motor falso, não você e não o Claude.

## Antes: a pasta de ensaio

Numa pasta fora de qualquer repositório, com o juiz, o motor falso e os dois pedidos ao lado:

```bash
A=~/harness-lab-materiais/modulo-5-loop/aula-5.1-o-script-do-loop
mkdir -p ~/harness-lab-sandbox && cd ~/harness-lab-sandbox
cp -r "$A/modelos/teste" "$A/modelos/motor-falso" "$A"/modelos/pedido-*.md .
```

Abra o Claude Code nessa pasta (`claude`).

## O pedido (cole no Claude Code)

> Escreva loop-minimo.sh em bash, até 50 linhas. Uso: ./loop-minimo.sh PHASES.md. Variáveis: ENGINE (padrão claude), TESTE (obrigatório), TENTATIVAS (padrão 3). Para cada heading '## Phase N: título': sessão nova com `$ENGINE -p "<prompt>" --dangerously-skip-permissions < /dev/null`, com o texto da fase no prompt; qualquer outro heading '## ' encerra a fase, como no ralph. Rode $TESTE; verde → git add -A e commit 'feat(phase-N): título'; vermelho → nova tentativa com as últimas 40 linhas da saída sob 'Motivo da falha'. Esgotou → 'travou na fase N' e exit 1. Acabou → 'terminou' e exit 0.

## O que ler no script gerado

Os seis passos, na ordem: quebra as fases · sessão nova com a fase · roda a Prova fora da sessão · verde, commit · vermelho, tenta de novo com a causa · esgotou, para. Confira também:

- `ENGINE` troca só o binário: serve para um CLI com as flags do claude, como o motor falso. Com `ENGINE=codex` quebra, porque no codex `-p` é `--profile`; o headless dele é `codex exec`, que lê o prompt do stdin com `-`. O ralph faz essa troca por dentro com `--engine codex`.
- `< /dev/null` na sessão: o `claude -p` lê o stdin quando ele não é um terminal, e engoliria o que o script estivesse lendo.
- A Prova roda fora da sessão, pelo script. Não é o modelo dizendo que passou.
- `--dangerously-skip-permissions` é a mesma flag do ralph. No `-p`, sem modo de permissão, o Claude Code começa no modo Manual e nega o que pediria aprovação. Em bypass, o que ainda segura são as regras de deny e os hooks `PreToolUse`: as Travas do Módulo 2.

## Como conferir

Na mesma pasta, fora do Claude Code:

```bash
bash teste/testa-loop-minimo.sh
```

Sem argumento, o juiz testa o `loop-minimo.sh` da pasta de cima, que é o seu. Três cenários com o motor falso: `ok` (2 commits de fase), `falha-uma-vez` (a fase 2 passa na 2a tentativa e o prompt traz "Motivo da falha") e `nunca-passa` (exit 1, sem commit). Esperado: `testa-loop-minimo: 15 passaram`.

Reprovou? Cole a falha no Claude Code e peça a correção uma vez. Não fechou, compare com o de referência: `$A/modelos/loop-minimo.sh` (39 linhas).

## No seu repositório (zero token)

Numa branch descartável, o seu núcleo no seu PHASES, com o motor falso e a sua Prova:

```bash
git switch -c ensaio-nucleo
ENGINE=~/harness-lab-sandbox/motor-falso/claude TESTE="<seu comando de teste>" ~/harness-lab-sandbox/loop-minimo.sh .spec/features/<slug>/PHASES.md
git switch - && git branch -D ensaio-nucleo
```

O motor falso não implementa nada (escreve `src/fase-N.txt`): o que se vê é o encanamento, as suas fases, a sua Prova e um commit por fase.

## Depois

O núcleo não tem os outros dois gates da receita da aula: a árvore limpa antes de começar e o avaliador. Próximo pedido: `pedido-gates.md`.
