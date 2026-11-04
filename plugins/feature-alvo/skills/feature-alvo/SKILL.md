---
name: feature-alvo
description: Ajuda a escolher, no repositório atual, a feature-alvo do Harness Lab, a feature que o loop vai entregar no dia 7. Levanta candidatas reais (git log, branches, TODO e FIXME, o backlog que o usuário contar), passa cada uma nas cinco peneiras (pequena, verificável, isolada, valor real, sem terceiro instável) e grava FEATURE-ALVO.md na raiz com 3 a 5 critérios de aceite em rascunho. Prática da aula 1.5 do Harness Lab.
disable-model-invocation: true
argument-hint: "[ideia de feature, opcional]"
allowed-tools:
  - Bash(${CLAUDE_SKILL_DIR}/scripts/candidatas.sh *)
  - Bash(${CLAUDE_SKILL_DIR}/scripts/area.sh *)
  - Bash(${CLAUDE_SKILL_DIR}/scripts/confere.sh *)
  - Read
---

# Escolher a feature-alvo (aula 1.5)

Objetivo: o usuário sai com `FEATURE-ALVO.md` na raiz do repositório, com uma feature que
passou nas cinco peneiras e de 3 a 5 critérios de aceite em rascunho. É essa feature que o
loop entrega no Módulo 6. Fale em português, frases curtas.

Regras desta skill:

- O único arquivo que você escreve é o `FEATURE-ALVO.md` da raiz. Não mexa em código, não
  escreva teste (os primeiros nascem no Módulo 4) e não faça commit sem o usuário pedir.
- Toda candidata vem de uma evidência: um commit, uma branch, um marcador no código ou algo
  que o usuário contou. Sugestão sua, lendo o código, entra marcada como "sugestão do
  agente" e passa pelas mesmas peneiras.
- Quem escolhe é o usuário. Você recomenda, ele decide.
- Se a sessão está em modo de plano, faça as etapas 1 a 4 só lendo e mostre o arquivo
  pronto no plano. Grave depois que o usuário aprovar.

## 0. O arquivo já existe?

Se existe `FEATURE-ALVO.md` na raiz, rode `${CLAUDE_SKILL_DIR}/scripts/confere.sh FEATURE-ALVO.md`.

- "espaço do modelo sobrando" em quase tudo: é o modelo vazio do `instalar.sh 1.5`. Siga
  e preencha esse arquivo.
- "resultado: ok": a feature-alvo já foi escolhida. Mostre o arquivo e pergunte se o usuário
  quer revisar os critérios ou escolher de novo. Sem resposta, pare aqui.
- Outro erro: ofereça corrigir só o que o `confere.sh` apontou.

## 1. Levante candidatas reais

Rode `${CLAUDE_SKILL_DIR}/scripts/candidatas.sh 20`. Ele mostra os últimos commits, as
branches, os TODO, FIXME e HACK, os arquivos mais mexidos e se o projeto tem teste.

Na mesma mensagem, pergunte ao usuário o que o git não sabe: duas ou três coisas do backlog,
do que o time pediu ou do que incomoda toda semana. Se ele passou uma ideia em `$ARGUMENTS`,
ela é a primeira candidata.

Monte de 3 a 5 candidatas. Uma linha cada: o que muda para quem usa o sistema e a evidência
(hash do commit, `arquivo:linha` do marcador, nome da branch ou "você contou").

## 2. Passe cada candidata nas cinco peneiras

Leia `${CLAUDE_SKILL_DIR}/references/peneiras.md` e `${CLAUDE_SKILL_DIR}/references/exemplos.md`.
Passe na ordem: pequena, verificável, isolada, valor real, sem terceiro instável.

- Isolada: rode `${CLAUDE_SKILL_DIR}/scripts/area.sh <termos>` com 2 ou 3 nomes da área,
  em português e em inglês (ex.: `cadastro register email`). Mostre a contagem e pergunte
  se ele revisaria esses arquivos com calma num PR.
- Valor real: só o usuário responde. Pergunte e espere.
- Sem terceiro instável: use as pistas do `area.sh` e pergunte de onde vem o dado que a
  prova vai conferir.

Mostre uma tabela: candidata, uma coluna por peneira (passa ou cai) e o veredito. Quando
uma candidata cai, proponha a fatia da própria candidata que passaria (nas linhas da tabela
de exemplos sem "(aula)", o alvo bom é a fatia do ruim: use como modelo) e trate a fatia como
candidata nova. Se cai em valor real, não há fatia: troque de candidata. Nunca afrouxe uma
peneira para alguém passar.

## 3. O usuário escolhe

Recomende uma, com o motivo em uma frase, e espere a escolha. Se nenhuma passou nas cinco,
volte à etapa 1 com candidatas novas.

## 4. Rascunhe os critérios de aceite

De 3 a 5, no formato `- [ ] Quando <ação>, então <resultado que dá para conferir>.`

- Um comportamento por linha, com um resultado que um teste consegue ler: estado no banco,
  contagem, mensagem exata entre aspas, status, URL.
- Inclua o caminho feliz que não pode quebrar (no exemplo: e-mail novo continua criando o
  usuário).
- Sem palavra vaga: rápido, bom, melhor, bonito, amigável, adequado, eficiente,
  corretamente, quando possível. Troque por número ou por texto exato.
- Sem numeração `AC-` nem forma DEVE ou NÃO DEVE: isso é o Módulo 4. Hoje é rascunho.

Mostre os critérios e peça para o usuário confirmar ou ajustar antes de gravar.

## 5. Grave o FEATURE-ALVO.md

Use exatamente os títulos e a ordem de `${CLAUDE_SKILL_DIR}/references/modelo.md`. O
Módulo 4 parte deles. O exemplo preenchido está em
`${CLAUDE_SKILL_DIR}/references/exemplo-preenchido.md`.

- Descrição: 2 ou 3 frases, o que muda para quem usa o sistema.
- Por que é pequena: quantas fases você imagina (2 a 4) e os arquivos ou módulos que toca.
- Critérios de aceite (rascunho): os da etapa 4.
- Como eu verificaria hoje, na mão: tela, comando ou consulta que o usuário faria.
- Riscos: o que pode fazer ela crescer ou travar, e o que fica fora desta feature.
- Cinco peneiras: as cinco linhas do modelo, marcadas `- [x]`. Se alguma não pode ser
  marcada, essa não é a feature-alvo: volte à etapa 2.

Não acrescente seção nem comentário HTML. Código ou tag vai entre crases. Depois de gravar,
rode `${CLAUDE_SKILL_DIR}/scripts/confere.sh FEATURE-ALVO.md` e corrija até
"resultado: ok". Mostre os avisos ao usuário: aviso não reprova, mas vale olhar.

## 6. Feche

Mostre o arquivo final e diga ao usuário as duas saídas, sem rodar nenhuma sozinho:

- Repositório dele: commit (`git add FEATURE-ALVO.md` e `git commit`).
- Repositório da empresa, sem versionar: `echo "/FEATURE-ALVO.md" >> .git/info/exclude`.

Nunca deixe o arquivo solto, fora do git e fora do exclude: o pré-voo do loop do Módulo 5
recusa árvore suja, e um `git clean -fd` apaga arquivo não versionado. Termine com uma
linha: no Módulo 4 esses critérios viram especificação e os primeiros testes.
