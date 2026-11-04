import { test } from 'node:test';
import assert from 'node:assert/strict';
import { eventoPorSlug } from '../src/eventos.mjs';

test('acha o evento pelo slug', () => {
  assert.equal(eventoPorSlug('imersao-harness').nome, 'Imersão Harness');
});

test('slug que não existe devolve null', () => {
  assert.equal(eventoPorSlug('nao-existe'), null);
});
