# As cinco peneiras (aula 1.5)

Cada peneira segura um tipo de pedra. O que chega no fundo é pouca coisa, pequena e
sólida: a feature-alvo. Pular peneira não economiza tempo, só empurra o problema para o
dia 7, quando o loop roda sozinho na feature.

Passe na ordem. A primeira que reprova já basta, a não ser que uma fatia da candidata
passe em todas (aí a fatia vira a candidata). Nunca afrouxe uma peneira para uma candidata
passar. A sugestão do agente também passa pela peneira: quem escolhe é o usuário.

## 1. Pequena: segura o que é grande demais

- Pergunta: cabe em 2 a 4 fases, cada uma com o próprio critério de pronto? É régua de
  bolso, não é lei.
- Sinais de que não cabe: "refazer", "migrar", "o sistema inteiro", "todo o", prazo em
  semanas, mais de 10 critérios de aceite.
- Como medir: liste as fases que você imagina e conte os critérios (3 a 5 é o alvo).
  No Módulo 4, o `/plan` da aula 4.3 (cópia do `commands/plan.md` do BC Harness 0.2.0)
  usa a contagem de critérios para escolher o tamanho do plano: até 3 é `light`, de 4 a 10
  é `standard`, 11 ou mais é `complete`.
- Se cair: corte uma fatia que entrega sozinha (um fluxo, um tipo de usuário, uma tela).
  O resto do bolo continua lá para depois.

## 2. Verificável: segura o que é vago

- Pergunta: dá para escrever 3 critérios "Quando ..., então ..." com um resultado que
  outra pessoa, ou um teste, confere sem precisar perguntar?
- Sinais de que não dá: adjetivo no lugar de resultado (melhor, mais bonito, mais rápido,
  amigável, adequado), "melhorar X", "deixar X bom".
- Como medir: para cada critério, diga o que um teste olharia: um estado no banco, uma
  contagem, uma mensagem exata, um status HTTP, a URL.
- Se cair: troque o adjetivo por número ou texto exato. "Mais rápido" vira "20 por página,
  com o total no cabeçalho". "Mensagem amigável" vira "a mensagem 'Este e-mail já está
  cadastrado' aparece abaixo do campo".

## 3. Isolada: segura o que está acorrentado no resto do sistema

- Pergunta: encosta em pouca coisa? Um endpoint novo, um campo novo, uma validação.
- Sinais de acoplada: trocar o ORM, mudar a autenticação, refatorar um sistema, migrar de
  framework, mexer em algo que todo módulo usa. Com essas, o loop mexe em arquivo que
  ninguém pediu e quebra teste que nem é da feature.
- Como medir: `scripts/area.sh` com 2 ou 3 nomes da área, em português e em inglês
  (ex.: `area.sh cadastro register signup email`). A pergunta da aula: você revisaria
  esses arquivos com calma num PR?
- Se cair: corte por enquanto, ou fique com a parte que mexe numa ponta só.

## 4. Valor real: segura o que não tem valor para você

- Pergunta: você faria isso de qualquer jeito, mesmo sem o curso? Está no backlog, o time
  pediu, te incomoda toda semana?
- Quem responde: só o usuário. Nunca marque esta peneira por conta própria.
- Se cair: troque de candidata. Feature de mentira não atesta que você resolveu um
  problema seu, e perde para a primeira prioridade que aparecer antes do dia 7.

## 5. Sem terceiro instável: segura o que depende de alguém de fora que falha

- Pergunta: dá para provar a feature sem API externa, sandbox de pagamento, serviço de
  outro time ou a resposta de um modelo de IA?
- Por quê: teste que depende disso fica vermelho e verde sem você mudar uma linha. O loop
  lê o vermelho como "eu errei" e mexe no código que estava certo.
- Como medir: `scripts/area.sh` mostra pistas (cliente HTTP, SDK, URL). Pergunte de onde
  vem o dado que a prova vai conferir.
- Se cair: escolha a parte que dá para provar aqui dentro (cálculo, validação, montagem do
  payload, tratamento de uma resposta gravada). A integração fica para depois.
