# assistente-voz

## Decisões
- Modelo carrega uma vez no startup (`src/assistente/modelo.py`), nunca por requisição.

## Erros que já aconteceram
- Rodar inferência sem `torch.inference_mode()` estourou a memória da GPU.
