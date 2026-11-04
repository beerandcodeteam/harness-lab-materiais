# Feature-alvo · Harness Lab

## Descrição
Hoje o cadastro aceita um e-mail que já existe quando muda só a caixa
das letras (Ana@Exemplo.com e ana@exemplo.com), e a pessoa acaba com
duas contas. A feature faz o cadastro recusar e-mail repetido,
ignorando maiúsculas, e mostrar o motivo no próprio campo.

## Por que é pequena
Três fases: validação no backend, mensagem no formulário, e-mail
salvo em minúsculas. Toca o controller (ou handler) de cadastro, a
regra de validação e o template do formulário. Nada de login, senha
ou permissão.

## Critérios de aceite (rascunho)
- [ ] Quando cadastro com um e-mail que já existe, então recebo erro
      de validação e nenhum usuário novo é criado.
- [ ] Quando cadastro Ana@Exemplo.com e já existe ana@exemplo.com,
      então o cadastro é recusado do mesmo jeito.
- [ ] Quando o cadastro é recusado, então a mensagem "Este e-mail já
      está cadastrado" aparece abaixo do campo de e-mail.
- [ ] Quando cadastro um e-mail novo, então o usuário é criado e o
      login funciona como antes.

## Como eu verificaria hoje, na mão
Abro a tela de cadastro, cadastro ana@exemplo.com, tento de novo com
Ana@Exemplo.com e olho a tela. Depois confiro no banco (php artisan
tinker, rails console ou npx prisma studio):
SELECT COUNT(*) FROM users WHERE LOWER(email) = 'ana@exemplo.com';
O resultado precisa ser 1.

## Riscos
- O banco já pode ter e-mails duplicados: um índice único quebra a
  migration. Conferir antes.
- Convite, importação por CSV e login social também criam usuário e
  podem não passar pela mesma validação. Se for preciso mexer neles,
  fica para depois desta feature.

## Cinco peneiras
- [x] Pequena: cabe em poucas fases.
- [x] Verificável: cada critério tem resposta sim ou não.
- [x] Isolada: não exige mexer em metade do sistema.
- [x] Valor real: eu faria isso de qualquer jeito.
- [x] Sem terceiro instável: dá para provar sem serviço de fora.
