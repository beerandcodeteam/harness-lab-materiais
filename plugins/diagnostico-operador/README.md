# diagnostico-operador

Plugin do Harness Lab (aula 1.1). A skill `/diagnostico-operador` lê o seu histórico do Claude Code
em `~/.claude/projects/` e mede quem fez o trabalho andar no repositório: você (o Operador) ou o
trilho. Ela separa cada mensagem sua em pedido de trabalho novo ou toque de operador (testou,
retomou, aprovou, repetiu) e grava `diagnostico-operador.md` na raiz do repositório.

```bash
claude plugin marketplace add beerandcodeteam/harness-lab-materiais
claude plugin install diagnostico-operador@harness-lab
```

Dentro do Claude Code, na raiz do seu repositório:

| Comando | O que faz |
| --- | --- |
| `/diagnostico-operador antes` | Foto do "antes": sessões interativas dos últimos 30 dias |
| `/diagnostico-operador listar testou repetiu` | Mensagens desses papéis (prática da aula 1.3) |
| `/diagnostico-operador depois` | Mede a execução do loop (`.phases/logs`) no dia 7 |
| `/diagnostico-operador comparar` | Tabela antes x depois |
| `/diagnostico-operador projetos` | Lista onde há sessões, se você abriu fora de um repositório |

Precisa de `python3`. Só lê o histórico; escreve apenas em `.diagnostico-operador/` e
`diagnostico-operador.md`. Guia completo: `modulo-1-o-operador-e-o-trilho/aula-1.1-voce-virou-operador-do-agente/`.
