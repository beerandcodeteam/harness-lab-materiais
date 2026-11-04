# Modelo · critérios de aceite (aula 4.3)

Cole a seção abaixo no seu `FEATURE-ALVO.md`, no lugar de "Critérios de aceite (rascunho)". Use lista `- AC-NN`, não `- [ ]`: a caixinha fica só para a checklist das cinco peneiras.

## Critérios de aceite
Testes em `<arquivo de teste>`. Comando do juiz: `<o comando da aula 4.1>`.

- AC-01 [<forma>] <frase na forma da tabela abaixo>.
  - Confere: <o que o teste mede: estado final, contagem, mensagem exata, código de status>.
  - Teste: <ativo, porque já funciona hoje | pendente, porque é novo>.
- AC-02 [<forma>] <frase>.
  - Confere: <...>.
  - Teste: <ativo | pendente>.

## As quatro formas

O plugin pede GEARS e não fixa palavra-chave. Estas são as quatro formas da aula, como saem nas SPECs reais do bc-harness, em português. O nome entre parênteses é o do specifier. A lista dele tem também `[Optional]` (ONDE ..., para recurso que pode estar ligado ou não), rara nas SPECs reais. E a SPEC gerada pode trazer um rótulo fora da lista, `[Ubiquitous]`: requisito sem gatilho ("O sistema DEVE ..."). Na SPEC da gravação da aula, RF-07, UI-01 e UI-02 saíram assim.

| Forma | Molde | Exemplo |
|---|---|---|
| Evento (Event-Driven) | QUANDO `<gatilho>`, o sistema DEVE `<resposta>`. | - AC-01 [Evento] QUANDO alguém se cadastra com um e-mail novo, o sistema DEVE criar o usuário e deixar a pessoa logada. |
| Estado (State-Driven) | ENQUANTO `<estado>`, o sistema DEVE `<comportamento>`. | - AC-02 [Estado] ENQUANTO a conta não confirmou o e-mail, o sistema DEVE mostrar o aviso de confirmação no topo do painel. |
| Condição (Conditional) | SE `<condição>`, ENTÃO o sistema DEVE `<resposta>`. | - AC-03 [Condição] SE o cadastro é recusado por e-mail repetido, ENTÃO o sistema DEVE mostrar "Este e-mail já está cadastrado" no campo de e-mail. |
| Indesejado (Unwanted) | SE `<situação indesejada>`, ENTÃO o sistema NÃO DEVE `<efeito>`. | - AC-04 [Indesejado] SE o e-mail já existe com outra caixa, ENTÃO o sistema DEVE recusar e NÃO DEVE criar usuário. |

## Antes de fechar cada critério

- Um estado final que se mede. "Recusa e NÃO DEVE criar usuário" se mede (`users` continua com 1 linha). "Valida o e-mail" não.
- Como provar: a linha "Confere" diz o que o teste olha. Se você não sabe escrever a linha, o critério ainda não está pronto.
- O que não pode mudar no caminho: o caminho feliz de hoje vira critério também (no exemplo, o AC de e-mail novo).
- Palavra proibida: rápido, bom, adequado, amigável, eficiente, quando possível, idealmente, etc. Troque por número ou por texto exato.
- Duas leituras possíveis? Escreva `[NEEDS CLARIFICATION: <a dúvida>]` no lugar de escolher uma. É o mesmo marcador que o specifier usa.

Exemplo completo, com os quatro critérios do cadastro: `exemplo-cadastro/FEATURE-ALVO.md`.
