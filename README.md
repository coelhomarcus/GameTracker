# GameTracker

App social pra acompanhar os jogos que você tá jogando: trackeie playthroughs (status, horas, nota, plataforma), veja um perfil com seu backlog e o dos amigos, poste sobre o que tá jogando, comente, siga outras pessoas e converse em tempo real. Trabalho de faculdade.

## O que o app faz

- **Biblioteca**: seus jogos por status (backlog, jogando, concluído, abandonado), com horas, nota de 1 a 10, datas, plataforma e anotações pessoais (só você vê). Replays contam como registros separados.
- **Explorar**: busca de jogos (dados da IGDB) e de pessoas.
- **Comunidade**: feed Geral e Seguindo, posts, atividades automáticas ao concluir ou abandonar um jogo, curtidas e comentários com respostas.
- **Perfis**: coleção, atividades e posts, favoritos, seguir, editar nome, bio, foto e capa.
- **Mensagens**: chat 1:1 em tempo real, com reconexão, envio sem duplicar, digitação e presença.
- **Notificações**: curtidas, comentários e novos seguidores, com selo no sino.

Push com o app fechado ainda não existe (precisa de um projeto Firebase); as notificações aparecem dentro do app.

## Estrutura

| Pasta | O que é |
| --- | --- |
| [`frontend/`](frontend/) | App oficial: Flutter (Android e web), Material 3, Riverpod, go_router, Dio, Socket.IO |
| [`backend/`](backend/) | API: Node.js, Express 5, TypeScript, Drizzle ORM (PostgreSQL), Redis + Socket.IO, JWT, IGDB |
| [`docs/`](docs/) | Documentação: [migração para Flutter](docs/MIGRACAO_FLUTTER.md) (decisões, histórico, aceite e o que falta), [roadmap histórico](docs/01_ROADMAP.md) |
| `docker-compose.test.yml` | Postgres e Redis descartáveis só para os testes |
| `.github/workflows/` | CI do Flutter, do backend (com integração Flutter↔API) e geração do APK de release |

## Rodando localmente

Pré-requisitos: Node 22+, Docker (pro Postgres e Redis locais), Flutter 3.47 (e o Android SDK, se for gerar APK) e uma conta na [IGDB/Twitch Developer](https://api-docs.igdb.com/#getting-started) pra buscar jogos.

### 1. Banco e Redis

```bash
docker compose -f docker-compose.dev.yml up -d   # Postgres :5432 e Redis :6379
```

### 2. Backend

```bash
cd backend
cp .env.example .env   # preencha DATABASE_URL, JWT_ACCESS_SECRET, IGDB_CLIENT_ID e IGDB_CLIENT_SECRET
npm install
npm run db:migrate     # aplica as migrations
npm run dev            # http://localhost:3000
```

Variáveis do `.env` que merecem atenção:

| Variável | Para quê |
| --- | --- |
| `DATABASE_URL`, `REDIS_URL` | Postgres e Redis |
| `JWT_ACCESS_SECRET` | Segredo dos tokens (troque o valor do exemplo) |
| `IGDB_CLIENT_ID`, `IGDB_CLIENT_SECRET` | Busca de jogos. Sem elas a busca responde `igdb_not_configured` |
| `PUBLIC_API_URL` | URL pública da API, usada nas URLs de capa e de upload |
| `CORS_ORIGINS` | Origens web autorizadas, separadas por vírgula. Sem ela qualquer origem é aceita. Defina em produção |
| `AUTH_RATE_LIMIT_MAX` | Só para ambientes de teste: sobe o limite de login e cadastro (padrão 20 por 15 min por IP) |

### 3. App Flutter

```bash
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_URL=http://localhost:3000
```

O app procura a API em `http://localhost:3100` por padrão (`http://10.0.2.2:3100` no emulador Android); passe `--dart-define=API_URL=...` para apontar para outro endereço, sem `/api` no fim. Mais detalhes em [`frontend/README.md`](frontend/README.md).

## Testes

Os testes ficam junto de cada projeto:

| Onde | O que cobre | Como rodar |
| --- | --- | --- |
| `frontend/test/` | Unidade e widget, suíte de aceite (layout, acessibilidade, volume) | `cd frontend && flutter analyze && flutter test` |
| `frontend/test/integration/` | O app contra um **backend real** (sessão, biblioteca, feed, perfis, chat com sockets, volume) | veja abaixo |
| `backend/src/**/*.test.ts` | Unidade (CORS, push, controllers) | `cd backend && npm test` |
| `backend/test/api/` | A **API de verdade** (Express + Socket.IO + Postgres + Redis): sessão e refresh, PATCH da biblioteca, privacidade das notas, notificações, perfil e upload, push, chat | `cd backend && npm test` |

Os testes criam e apagam dados, então rodam **só** em um banco local cujo nome termina em `_test` (a trava recusa qualquer outro, inclusive o de desenvolvimento). O ambiente descartável sobe com Docker:

```bash
cd backend
cp .env.test.example .env.test   # uma vez (fica fora do git)
npm run test:db:up               # Postgres :5434 e Redis :6381 de teste + migrations
npm test                         # backend: unidade + API (108 testes)
```

Para os testes de integração do Flutter, suba a API de teste em outro terminal:

```bash
cd backend && npm run test:seed && npm run dev:test        # jogos sintéticos + API em :3100
cd frontend && flutter test test/integration --dart-define=GT_BACKEND=http://localhost:3100
```

`frontend/test/fixtures/` guarda respostas reais do backend para os testes de modelo (veja o README da pasta). O GitHub Actions roda tudo isso em `.github/workflows/backend.yml`.

## Build do APK (Android)

```bash
cd frontend
# precisa de android/key.properties (fora do git) com a chave de assinatura
API_URL=https://api.seudominio.com tool/build_release.sh
```

O script exige API com HTTPS e recusa APK assinado com a chave de debug. O mesmo fluxo roda no GitHub Actions (`.github/workflows/flutter-release.yml`, com secrets). Para só demonstrar o app, o APK debug que o CI gera (`flutter.yml`) já basta. Detalhes e como gerar a chave em [`docs/MIGRACAO_FLUTTER.md`](docs/MIGRACAO_FLUTTER.md#9-build-distribuição-e-ambientes).

## Documentação

- [`docs/MIGRACAO_FLUTTER.md`](docs/MIGRACAO_FLUTTER.md): como e por que o app foi refeito em Flutter, o que foi verificado, as limitações e as ideias do que falta.
- [`docs/01_ROADMAP.md`](docs/01_ROADMAP.md): histórico do projeto, anterior à migração.
