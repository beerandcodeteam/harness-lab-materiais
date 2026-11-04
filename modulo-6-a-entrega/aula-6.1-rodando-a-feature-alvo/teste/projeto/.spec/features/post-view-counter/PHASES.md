# Phases: post-view-counter

Projeto de teste da aula 6.1: as cinco fases da gravação, com tasks curtas.

## Phase 1: Storage e configuração

Antes de implementar, leia:
1. `.spec/features/post-view-counter/SPEC.md`

- [ ] T01: Storage dos contadores
      Arquivos: `src/fase-1.txt`
      Acceptance criteria: src/fase-1.txt existe e diz ok.
      Testes: `vendor/bin/sail test`: a suíte inteira.
- [ ] T02: Configuração da feature
      Arquivos: `src/fase-1.txt`
      Acceptance criteria: a configuração fica em src/fase-1.txt.
      Testes: `vendor/bin/sail test`: a suíte inteira.

## Phase 2: Services e infraestrutura HTTP

- [ ] T03: Service de registro, base do AC-01 e do AC-02
      Arquivos: `src/fase-2.txt`
      Acceptance criteria: src/fase-2.txt diz ok.
      Testes: `vendor/bin/sail test`: a suíte inteira.

## Phase 3: Endpoint e admin

- [ ] T04: Endpoint e coluna no admin (AC-03)
      Arquivos: `src/fase-3.txt`, `tests/Feature/Blog/PostViewAceiteTest.php`
      Acceptance criteria: src/fase-3.txt diz ok; AC-03 roda sem pendente.
      Testes: `tests/Feature/Blog/PostViewAceiteTest.php`: AC-03.

## Phase 4: Disparo na view

- [ ] T05: Disparo na view do post (AC-01 e AC-02)
      Arquivos: `src/fase-4.txt`, `tests/Feature/Blog/PostViewAceiteTest.php`
      Acceptance criteria: src/fase-4.txt diz ok; AC-01 e AC-02 rodam sem pendente.
      Testes: `tests/Feature/Blog/PostViewAceiteTest.php`: AC-01 e AC-02.

## Phase 5: Verificação transversal

- [ ] T06: Suíte inteira verde, sem teste de aceite pendente
      Arquivos: `src/fase-5.txt`
      Acceptance criteria: src/fase-5.txt diz ok; a suíte inteira passa.
      Testes: `vendor/bin/sail test`: a suíte inteira.
