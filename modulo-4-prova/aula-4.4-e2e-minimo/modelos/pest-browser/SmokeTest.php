<?php

// SmokeTest.php · aula 4.4 · o comando da Prova consegue abrir um navegador?
//
// Onde pôr: tests/Browser/SmokeTest.php (e tests/Browser numa <testsuite> do phpunit.xml)
// Fica ATIVO, sem marcador de pendente. O E2E da feature nasce pendente, e teste pendente não abre
// o navegador: sem este smoke, a Prova fica verde mesmo sem Chromium no ambiente.
//
// Rode no MESMO comando da Prova (com Sail, dentro do container):
//   vendor/bin/sail test --filter=Smoke      ou      ./vendor/bin/pest --filter=Smoke
// Vermelho aqui não tem nada a ver com a feature: é o ambiente. Conserte antes do E2E.

it('abre a home sem erro no console', function () {
    visit('/')->assertNoSmoke();
});
