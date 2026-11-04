// cadastro.ts · aula 4.3 · o cadastro "de hoje", só para os testes rodarem.
// No seu projeto, o teste importa a sua rota, handler ou serviço de cadastro.
// Recusa e-mail idêntico, mas não ignora maiúsculas e responde em inglês.

export type Usuario = { nome: string; email: string };
export type Resultado =
  | { ok: true; usuario: Usuario }
  | { ok: false; erros: Record<string, string> };

export function cadastrar(usuarios: Usuario[], dados: Usuario): Resultado {
  if (usuarios.some((u) => u.email === dados.email)) {
    return { ok: false, erros: { email: 'The email has already been taken.' } };
  }
  usuarios.push(dados);
  return { ok: true, usuario: dados };
}
