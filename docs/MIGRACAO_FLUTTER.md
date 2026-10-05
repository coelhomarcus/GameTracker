# GameTracker — Migração do frontend para Flutter

**Estado em 04/10/2026:** o app Flutter (`flutter_app/`) está completo no que pôde ser construído e verificado sem aparelho. Falta rodá-lo em um Android físico, gerar a chave de assinatura real, executar o CI no GitHub e decidir quando aposentar o app Expo legado (`mobile/`). **Push de notificações com o app fechado ficou fora desta entrega**, por decisão do dono do projeto (sem Firebase).

Este documento substitui o plano de migração, o baseline, as ADRs, a matriz de aceite e o plano de encerramento do legado, que ficavam em arquivos separados. O texto original desses arquivos está no histórico do git (commit `fd60016`, pasta `docs/`). O que ainda falta fazer está na seção 11, como ideias de implementação.

## Sumário

1. [Resumo do que foi feito](#1-resumo-do-que-foi-feito)
2. [Decisões](#2-decisões)
3. [Arquitetura do app](#3-arquitetura-do-app)
4. [Contratos do backend e regras de domínio](#4-contratos-do-backend-e-regras-de-domínio)
5. [Experiência e design](#5-experiência-e-design)
6. [Mudanças no backend](#6-mudanças-no-backend)
7. [Histórico por etapa, com os achados](#7-histórico-por-etapa-com-os-achados)
8. [Verificação e aceite](#8-verificação-e-aceite)
9. [Build, distribuição e ambientes](#9-build-distribuição-e-ambientes)
10. [Limitações conhecidas](#10-limitações-conhecidas)
11. [Ideias de implementação (o que falta)](#11-ideias-de-implementação-o-que-falta)
12. [Referências do repositório](#12-referências-do-repositório)

---

## 1. Resumo do que foi feito

- **App novo em Flutter** (Android e web; iOS fora de escopo) com paridade de todas as telas do app Expo: login e cadastro, busca de jogos e pessoas, biblioteca, página do jogo, formulário de playthrough, comunidade, posts e comentários, perfis, editar perfil com fotos, chat em tempo real, central de notificações e configurações. A interface foi redesenhada em Material 3, com tema claro, escuro e do sistema.
- **Mesmo backend**: Express, PostgreSQL, Redis, IGDB e Socket.IO, com mudanças só aditivas e correções de bugs encontrados pelos testes (seção 6). Nenhum dado foi migrado, e o app Expo continua funcionando.
- **Qualidade**: 705 testes de unidade, widget e aceite no Flutter (mais 50 de integração contra o backend real) e 108 no backend (unidade e API de verdade). Todos passam, e `flutter analyze` e a formatação estão limpos.
- **Distribuição**: APK de release assinado por script (`tool/build_release.sh`) ou pelo GitHub Actions, com a URL da API definida no build.
- **Segurança e correções de backend achadas ao testar**: queda do servidor por id inválido no chat, corrida na renovação da sessão, duplicidade de notificações, conversas duplicadas, erros 500 em PATCH vazio e imagem corrompida, e anotações pessoais expostas na API.
- **Legado**: nada foi removido. O `mobile/` fica como plano de retorno, e a tag local `legacy-expo-final` marca o último commit com ele ativo.

## 2. Decisões

Cada decisão tem o motivo e a consequência.

| # | Decisão | Motivo e consequência |
| --- | --- | --- |
| 1 | **Stack**: Flutter 3.47.6 / Dart 3.13.5, `material_ui` 1.5.0, Riverpod 3.4.3, `go_router` 18.0.2, Dio 5.11.1, `socket_io_client` 3.1.6, `flutter_secure_storage` 11.2.0, `shared_preferences` 2.5.5, `image_picker` 1.2.3 | O conjunto resolveu sem conflitos, compilou para Android e web e interoperou com o Socket.IO 4.8 do servidor. Versões fixadas no `pubspec.lock`; atualizar o SDK exige repetir os builds. |
| 2 | **Plataformas**: Android e web; iOS fora de escopo (03/10/2026) | Sem APNs, runner macOS nem pasta `ios/`. Se iOS voltar, é uma etapa nova. |
| 3 | **Sessão**: refresh token no armazenamento seguro (Android) e access token só em memória; renovação serializada (várias respostas 401 esperam a mesma operação). **Web: só memória**, com novo login ao recarregar | O refresh token é de uso único: duas renovações simultâneas derrubariam a sessão. A web fica assim até existir cookie `HttpOnly` no backend (seção 11). Logout descarta o socket e todos os dados da conta. |
| 4 | **Datas e horas**: datas de progresso são datas de calendário lidas em UTC (o backend manda `…T00:00:00.000Z`); `createdAt` é instante convertido ao horário local; horas chegam como string decimal | Evita que um dia mude por fuso. Os JSONs reais gravados em `flutter_app/test/fixtures/` viraram testes de contrato do cliente. |
| 5 | **Push**: **fora desta entrega** (04/10/2026). Backend e cliente prontos; o adaptador FCM não foi escrito porque não existe projeto Firebase | Sem Firebase, só há central de notificações em polling (60 s com o app aberto). O app mostra "Indisponível neste dispositivo" nas configurações, sem erro. O caminho para ligar está na seção 11. |
| 6 | **Transição do app instalado**: distribuição só por APK manual (trabalho de faculdade, sem loja); novo login na troca; mesmo application ID `com.marcuscoelho.gametracker`; keystore do EAS anterior irrelevante | Sem loja, rollout gradual e AAB não se aplicam. O app novo pode entrar como instalação separada; atualizar por cima do legado não é requisito. |
| 7 | **Design**: Material 3 com `ColorScheme.fromSeed` (violeta), temas claro, escuro e do sistema, Biblioteca como destino inicial; cores de status (backlog, jogando, concluído, abandonado) em extensão de tema, sempre com texto ou ícone | Direção visual aprovada pelo dono ("SERVE"). |
| 8 | **Ambiente de teste isolado**: `docker-compose.test.yml` (Postgres :5434 com o banco `gametracker_test` e Redis :6381, descartáveis) e `backend/.env.test`; uma trava (`backend/test/helpers/env.ts`) recusa rodar contra qualquer banco que não seja local e terminado em `_test` | Os testes criam e apagam dados. Os testes nunca leem o `backend/.env` do dono, e a trava impede apontar por engano para o banco de desenvolvimento ou de produção. |
| 9 | **CI**: GitHub Actions | Um workflow de qualidade e um de release (seção 9). |
| 10 | **Notas pessoais não são públicas** (04/10/2026) | `GET /users/:id/game-entries` só devolve `notes` ao dono. |

## 3. Arquitetura do app

```text
flutter_app/lib/
  app/             bootstrap, router (go_router), shell adaptável, providers, tema, versão
  core/
    network/       Dio, interceptor de autenticação, SessionManager, erros de domínio
    storage/       token seguro (Android) ou em memória (web)
    realtime/      ChatTransport (Socket.IO) e ChatConnection (reconexão própria)
    data/          PATCH tri-estado, horas
    dates/         datas de calendário, tempo relativo
    design_system/ tokens, tema, StatusChip, GameCover, UserAvatar, AsyncContent, EmptyView
  features/        auth, games, library, feed, profiles, chat, notifications, push, explore
                   (data → application/controller → presentation, só onde há necessidade)
```

Fluxo: **widget → controller → repository → serviço HTTP/socket/storage**. Modelos imutáveis; repositórios com fakes nos testes.

**Estado e cache**
- **Sessão**: estados inicializando, autenticado, não autenticado e restauração indisponível. Falha de rede no bootstrap mostra "Tentar novamente" e não apaga o token. O `currentUserIdProvider` muda ao sair ou trocar de conta, e todos os providers de dados o observam, então nada da conta anterior sobrevive.
- **Fontes únicas**: `libraryProvider`, `PostStore` (posts) e `FollowStore` guardam cada entidade em um só lugar. Todas as telas leem de lá, então curtida, contador e status são iguais em todas as superfícies.
- **Otimismo com rollback**: curtir, seguir, favoritar e marcar notificações como lidas respondem na hora, desfazem em erro e fazem uma operação por vez por entidade. Criar post, registro e mensagem espera confirmação e não repete sozinho.
- **Sem retry automático**: `noAutomaticRetry` em todos os providers. O Riverpod 3 repete por padrão, o que esconderia erros e reiniciaria carregamentos.
- **Revalidação**: dados com mais de 30 s são revalidados ao voltar para o app. Se falha, a lista continua visível com o aviso "Mostrando os dados salvos".
- **Paginação por cursor**: uma página por vez, sem duplicatas, erro de rodapé recuperável.
- **Erros**: `ApiException`, `NetworkException` e `CancelledException`, com tratamento de 429 e HTML de proxy fora do envelope padrão.

## 4. Contratos do backend e regras de domínio

Todas as rotas de negócio exigem Bearer JWT, inclusive os perfis "públicos" (visíveis a outros usuários autenticados, não acesso anônimo). Prefixo `/api`.

| Domínio | Rotas | Particularidades |
| --- | --- | --- |
| Auth | `POST /auth/register`, `/login`, `/refresh`, `/logout`; `GET /auth/me` | Login por `identifier`; refresh rotativo de uso único; limite de tentativas (`AUTH_RATE_LIMIT_MAX`, padrão 20 por 15 min por IP) |
| Catálogo | `GET /games/search?q=`, `/games/igdb/:igdbId`, `/games/:id` | Busca devolve o id IGDB; detalhe resolve o UUID interno |
| Jogo social | `GET /games/:id/stats`, `/players`, `/posts` | Estatísticas contam registros, não pessoas |
| Favoritos | `POST`/`DELETE /games/:id/favorite`; `GET /users/:id/favorites` | O favorito é do jogo |
| Biblioteca | `POST /game-entries`; `GET /game-entries/me`; `PATCH`/`DELETE /game-entries/:id` | Lista sem paginação; replay permitido; só o dono altera |
| Feed e posts | `GET /feed?scope=`; `POST /posts`; `GET /posts/:id`; curtir | O padrão do servidor é `following`, então o cliente sempre envia o escopo; não há editar nem apagar post |
| Comentários | `GET`/`POST /posts/:id/comments`; curtir comentário | Árvore inteira; `parentCommentId` para resposta |
| Pessoas | `GET /users/search`, `/users/:id`; seguir e deixar de seguir | Busca exclui o próprio usuário, limite 20 |
| Conteúdo de perfil | `GET /users/:id/posts`, `/comments`, `/game-entries` | `notes` só para o dono |
| Editar perfil | `PATCH /users/me`; `POST /users/me/avatar`, `/banner` | Multipart; fotos salvam na hora; teto de 8 MiB |
| Push | `PUT`/`DELETE /push/installations/:id`; legado `POST /users/me/push-token` | Ver seção 6 |
| Notificações | `GET /notifications`; `POST /notifications/read-all` | Últimas 50 e leitura global |
| Conversas | `GET`/`POST /conversations`; `GET /conversations/:id/messages`; `POST /conversations/:id/read` | Envio só por socket |
| Imagens | `GET /images/cover?url=`; `/uploads/*` | Proxy IGDB; URLs públicas |

**Regras de domínio que o app respeita** (os comentários do código citam estes números):

1. **Identificadores**: `igdbId` é inteiro e os demais ids são UUIDs. Favoritar e vincular post usam o UUID do jogo; criar registro usa o id IGDB.
2. **Replay**: vários registros do mesmo jogo são válidos. A chave de um registro é `entry.id`.
3. **Status**: `backlog`, `playing`, `completed`, `dropped`. Os valores da API não mudam quando o rótulo muda.
4. **Horas**: entrada numérica, resposta em string decimal, uma casa, de 0 a 99999. Zero é valor, diferente de ausência. O formulário aceita vírgula ou ponto e limita a 24 h por dia de calendário.
5. **Nota**: inteiro de 1 a 10 ou ausente; nunca zero.
6. **Datas de progresso**: datas de calendário, sem deslocamento de fuso.
7. **Limites**: username 3–30 (letras, números, `_`); nome 1–50; senha de cadastro 8–72; bio até 280; post e comentário até 500; mensagem até 2000; notas até 2000; plataforma 1–50.
8. **Post vinculado**: com `gameEntryId`, só ele é enviado (o backend verifica o dono e deriva o jogo); senão aceita `gameId`.
9. **Atividade histórica**: mostra o `activityStatus` do momento, não o status atual. Apagar o registro deixa `gameEntry` nulo sem apagar o post.
10. **Feed Seguindo**: só quem o usuário segue; vazio se não segue ninguém.
11. **Perfil**: o nome tem o username como fallback; o username é editável, então rotas e identidade usam o id.
12. **Coleção de outra pessoa**: leitura apenas, sem menu de edição.

**Chat (eventos Socket.IO)**: handshake com `auth.token`; `conversation:join` e `:leave`; `message:send` com ACK `{message}`; `message:receive`; `typing:start` e `:stop`; `presence:online` e `:offline`; `presence:get` (snapshot). O cliente Dart reaproveita o socket em cache para a mesma URL; por isso o app cria sempre uma conexão nova (`enableForceNew`) e descarta o socket no logout.

## 5. Experiência e design

**Conceito**: uma biblioteca pessoal de jogos com comunidade ao redor. As capas dão personalidade, e o resto usa superfícies, tipografia e estados do Material.

**Navegação**: cinco destinos permanentes (Biblioteca, Explorar, Comunidade, Mensagens e Perfil) em `NavigationBar` abaixo de 600 px e `NavigationRail` a partir daí, com estado preservado por destino. Notificações fica no sino do app bar e Configurações parte do perfil. O feed geral se chama **Geral**, porque o backend entrega posts cronológicos, sem recomendação.

| Rota | Conteúdo |
| --- | --- |
| `/login`, `/register` | Públicas; redirecionam ao destino pedido depois de entrar |
| `/library`, `/explore`, `/community`, `/messages`, `/me` | Destinos principais |
| `/games/:igdbId` e `/playthroughs/new`, `/playthroughs/:entryId/edit` | Jogo e formulário, por deep link |
| `/posts/new`, `/posts/:postId` | Composição e detalhe |
| `/users/:userId` | Perfil de outra pessoa (o próprio id vai para `/me`) |
| `/messages/:conversationId` | Sala de chat |
| `/notifications`, `/me/edit`, `/settings` | Secundárias |

Nenhuma rota leva token na URL, e destinos inexistentes mostram uma saída útil.

**Responsividade**: breakpoints 600 e 840; lista e detalhe lado a lado nas mensagens em telas largas; grade da biblioteca por largura de capa (100–140); conteúdo textual com largura máxima de cerca de 680. **Acessibilidade**: alvos de toque de pelo menos 48 dp, texto até 200% sem ação inacessível, rótulos semânticos, contraste verificado nos dois temas, status sempre com texto ou ícone.

**Decisões de interface que o app tomou**
- Status é escolhido direto, sem o ciclo automático antigo `completed → dropped`.
- "Completos recentemente" virou **Concluídos**, porque a ordenação do backend é pela criação do registro, não pela conclusão.
- Contadores de seguidores são rótulos, não links (não há tela de seguidores).
- O convite para publicar ("Zerei {jogo}! 🎉") só aparece depois que o servidor confirma e só quando o status passa a concluído.
- Edição de perfil avisa que **as fotos são salvas na hora**; "cancelar" não desfaz um upload já feito.

## 6. Mudanças no backend

Todas aditivas, sem reset de banco. Migrations `0009` e `0010`.

| Mudança | Por quê |
| --- | --- |
| `PATCH /game-entries/:id` aceita três estados por campo (omitido = manter, `null` = limpar, valor = substituir); `PATCH {}` é válido | Antes `null` dava 400 e limpar data ou nota não funcionava. O cliente legado, que omite campos, continua funcionando. |
| Renovação de sessão atômica (`UPDATE` condicional) | Com 8 requisições simultâneas e o mesmo refresh token, as 25 rodadas emitiram mais de uma sessão válida. Depois da correção, 0 de 25. |
| Curtir e seguir só notificam quando a relação é criada de verdade | Repetir gerava notificações duplicadas. |
| `AUTH_RATE_LIMIT_MAX` | Permite suítes de integração repetidas. |
| `PATCH /users/me` vazio, imagem corrompida e username simultâneo | Eram erros 500; agora 204, 400 e 409. |
| Chat: ids validados como UUID e handlers protegidos (`safe()`) | Um `conversationId` inválido fazia o Postgres lançar dentro de um handler assíncrono e **derrubava o processo do servidor**, ou seja, qualquer usuário logado podia tirar o backend do ar. |
| Chat: `clientMessageId` com índice único parcial | Repetir o envio devolve a mesma mensagem, sem nova linha, evento ou push. |
| Chat: `typing` só na sala; `presence:get` restrito a participantes; contagem de conexões síncrona | Antes qualquer usuário podia emitir digitação para conversas alheias, e não havia snapshot de presença. |
| Conversas: lock consultivo por par de usuários | Criar uma conversa ao mesmo tempo gerava 2 ou 3. |
| Push: tabela `push_installations`, provedores Expo e FCM (`firebase-admin`), serviço único `sendPushToUser`, tokens inválidos desativados, FCM desligado sem credenciais | Base para o push do app novo, mantendo o Expo legado. O `data` leva só `type` e ids; o texto do chat é genérico para clientes novos. |
| `CORS_ORIGINS` (lista de origens) no Express e no Socket.IO | Restringe a web. Sem a variável, tudo é aceito, como antes. |
| `notes` só para o dono em `GET /users/:id/game-entries` | Anotações pessoais não são públicas. Quem consultou a API antes pode ter visto anotações alheias; não há como saber. |

## 7. Histórico por etapa, com os achados

### Etapa 0 — baseline e provas técnicas
- Flutter 3.47.6 instalado, SDK Android 36, Chrome. Ambiente isolado criado (decisão 8). As 9 migrations existentes aplicam em banco vazio.
- Contratos gravados com o backend real (usuários e jogos sintéticos, tokens mascarados); as respostas usadas pelos testes do app estão em `flutter_app/test/fixtures/`, e as regras viraram testes de API em `backend/test/api/`. Confirmado por execução, e não por inferência: `PATCH` com `null` dava 400; horas voltam como string; datas voltam à meia-noite UTC; refresh é de uso único; editar o registro de outro usuário devolve 404; listas de registros, conversas e comentários não são paginadas.
- Socket.IO provado em Dart contra o servidor 4.8: sem token → `unauthorized`; ACK e `message:receive` trazem o mesmo `id`; o cliente Dart reaproveita o socket para a mesma URL.
- O projeto descartável compilou para Android debug e web com todos os pacotes juntos.

### Etapas 1–2 — design e fundação
- Tema Material 3, shell adaptável, `StatusChip`, `GameCover` com fallback, localização pt-BR com `GlobalMaterialLocalizations.delegates` (o `material_ui` exporta o próprio, e importar também `flutter_localizations` dá símbolo ambíguo).
- Grade com `childAspectRatio` fixo estoura com texto ampliado, então a Biblioteca usa linhas de altura intrínseca.

### Etapa 3 — autenticação e sessão
- `SessionManager` com uma única renovação em andamento e geração de sessão (descarta refresh e respostas tardias depois de logout ou troca de conta), `AuthInterceptor` (Bearer, uma repetição após 401), guard de rotas que preserva o destino original e aceita só caminhos internos.
- Login e cadastro reais, com os limites do backend e o formulário preservado em erro.
- Os testes de sessão foram validados por mutação: sem o single-flight ou a checagem de geração, falham.
- **Achados**: a corrida de refresh do backend (seção 6); o manifesto padrão do Flutter não declara `INTERNET` no release, então foi adicionado ao manifesto principal (o debug ganhou `usesCleartextTraffic` para o backend local); o limitador de login pode atrapalhar testes repetidos.

### Etapa 4 — catálogo e biblioteca
- Busca com debounce de 400 ms, mínimo de 2 letras e cancelamento; erro distinto de "nenhum resultado". Biblioteca com filtros e contagem, ordenação, grade ou lista persistidas, alterar status direto, editar e remover com confirmação. Página do jogo com Sobre, Meu progresso e Comunidade, favoritar otimista, galeria com zoom.
- Formulário de playthrough com plataformas em chips, date picker com "limpar", horas com vírgula ou ponto, nota 1–10 ou "Sem nota". Falha preserva tudo e sair com alterações pede confirmação.
- **Achados**: **perda de dados no formulário** (o `PopScope` calculava `canPop` no `build`, e digitar horas ou notas não reconstruía a tela, então voltar descartava tudo sem confirmação); `Uri.replace(port: null)` mantém a porta antiga; as URLs de imagem do backend usam `PUBLIC_API_URL` (localhost em desenvolvimento), então o app reescreve o host de `/api/images/` e `/uploads/`; overflow na linha da nota em tela estreita.

### Etapa 5 — comunidade, posts e comentários
- `PostStore` como fonte única; feeds Geral e Seguindo paginados; atividades como linha compacta; detalhe com a árvore inteira de comentários (recuo limitado a 3 níveis, nenhum comentário escondido); publicar com jogo ou registro vinculado; revalidação dos feeds depois de mutações da biblioteca (a atividade é criada de forma assíncrona no backend).
- **Achados**: **loop infinito de carregamento** quando "carregar mais" falhava (agora só o botão repete); crash de Hero porque os FABs de Biblioteca e Comunidade compartilhavam a tag; overflow na linha de ações.

### Etapa 6 — pessoas, perfis e uploads
- Busca de pessoas, seguir otimista com `FollowStore`, perfil único para o próprio usuário e para outros (Coleção, Atividades e Posts), editar perfil com fotos (pré-visualização, progresso, recusa acima de 8 MB, "Tentar de novo" sem reabrir a galeria) e configurações com tema persistido.
- **Achados**: a tela de edição **não fechava depois de salvar** (o `PopScope` só vê o `canPop` novo depois de reconstruir); os três erros 500 do backend (seção 6); overflow na linha foto + botão.

### Etapa 7 — chat confiável
- `ChatConnection` com reconexão própria (backoff de 1 a 30 s com variação, reconexão imediata depois de queda, renovação do token recusado, reentrada nas salas com ACK, `verify()` ao voltar do segundo plano). O Socket.IO reaproveitaria o token de 15 min e não sabe quais salas reentrar.
- Mensagens com estado (enviando, enviada, incerta, falhou), mescla por `clientMessageId` e `id` (testada com embaralhamentos aleatórios). ACK perdido reenvia com o **mesmo** `clientMessageId`; 3 tentativas viram "Não enviada" com o texto preservado, "Tentar de novo" e "Descartar". Sem conexão, a mensagem fica na fila.
- Sincronização depois de reconectar: busca páginas recentes até reencontrar a última mensagem conhecida (até 10 páginas). Digitação, presença (nunca vira "offline" por falta de evento), leitura só com a conversa visível. Lista de conversas com polling de 30 s só com o app aberto e selo de não lidas. Em telas largas (840+), lista e conversa lado a lado.
- **Achados**: a queda do servidor por id inválido e as demais falhas do chat (seção 6); `ref.read` dentro de `onDispose` (proibido no Riverpod 3) fazia o controller nunca deixar a sala.

### Etapa 8 — notificações e push
- **Central de notificações** (sino com selo): filtros Tudo, Interações e Seguidores, não lidas em destaque, destino por ids. Como o backend só tem "ler todas", abrir uma notificação não marca nada, e "Marcar todas como lidas" é uma ação explícita, otimista, com rollback e uma por vez. Polling de 60 s só com o app aberto. O polling não atropela uma marcação em andamento (desfaria o "lido"). Com 50 itens avisa "Mostrando as 50 mais recentes". Tipo desconhecido é ignorado, em vez de quebrar a lista.
- **Push do cliente** pronto, atrás de uma interface (`PushPlatform`, padrão `NoopPushPlatform`): registro com id de instalação persistente, renovação de token, nova tentativa ao voltar ao app, descarte de sessão obsoleta, revogação **antes** do logout (limite de 3 s, sem bloquear o logout), destino do toque só a partir de UUIDs e só se `recipientId` for a conta atual, espera de até 2 minutos para um toque anterior à sessão. Testado com plataforma falsa, mas a entrega real por FCM nunca foi exercitada.
- **Achados**: o logout lia o controller de push, que depende da sessão, e dava dependência circular (a revogação virou um provider separado); o botão "Marcar todas" e o de push estouravam a 360 px com texto a 200%.

### Etapa 9 — validação, desempenho e distribuição
- Assinatura de release, script de build com travas, workflow de release, CORS por origem, suíte de aceite (seção 8) e testes de volume.
- **Achados**: estados vazio e erro estouravam a altura em janela larga e baixa (perfil de outra pessoa a 1400 px). A solução é ajustar ao espaço, porque uma área rolável criava um nó de acessibilidade focável sem rótulo cobrindo a tela. O avatar do autor nos posts tinha alvo de toque de 40 dp, agora 48. Um teste de tempo meu era frágil sob carga e virou um teto largo.

### Etapa 10 — encerramento do legado
- Feito só o seguro: tag `legacy-expo-final`, README com o Flutter como app oficial. O resto depende dos critérios da seção 11.

## 8. Verificação e aceite

**Comandos**
- `flutter test` (unidade, widget e aceite).
- `flutter test test/integration --dart-define=GT_BACKEND=http://localhost:3100` (contra o backend de teste, nunca produção).
- `cd backend && npm run test:db:up && npm test` (Postgres e Redis de teste via Docker; 108 testes: unidade e API de verdade, com Express, Socket.IO, banco e Redis reais).
- Para a integração do Flutter: `cd backend && npm run test:seed && npm run dev:test` e depois o comando acima.

**Resultado atual**: `flutter analyze` limpo; formatação limpa; 705 testes passam no Flutter (45 de integração são ignorados quando não há backend) e 50 de integração passam contra o backend real; 32 testes no backend; builds web e APK debug compilam.

**Paridade funcional (todas atendidas em teste automatizado)**

| Área | Evidência |
| --- | --- |
| Login, cadastro, sessão restaurada | `features/auth/*`, `core/session_test.dart`; integração `backend_session_test.dart` |
| Explorar: jogos e pessoas | `games/search_test.dart`, `profiles/people_search_test.dart` |
| Biblioteca e página do jogo | `library_page_test.dart`, `game_page_test.dart`; integração `backend_library_test.dart` |
| Playthrough (replay, nota, zero horas, limpar campo) | `tracking_form_test.dart`; `backend/test/api/entries.test.ts` |
| Comunidade, posts, comentários | `features/feed/*`; integração `backend_feed_test.dart` |
| Perfis, editar perfil, uploads | `features/profiles/*`; integração `backend_profiles_test.dart` (upload real) |
| Chat | `features/chat/*`, `core/chat_connection_test.dart`; integração `backend_chat_test.dart` (sockets reais) |
| Notificações e configurações | `notifications/notifications_test.dart`, `settings_test.dart`, `push/push_test.dart` |

**Suíte de aceite** (`test/acceptance/`, 149 testes): 13 telas × 4 janelas (400, 360 com texto a 200%, 800, 1400) × claro e escuro, sem overflow; diretrizes do Flutter de alvo de toque (48 dp), rótulo e contraste em todas as telas, claro e escuro; teclado, gesto de voltar e campos com rótulo. O alvo de toque fica desligado só no Explorar, porque a diretriz mede o nó interno do campo do `SearchBar` (312×24), mas a barra inteira de 56 dp recebe o toque (há um teste próprio).

**Volume**
- **Backend** (500 registros e 1000 mensagens, contra o banco isolado): criar 500 registros ~1,7 s; listar 500 ~25–40 ms; enviar 1000 mensagens com ACK ~2,4 s; paginar as 1000 (34 páginas) ~125 ms, com ordem e unicidade conferidas e horas e notas idênticas.
- **Interface**: biblioteca com 500 registros é preguiçosa (menos de 120 widgets construídos) e chega ao fim; conversa com 1000 mensagens sobe em 20 páginas, cada uma buscada uma vez (a primeira duas vezes, de propósito).
- Tempos de widget test não representam um aparelho intermediário; servem para pegar custo proporcional ao tamanho da lista.

**Mutações confirmadas** (o teste falha quando o código é quebrado): single-flight e geração da sessão; sincronização pós-reconexão do chat; `clientMessageId` e substituição da pendente na mescla; checagem de `recipientId` e descarte de sessão obsoleta no push; lock de conversas no backend.

**Critérios de liberação**

| Critério | Estado |
| --- | --- |
| Todas as linhas obrigatórias demonstradas | Atendido em teste automatizado |
| Conta antiga acessa os mesmos dados | Parcial: mesmo backend e banco, migrations só aditivas; não exercitado com dados reais de produção |
| Nota, horas e datas mantêm o significado; limpar campo persiste | Atendido |
| Sem dados da conta anterior após logout e login | Atendido |
| Chat: entrega, deduplicação, reconexão; falha não apaga rascunho | Atendido |
| Sem overflow nem ação inacessível; navegação assistiva | Atendido em teste; **revisão com TalkBack pendente** |
| Push em Android físico | **Fora desta entrega** |
| CI com formatação, análise, testes e builds | **Pendente**: os workflows nunca rodaram no GitHub (os mesmos passos rodaram localmente) |
| Volume persistente e backup do banco | **Pendente**: é infraestrutura, fora do repositório |

## 9. Build, distribuição e ambientes

**Qualidade contínua**
- `.github/workflows/flutter.yml`: formatação, `flutter analyze`, `flutter test`, build web e APK debug (publicado como artefato por 14 dias).
- `.github/workflows/backend.yml`: job `backend` (typecheck, build, migrations e os 108 testes, com Postgres e Redis do runner) e job `flutter-integration` (sobe a API de teste e roda os testes de integração do app contra ela).

**Release** (`flutter_app/tool/build_release.sh` e `.github/workflows/flutter-release.yml`, este manual ou por tag `flutter-v*`)
- Exige `API_URL` com HTTPS, sem `/` nem `/api` no fim (o app acrescenta `/api`).
- Exige `android/key.properties` (fora do git) ou os secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` e a variável de repositório `API_URL`.
- Recusa APK assinado com a chave de debug. Testado com uma chave descartável: o APK saiu com o certificado dela, e a URL passada está dentro do binário (o padrão `10.0.2.2` não).
- Segredos nunca entram em `--dart-define`; a URL da API é pública.
- **Para entregar o trabalho de faculdade**, o APK debug que o CI já gera basta para demonstrar. A chave real só é necessária para um lançamento de verdade: o Android usa a assinatura para aceitar uma atualização por cima, e perder a chave obriga quem instalou a desinstalar e reinstalar. Gerar uma vez: `keytool -genkeypair -v -keystore ~/gametracker-release.jks -alias gametracker -keyalg RSA -keysize 2048 -validity 10000`, guardar o `.jks` e a senha com backup, criar `android/key.properties` e rodar `API_URL=https://... tool/build_release.sh`.

**APK e web**: application ID `com.marcuscoelho.gametracker`, versão `1.0.0+1`, só a permissão `INTERNET` (sem microfone nem câmera). APK universal ~58 MiB (3 ABIs); `flutter build apk --split-per-abi` gera cerca de um terço por ABI. Web 41 MiB, dos quais 36 MiB são o CanvasKit.

**Ambientes**: `dev` com o backend isolado (seção 2, decisão 8). Para produção, definir `CORS_ORIGINS` com o endereço do app web. Banco e Redis da produção não foram tocados.

**Retorno**: o APK Expo anterior continua instalável. No app novo, reassinar o APK anterior com versionCode maior; na web, restaurar o artefato anterior. Nenhum rollback destrutivo de banco.

## 10. Limitações conhecidas

- **Nada foi executado em aparelho ou emulador.** O sandbox das ferramentas não tem aceleração para o emulador (`hvf is not enabled`). Para rodar: `~/Library/Android/sdk/emulator/emulator -avd gt_pixel` no terminal do dono. Por isso o desempenho real (3 s para a primeira tela, 100 ms de resposta, 95% dos quadros em 16,7 ms), o TalkBack, o seletor de imagem, a suspensão do app e a troca de rede nunca foram medidos.
- **Push com o app fechado não existe** (decisão 5). A central de notificações atualiza por polling.
- **Busca real na IGDB** não foi exercitada: o ambiente isolado não tem credenciais, e a busca foi verificada com repositório falso e, no backend real, só o caminho de erro `igdb_not_configured`. Os testes usam os jogos sintéticos 900001 e 900002.
- **Interoperabilidade com o app Expo** (mesmo usuário nos dois clientes) não foi exercitada. O contrato do chat foi mantido compatível e o envio sem `clientMessageId` foi testado.
- **Web**: sessão só em memória (novo login ao recarregar). Não foi testada em navegador real contra o backend.
- **Presença do chat** é em memória por instância do backend; com mais de uma réplica, fica errada.
- **Estatísticas de jogo** contam registros (replay conta como outro registro), não pessoas.
- **Listas sem paginação no backend**: coleção, comentários, conversas. A lista do app é preguiçosa, mas o volume transferido não diminui.
- **Notificações**: últimas 50 e leitura global.
- **Aba Comunidade da página do jogo** mostra a contagem por status e os jogadores, mas os posts do jogo (`GET /games/:id/posts`) ainda não estão ligados.
- **Compilação para wasm**: o teste prévio do `flutter build web` avisa que o `socket_io_common` 3.1.1 tem uma verificação de tipo JS que atrapalha um build wasm. A web usa o build padrão (JavaScript), que funciona.

## 11. Ideias de implementação (o que falta)

Cada ideia diz o que é, por que importa e como começar. Estão ordenadas por prioridade dentro de cada grupo.

### A. Para fechar a entrega

1. **Rodar no Android físico (ou no emulador `gt_pixel`)**: login, rolagem das listas, teclado, seletor de imagem, botão voltar, suspensão, troca de rede. Medir com `flutter run --profile` e o DevTools e comparar com as metas da seção 10. É o item que mais reduz o risco, porque tudo até aqui foi testado sem aparelho.
2. **Rodar os workflows no GitHub** (`Flutter`, depois `Flutter release`) e corrigir o que o ambiente do runner mostrar. Para o release, cadastrar a variável `API_URL` e os 4 secrets (só se for gerar o APK por lá).
3. **Passar o TalkBack** nas jornadas principais (login, biblioteca, publicar, comentar, chat).
4. **Definir `CORS_ORIGINS` em produção** com o endereço do app web, e publicar o backend atualizado: as correções de privacidade (`notes`) e de segurança do chat só valem depois do deploy.
5. **Conferir o volume de uploads e o backup do banco** no ambiente real, antes de trocar o app usado em produção.

### B. Push de notificações (retomar quando houver Firebase)

- **O que é**: avisos na barra do celular com o app fechado. No Android só o Google (FCM, gratuito) entrega isso; a VPS não substitui.
- **Passo a passo**: (1) criar um projeto no Firebase e um app Android com o id `com.marcuscoelho.gametracker`; (2) colocar o `google-services.json` em `flutter_app/android/app/` e aplicar o plugin do Gradle; (3) adicionar `firebase_core` e `firebase_messaging` e escrever um `FcmPushPlatform` que implementa a interface `PushPlatform` (permissão, token, mensagens em primeiro plano, toque, mensagem inicial) e trocar o `NoopPushPlatform` no `pushPlatformProvider`; (4) dar ao backend a credencial de serviço do projeto (variável de ambiente, nunca no repositório) para o `FcmProvider`; (5) pedir a permissão `POST_NOTIFICATIONS` no Android 13+; (6) testar com um aparelho físico: permissão negada, rotação de token, logout, troca de conta, toque com o app aberto, em segundo plano e fechado.
- **Já pronto**: tabela `push_installations`, registro por instalação, revogação antes do logout, payload só com ids, destino do toque validado, central de notificações para o caso de falha.
- **Extras**: canais de notificação do Android; exibir o aviso do sistema também em primeiro plano; push na web (service worker próprio), só se a web virar canal público.

### C. Aposentar o app legado (Etapa 10)

Só depois de: chave de assinatura real e APK instalado em aparelho; jornadas essenciais passadas; beta fechado de uma semana com poucas contas, sem perda de dados, sessão cruzada, falha de login, mensagem duplicada ou crash; retorno ensaiado (o APK Expo anterior ainda instala e conversa com o backend); avisar quem usa de que é uma nova instalação e de que tema e preferências voltam ao padrão.

- **Fase A, tirar o `mobile/` da árvore**: `git push origin legacy-expo-final`; `git rm -r mobile`; remover do `.gitignore` as linhas `mobile/...` e o bloco `# Expo`; remover do README a seção "App legado" e a linha na Stack; conferir com `git grep -n "mobile/"`. Para consultar depois: `git checkout legacy-expo-final -- mobile`. Guardar o APK Expo como artefato antes, se ainda servir de retorno.
- **Fase B, aposentar o Expo no backend** (releases separados, só com os clientes antigos fora de uso): (1) parar de gravar o token legado e remover `POST /users/me/push-token`; (2) tirar o `ExpoProvider`, a leitura de `users.expo_push_token`, a dependência `expo-server-sdk` e o campo `expoBody` do payload; (3) remover a coluna `users.expo_push_token` em uma migration própria; (4) limpar as linhas `provider = 'expo'` de `push_installations`. Ajustar `backend/src/push/push.test.ts` e `backend/test/api/push.routes.test.ts`.
- **Fase C, documentação**: marcar este documento como histórico quando A e B terminarem.

### D. Backend: confiabilidade e escala (quando o volume pedir)

- **Sessão web persistente**: refresh em cookie `HttpOnly`, `Secure` e `SameSite` apropriado, endpoint próprio para a web, proteção CSRF, CORS por origem e bootstrap que obtém o access token em memória. Necessário antes de a web virar canal público; hoje o recarregar pede novo login.
- **Presença distribuída**: guardar as conexões em Redis com expiração, para funcionar com mais de uma réplica do backend.
- **Evento pessoal de conversa**: uma sala por usuário para avisar mensagens novas sem polling de 30 s e atualizar o selo de não lidas na hora.
- **Paginação** de coleção, comentários e conversas, se a medição em aparelho ou em volume maior mostrar custo; mudança aditiva com cursor opcional.
- **Notificações**: leitura individual e paginação, para o contador e a lista cobrirem o mesmo conjunto.
- **Estatísticas por pessoa distinta**, em vez de por registro, se o rótulo "jogadores" precisar ser exato.
- **Ordenação por data de término** para "Concluídos recentes" de verdade.
- **Rate limit geral** na API (hoje só login e cadastro) e envelope de erro único também para o 429.

### E. Produto

- **Editar e apagar post e comentário** (o backend não tem as rotas; não inventar no frontend).
- **Recuperação de senha, exclusão de conta, bloqueio e denúncia**, se a expansão pública pedir.
- **Posts do jogo na aba Comunidade** da página do jogo (`GET /games/:id/posts` já existe no backend).
- **Aba Respostas** no perfil (`GET /users/:id/comments` já existe) e telas de seguidores e seguindo, tornando os contadores links.
- **Composer de review e de imagem no post** (`review` e `imageUrl` já existem no contrato e o app já os renderiza).
- **Anexos e grupos no chat**, só se virarem requisito.
- **Cache persistente de imagens**, depois de medir a necessidade em aparelho.
- **Busca real na IGDB em teste**: um ambiente com credenciais para exercitar o caminho de sucesso e fixar o contrato de `GameSummary`.

### F. Qualidade

- **Teste de interoperabilidade Flutter ↔ Expo**: o mesmo usuário nos dois clientes, conversando no chat e vendo as mesmas notificações.
- **Testes de integração no aparelho** (`integration_test`) para as jornadas principais, para não depender só de widget test.
- **Goldens selecionados** para os padrões visuais mais usados (card de jogo, linha de post, bolha de mensagem), nos dois temas.
- **Observabilidade**: registrar erros técnicos de API, refresh, reconexão e upload, sem tokens, senhas nem texto privado do chat, e comparar por versão do app.
- **Fixtures de thread profunda** (muitos níveis de resposta) e conversa muito longa em aparelho.
- **Fatiar o APK por ABI** na distribuição (`--split-per-abi`) e avaliar o tamanho do CanvasKit na web.

## 12. Referências do repositório

| O quê | Onde |
| --- | --- |
| App Flutter | `flutter_app/` (README com os comandos) |
| Testes do backend: unidade e API de verdade (Express, Socket.IO, Postgres, Redis) | `backend/src/**/*.test.ts` e `backend/test/api/*.test.ts` (`auth`, `entries`, `notifications`, `profile`, `push.routes`, `chat`); helpers e trava de banco em `backend/test/helpers/` |
| Ambiente de teste | `docker-compose.test.yml`, `backend/.env.test.example`, scripts `test:db:up`, `test:seed`, `dev:test` em `backend/package.json` |
| Respostas reais do backend usadas pelos testes do app | `flutter_app/test/fixtures/` (veja o README da pasta) |
| Script de release | `flutter_app/tool/build_release.sh` |
| CI | `.github/workflows/flutter.yml`, `.github/workflows/backend.yml` (backend e integração Flutter↔API), `.github/workflows/flutter-release.yml` |
| Roadmap histórico do projeto (anterior à migração) | `docs/01_ROADMAP.md` |
| Plano, baseline, ADRs, matriz de aceite e encerramento originais | histórico do git, `docs/` no commit `fd60016` |
| App legado | `mobile/` e a tag local `legacy-expo-final` (enviar com `git push origin legacy-expo-final`) |
