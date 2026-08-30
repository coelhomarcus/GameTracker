# GameTracker — Roadmap

Checklist de progresso.

## Fase 0 — Setup do projeto
- [x] `git init` + `.gitignore`
- [x] Criar `ROADMAP.md`
- [x] Inicializar `mobile/` com Expo (TypeScript template) + React Navigation
- [x] Inicializar `backend/` com Express + TypeScript + Prisma
- [x] Docker Compose de dev (Postgres)
- [x] `.env.example` nos dois projetos

## Fase 1 — MVP: Auth + Tracker de jogos
### Backend
- [x] Schema Prisma: `users`, `refresh_tokens`, `games`, `game_entries` + migration inicial
- [x] `POST /api/auth/register`
- [x] `POST /api/auth/login`
- [x] `POST /api/auth/refresh`
- [x] `POST /api/auth/logout`
- [x] Middleware de auth (JWT)
- [x] Integração IGDB: token OAuth via Twitch + cache (código pronto, falta configurar `IGDB_CLIENT_ID`/`IGDB_CLIENT_SECRET`)
- [x] `GET /api/games/search?q=`
- [x] `GET /api/games/:id`
- [x] `POST /api/game-entries`
- [x] `GET /api/game-entries/me`
- [x] `PATCH /api/game-entries/:id`
- [x] `DELETE /api/game-entries/:id`

### Mobile
- [x] Navegação base (Login, Registro, Home, Busca, Detalhe do jogo, Perfil)
- [x] Tela de busca de jogos
- [x] Fluxo de trackear jogo (status, datas, horas, plataforma)
- [x] Tela "Meus jogos" com filtro por status
- [x] Sessão persistida (expo-secure-store + auto-login)

## Fase 2 — Timeline social
### Backend
- [x] Schema: `posts`, `comments`, `likes`, `follows`, `notifications`
- [x] `POST /api/posts`
- [x] `GET /api/feed`
- [x] `POST /api/posts/:id/like` / `DELETE /api/posts/:id/like`
- [x] `POST /api/posts/:id/comments` + `GET /api/posts/:id/comments`
- [x] `POST /api/users/:id/follow` / `DELETE /api/users/:id/follow`
- [x] `GET /api/users/:id` (perfil público)
- [x] Post automático ao completar jogo (oferecido via prompt no mobile, não é silencioso)
- [x] Push notifications (like/comentário/follow) — via Expo push tokens

### Mobile
- [x] Timeline/feed (infinite scroll)
- [x] Criar post
- [x] Perfil público + seguir
- [x] Central de notificações in-app

## Fase 3 — Chat em tempo real
### Backend
- [x] Socket.IO + Redis adapter
- [x] Schema: `conversations`, `conversation_participants`, `messages`
- [x] `GET /api/conversations` + `POST /api/conversations` (find-or-create 1:1) + `POST /api/conversations/:id/read`
- [x] `GET /api/conversations/:id/messages`
- [x] Eventos socket: `message:send/receive`, `typing:start/stop`, `presence:online/offline`, `conversation:join/leave`

### Mobile
- [x] Lista de conversas (com indicador de não lida)
- [x] Tela de chat 1:1 (histórico paginado + tempo real)
- [x] Indicador de digitando/online (online funciona quando ambos estão na tela do chat — ver nota abaixo)
- [x] Push notification de mensagem nova

## Fase 4 — Polimento e deploy

**Infra**: Postgres e Redis já rodam no Dokploy (não é este projeto que sobe eles). O backend vira uma Application no Dokploy, buildada a partir do `backend/Dockerfile`. Traefik cuida de SSL e proxy de WebSocket automaticamente — sem Nginx nem Certbot manual.

**Banco único**: por decisão do usuário, `backend/.env` local já aponta direto pro Postgres/Redis do Dokploy (via IP público + porta expostos), não mais pro `docker-compose.dev.yml`. Ou seja, dev local e produção compartilham o mesmo banco por enquanto — migrations rodadas localmente (`npm run db:migrate`) já valem pra produção. Cuidado: não criar dados de teste à toa nesse banco, já que não é mais um sandbox descartável.

### Migração Prisma → Drizzle (concluída)

Backend migrado inteiramente de Prisma pra Drizzle ORM (`drizzle-orm` 0.45.2 + `drizzle-kit` 0.31.10, driver `node-postgres` reaproveitando o `pg` já instalado). Motivo: pedido do usuário. Detalhes:
- Schema novo em `backend/src/db/schema.ts` (idêntico ao Prisma original: 12 tabelas, 3 enums, FKs, unique constraints, índices — validado campo a campo contra o `schema.prisma` antigo antes de apagá-lo)
- UUIDs agora gerados no Postgres (`gen_random_uuid()`) em vez de client-side
- Paginação cursor-based (feed e mensagens) reescrita como keyset pagination explícita com token opaco (`src/lib/cursor.ts`) — mais robusta que o cursor do Prisma (não quebra se a linha do cursor for deletada entre páginas)
- `backend/prisma/`, `prisma7.config.ts`, `src/generated/`, `src/lib/prisma.ts` e as pastas de skill do Prisma (`.claude/skills`, `.windsurf/skills`, `.agents/skills`) foram todos removidos
- `Dockerfile` atualizado: sem step de `prisma generate`, `runner` agora usa `npm ci --omit=dev` (imagem menor, não precisa mais do CLI em runtime), CMD roda `node dist/db/migrate.js` antes do server
- Testado de ponta a ponta localmente (Postgres/Redis do `docker-compose.dev.yml`, resetados do zero): build da imagem Docker, migration aplicada, registro/login, IGDB real, game entry, post vinculado a game entry, like/unlike (idempotente), comentários, paginação do feed atravessando página, conversa 1:1 (idempotente), chat em tempo real via WebSocket (join, typing, mensagem), notificações — tudo com resultado idêntico ao comportamento anterior no Prisma
- **Pendente**: o Postgres real do Dokploy ainda tem as tabelas antigas do Prisma. Antes de rodar `npm run db:migrate` apontando pra lá, ele precisa ser resetado (schema `public` limpo) — combinar com o usuário antes de mexer nesse banco.

- [x] `backend/Dockerfile` (multi-stage: build com devDependencies, `runner` com `npm ci --omit=dev`, roda a migration do Drizzle no start)
- [x] `backend/.dockerignore`
- [x] Testado localmente: build da imagem + container rodando contra Postgres/Redis reais, migration aplicada, `/api/health` respondendo
- [ ] Resetar o Postgres real do Dokploy e rodar `npm run db:migrate` lá (schema Drizzle ainda não foi aplicado em produção)
- [ ] Criar a Application no Dokploy apontando pro repo (root directory `backend/`, build type Dockerfile)
- [ ] Configurar env vars no Dokploy: `DATABASE_URL`/`REDIS_URL` (mesmos valores do `.env` local, ou trocar pro hostname interno do Dokploy em vez do IP público exposto — mais seguro), `JWT_ACCESS_SECRET` (gerar um novo, forte — não usar o de dev), `JWT_ACCESS_EXPIRES_IN`, `JWT_REFRESH_EXPIRES_IN`, `IGDB_CLIENT_ID`, `IGDB_CLIENT_SECRET`, `PORT=3000`
- [ ] Configurar domínio da API no Dokploy (ex: `api.seudominio.com` → porta 3000 do container)
- [ ] Apontar `mobile/.env` de produção (`EXPO_PUBLIC_API_URL`) pra esse domínio antes do build EAS
- [ ] Backup automático do Postgres (a definir se cron externo ou algo nativo do Dokploy)
- [ ] Build com EAS + teste em dispositivo físico Android
- [ ] Ajustes de UX, error states, ícone/splash