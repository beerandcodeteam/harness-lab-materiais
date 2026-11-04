<?php

// E2E do fluxo principal da agenda: abre o evento, clica no botão, recebe o .ics.

it('baixa o .ics a partir da página do evento', function () {
    $this->get('/eventos/imersao-harness')->assertSee('/eventos/imersao-harness/agenda.ics');
    $this->get('/eventos/imersao-harness/agenda.ics')->assertOk();
})->todo();
