# boostify

A filosofia do Laravel Boost para qualquer stack que não seja Laravel (Node/TS, Python, Ruby, Go,
Rust, Elixir, Java, .NET). Aula 3.2 do Harness Lab.

1. Detecta a stack e as versões instaladas (lockfile, `node_modules`, `go.mod`, `Gemfile.lock`,
   `Cargo.lock`...) e os comandos que o CI roda (`scripts/detecta.py`, só leitura).
2. Pergunta ao context7 o que muda na versão maior de cada pacote principal.
3. Mostra o bloco e, depois da sua aprovação, grava só entre `<boostify-guidelines>` e
   `</boostify-guidelines>` no CLAUDE.md. O que o time escreveu fora do bloco fica intacto.
4. Devolve sugestões: o "nunca rode X" vira hook, o passo a passo longo vira skill.

```bash
claude plugin marketplace add beerandcodeteam/harness-lab-materiais
claude plugin install boostify@harness-lab
npx ctx7 setup --claude
```

Na sessão interativa: `/reload-plugins` e `/boostify:boostify`. Num projeto Laravel, ele para e
manda usar o Laravel Boost.
