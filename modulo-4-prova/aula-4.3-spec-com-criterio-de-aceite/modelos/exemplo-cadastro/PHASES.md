# Phases: cadastro-email-duplicado

Exemplo do curso (aula 4.3), escrito à mão no formato do planner do /plan (bc-harness 0.2.0), para o cadastro da aula 1.5. Não é saída de um /plan de verdade: mostra a forma que o loop do Módulo 5 lê. O seu sai em `.spec/features/<slug>/PHASES.md`.

## Phase 1: Recusa sem diferença de caixa

Antes de implementar, leia:
1. `.spec/features/cadastro-email-duplicado/SPEC.md`: requisitos RIGID que esta fase cobre
2. `.spec/features/cadastro-email-duplicado/PLAN.md`: decomposição completa, dependências e riscos

- [ ] T01: E-mail em minúsculas antes de validar e de gravar
      Arquivos: `app/Actions/Fortify/CreateNewUser.php`
      Mudança: aplicar trim e minúsculas ao email do input antes do Validator e gravar o valor normalizado. A regra unique de `app/Concerns/ProfileValidationRules.php` fica como está.
      Cobre: RF-01, RF-02
      Acceptance criteria: com ana@exemplo.com cadastrado, POST /register com Ana@Exemplo.com volta com erro em email e `users` continua com 1 linha; cadastro novo com Bruno@Exemplo.com grava bruno@exemplo.com.
      Testes: `tests/Feature/CadastroNormalizaEmailTest.php`: e-mail novo gravado em minúsculas; e-mail com outra caixa recusado.
- [ ] T02: Ativar AC-02 no teste de aceite
      Arquivos: `tests/Feature/CadastroEmailDuplicadoTest.php`
      Mudança: tirar o ->todo() do AC-02 e fazer passar. Só o marcador sai; o corpo do teste não muda.
      Cobre: AC-02
      Acceptance criteria: o teste AC-02 roda sem ->todo() e passa.
      Testes: `tests/Feature/CadastroEmailDuplicadoTest.php`: AC-02.

## Phase 2: Mensagem no campo de e-mail

Antes de implementar, leia:
1. `.spec/features/cadastro-email-duplicado/SPEC.md`: requisitos RIGID que esta fase cobre
2. `.spec/features/cadastro-email-duplicado/PLAN.md`: decomposição completa, dependências e riscos

- [ ] T03: Mensagem "Este e-mail já está cadastrado" para e-mail repetido
      Arquivos: `app/Actions/Fortify/CreateNewUser.php`
      Mudança: passar ao Validator a mensagem de `email.unique`: "Este e-mail já está cadastrado". Nenhuma outra mensagem de validação muda.
      Cobre: RF-03
      Acceptance criteria: POST /register com e-mail repetido volta com o erro do campo email exatamente igual a "Este e-mail já está cadastrado"; com email vazio, a mensagem continua a de hoje.
      Testes: `tests/Feature/CadastroMensagemTest.php`: mensagem do unique; mensagem do required sem mudança.
- [ ] T04: Ativar AC-03 e fechar o aceite
      Arquivos: `tests/Feature/CadastroEmailDuplicadoTest.php`
      Mudança: tirar o ->todo() do AC-03 e fazer passar. AC-01 e AC-04 seguem ativos e verdes.
      Cobre: AC-01, AC-03, AC-04
      Acceptance criteria: os quatro testes, AC-01 a AC-04, rodam sem ->todo() e passam; a suíte inteira passa.
      Testes: `tests/Feature/CadastroEmailDuplicadoTest.php`: AC-01, AC-02, AC-03, AC-04.
