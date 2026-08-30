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

- [x] `backend/Dockerfile` (multi-stage: build com devDependencies, roda `prisma migrate deploy` no start)
- [x] `backend/.dockerignore`
- [x] Testado localmente: build da imagem + container rodando contra Postgres/Redis reais, migration aplicada, `/api/health` respondendo
- [ ] Criar a Application no Dokploy apontando pro repo (root directory `backend/`, build type Dockerfile)
- [ ] Configurar env vars no Dokploy: `DATABASE_URL`/`REDIS_URL` (hostname interno dos serviços existentes), `JWT_ACCESS_SECRET` (gerar um novo, forte — não usar o de dev), `JWT_ACCESS_EXPIRES_IN`, `JWT_REFRESH_EXPIRES_IN`, `IGDB_CLIENT_ID`, `IGDB_CLIENT_SECRET`, `PORT=3000`
- [ ] Configurar domínio da API no Dokploy (ex: `api.seudominio.com` → porta 3000 do container)
- [ ] Apontar `mobile/.env` de produção (`EXPO_PUBLIC_API_URL`) pra esse domínio antes do build EAS
- [ ] Backup automático do Postgres (a definir se cron externo ou algo nativo do Dokploy)
- [ ] Build com EAS + teste em dispositivo físico Android
- [ ] Ajustes de UX, error states, ícone/splash
