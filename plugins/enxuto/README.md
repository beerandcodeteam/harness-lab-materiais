# enxuto · Harness Lab, aula 3.1

Skill `/enxugar-claude-md`: passa cada linha do seu CLAUDE.md no filtro da aula 3.1 ("o agente
descobriria isso lendo o código?"), mede o que carrega em toda sessão, classifica cada linha (fica,
sai, vira hook, vira skill, vai para o prompt ou para o CLAUDE.local.md), reescreve erro cometido
como regra + jeito + porquê e propõe a versão nova. Só grava com a sua aprovação, com backup em
`CLAUDE.old.md`.

O script `skills/enxugar-claude-md/scripts/filtro.py` só lê arquivos e usa só a biblioteca padrão
do Python 3. Rode sozinho: `python3 filtro.py /caminho/do/projeto` (ou `--json`).
