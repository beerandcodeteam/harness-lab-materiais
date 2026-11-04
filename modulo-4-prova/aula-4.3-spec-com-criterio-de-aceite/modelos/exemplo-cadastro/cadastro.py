"""cadastro.py · aula 4.3 · o cadastro "de hoje", só para os testes rodarem.

No seu projeto, o teste importa a sua view, rota ou serviço de cadastro.
Recusa e-mail idêntico, mas não ignora maiúsculas e responde em inglês.
"""


def cadastrar(usuarios, nome, email):
    if any(u["email"] == email for u in usuarios):
        return {"ok": False, "erros": {"email": "The email has already been taken."}}
    usuario = {"nome": nome, "email": email}
    usuarios.append(usuario)
    return {"ok": True, "usuario": usuario}
