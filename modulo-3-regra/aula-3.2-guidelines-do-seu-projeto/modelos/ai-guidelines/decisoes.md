# Decisões do projeto

<!--
Guideline do time que sobrevive a cada atualização do bloco gerado.
- Laravel: o boost:install e o boost:update colocam este arquivo dentro do <laravel-boost-guidelines>.
- Outras stacks: o boostify coloca este arquivo na seção "do projeto" do <boostify-guidelines>.
Só o que o agente não descobre lendo o código. Uma linha por decisão, com o porquê.
-->

- Regra de negócio mora em `app/Actions`, uma classe por caso de uso. Controller só valida e chama a action.
- Valor em dinheiro é inteiro em centavos. (Arredondamento de float já gerou diferença de R$ 0,01 em nota fiscal.)
- Integração externa passa sempre pelo client em `app/Clients`, que tem retry e timeout configurados.
