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

## Critérios de aceite
Testes em `tests/Feature/CadastroEmailDuplicadoTest.php`. Comando do juiz: `vendor/bin/sail test`.

- AC-01 [Indesejado] SE alguém se cadastra com um e-mail que já existe, ENTÃO o sistema DEVE recusar com erro de validação no campo e-mail e NÃO DEVE criar usuário.
  - Confere: a resposta traz erro em `email`; a tabela `users` continua com 1 linha; ninguém fica logado.
  - Teste: ativo. O cadastro já faz isso hoje; o teste protege contra regressão.
- AC-02 [Indesejado] SE o e-mail já existe com outra caixa (ana@exemplo.com cadastrado, Ana@Exemplo.com enviado), ENTÃO o sistema DEVE recusar do mesmo jeito e NÃO DEVE criar usuário.
  - Confere: a resposta traz erro em `email`; `SELECT COUNT(*) FROM users WHERE LOWER(email) = 'ana@exemplo.com'` devolve 1.
  - Teste: pendente. Hoje o cadastro aceita e cria a segunda conta.
- AC-03 [Condição] SE o cadastro é recusado por e-mail repetido, ENTÃO o sistema DEVE mostrar a mensagem "Este e-mail já está cadastrado" no campo de e-mail.
  - Confere: a mensagem de erro do campo `email` é exatamente "Este e-mail já está cadastrado". Na tela, ela aparece abaixo do campo (E2E da aula 4.4).
  - Teste: pendente. Hoje a mensagem é a padrão do framework, em inglês.
- AC-04 [Evento] QUANDO alguém se cadastra com um e-mail novo, o sistema DEVE criar o usuário e deixar a pessoa logada, como antes.
  - Confere: `users` ganha 1 linha com o e-mail enviado; a sessão fica autenticada; a resposta não traz erro.
  - Teste: ativo. Protege o caminho feliz enquanto o resto muda.

Fora do escopo: convite, importação por CSV e login social. Nenhum critério acima fala deles.

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
