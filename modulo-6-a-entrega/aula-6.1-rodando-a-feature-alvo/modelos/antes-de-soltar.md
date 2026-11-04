# Antes de soltar o loop · aula 6.1

Releia antes de cada run. Cada item tem o comando que prova. Troque `<slug>` pelo nome da
pasta da sua feature em `.spec/features/`.

## O que a aula revisou

- [ ] **A Regra está escrita.** `AGENTS.md` (ou `CLAUDE.md`) gerado pelo `/bc-harness:ai-context`
      e enxuto, com as guidelines do Boostify ou do Laravel Boost (aulas 3.1, 3.2 e 3.4).
      Prova: `wc -l CLAUDE.md AGENTS.md` (meta da doc, usada na 3.1: menos de 200 linhas por
      arquivo; o `/enxuto:enxugar-claude-md` mede e enxuga) e `ls docs/agents`.
- [ ] **A feature tem plano em fases.** SPEC, PLAN e PHASES do `/plan` da aula 4.3
      (`instalar.sh 4.3`, `/plan FEATURE-ALVO.md`; só com o plugin, `/bc-harness:plan FEATURE-ALVO.md`).
      Prova: `ls .spec/features/<slug>/`.
- [ ] **O loop existe e tem os gates** (Módulo 5): árvore limpa, sessão sem cabeça (`claude -p`),
      suíte de testes e juiz. Prova: `.claude/scripts/loop.sh --checa .spec/features/<slug>/PHASES.md`.
- [ ] **É a feature-alvo da aula 1.5:** pequena e verificável. Prova: `ls FEATURE-ALVO.md`
      (o plugin `feature-alvo@harness-lab` escreve o arquivo).
- [ ] **A guarda dos testes de aceite está ligada** (aula 4.2): `instalar.sh 4.2` e o
      `.claude/aceite.txt` com os seus testes.

## As cinco perguntas da documentação

Fonte: https://code.claude.com/docs/en/best-practices, seção "Let Claude run without you".

| Pergunta | Onde está a resposta no seu repositório | Linha do `--checa` |
|---|---|---|
| Sabe o que é pronto? | SPEC com critérios e um "Acceptance criteria" por task no PHASES (4.3) | `confere-phases`, testes de aceite |
| Consegue checar o próprio trabalho? | Gate 2 roda a suíte; gate 3, o juiz, confere task por task | `Prova:` |
| O que pode tocar? | Uma branch só da feature, as Travas do Módulo 2, o hook dos testes de aceite | `branch:`, `hook guarda-aceite.py` |
| O que para? | `MAX_CICLOS`, `LOOP_TIMEOUT` e `LOOP_BUDGET_USD` por sessão (Módulo 5) | `freios:` |
| Para onde vai e quem aprova? | Um `feat(phase-N)` por fase na branch, o aviso no celular, o PR que é seu (6.3) | `aviso:` no bloco de camadas |

## No terminal, antes do Enter

- [ ] Branch só da feature: `git branch --show-current` não é `main` nem `master`.
- [ ] Árvore limpa: `git status --short` vazio. O `.spec/` do `/plan` commitado (ele nunca commita).
- [ ] `__pycache__/` no `.gitignore` (os hooks Python da aula 2.3 gravam bytecode).
- [ ] Diagnóstico da 1.1 no `.git/info/exclude`: `/.diagnostico-operador/` e `/diagnostico-operador.md`.
      Numa git worktree o `.git` é um arquivo: o exclude certo é o de `git rev-parse --git-path info/exclude`,
      e o `loop.sh` já grava o `/.loop-logs/` e o `/.phases/` nele.
- [ ] Nenhuma credencial de API exportada: `env | grep -E 'ANTHROPIC|CLAUDE_CODE_USE'` vazio.
      Com a chave no ambiente, o `claude -p` cobra por API, não pela assinatura.
- [ ] O comando de teste roda: container de pé (`vendor/bin/sail up -d`, `docker compose up -d`).
- [ ] O aviso chegou: `.claude/scripts/aviso-env.sh "teste"`, com os segredos em
      `~/.config/harness-lab/aviso.env` e o link `.claude/scripts/.env` ignorado pelo git
      (`git check-ignore -v .claude/scripts/.env`). Token nunca exportado no terminal.
- [ ] Terminal próprio, dentro de um tmux (`tmux new -s loop`). Nunca pelo Bash do Claude Code: lá o
      comando estoura o timeout e vai para segundo plano, sem terminal e sem o painel.
- [ ] Um ralph por vez: o `loop.sh` ou o ralph da 5.3, nunca os dois na mesma árvore.
- [ ] Tempo reservado: nos runs reais medidos para o curso, uma fase leva de 6 a 33 minutos
      (pico de 1h39). O run da gravação: 5 fases em 62 minutos.

## Enquanto roda

- [ ] Assista a fase 1 até o primeiro `feat(phase-1)` no `git log --oneline -1`. Depois, saia.
- [ ] Não mexa na árvore: cada fase fecha com `git add -A`, e o que você criar entra no commit.
- [ ] Não edite o PHASES: o próximo run zera o progresso e refaz as fases já feitas.
- [ ] Antes de rodar de novo, guarde o log: o ralph apaga `.phases/` a cada run
      (o `loop.sh` já copia para `.loop-logs/<run>/`).
