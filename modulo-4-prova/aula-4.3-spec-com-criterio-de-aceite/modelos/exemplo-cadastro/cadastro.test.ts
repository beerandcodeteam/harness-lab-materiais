// cadastro.test.ts · aula 4.3 · um teste por critério do FEATURE-ALVO.md (Vitest ou Jest)
// Pendente = test.skip com o corpo escrito. Não use test.todo: no Jest ele lança erro
// se receber o corpo. O loop só troca test.skip por test.
// Vitest: os globais test/expect vêm do import abaixo. Jest: apague o import.
import { beforeEach, expect, test } from 'vitest';
import { cadastrar, type Usuario } from './cadastro';

let usuarios: Usuario[];

beforeEach(() => {
  usuarios = [{ nome: 'Ana Souza', email: 'ana@exemplo.com' }];
});

test('AC-01 · recusa e-mail que já existe e não cria usuário', () => {
  const r = cadastrar(usuarios, { nome: 'Ana de novo', email: 'ana@exemplo.com' });

  expect(r.ok).toBe(false);
  expect(usuarios).toHaveLength(1);
});

test.skip('AC-02 · recusa o mesmo e-mail com outra caixa', () => {
  const r = cadastrar(usuarios, { nome: 'Ana de novo', email: 'Ana@Exemplo.com' });

  expect(r.ok).toBe(false);
  expect(usuarios.filter((u) => u.email.toLowerCase() === 'ana@exemplo.com')).toHaveLength(1);
});

test.skip('AC-03 · mostra "Este e-mail já está cadastrado" no campo de e-mail', () => {
  const r = cadastrar(usuarios, { nome: 'Ana de novo', email: 'ana@exemplo.com' });

  expect(r).toEqual({ ok: false, erros: { email: 'Este e-mail já está cadastrado' } });
});

test('AC-04 · cadastra e-mail novo, como antes', () => {
  const r = cadastrar(usuarios, { nome: 'Bruno Lima', email: 'bruno@exemplo.com' });

  expect(r.ok).toBe(true);
  expect(usuarios.map((u) => u.email)).toContain('bruno@exemplo.com');
});
