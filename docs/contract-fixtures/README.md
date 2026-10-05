# contract-fixtures

"Contrato" é o que o app e o backend combinam entre si: quais rotas existem, que campos vêm em cada resposta, o que é `null`, em que formato vêm as datas e as horas. Esta pasta guarda **provas de que esse contrato é o que o backend realmente faz**, para o app Flutter não ser escrito em cima de suposições.

## O que tem aqui

| O quê | Para que serve |
| --- | --- |
| `responses/*.json` | Respostas **reais** do backend, gravadas por `capture.mjs`: `{status, body}` de cada chamada (login, biblioteca, feed, perfis, conversas, erros...). Os testes do Flutter leem esses arquivos e conferem se os modelos Dart entendem o formato verdadeiro. Os dados são sintéticos e os tokens são mascarados. |
| `capture.mjs` | Roda uma sequência de chamadas contra um backend e regrava `responses/`. |
| `*_contract.mjs`, `notification_dedup.mjs`, `entries_privacy.mjs`, `refresh_race.mjs` | Scripts de verificação com `assert`. Cada um prova uma regra do backend: PATCH que limpa campos, notificação sem duplicar, anotações só para o dono, renovação de sessão sem corrida, regras do chat e do push. Eles **falharam antes das correções** e passam agora; por isso ficam como teste de regressão. |
| `socket_probe.dart` | Sonda do Socket.IO feita em Dart: conecta, entra na sala, envia e recebe mensagem. Provou que o cliente Dart conversa com o servidor. |

## Como rodar

Sempre contra um backend **isolado** (banco e Redis próprios, nunca produção ou banco compartilhado), porque os scripts criam usuários e dados:

```bash
# backend isolado (exemplo): Postgres em :5433, Redis em :6380, API em :3100
cd backend && DATABASE_URL=... REDIS_URL=... PORT=3100 AUTH_RATE_LIMIT_MAX=1000 npm run dev

# em outro terminal
API=http://localhost:3100/api node docs/contract-fixtures/patch_contract.mjs
API=http://localhost:3100/api node docs/contract-fixtures/entries_privacy.mjs
```

Os scripts que usam o jogo sintético `900001` (como `entries_privacy.mjs`) precisam que ele exista no cache de jogos do backend isolado, porque a IGDB não é usada nesses testes. O `capture.mjs` cria esses jogos inserindo-os no Postgres pelo container indicado em `PG_CONTAINER` (`API=http://localhost:3100/api PG_CONTAINER=gt-flutter-pg node docs/contract-fixtures/capture.mjs`).

## Quando mexer

- Mudou uma rota ou um campo do backend: rode o script correspondente e, se o formato mudou, rode `capture.mjs` para atualizar `responses/` e depois `flutter test`, que mostra o que o app não entende mais.
- Achou um bug de contrato: escreva primeiro um script aqui que falha, corrija o backend e confirme que passa.
- O gerador dos payloads de push é `backend/scripts/capturePushPayloads.ts` (grava `responses/push_payloads.json`).
