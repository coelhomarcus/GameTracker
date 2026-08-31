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
- [x] Resetar o Postgres real do Dokploy e rodar `npm run db:migrate` lá (tabelas antigas do Prisma removidas, schema Drizzle aplicado — 12 tabelas confirmadas)
- [ ] Criar a Application no Dokploy apontando pro repo (root directory `backend/`, build type Dockerfile)
- [ ] Configurar env vars no Dokploy: `DATABASE_URL`/`REDIS_URL` (mesmos valores do `.env` local, ou trocar pro hostname interno do Dokploy em vez do IP público exposto — mais seguro), `JWT_ACCESS_SECRET` (gerar um novo, forte — não usar o de dev), `JWT_ACCESS_EXPIRES_IN`, `JWT_REFRESH_EXPIRES_IN`, `IGDB_CLIENT_ID`, `IGDB_CLIENT_SECRET`, `PORT=3000`
- [ ] Configurar domínio da API no Dokploy (ex: `api.seudominio.com` → porta 3000 do container)
- [ ] Apontar `mobile/.env` de produção (`EXPO_PUBLIC_API_URL`) pra esse domínio antes do build EAS
- [ ] Backup automático do Postgres (a definir se cron externo ou algo nativo do Dokploy)
- [ ] Build com EAS + teste em dispositivo físico Android
- [ ] Ajustes de UX, error states, ícone/splash

## Melhorias de UX (concluído)

Lista de polimento que tinha acumulado (ícones, busca, capas, tracking, página de foco do jogo):

- [x] `@expo/vector-icons` (Ionicons) instalado — substituiu emojis em `PostCard`, `FeedScreen`, `NotificationsScreen`; abas do `MainTabs` ganharam ícone
- [x] Busca: mantido o debounce de 400ms + botão de busca explícito (`SearchScreen`)
- [x] "Meus jogos": capas em todo item, toggle lista/grid persistido (`@react-native-async-storage/async-storage`)
- [x] Tracking: `@react-native-community/datetimepicker` pros campos de data, componente `StarRating` (10 estrelas) pra nota — `TrackingFormScreen` (antigo `GameDetailScreen`) agora serve criação **e** edição de playthrough
- [x] Proxy de capas via VPS: `GET /api/images/cover?url=` (stream + `Cache-Control` de 1 ano, valida host `images.igdb.com`) — resolve o bloqueio da IGDB na rede da faculdade. `PUBLIC_API_URL` nova env var
- [x] Página de "Foco" do jogo (`GameFocusScreen`): capa, sinopse (`games.summary`, novo campo), lista de playthroughs do usuário (suporta replay) com edição. Busca via `GET /api/games/igdb/:igdbId` (fetch-or-cache) e `GET /api/game-entries/me?igdbId=`
- Testado: `tsc` limpo nos dois projetos, os 3 endpoints novos testados via curl (proxy retornando JPEG real, fetch-or-cache, filtro por igdbId com replay), bundle Metro (1120 módulos) e `expo-doctor` 21/21
- **Não testado em dispositivo/emulador real** — sem acesso a isso neste ambiente

## Fase 5 — Perfil social, feed geral e polimento (concluído)

Pontos levantados usando o app de verdade no celular. Todos os 8 itens implementados e testados (backend via curl, `tsc` limpo nos dois projetos a cada etapa, bundle Metro e `expo-doctor` 21/21 no final). Sem dispositivo/emulador neste ambiente — não validei a UI renderizada de verdade.

- [x] **5.1 — Bug de status bar**: `FeedScreen` (única tela com header customizado + `headerShown:false`) agora usa `useSafeAreaInsets()` com `paddingTop: insets.top + 16`; `ChatRoomScreen` idem no composer (`insets.bottom`). Confirmei que as outras telas usam o header padrão do React Navigation, que já respeita a safe area sozinho — não precisaram de mudança
- [x] **5.4 — Grid fixo 4 colunas**: `MyGamesScreen` calcula a largura da célula via `useWindowDimensions()` dividido por 4 (constante `GRID_COLUMNS`); trocou o badge de status por um texto por um ponto colorido no canto da capa (célula ficou pequena demais pra badge com texto)
- [x] **5.2 — Buscar usuários**: `GET /api/users/search?q=` (ilike + exclui o próprio usuário + calcula `isFollowedByMe` via left join) e tela `FindUsersScreen` nova (busca, seguir inline, botão de mensagem). Acessível pelo ícone no header da aba Chat
- [x] **5.8 — Feed geral vs seguindo**: `GET /api/feed?scope=following|general` (default `following`, não quebra nada que já existia); `FeedScreen` ganhou abas no estilo Twitter — **decidi deixar "Para você" (geral) como aba padrão** ao abrir o app, já que "seguindo" fica vazio pra quem ainda não segue ninguém
- [x] **5.5 — Perfil com avatar/bio/posts**: `POST /api/users/me/avatar` (multer + sharp, resize 400x400, apaga o arquivo antigo ao trocar), `PATCH /api/users/me` (bio), `GET /api/users/:id/posts`. Storage é disco local da VPS (`backend/uploads/`, servido via `express.static` em `/uploads`) — **atenção**: esse diretório precisa de um volume persistente no Dokploy, senão perde os avatares a cada redeploy (ainda não configurado lá). `ProfileScreen` e `UserProfileScreen` viraram uma `FlatList` com os posts do usuário e um `ListHeaderComponent` com avatar (tocável, abre `expo-image-picker`), bio editável inline e stats
- [x] **5.6 — Atividade automática**: `gameEntries.service.ts` cria um post `type:'activity'` ao adicionar um jogo (`create()`) e ao mudar status pra `playing`/`completed` (`update()`) — `dropped` não gera post. Mantive o prompt manual de "quer postar que zerou" do `MyGamesScreen` sem mexer — os dois convivem (um é um log automático discreto, o outro é uma celebração com as palavras do usuário). `PostCard` ganhou uma variante compacta/discreta pra `type:'activity'` (sem avatar grande, sem borda de card)
- [x] **5.3 — Design do chat**: avatar de verdade em `ConversationsScreen` e no header do `ChatRoomScreen` (precisou estender os params de navegação da rota `ChatRoom` com `otherUserId`/`otherAvatarUrl` — os 3 pontos que navegam pra lá, `ConversationsScreen`/`UserProfileScreen`/`FindUsersScreen`, foram atualizados); indicador "online" no header consumindo os eventos `presence:online`/`presence:offline` que já existiam no backend mas não eram usados em lugar nenhum; horário em cada balão de mensagem
- [x] **5.7 — Screenshots**: `screenshots.url` nos `fields` da IGDB (só em `getGameByIgdbId`, não na busca — mantém o payload da busca leve), campo `games.screenshots` novo, reaproveita o mesmo proxy de imagem trocando o tamanho pra `t_screenshot_big`. `GameFocusScreen` ganhou uma galeria horizontal abaixo da sinopse

### Pendências que sobraram

- [x] Configurar volume persistente pro diretório `uploads/` no Dokploy (senão avatares somem a cada redeploy)
- [x] Testar tudo isso num dispositivo/emulador de verdade — build nativo rodando no iPhone físico via `expo run:ios --device`

## Fase 6 — Tema escuro (X), correções de UX e bugs

Itens levantados usando o app de verdade no celular (`TODO.md`). Ordem de execução: itens pequenos/isolados primeiro, bug do chat em seguida, tema por último (toca o maior número de arquivos). Paleta e estrutura da X pesquisadas e seguidas à risca, com reestruturação de navegação (não só cor) — decisão do usuário.

- [x] **6.1 — "Meus jogos" padrão grid**: `viewPreference.ts` (`getViewMode`, default e fallback de erro) e `MyGamesScreen.tsx` (estado inicial) passam a assumir `'grid'` quando não há preferência salva
- [x] **6.2 — Avatar na busca de usuários**: `FindUsersScreen.tsx` não lia `item.avatarUrl` — aplicado o mesmo padrão condicional Image/placeholder já usado em `PostCard.tsx`
- [x] **6.3 — `StarRating` 10→5 estrelas**: componente reescrito pra 5 estrelas grandes (mapeamento 2 pontos por estrela, arredondamento pra dados antigos ímpares), sem mudança de contrato no backend (`rating` continua 1-10 int); textos de exibição (`GameFocusScreen`, `MyGamesScreen`) convertidos pra `/5`
- [x] **6.4 — Zoom de screenshots**: `ImageViewerModal.tsx` novo (Modal nativo, sem libs novas) — tela cheia, swipe entre screenshots, fecha ao tocar; usado em `GameFocusScreen`
- [x] **6.5 — Teclado cobrindo inputs**: `KeyboardAvoidingScreen.tsx` novo (wrapper compartilhado); aplicado em Login, Registro, CreatePost, TrackingForm, Profile (edição de bio), FindUsers, Search
- [x] **6.6 — Bug "mensagem enviada aparece como da outra pessoa"**: investigado a fundo (hipótese de race na hidratação da sessão descartada — `RootNavigator` já bloqueia a stack autenticada até `isHydrating` terminar, e `user` é setado antes disso). Nenhum bug encontrado na leitura estática do código. Adicionado assert de dev (`__DEV__`) comparando `senderId` do ack com `myId`; hipótese mais provável é confusão de sessão em teste manual multi-conta sem logout completo — segue em monitoramento, não como bug confirmado
- [x] **6.7 — Tema escuro estilo X (dark-only, sem light mode)**: `theme/colors.ts` novo com paleta "Lights Out" da X (fundo `#000`, superfície `#16181c`, borda `#2f3336`, texto `#e7e9ea`/`#71767b`, accent `#1d9bf0` substituindo o indigo `#4f46e5`, curtida `#f91880`, sucesso/online `#00ba7c`); `theme/navigationTheme.ts` baseado em `DarkTheme` do React Navigation, aplicado no `NavigationContainer`; `StatusBar` global vira `style="light"`. Reestruturação além da cor: Notificações vira aba da bottom tab bar (substitui Perfil), acesso ao próprio perfil via avatar no header (`AvatarHeaderButton.tsx` novo, padrão da X), botão de criar post virou FAB flutuante no Feed, abas segmentadas em Notificações (Tudo/Interações/Seguidores), perfil (`ProfileScreen`/`UserProfileScreen`) ganhou banner decorativo + avatar sobreposto + layout alinhado à esquerda, `PostCard` sem borda (timeline full-bleed com hairline), tab bar com ícones outline/filled conforme foco. Todas as 15 telas + componentes migrados, nenhuma cor antiga sobrando (`grep` confirmou)

### Verificação

- `tsc --noEmit` limpo, `expo export --platform ios` (bundle Metro, 1125 módulos) sem erros, `expo-doctor` 21/21
- **Não validado visualmente num dispositivo** — build no iPhone físico ficou pra depois, a pedido do usuário; conferir a UI de verdade antes de considerar a Fase 6 fechada

## Fase 7 — Posts de atividade unificados e foco de post estilo X

- [x] **7.1 — Atividades como posts normais**: `PostCard.tsx` não tem mais uma variante "discreta" separada pra `type:'activity'` — usa o mesmo layout completo (avatar, header, ações de like/comentário) de qualquer post, só com uma tag pequena "Atividade" acima do cabeçalho pra dar contexto. Como toda atividade já vem com `gameEntryId`, o tag do jogo aparece automaticamente igual num post manual
- [x] **7.2 — Foco de post estilo X**: `PostDetailScreen.tsx` reescrita — antes só listava comentários sem nem mostrar o post original. Agora busca o post via novo endpoint `GET /api/posts/:id` (`postsService.getById`, `getByIdHandler`) e renderiza com o mesmo `PostCard` completo no topo (like funcional), com os comentários embaixo como `ListHeaderComponent` de uma `FlatList` — cada comentário agora tem avatar, nome em negrito e tempo relativo (`lib/relativeTime.ts` novo: "agora"/"Xmin"/"Xh"/"Xd"/data), no lugar do texto cru de antes
- [x] **7.3 — Capa do jogo nos posts de atividade**: `PostCard.tsx` — a tag do jogo (`gameTag`) agora mostra a capa (`coverUrl`) quando disponível, com o ícone de fallback só quando não há capa; corrigido também o padding torto da tag "Atividade" (tinha um `marginLeft: 40` que a jogava pra direita sem alinhar com nada)
- [x] **7.4 — Busca em abas estilo X (Jogos/Usuários)**: `SearchScreen.tsx` absorveu toda a funcionalidade de `FindUsersScreen.tsx` (removida) — uma barra de busca só, com abas "Jogos"/"Usuários" abaixo (mesmo padrão visual de abas do Feed/Notificações); segue/mensagem funcionam na aba de usuários igual antes. Removida a rota `FindUsers` e o ícone que ficava escondido no header do Chat (`MainTabs.tsx`, `RootNavigator.tsx`, `types.ts`); texto vazio de `ConversationsScreen` atualizado pra apontar pra aba de Busca

## Fase 8 — Perfil com abas, banner e página de configurações

- [x] **8.1 — Perfil em abas (Atividades/Posts/Respostas)**: `ProfileScreen.tsx`/`UserProfileScreen.tsx` ganharam abas estilo X abaixo das estatísticas. Backend: `GET /users/:id/posts` ganhou filtro opcional `?type=activity|post` (`postsService.getUserPosts`) pra cada aba paginar corretamente por cursor sem misturar tipos; novo endpoint `GET /users/:id/comments` (`postsService.getUserComments`, cursor pagination igual posts) alimenta a aba "Respostas", mostrando cada comentário com o contexto do post original (`Respondeu a @fulano: "..."`)
- [x] **8.2 — Upload de banner**: campo `users.banner_url` novo (migration `0003_clean_killraven.sql`, aplicada). Backend replica o padrão do avatar: `bannerUpload`/`saveBanner`/`deleteBannerIfLocal` em `lib/uploads.ts` (resize 1500x500, 3:1 como o da X), `POST /users/me/banner`. Mobile: banner tocável no próprio perfil (`ProfileScreen`), abre `expo-image-picker` com aspect 3:1
- [x] **8.3 — Página de Configurações**: `SettingsScreen.tsx` nova, rota `Settings` no `RootNavigator`; ícone de engrenagem no header do próprio perfil (`Profile`) navega pra lá. Botão de logout saiu do corpo do `ProfileScreen` e agora mora só em Configurações — centraliza o que antes tava espalhado, e já deixa a tela pronta pra crescer com mais opções no futuro

### Verificação

- `tsc --noEmit` limpo nos dois projetos, `expo export --platform ios` (bundle Metro) sem erros, `expo-doctor` 21/21
- Migration `0003` aplicada no banco real (banco único, dev = produção)

## Fase 9 — Polimento de header, placeholder e empty/loading states

- [x] **9.1 — Header colado no avatar**: `AvatarHeaderButton.tsx` só tinha `marginLeft`, sem `marginRight` — o título das telas com header padrão (Busca, Meus jogos, Chat) ficava colado na foto. Adicionado `marginRight: 12`; mesmo ajuste no ícone de engrenagem do header do próprio perfil
- [x] **9.2 — Placeholder da busca**: `SearchScreen.tsx` — "Buscar jogo..."/"Buscar por username..." virou só "Buscar"
- [x] **9.3 — Empty states e loading states**: dois componentes novos e reutilizáveis — `EmptyState.tsx` (ícone circular + título + subtítulo opcional) e `LoadingState.tsx` (spinner centralizado na cor do accent, com variante `fullScreen`). Substituído texto cru em: `SearchScreen` (jogos/usuários/estado inicial "busque pelo menos 2 letras"), `MyGamesScreen`, `FeedScreen` (loading + 2 variantes de empty), `ConversationsScreen`, `NotificationsScreen`, `ProfileScreen`/`UserProfileScreen` (3 abas cada + loading em tela cheia no perfil de terceiros), `PostDetailScreen` (comentários + post carregando), `GameFocusScreen` (loading em tela cheia + "ainda não trackeou")

### Verificação

- `tsc --noEmit` limpo, `expo export --platform ios` sem erros, `expo-doctor` 21/21