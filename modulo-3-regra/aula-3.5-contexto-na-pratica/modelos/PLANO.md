# Frete por peso

<!--
Modelo de PLANO.md da aula 3.5. Copie para features/<sua-feature>/PLANO.md.
Um plano por feature, sempre com o mesmo nome e no mesmo lugar: é o que a
sessão nova lê para continuar, e o que o hook plano-depois-do-compact.sh
devolve ao modelo depois de cada compactação.

Regras:
- Item pendente é "- [ ]", feito é "- [x]". Um item = uma sessão curta.
- O primeiro "- [ ]" do arquivo é o próximo item. Mantenha a ordem.
- "Não deu certo" é a parte que mais economiza: sem ela, a sessão nova tenta de novo.
- O critério de pronto mora na spec da feature (Módulo 4), não aqui.
- Atualize no fim de cada item, junto com o commit.
-->

Spec: features/frete/SPEC.md (critério de pronto, Módulo 4)

## Feito
- [x] faixa "pesado" em config/frete.php (commit a1b2c3d)

## Próximo
- [ ] frete grátis acima de R$ 300
- [ ] mostrar o prazo no resumo do carrinho

## Não deu certo
- Calcular o frete no model: dobrou o arredondamento. Ficou na Action.
- Cache da tabela de faixas: os testes passaram a depender da ordem. Sem cache por enquanto.

## Decisões
- Valores em centavos (int), nunca float.
