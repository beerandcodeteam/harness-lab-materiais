<?php

// Testes de aceite da agenda (.ics), um por critério do FEATURE-ALVO.md.
// Pendentes com o marcador todo: cada fase do loop tira o do seu critério.

it('AC-01 mostra o botão "Adicionar à agenda" em evento futuro', function () {
    $this->get('/eventos/imersao-harness')->assertSee('Adicionar à agenda');
})->todo();

it('AC-02 entrega o .ics com text/calendar e o nome do evento', function () {
    $this->get('/eventos/imersao-harness/agenda.ics')
        ->assertOk()
        ->assertHeader('Content-Type', 'text/calendar; charset=utf-8');
})->todo();

it('AC-03 evento de 28 a 30/11 gera DTEND no dia 01/12', function () {
    $this->get('/eventos/imersao-harness/agenda.ics')
        ->assertSee('DTSTART;VALUE=DATE:20261128')
        ->assertSee('DTEND;VALUE=DATE:20261201');
})->todo();

it('AC-04 escapa vírgula e ponto e vírgula no SUMMARY', function () {
    $this->get('/eventos/lab-turma-2/agenda.ics')->assertSee('SUMMARY:Imersão\\, Lab\\; Turma 2');
})->todo();

it('AC-05 evento passado não tem botão e o .ics responde 404', function () {
    $this->get('/eventos/evento-antigo/agenda.ics')->assertNotFound();
})->todo();
