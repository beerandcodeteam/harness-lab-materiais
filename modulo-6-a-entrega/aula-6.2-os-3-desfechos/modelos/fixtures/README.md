# Fixtures da aula 6.2 · oito estados de run

Para treinar a leitura do desfecho antes do seu run, sem gastar token. Cada um é um `run.tsv`
(o estado que o ralph do bc-harness grava em `.phases/state/`) ou uma pasta no formato do
`.loop-logs/<run>/` que o `loop.sh` do Módulo 5 guarda (`run.tsv`, `logs/`, `prompts/`).

"Gerado" quer dizer: o `ralph.sh` de verdade (bc-harness 0.2.0, do cache do plugin), com um `claude`
falso no PATH no lugar da sessão, num repositório temporário com um PHASES de duas fases de uma
agenda (.ics). O ralph é o real; a sessão do Claude é simulada. Por isso o comando de teste aparece
como `testes/motor-falso/teste-do-projeto`.

| Arquivo | Origem | O que o `desfecho.sh` diz | Exit |
|---|---|---|---|
| `run-entregou.tsv` | Real: `workshop-cron-explainer`, run de 19/08/2026 | ENTREGOU 4/4, fases 1 a 3 já implementadas, 13m 08s | 0 |
| `run-falhou-g3/` | Gerado: o juiz reprova a task 1 nos 3 ciclos | FALHOU, fase 1, gate 3, `verify-3.log`, camada provável Prova | 20 |
| `run-falhou-g2/` | Gerado: o teste do AC-03 vermelho nos 3 ciclos | FALHOU, gate 2, `test-3.log` | 20 |
| `run-falhou-g0/` | Gerado: a sessão termina sem a linha de resultado | FALHOU, gate 0, fim do `cycle-3.log`, camada provável Loop | 20 |
| `run-interrompido.tsv` | Gerado: Ctrl-C no grupo do ralph com a fase 1 rodando | INTERROMPIDO, sem causa no log | 21 |
| `run-morto.tsv` | Gerado: `kill -KILL` no grupo | MORTO, o PID gravado não existe mais | 22 |
| `run-esperando.tsv` | Gerado: limite de uso, `kill -KILL` durante a espera | MORTO "durante a espera". Com um ralph vivo naquele PID, seria ESPERANDO LIMITE (11) | 22 |
| `run-sem-commit.tsv` | Gerado: tudo verde com um hook de `pre-commit` recusando | ENTREGOU 2/2. Num repositório sem os commits `feat(phase-N)`, vira alerta de fase sem commit | 0 |

No `run-falhou-g0/`, a camada provável sai como "teto de tempo do shim (o timeout sai com 124, aula
5.2)", o freio de condições de parada.

Arquivo solto (fora de um `.phases/` ou `.loop-logs/`) não é cruzado com o git: o `desfecho.sh`
só cruza fases e commits no repositório dono do run. Os PIDs gravados são de 03/11/2026; se por
acaso um processo com o mesmo número existir na sua máquina, o script confere o nome pelo `/proc`
(Linux) e continua dizendo MORTO.

Uso, na raiz do seu projeto, com a aula 6.2 instalada:

```bash
A=~/harness-lab-materiais/modulo-6-a-entrega
F=$A/aula-6.2-os-3-desfechos/modelos/fixtures
.claude/scripts/desfecho.sh "$F/run-falhou-g3/" || echo "exit $?"
```
