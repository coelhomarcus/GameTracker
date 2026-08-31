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
- [x] Criar a Application no Dokploy apontando pro repo (root directory `backend/`, build type Dockerfile)
- [x] Configurar env vars no Dokploy: `DATABASE_URL`/`REDIS_URL` (mesmos valores do `.env` local, ou trocar pro hostname interno do Dokploy em vez do IP público exposto — mais seguro), `JWT_ACCESS_SECRET` (gerar um novo, forte — não usar o de dev), `JWT_ACCESS_EXPIRES_IN`, `JWT_REFRESH_EXPIRES_IN`, `IGDB_CLIENT_ID`, `IGDB_CLIENT_SECRET`, `PORT=3000`
- [x] Configurar domínio da API no Dokploy (ex: `api.seudominio.com` → porta 3000 do container)
- [x] Apontar `mobile/.env` de produção (`EXPO_PUBLIC_API_URL`) pra esse domínio antes do build EAS
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

## Fase 10 — Comentários curtíveis e aninhados (respostas a comentários)

Referência: screenshot da página de post da X, pedindo comentários com curtida e resposta próprias, estilo mais parecido com a X.

- [x] **10.1 — Schema**: `comments.parent_comment_id` novo (self-FK nullable, cascade) permite comentário responder outro comentário; tabela `comment_likes` nova (mesmo padrão de `likes`: unique em `comment_id`+`user_id`). Migration `0004_slimy_lady_deathstrike.sql` gerada e aplicada
- [x] **10.2 — Backend**: `postsService.addComment` aceita `parentCommentId` opcional (valida que pertence ao mesmo post); `listComments` agora monta uma árvore (comentários de topo com `replies: []` aninhado) e calcula `likeCount`/`likedByMe` por comentário; notificação de resposta vai pro autor do comentário-pai (não mais sempre pro dono do post) quando é uma resposta aninhada. Novo `likeComment`/`unlikeComment` + router `comments.routes.ts` (`POST`/`DELETE /api/comments/:id/like`), montado em `/api/comments`
- [x] **10.3 — Mobile**: `PostDetailScreen.tsx` — `CommentItem` virou um componente recursivo (curtir, responder, "Ver N respostas" pra expandir aninhamento, indentado com borda à esquerda); composer ganhou um banner "Respondendo a @fulano" quando você toca em "Responder" num comentário, com botão pra cancelar

### Verificação

- `tsc --noEmit` limpo nos dois projetos, `expo export --platform ios` sem erros, `expo-doctor` 21/21
- **Sem teste end-to-end ao vivo** — Docker não estava rodando pra usar o sandbox local, e evitei testar direto no banco de produção compartilhado pra não sujar com dados de teste. A verificação ficou só na tipagem (que é forte aqui, os tipos do Drizzle fluem do schema até o service sem `any`) — vale testar na prática assim que possível

## Fase 11 — Nome de exibição, edição de perfil em página própria e respostas estilo X

- [x] **11.1 — Nome de exibição (name) separado do username**: `users.name` novo (nullable, migration `0005_perpetual_carnage.sql`) — `username` continua único e imutável (usado pro @handle e login), `name` é editável livremente. Cadastro (`RegisterScreen`) ganhou campo "Nome"; busca (`GET /api/users/search`) agora casa `username` OU `name`. `name` propagado em todo lugar que já selecionava `username`+`avatarUrl` de forma compacta: `posts.service.ts`, `conversations.service.ts`, `socket/chatHandlers.ts`, `notifications.service.ts`. Helper `lib/displayName.ts` novo (`name` com fallback pro `username`) usado em todo componente que exibe autor: `PostCard`, comentários, resultados de busca, conversas, header do chat, texto de notificações, avatares-placeholder
- [x] **11.2 — Página de Editar Perfil**: `EditProfileScreen.tsx` nova (modal) — nome, bio e upload de avatar/banner centralizados ali, com "Salvar" no header. `ProfileScreen` não edita mais nada inline: perfil virou somente leitura + botão "Editar perfil" (estilo X, alinhado à direita do avatar)
- [x] **11.3 — Avatar/banner abrem em modal**: tocar no avatar ou banner (próprio perfil ou de terceiros) abre o `ImageViewerModal` (o mesmo componente das screenshots de jogo) em vez de abrir o picker direto — visualização em tela cheia, igual X. Botão "Seguir"/"Mensagem" (perfil de terceiros) moveu pra a mesma linha do avatar, alinhado à direita, no lugar de ficar embaixo das estatísticas
- [x] **11.4 — Aba "Respostas" com post original vinculado**: `ProfileScreen`/`UserProfileScreen` — cada resposta agora mostra o post original (avatar, nome, @handle, conteúdo) com uma linha de thread conectando até a resposta embaixo (avatar, nome, @handle, conteúdo, tempo relativo), igual a página de post da X — antes era só uma linha de texto cru "Respondeu a @fulano: ..."

### Verificação

- `tsc --noEmit` limpo nos dois projetos, `expo export --platform ios` sem erros, `expo-doctor` 21/21
- Migration `0005` aplicada no banco real (banco único, dev = produção)
- **Sem teste end-to-end ao vivo** — mesmo motivo da Fase 10 (Docker não disponível, evitei mexer no banco de produção com dados de teste)

## Fase 12 — Username editável, login por username, bug de upload na web

- [x] **12.1 — Username editável com checagem de unicidade**: `PATCH /users/me` aceita `username` opcional agora (mesma regex do cadastro, `usernameSchema` extraído pra `auth.schema.ts` e reaproveitado); `updateProfile` no service valida que o novo username não pertence a outro usuário antes de salvar (409 se já estiver em uso). `EditProfileScreen.tsx` ganhou o campo com prefixo "@" e uma dica de validação
- [x] **12.2 — Login por email ou username**: `loginSchema` trocou `email` por `identifier`; `authService.login` busca por `email` OU `username` (`or(eq(...), eq(...))`). `LoginScreen.tsx` — campo "Email ou username" no lugar de só "Email"
- [x] **12.3 — Bug de upload de banner/avatar na web**: causa raiz — no navegador, `FormData` é o nativo do DOM e exige um `Blob`/`File` de verdade; o shape `{uri, name, type}` que funciona no React Native nativo (iOS/Android) virava `"[object Object]"` no web, chegando no backend sem arquivo nenhum (daí o 400 "Nenhum arquivo enviado"). Novo helper `lib/uploadFile.ts` detecta `Platform.OS === 'web'` e faz `fetch(uri)` + `.blob()` antes de anexar; mantém o comportamento nativo intacto nas outras plataformas

### Verificação

- `tsc --noEmit` limpo nos dois projetos
- **Confirmado sem teste ao vivo** (mesma limitação de ambiente) — o bug do upload web foi diagnosticado a partir do log de erro que o usuário colou, não reproduzido aqui

## Fase 13 — Backlog público no perfil

- [x] **13.1 — Endpoint público de game entries**: `GET /users/:id/game-entries?status=` novo — reaproveita `gameEntriesService.listMine` (já era genérico por `userId`, nunca checava dono) exposto sem essa restrição via `users.routes.ts`. Mesmo filtro de status do endpoint privado (`listGameEntriesQuerySchema` reaproveitado)
- [x] **13.2 — Aba "Backlog" como principal**: `ProfileScreen.tsx`/`UserProfileScreen.tsx` ganharam a aba "Backlog" — grid de capas (4 colunas) com os mesmos filtros de status do `MyGamesScreen` (Todos/Backlog/Jogando/Completo/Abandonado), e virou a aba **padrão** ao abrir qualquer perfil (antes era "Atividades"). É somente leitura — sem avançar status ou remover, isso continua exclusivo da aba "Meus jogos" do próprio usuário
- [x] **13.3 — Extração de componentes compartilhados**: como a renderização de grid de jogos passou a existir em 3 lugares (`MyGamesScreen` + as duas telas de perfil), virou `components/GameEntryGridCell.tsx` novo; `STATUS_COLOR` e `STATUS_FILTERS` (antes redefinidos em cada tela) centralizados em `lib/gameEntryLabels.ts` junto do `STATUS_LABEL` que já existia lá

### Verificação

- `tsc --noEmit` limpo nos dois projetos, `expo export --platform ios` sem erros, `expo-doctor` 21/21
- Sem migration nessa fase (endpoint novo reaproveita a tabela `game_entries` já existente)
- **Sem teste end-to-end ao vivo** — mesma limitação de ambiente das fases anteriores

## Fase 14 — Polimento de design baseado na pesquisa sobre o X

Usuário trouxe uma pesquisa detalhada sobre o design system da X (cores, tipografia, grid de 4pt, raios de borda, blur no header, animação do botão de curtir). Boa parte é específica de web/Tailwind (CSS `backdrop-filter`, `position:sticky`, layout de 3 colunas, media queries de desktop) e não se aplica a um app React Native mobile — o que foi extraído e aplicado:

- [x] **14.1 — Validação da paleta**: os tokens de cor que já tínhamos (`theme/colors.ts`, feito na Fase 6) já batiam quase exatamente com os valores documentados pra o modo "Lights Out" da X (`#000`, `#16181C`, `#E7E9EA`, `#71767B`, `#2F3336`, `#f91880`, `#00ba7c`) — nenhuma mudança de cor necessária, só confirmação
- [x] **14.2 — Tokens de raio de borda + botões em pílula**: `theme/radius.ts` novo (`sm:4`, `md:16`, `pill:9999`, igual à especificação). Botões primários (Entrar, Cadastrar, Publicar, Trackear jogo, Salvar, Seguir/Mensagem, enviar no chat/comentário) viraram pílula em vez de `borderRadius:8`; cards/mídia maiores (capa e screenshots do jogo, card de playthrough, card de lista do Meus Jogos, balão de chat) subiram pra `radius.md`; barra de busca também virou pílula (igual a da X)
- [x] **14.3 — Animação de curtir estilo X**: `LikeButton.tsx` novo (compartilhado entre `PostCard` e os comentários) — usa `Animated.spring` nativo do React Native pra um efeito de "estouro" (encolhe e volta com overshoot) ao curtir, disparado na hora do toque, sem esperar confirmação do servidor. Contador só aparece quando > 0, igual ao comportamento real da X
- [x] **14.4 — Header com blur no Feed**: `expo-blur` instalado; o header do Feed (avatar + título + abas Para você/Seguindo) virou um `BlurView` flutuante e fixo no topo, com o feed rolando por baixo (efeito de vidro fosco), em vez de um bloco sólido separado da lista

### Fora de escopo (específico de web, não se aplica a app mobile nativo)

Layout de 3 colunas com breakpoints de desktop, `position:sticky`/`backdrop-filter` em CSS puro, escala tipográfica em `rem`, grid de 4pt aplicado retroativamente a cada valor de espaçamento já existente no app (risco alto de diff gigante por ganho marginal, já que os valores atuais já são consistentes dentro de cada tela)

### Verificação

- `tsc --noEmit` limpo, `expo export --platform ios` **e** `--platform web` sem erros (o usuário testa pela web também), `expo-doctor` 21/21
- **`expo-blur` é um módulo nativo novo** — como o usuário testa localmente via `expo start --web`/Expo Go, isso funciona direto; só quando for buildar de novo nativo pro iPhone físico (`expo run:ios --device`) que vai precisar rodar de novo (o comando já cuida disso sozinho, detecta a dependência nova)

## Fase 15 — Header padronizado e correção do "próprio perfil parece de outra pessoa"

- [x] **15.1 — Header inconsistente**: causa raiz — `MainTabs.tsx` forçava `headerStyle: {backgroundColor: colors.background}` (preto puro) nas 4 abas com header padrão (Busca/Meus jogos/Chat/Notificações), mas `RootNavigator.tsx` não definia nada, caindo no `card` do `navigationTheme` (`colors.backgroundElevated`, cinza) pras outras ~9 telas (Foco do jogo, Tracking, Novo post, Perfil de terceiros, Perfil, Editar perfil, Configurações, Post, Chat) — resultado: metade dos headers pretos, metade cinza. Corrigido adicionando o mesmo `headerStyle`/`headerTintColor` como `screenOptions` do `Stack.Navigator` no `RootNavigator`, e alinhando o `card` do `navigationTheme.ts` pra `colors.background` também, eliminando o token órfão que causava a divergência. De quebra, a aba de Notificações ganhou o botão de avatar no header (só faltava ali, as outras 3 abas já tinham)
- [x] **15.2 — "Meu perfil parece que não é meu"**: causa raiz — ao tocar no próprio nome/avatar num post do feed, a navegação ia pra `UserProfileScreen` (a tela de "perfil de terceiros"), que só escondia os botões de Seguir/Mensagem quando `isMe` — mas não ganhava nada das capacidades reais do próprio perfil (botão de Editar Perfil, engrenagem de Configurações, etc.), então parecia uma versão incompleta "de visitante" do próprio perfil. Corrigido na raiz: `UserProfileScreen` agora detecta `isMe` antes de buscar qualquer dado (`enabled: !isMe` nas queries, sem gastar requisição à toa) e redireciona (`navigation.replace('Profile')`) pra tela real do próprio perfil — não existe mais um caminho onde "meu perfil" é renderizado por um componente diferente da experiência oficial, então essa divergência não pode mais acontecer nem aqui nem em qualquer ponto futuro que navegue pra `UserProfile`

### Verificação

- `tsc --noEmit` limpo, `expo export --platform ios` sem erros, `expo-doctor` 21/21
## Fase 16 — Feed "Seguindo" sem os próprios posts e modernização visual

- [x] **16.1 — Próprios posts fora da aba "Seguindo"**: `postsService.getFeed` montava `authorIds = [userId, ...seguindo]`, incluindo o próprio usuário de propósito. Agora a aba lista só quem o usuário segue de verdade; se ele não segue ninguém, retorna página vazia direto (evita depender do comportamento do `inArray` com lista vazia)
- [x] **16.2 — Filtros de status compactos**: os chips de Backlog/Jogando/Completo/Abandonado quebravam em duas linhas e ocupavam um bloco enorme nos perfis. Viraram `StatusFilterChips.tsx` — uma linha só, rolável na horizontal, chips menores e preenchidos — usado nos 3 lugares (Meus jogos + os dois perfis), removendo a duplicação de estilo que existia em cada tela
- [x] **16.3 — Inputs preenchidos em todo o app**: `theme/forms.ts` novo (input preenchido com fundo elevado e sem borda dura, variante pílula e variante multilinha). Aplicado em Login, Registro, Novo post, Editar perfil, Busca, composer de comentário e composer do chat — sai o visual de "caixinha com contorno" que dava o ar amador
- [x] **16.4 — Tela de trackear repaginada**: hierarquia corrigida (nome do jogo como título, tipo de playthrough como rótulo acima), campos de data viraram linhas com ícone de calendário **e botão de limpar** (antes não dava pra desmarcar uma data depois de escolher), horas com sufixo "horas", nota num bloco centralizado, chips preenchidos e datas lado a lado em duas colunas
- [x] **16.5 — Retoques gerais**: botões desabilitados agora têm feedback visual (opacidade) em Login/Registro/Novo post/Trackear — antes pareciam clicáveis e não faziam nada; botões de enviar (comentário e chat) viraram botões circulares com seta em vez de texto "Enviar"; títulos de seção viraram rótulos pequenos em maiúsculas; cards de jogo (Meus jogos e Foco do jogo) passaram de contorno pra fundo preenchido, com badges e ações em pílula

### Verificação

- `tsc --noEmit` limpo nos dois projetos, `expo export --platform ios` sem erros, `expo-doctor` 21/21
- **Sem teste ao vivo** — mesma limitação de ambiente das fases anteriores

## Fase 17 — Bug do visualizador de screenshots, chat agrupado e respostas em thread

- [x] **17.1 — Screenshot sempre abria a primeira**: causa raiz — o `ImageViewerModal` posicionava a lista com a prop `contentOffset` do `ScrollView`, que é **exclusiva do iOS** e só vale no momento da montagem. Como o modal fica montado entre aberturas, ele nunca reposicionava e sempre voltava pra primeira imagem. Trocado por um `ref` + `scrollTo`, disparado no `onLayout` e sempre que o modal abre — funciona nas duas plataformas
- [x] **17.2 — Design do chat**: mensagens consecutivas do mesmo autor agora são agrupadas — espaçamento apertado dentro do grupo e respiro entre grupos, "rabinho" (canto menos arredondado) só no último balão do grupo, horário só no fim do grupo em vez de repetido em toda mensagem, e o avatar da outra pessoa aparece ao lado do último balão dela. Balões maiores e com mais respiro interno
- [x] **17.3 — Aba de Respostas em thread**: `ReplyThreadCard.tsx` novo (compartilhado — antes o layout estava duplicado inteiro nos dois perfis, com ~15 estilos repetidos em cada). Agora o post pai e a resposta ficam claramente separados: pai com texto em tom secundário e menor, linha de thread ligando os dois avatares, resposta em destaque com a legenda "Respondendo a @fulano" — bem mais perto de como a X apresenta

### Verificação

- `tsc --noEmit` limpo nos dois projetos, `expo export --platform ios` sem erros, `expo-doctor` 21/21
- **Sem teste ao vivo** — vale conferir principalmente o chat (o agrupamento depende da lista invertida) e o visualizador de screenshots
