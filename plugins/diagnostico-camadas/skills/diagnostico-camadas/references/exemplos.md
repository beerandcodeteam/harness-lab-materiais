# Exemplos resolvidos

Um por camada, mais os dois que mais confundem. Em cada um: o que aconteceu, a camada,
a pergunta que decidiu e o que teria evitado.

## Os dois que mais confundem

| O que aconteceu | Camada | Pergunta que decidiu | O que teria evitado |
| --- | --- | --- | --- |
| Estava escrito no CLAUDE.md "nunca rode `php artisan migrate:fresh`". No meio da feature, para o teste passar, ele rodou e apagou o banco local. (Node: `npx prisma migrate reset`. Rails: `rails db:reset`.) | Trava | 2. Sabia e fez mesmo assim | Um hook `PreToolUse` que barra o comando (aula 2.3). Repetir a regra em maiúscula não resolve: ele já sabia |
| Usou um método que não existe mais na versão do SDK do projeto. Parecia "o modelo é burro". | Regra | 1. Não tinha a informação | A versão do SDK e a doc dela no contexto: skill ou rule com a doc da versão (Módulo 3). O modelo conhece a versão que viu no treino |

## Um de cada

| O que aconteceu | Camada | Pergunta que decidiu | O que teria evitado |
| --- | --- | --- | --- |
| Criou o endpoint devolvendo um array solto, e o projeto inteiro responde `{ data, meta }`. O padrão não estava escrito em lugar nenhum. | Regra | 1. Não tinha a informação | O padrão de resposta numa skill ou rule que entra quando ele mexe em endpoint (aulas 3.2 e 3.3) |
| Leu o `.env` para "conferir a conexão" e colou a senha do banco na resposta. | Trava | 2. Sabia e fez mesmo assim (ou nem precisava saber: segredo não depende de bom senso) | `permissions.deny` com `Read(./.env)` ou um hook que barra o arquivo (aula 2.3) |
| Disse "pronto, testes passando". Os testes passavam, mas nenhum chamava a API de verdade, e a integração devolveu 400. | Prova | 3. Disse "pronto" e não estava | Critério de aceite escrito antes e um teste que toca o comportamento real (Módulo 4) |
| Terminou a migration, parou e ficou esperando. Você digitou "continua" seis vezes na mesma tarde. | Loop | 4. Parou e esperou você | A lista de tarefas e o loop que pega a próxima sozinho, com a Prova no meio (Módulo 5) |
| Duas horas na mesma sessão. Na terceira feature, ele voltou a usar o nome de tabela que você tinha corrigido na primeira. | Loop | 4. A sessão longa estragou o resto | Uma sessão nova por tarefa, com o estado em arquivo e no git (Módulo 5). Antes disso: `/clear` entre tarefas |
| Pediu um algoritmo de agendamento com restrições que conflitam. Com a regra escrita, o teste pronto e três tentativas limpas, ele errou as três. | Inteligência | 5. Com as quatro de pé, ainda erraria | Quebrar o problema em partes menores ou fazer você a parte difícil. É raro: confira as quatro perguntas de novo antes de marcar |

## Sintoma não é causa

- "Errou o teste" parece Prova. Se ele não sabia como o projeto testa, é Regra.
- "Rodou o comando errado" parece Trava. Se o comando certo não estava escrito em lugar nenhum, é Regra.
- "Esqueceu a regra" parece Regra. Se a regra estava no CLAUDE.md e ele recita quando você pergunta, é Trava.
- "Ficou burro no fim do dia" parece Inteligência. Quase sempre é sessão longa: Loop.
