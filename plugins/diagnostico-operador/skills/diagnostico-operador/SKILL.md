---
name: diagnostico-operador
description: Mede quem fez cada parte do trabalho neste repositório, se você (o Operador) ou o trilho (harness). Use "antes" no início do curso (lê as sessões interativas do Claude Code) e "depois" quando o loop terminar (lê .phases/logs) para comparar. Harness Lab, aulas 1.1 e dia 7.
argument-hint: antes | depois | comparar | listar | projetos
disable-model-invocation: true
allowed-tools: Bash(python3 ${CLAUDE_SKILL_DIR}/scripts/medir.py *), Read, Write
---

# Diagnóstico do Operador

Mede, com o histórico real, **quem fez o trabalho andar**: você ou o trilho. Não é nota nem julgamento. Pedir trabalho novo é o seu papel e não conta contra você. O que conta são os momentos em que você fez um trabalho que uma estrutura poderia fazer no seu lugar. Esses são os **toques de operador**:

| Papel | Quando |
|---|---|
| **testou** | você testou na mão e avisou que algo não funciona, colou erro ou log |
| **retomou** | você retomou, mandou continuar, cobrou status ou perguntou se terminou |
| **aprovou** | você aprovou, autorizou ou escolheu uma opção que o agente propôs, ou fez na mão um passo que destravou o agente |
| **repetiu** | você repetiu algo que o agente já devia saber: convenção, preferência, contexto do projeto |

**Nos modos `antes` e `listar`, não use os nomes das camadas do curso (Regra, Trava, Prova, Loop) para falar destes papéis.** Dizer qual camada faltou em cada caso é a prática da aula 1.4, que tem um método próprio. O diagnóstico não pode adiantar essa resposta nem contradizê-la.

O script é `${CLAUDE_SKILL_DIR}/scripts/medir.py`. Ele só lê o histórico em `~/.claude/projects/` e escreve apenas em `.diagnostico-operador/` e `diagnostico-operador.md`, na raiz do repositório medido. Rode sempre com `python3 ${CLAUDE_SKILL_DIR}/scripts/medir.py ...`.

Argumento recebido: `$ARGUMENTS`. Se vier vazio, use `antes` quando `.diagnostico-operador/antes.json` não existir; senão, pergunte se é `depois` ou `comparar`.

## Qual repositório medir

O script mede o repositório git do diretório atual (e as sessões abertas em subpastas dele). Se o diretório atual não for um repositório git, ou for a pasta pessoal ou uma pasta que só agrupa projetos (como `~/projects`):

1. Rode `python3 ${CLAUDE_SKILL_DIR}/scripts/medir.py projetos`. Ele lista as pastas onde o aluno abriu o Claude Code nos últimos 30 dias, com o número de sessões interativas.
2. Mostre a lista e pergunte qual é o projeto em que ele mais trabalha com o agente.
3. Nos comandos seguintes, passe `--repo <pasta escolhida>` logo depois de `medir.py` (exemplo: `medir.py --repo "/home/ana/projetos/loja" antes`). Os arquivos de saída vão para a pasta escolhida.

## antes

1. `python3 ${CLAUDE_SKILL_DIR}/scripts/medir.py antes`
   - Mostre as pastas de sessão que ele leu e confirme com o aluno que são deste projeto. O script também pega as sessões abertas em subpastas e a cópia do mesmo repositório aberta pelo outro lado do WSL, como `/mnt/c/...`.
   - Se `entregas_commits` vier vazio ou 0 (repo sem git, ou sem commits na janela), pergunte quantas entregas o aluno fez nesse período e rode de novo com `--entregas N` (exemplo: `medir.py antes --entregas 5`).
2. Leia `.diagnostico-operador/antes-mensagens.jsonl` e classifique **cada** mensagem (veja "Como classificar"). Grave `.diagnostico-operador/antes-classes.jsonl`, uma linha por mensagem: `{"id": 0, "papel": "testou"}`.
3. `python3 ${CLAUDE_SKILL_DIR}/scripts/medir.py fechar antes`
4. Mostre ao aluno os números e os exemplos de cada papel. Explique em uma frase cada métrica: toques por entrega (quantas vezes ele fez o papel do trilho para cada commit), trecho autônomo típico (a mediana de quanto tempo o agente trabalhou sozinho depois de cada mensagem dele) e o maior trecho. Pergunte qual foi a situação que mais o fez operar o agente nesta semana e acrescente a frase dele no fim de `diagnostico-operador.md`, numa linha `- O que mais me fez operar: ...`.
5. Lembre o aluno de que o Claude Code apaga sessões com mais de 30 dias (configurável em `cleanupPeriodDays`). Este snapshot é o "antes" do curso e precisa ficar salvo. Se ele não quiser versionar, sugira colocar `.diagnostico-operador/` e `diagnostico-operador.md` em `.git/info/exclude`.

## depois

1. `python3 ${CLAUDE_SKILL_DIR}/scripts/medir.py depois` (use `--logs <pasta>` se os logs do loop não estiverem em `.phases/logs`).
2. Se houver mensagens do aluno durante a janela do loop, classifique `.diagnostico-operador/depois-mensagens.jsonl` em `depois-classes.jsonl`, como no passo 2 do `antes`.
3. `python3 ${CLAUDE_SKILL_DIR}/scripts/medir.py fechar depois`
4. Siga para `comparar`.

## comparar

`python3 ${CLAUDE_SKILL_DIR}/scripts/medir.py comparar` imprime a tabela antes x depois e a acrescenta a `diagnostico-operador.md`. Mostre a tabela e leia com o aluno, linha por linha, o que passou a ser feito pelo trilho: o gate testando, o loop retomando, as regras e travas que dispensaram aprovação e repetição. Aqui, depois da aula 1.4, já pode falar das camadas. Se alguma linha do depois ainda tiver toques do aluno, mostre as mensagens com `listar ... --de depois` e pergunte qual camada ele reforçaria.

## listar

`python3 ${CLAUDE_SKILL_DIR}/scripts/medir.py listar testou repetiu` imprime as mensagens desses papéis com a data. É o ponto de partida da prática da aula 1.3 (as últimas correções). Aceita qualquer papel, e `--de depois` lista as mensagens do dia 7.

## Como classificar

Um papel por mensagem. Leia a mensagem inteira. Quando ela misturar papéis, use o primeiro que se aplicar nesta ordem: **testou, repetiu, aprovou, retomou, pedido, outro**.

- **testou**: "To falando e nada acontecendo", "nao consigo abrir o app com --pt", log ou stack trace colado, "a tela não está mostrando X", "deu erro", "tem uns problemas na conversa". Avisar que **funcionou** depois de testar na mão também conta, quando é só confirmação ("ok, agora foi"). Se junto vier trabalho novo, é pedido.
- **repetiu**: "me dá o caminho completo" pela segunda vez, "lembrando que aqui é o X", "não usa Y", "sempre faz Z", correção de estilo ou convenção que vale para sempre e não só para esta tarefa.
- **aprovou**: "pode fazer o 1", "posso rodar o .bat?", "mantém o opus então", "taca pau", "pode apagar o cache", "fiz o login no terminal". É aprovação ou escolha, sem escopo novo.
- **retomou**: "retome", "continua", "como estamos?", "será que demora?", "ta rodando mesmo?", "como continuo amanhã?", "beleza, ta andando".
- **pedido**: trabalho ou pergunta nova vinda do aluno: feature, pesquisa, dúvida técnica, mudança de direção. É o papel dele de verdade e não conta como toque de operador.
- **outro**: elogio, conversa, mensagem duplicada, "vou dormir".

Na dúvida entre pedido e um papel, escolha **pedido**: o diagnóstico deve errar a favor do aluno, nunca inflar o Operador. Se houver mais de 300 mensagens, o script entrega só as 300 mais recentes e reescala a contagem.

## O que o script não vê

- Sessões de `claude -p` e de scripts (entrypoint `sdk-cli`): não é o aluno digitando.
- Revisar diff e refazer na mão: são ações, não mensagens. Se o aluno quiser esse número, ele anota à parte.
- Pausas de mais de 1 hora com a sessão aberta encerram o trecho autônomo: horas paradas não contam como o agente trabalhando sozinho.
