// Testes de aceite da agenda (.ics), escritos antes do código (Módulo 4).
// Pendentes com .skip: a task de ativação de cada fase tira o marcador.
import { test } from 'node:test';
import assert from 'node:assert/strict';

test.skip('AC-01 evento de 28/11 a 30/11: DTSTART 20261128 e DTEND 20261201', async () => {
  const { paraEvento } = await import('../src/agenda-ics.mjs');
  const ics = paraEvento({ nome: 'Imersão Harness', inicio: '2026-11-28', fim: '2026-11-30' });
  assert.match(ics, /DTSTART;VALUE=DATE:20261128/);
  assert.match(ics, /DTEND;VALUE=DATE:20261201/);
});

test.skip('AC-02 evento sem fim: DTEND no dia seguinte ao início', async () => {
  const { paraEvento } = await import('../src/agenda-ics.mjs');
  const ics = paraEvento({ nome: 'Live', inicio: '2026-12-10', fim: null });
  assert.match(ics, /DTEND;VALUE=DATE:20261211/);
});

test.skip('AC-03 vírgula e ponto e vírgula escapados no SUMMARY', async () => {
  const { paraEvento } = await import('../src/agenda-ics.mjs');
  const ics = paraEvento({ nome: 'Imersão, Lab; Turma 2', inicio: '2026-11-28', fim: null });
  assert.match(ics, /SUMMARY:Imersão\\, Lab\; Turma 2/);
});
