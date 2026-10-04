# Etapa 0 — Baseline, contratos e provas técnicas

**Data:** 03/10/2026  
**Estado:** em andamento. Itens concluídos abaixo; pendências na seção 5.  
**Decisão tomada:** iOS está fora de escopo. Plataformas: Android e web. O plano [02](02_PLANO_MIGRACAO_FLUTTER.md) foi ajustado.

## 1. Ambiente de desenvolvimento

| Item | Resultado |
| --- | --- |
| Flutter | 3.47.6 estável, Dart 3.13.5 (instalado via Homebrew) |
| Android | SDK 36 existente, `cmdline-tools` instalado, licenças aceitas; `flutter doctor` ✓ |
| Web | Chrome ✓ |
| iOS/Xcode | Não usado (fora de escopo) |

## 2. Ambiente isolado (nunca o banco compartilhado)

A porta 5432 é usada por outro projeto local, e os volumes antigos do GameTracker foram preservados. O ambiente da migração usa containers e volumes próprios:

```bash
docker run -d --name gt-flutter-pg -e POSTGRES_USER=gametracker -e POSTGRES_PASSWORD=gt_flutter_dev \
  -e POSTGRES_DB=gametracker_flutter -p 5433:5432 -v gt_flutter_pg:/var/lib/postgresql/data postgres:16-alpine
docker run -d --name gt-flutter-redis -p 6380:6379 redis:7-alpine
```

`backend/.env` (ignorado pelo git) aponta para eles com `PORT=3100`. Subir: `cd backend && npm run db:migrate && npm run dev`. As 9 migrations aplicam em banco vazio.

## 3. Matriz candidata de dependências (compila para Android debug e web)

| Pacote | Versão |
| --- | --- |
| `material_ui` | 1.5.0 |
| `flutter_riverpod` | 3.4.3 |
| `go_router` | 18.0.2 |
| `dio` | 5.11.1 |
| `socket_io_client` | 3.1.6 |
| `flutter_secure_storage` | 11.2.0 |
| `shared_preferences` | 2.5.5 |
| `image_picker` | 1.2.3 |
| `firebase_core` / `firebase_messaging` | 4.15.0 / 16.7.0 |

Provado: `flutter analyze` sem erros no código do app, `flutter build web` e `flutter build apk --debug` concluídos, projeto descartável com `MaterialApp.router`, `ColorScheme.fromSeed`, Dio e Socket.IO importados juntos. **Não provado:** execução em aparelho/emulador, upload multipart, release assinado, Firebase real (falta `google-services.json`).

## 4. Contratos capturados

Script: [contract-fixtures/capture.mjs](contract-fixtures/capture.mjs). Respostas reais em [contract-fixtures/responses/](contract-fixtures/responses/) (usuários e jogos sintéticos; tokens mascarados). Rodar de novo exige backend isolado no ar.

Confirmado por execução (antes eram inferências do plano):

| Achado | Evidência |
| --- | --- |
| `PATCH` com `null` era rejeitado (**corrigido na Etapa 4**: agora `null` limpa o campo) | Baseline: 400 `validation_error`. Hoje: `docs/contract-fixtures/patch_contract.mjs` |
| Limpar campo hoje só é possível para `notes` (vira `""`, não `null`) | `entries_list_after_patch` |
| Horas voltam como string (`"20.0"`, `"0.0"`); zero é válido | `entries_create_zero_hours` |
| Datas de progresso voltam como instante UTC à meia-noite (`2026-01-05T00:00:00.000Z`) | `entries_list_after_patch`; o cliente deve ler ano/mês/dia em UTC |
| Curtir e seguir repetidos geravam notificações duplicadas (**corrigido na Etapa 5**) | Baseline: `notifications_list` com 2× `like`, 2× `follow`, `unreadCount: 5` para 3 eventos reais. Hoje: `docs/contract-fixtures/notification_dedup.mjs` |
| Refresh token é de uso único (reuso → 401 `invalid_refresh_token`) | `auth_refresh_reused_token` |
| Envelope de erro `{ error: { code, message } }`; validação devolve só a primeira mensagem | `auth_register_invalid` |
| Editar registro de outro usuário devolve 404, não 403 | `entries_patch_forbidden` |
| `PATCH /users/me` devolve 204 sem corpo | `profile_update` |
| Jogo sem sinopse/gêneros vem com `summary: null` e `genres: []` | `games_by_igdb_incomplete` |
| Listas sem paginação: `/game-entries/me`, `/conversations`, comentários do post | `entries_list_mine`, `conversations_list`, `post_comments` |

**Socket.IO** ([contract-fixtures/socket_probe.dart](contract-fixtures/socket_probe.dart), Dart VM contra o servidor 4.8.x do projeto):

- Sem `auth.token` → `connect_error: unauthorized`; com token válido conecta.
- `conversation:join` → `{ok: true}`; conversa inexistente → `{error: "Conversa não encontrada"}`.
- `message:send` devolve ACK `{message}` e o outro participante recebe o mesmo objeto em `message:receive` (mesmo `id`: dá para deduplicar evento + ACK).
- **Armadilha do cliente Dart:** `io.io()` reaproveita o socket em cache para a mesma URL. Trocar de conta sem `enableForceNew()` mantém o `auth` antigo. Isso reforça o requisito de descartar o socket no logout.
- Não provado em Android nem no navegador; só na VM Dart.

## 5. Pendências da Etapa 0

- [x] Distribuição: apenas APK manual (trabalho de faculdade). [ ] Falta confirmar se existe keystore do build anterior; define se a atualização por cima do app legado é possível.
- [ ] Projeto Firebase e credenciais FCM (sem APNs). Não existe projeto; há uma VPS disponível.
- [ ] Decidir se a web é só teste ou canal público (muda a política de sessão).
- [x] CI: GitHub Actions (escolhido). [ ] Workflow ainda não criado.
- [ ] Rodar o probe de socket e uma chamada autenticada em emulador/aparelho Android e no Chrome. O AVD `gt_pixel` já existe, mas o sandbox das ferramentas do Claude bloqueia a virtualização (`hvf is not enabled`, `mprotect failed`). Precisa ser iniciado no terminal do usuário: `~/Library/Android/sdk/emulator/emulator -avd gt_pixel`.
- [ ] Prova de upload multipart (`avatar`/`banner`) e de push em aparelho físico.
- [ ] Fixtures de volume (500 registros, 1000 mensagens) e de thread profunda.
- [ ] ADRs curtas: stack, sessão web, design, push, transição do app instalado.
- [ ] Remover `RECORD_AUDIO` do manifesto no cliente Flutter (não usada).

## 6. Etapa 2 iniciada: fundação em `flutter_app/`

Primeiro lote do plano (seção 11), com dados de fixture, sem backend real:

- Pacote Android `com.marcuscoelho.gametracker` (igual ao legado), alvos Android e web.
- Tema Material 3 claro/escuro/sistema, cores de status como extensão de tema, `StatusChip` com cor + ícone + texto, `GameCover` com fallback.
- Shell adaptável: `NavigationBar` abaixo de 600, `NavigationRail` a partir de 600, cinco destinos, estado preservado por destino.
- Login visual, Biblioteca (filtros por status, grade/lista, FAB), página de jogo por `igdbId` com dois playthroughs, rota inexistente com saída útil.
- Localização pt-BR com `GlobalMaterialLocalizations.delegates` do `material_ui`.

Verificado: `flutter analyze` sem avisos, 10 testes de widget passando (larguras 360/599/600/840/1280, texto a 200%, filtro preservado, vírgula decimal), `flutter build web` e `flutter build apk --debug` concluídos.

Achados durante a implementação:

- `material_ui` exporta o próprio `GlobalMaterialLocalizations`; importar também `flutter_localizations` gera símbolo ambíguo. Usar só `GlobalMaterialLocalizations.delegates` (plural), senão falta o delegate do Cupertino para pt-BR.
- Grade com `childAspectRatio` fixo estoura com texto ampliado. A Biblioteca usa linhas de altura intrínseca (lazy, número de colunas pela largura).

Não feito ainda: CI (depende do provedor do repositório), execução em emulador/aparelho, autenticação, Dio e socket integrados ao app, validação visual por você.

## 7. Etapa 3: autenticação e sessão

Implementado em `flutter_app/` e verificado contra o backend isolado.

- **Rede e sessão** (`core/network`, `core/storage`): `SessionManager` com uma única renovação em andamento, geração de sessão que descarta refresh e respostas tardias após logout/troca de conta, `AuthInterceptor` (Bearer, uma repetição após 401, sem recursão nas rotas `/auth/*`) e erros de domínio (`ApiException`, `NetworkException`, `CancelledException`) com fallback para corpo fora do envelope (429/HTML de proxy).
- **Armazenamento:** refresh token no `flutter_secure_storage` no Android; na web, só memória (ADR-3). Access token só em memória.
- **Estados da sessão:** inicializando, autenticado, não autenticado e restauração indisponível. Falha de rede ou 5xx no bootstrap mostra "Tentar novamente" e **não** apaga o token.
- **Guard de rotas** com `from` preservado para deep links; só caminhos internos são aceitos como destino.
- **Telas:** login e cadastro reais (limites de validação iguais aos do backend, erro inline, formulário preservado, envio único), splash, tela de restauração indisponível e botão Sair no perfil.
- **Isolamento entre contas:** `currentUserIdProvider` muda ao sair/trocar de conta; providers de dados devem observá-lo.

Verificado: `flutter analyze` sem avisos; 56 testes unitários/widget; 5 testes de integração com o backend real (`flutter test test/integration --dart-define=GT_BACKEND=http://localhost:3100`); builds web, APK debug e APK release (com `--dart-define=API_URL=...`). Os testes de sessão foram validados por mutação: remover o single-flight ou a checagem de geração faz testes falharem.

Achados:

- **Corrida de refresh confirmada no backend:** com 8 requisições simultâneas e o mesmo refresh token, todas as 25 rodadas emitiram mais de uma sessão válida (`docs/contract-fixtures/refresh_race.mjs`). Corrigido com `UPDATE` condicional atômico em `auth.service.ts`; depois da correção, 0 de 25.
- Riverpod 3 proíbe `ref.read` dentro de `onDispose`; capturar o objeto antes.
- O manifesto padrão do Flutter não declara `INTERNET` no build release (só no debug). Adicionado ao manifesto principal; o debug ganhou `usesCleartextTraffic` para o backend local.
- O build release usa assinatura de debug. Para distribuir o APK, falta criar uma keystore própria.
- O CORS do backend está `*`. Aceitável em desenvolvimento; restringir por origem antes de publicar a web.
- O limitador de `/auth/login` e `/auth/register` (20 por 15 minutos por IP) pode interferir em testes repetidos; reiniciar o backend zera o contador.

Não verificado: execução em emulador/aparelho (sandbox bloqueia o emulador), web contra o backend em navegador real, teste de atualização por cima do app legado (declarado irrelevante).

## 8. Etapa 4: catálogo e biblioteca

Implementado em `flutter_app/` e no backend, com dados reais.

**Backend:** contrato de `PATCH /game-entries/:id` com três estados por campo opcional (omitido = manter, `null` = limpar, valor = substituir) para `startedAt`, `finishedAt`, `hoursPlayed`, `rating` e `notes`. `PATCH {}` é válido. `platform` e `status` não aceitam `null`. Verificado por `docs/contract-fixtures/patch_contract.mjs` (13 verificações), incluindo o cliente legado que omite campos.

**App:**
- **Busca de jogos** com debounce de 400 ms, mínimo de 2 letras e cancelamento da requisição em voo; erro (inclusive "IGDB não configurada") é distinto de "nenhum resultado". Seletor de jogo em sheet para "Adicionar jogo".
- **Biblioteca** com dados reais: filtros por status com contagem, ordenação (recentes, antigos, mais jogados com "sem horas" no fim), grade/lista persistidas, alterar status direto, editar e remover com confirmação. Cada registro é um card (replay = dois cards).
- **Página de jogo** por `igdbId` (deep link): Sobre (sinopse, gêneros, screenshots com galeria em tela cheia e zoom), Meu progresso (playthroughs e "Novo playthrough (replay)") e Comunidade (contagem de playthroughs por status e jogadores, escopo Todos/Quem eu sigo). Favoritar com resposta imediata, rollback e uma alternância por vez.
- **Formulário de playthrough** (criar/editar, também por deep link): plataformas do jogo como chips, status, datas de calendário por date picker com botão limpar, horas com vírgula ou ponto, teto de 24 h por dia de calendário, nota 1–10 ou "Sem nota" (nunca zero), notas. Falha de salvar preserva tudo; sair com alterações pede confirmação.
- **Consistência:** `libraryProvider` é a fonte única; cada mutação aplica a resposta do servidor, então Biblioteca, página de jogo e formulário concordam sem refetch. Estatísticas e jogadores são invalidados após mutações. Mutação concluída depois de logout ou troca de conta não entra na coleção da outra conta.
- **Cache:** revalida ao voltar para o app se os dados têm mais de 30 s. Se a atualização falha, a lista continua visível com um aviso "Mostrando os dados salvos".
- Sem retry automático em nenhum provider (`noAutomaticRetry`): o Riverpod 3 repete sozinho por padrão, o que esconderia erros e reiniciaria o carregamento.

Verificado: `flutter analyze` sem avisos, 165 testes de unidade/widget, 14 testes de integração contra o backend real, builds web e APK debug. Os modelos são validados contra as respostas reais gravadas em `contract-fixtures`.

Achados:

- **Bug de perda de dados achado por teste:** o `PopScope` do formulário calculava `canPop` no `build`, mas digitar em campos de texto não reconstruía a tela. Quem editasse só as horas ou as notas perdia tudo ao voltar, sem confirmação. Corrigido ouvindo os controllers.
- **Bug de URL achado por teste:** `Uri.replace(port: null)` mantém a porta original, o que gerava `api.test:3100`. Corrigido reconstruindo a URI.
- As URLs de imagem do backend usam `PUBLIC_API_URL`, que em desenvolvimento é `localhost` e não funciona no emulador. O app reescreve o host das rotas `/api/images/` e `/uploads/` para o da API em uso.
- Overflow real no formulário (linha da nota) em largura estreita, achado por teste.
- `ensureVisible` do teste dentro de `TabBarView` troca de aba; o helper `tapAndSettle` só rola quando o alvo está fora da tela.

Não feito / não verificado:

- **Convite para publicar após concluir um jogo:** depende do compositor de posts, que é da Etapa 5.
- **Busca real na IGDB:** o ambiente isolado não tem credenciais. A busca foi verificada com repositório falso e, no backend real, só o caminho de erro `igdb_not_configured`. O caminho de sucesso contra a IGDB não foi exercitado.
- **Execução em emulador/aparelho:** o sandbox bloqueia o emulador.
- **Volume:** coleção de 500 registros ainda não medida; a lista é lazy, mas o backend não pagina.

## 9. Etapa 5: comunidade, posts e comentários

**Backend:** `like` e `follow` só notificam (e só disparam push) quando a relação é realmente criada, usando `returning` do `INSERT ... ON CONFLICT DO NOTHING`. Descurtir e curtir de novo continua gerando uma nova notificação, porque é uma nova curtida de verdade. Verificado por `docs/contract-fixtures/notification_dedup.mjs` (7 verificações), que falha no código antigo. O limite de login/cadastro agora aceita `AUTH_RATE_LIMIT_MAX` (padrão 20 por 15 min por IP) para suítes de integração.

**App:**
- **Fonte única de posts** (`PostStore`): feed Geral, Seguindo e detalhe guardam só ids e leem o post de um mesmo lugar, então curtida e contadores são iguais em todas as superfícies. Curtir é imediato, com rollback exato em erro e uma alternância por vez por post. Descartado ao sair ou trocar de conta.
- **Feed paginado por cursor** (Geral/Seguindo, escopo enviado sempre de forma explícita porque o padrão do servidor é `following`): sem duplicatas, uma página por vez, erro de rodapé recuperável, "Você chegou ao fim", pull-to-refresh, dados antigos mantidos com aviso quando a atualização falha.
- **Atividades** como linha compacta, com o ícone do status *no momento da atividade* (`activityStatus`); sobrevivem à exclusão do registro (`gameEntry` nulo).
- **Detalhe do post** por deep link, com a árvore de comentários inteira (recuo limitado a 3 níveis; nenhum comentário é escondido), curtida otimista por comentário, resposta com alvo visível e composer que preserva texto e alvo em falha.
- **Publicar:** texto de até 500 caracteres, jogo opcional (por busca; o backend vincula pelo UUID) e registro opcional. Com registro, só o `gameEntryId` é enviado (o backend deriva o jogo). Falha preserva texto e vínculos; sair com texto pede confirmação.
- **Convite para publicar ao concluir um jogo**, só depois do servidor confirmar e só quando o status *passa* a concluído (menu de status e formulário). O compositor abre com "Zerei {jogo}! 🎉" e o registro vinculado. É distinto da atividade automática.
- **Revalidação:** as mutações da biblioteca marcam os feeds como desatualizados (a atividade é criada de forma assíncrona no backend); eles revalidam ao entrar na aba Comunidade e ao voltar para o app (30 s).
- Rota `/users/:userId` provisória (placeholder); o próprio usuário resolve para `/me`.

Verificado: `flutter analyze` sem avisos, 254 testes de unidade/widget, 22 de integração contra o backend real (inclui paginação com 23 posts em 2 páginas, árvore de comentários de 4 níveis, atividade com snapshot de status e exclusão do registro), builds web e APK debug.

Achados (todos por teste):

- **Loop infinito no feed:** quando carregar mais falhava, o pré-carregamento automático tentava de novo a cada reconstrução. Agora, após um erro, só o botão repete.
- **Crash de Hero:** os FABs da Biblioteca e da Comunidade coexistem no `IndexedStack` e compartilhavam a tag padrão; navegar para outra rota quebrava. Cada um tem tag própria.
- **Overflow** na linha de ações (curtir/comentar/responder) em largura estreita com texto grande; trocado por `Wrap`.
- O tratamento de **429 fora do envelope** foi exercitado de verdade pelo limitador do backend.
- `PopScope` e `ListenableBuilder`: quando o estado vive em `TextEditingController`, é preciso ouvi-lo.

Não feito / não verificado:

- Perfis de outras pessoas (Etapa 6): tocar no autor abre uma página provisória.
- Edição e exclusão de posts não existem no backend, então não foram feitas.
- Posts de um jogo na aba Comunidade da página de jogo (`GET /games/:id/posts`) ainda não estão ligados.
- Execução em emulador/aparelho (o sandbox bloqueia).

## 10. Etapa 6: pessoas, perfis e uploads

**Backend** (verificado por `docs/contract-fixtures/profile_contract.mjs`, 16 verificações):
- `PATCH /users/me` com corpo vazio devolvia **500** (o Drizzle rejeita `SET` sem colunas). Agora é 204 e não altera nada.
- Imagem corrompida com MIME `image/*` devolvia **500** (o `sharp` lança). Agora é **400** `validation_error` ("Imagem inválida ou corrompida").
- Duas trocas simultâneas para o mesmo username: a perdedora batia na restrição de unicidade e dava 500. Agora é 409.

**App:**
- **Busca de pessoas** (aba Pessoas de Explorar): debounce de 400 ms, mínimo de 2 letras, cancelamento; erro distinto de "ninguém encontrado"; Seguir/Seguindo direto nos resultados.
- **Seguir** com resposta imediata, rollback em erro e uma alternância por vez por pessoa, em um `FollowStore` compartilhado: seguir na busca aparece no perfil, com o contador de seguidores somado. Dados novos do servidor descartam o ajuste local. Seguir marca o feed Seguindo como desatualizado.
- **Perfil único** para o próprio usuário (`/me`, dentro da navegação principal) e para outras pessoas (`/users/:id`, o próprio id redireciona para `/me`): capa e foto (tocar abre a visualização ampliada), nome (com fallback para o username), bio, contadores como rótulos (não são links) e abas **Coleção / Atividades / Posts**.
- **Coleção:** favoritos, "Jogando agora", "Concluídos" (renomeado de "completos recentemente", que ordenava pela criação do registro, não pela conclusão) e todos os registros com filtro e contagem. Somente leitura, sem menu de edição. O próprio usuário usa a coleção da Biblioteca (sempre consistente); favoritar um jogo atualiza os favoritos do perfil.
- **Privacidade:** `GET /users/:id/game-entries` devolve o registro inteiro, inclusive as **notas pessoais**, a qualquer usuário autenticado. O app nunca as exibe para outra pessoa, mas o dado continua exposto pela API. **Decisão pendente do dono do projeto:** remover `notes` da resposta pública.
- **Atividades e posts** do perfil: mesma lista paginada do feed (extraída para `PostList`/`PagedPostsController`), mesma fonte única de posts: curtir no perfil reflete no feed.
- **Editar perfil:** nome, username (409 vira erro no campo, sem perder o resto) e bio (vazia limpa). Foto e capa com pré-visualização local, progresso, recusa de arquivo acima de 8 MB antes de enviar, erro com "Tentar de novo" que reenvia sem reabrir a galeria, e aviso explícito de que **as fotos são salvas na hora**. Sair com alterações explica o que se perde (textos) e o que não (fotos já enviadas).
- **Identidade nova** propagada depois de salvar: sessão, perfil e posts do próprio usuário já carregados.
- **Configurações:** tema Sistema/Claro/Escuro **persistido** no aparelho, conta, versão (um teste confere que bate com o `pubspec.yaml`) e Sair. O botão Sair saiu do perfil.

Verificado: `flutter analyze` sem avisos, 341 testes de unidade/widget, 33 de integração contra o backend real (inclui upload real de PNG pelo `sharp`, arquivo corrompido, não-imagem e acima de 8 MiB), builds web e APK debug.

Achados (todos por teste):

- **A tela de edição não fechava depois de salvar com sucesso.** O `PopScope` só enxerga o `canPop` novo depois de reconstruir, e o `pop()` acontecia na mesma pilha de chamadas. Agora marca o estado e sai no frame seguinte.
- Overflow real na linha foto + botão em largura estreita com texto grande.
- Os dois 500 do backend acima.

Não feito / não verificado:

- **Mensagem** no perfil de outra pessoa: depende do chat (Etapa 7).
- Execução em emulador/aparelho (o sandbox bloqueia), seleção real de foto no Android e permissão negada em aparelho; só o seletor foi simulado.
- HEIC: o suporte depende do aparelho e do `sharp` do servidor; não foi testado com arquivo real.
- Seguidores e seguindo não têm tela própria (não há API de lista), por isso os contadores não são links.

## 11. Etapa 7: chat confiável

**Backend** (verificado por `docs/contract-fixtures/chat_contract.mjs`, 13 verificações; migration aditiva `0009`):
- **Falha grave:** um `conversationId` que não é UUID em `conversation:join` fazia o Postgres lançar dentro de um handler assíncrono sem `try/catch`: a *unhandled rejection* **derrubava o processo do backend**. Qualquer usuário autenticado conseguia tirar o servidor do ar. Reproduzido antes da correção. Agora todos os ids são validados antes de consultar, e todos os handlers respondem o ACK com erro em vez de falhar.
- `clientMessageId` opcional no envio, com índice único parcial `(conversa, remetente, clientMessageId)`: repetir o envio devolve a mensagem já gravada, sem nova linha, sem novo evento e sem novo push. O campo vai nos eventos `message:receive` e no histórico (nulo nas mensagens do cliente legado, que continua funcionando).
- `typing:*` só é retransmitido para quem está na sala da conversa. `socket.to(sala)` não exige estar na sala, então antes qualquer usuário podia emitir digitação para conversas alheias.
- Snapshot de presença (`presence:get`), restrito a participantes. Contagem de conexões feita de forma síncrona e avisos de presença calculados com as conversas atuais. Continua em memória por instância (precisa de armazenamento compartilhado antes de escalar).
- Criar conversa ao mesmo tempo (inclusive cada pessoa iniciando com a outra) criava 2 ou 3 conversas. Agora há lock consultivo por par; sem o lock o teste volta a falhar.

**App:**
- **`ChatTransport`/`ChatConnection`:** uma conexão por sessão com reconexão própria (a do Socket.IO reaproveitaria o token de 15 min e não sabe quais salas reentrar). Backoff 1, 2, 4, 8, 16, 30 s com variação; queda depois de conectado reconecta na hora; servidor recusa o token → renova a sessão e reconecta (no máximo 2 repetições imediatas antes de voltar ao backoff; sessão encerrada → para); reentra nas salas com ACK (timeout derruba e refaz a conexão); `verify()` ao voltar do segundo plano; logout fecha o socket e esquece as salas.
- **Mensagens com estado** (enviando, enviada, incerta, falhou) e mescla pura por `clientMessageId`/`id` (testada com embaralhamentos aleatórios): evento antes do ACK, ACK antes do evento ou ACK perdido nunca duplicam. ACK perdido reenvia com o **mesmo** `clientMessageId` (seguro por idempotência); 3 tentativas sem confirmação viram "Não enviada" com **o texto preservado**, "Tentar de novo" e "Descartar". Recusa definitiva do servidor falha na hora. Sem conexão, a mensagem fica na fila e sai uma vez ao reconectar, sem gastar tentativas.
- **Sincronização depois de reconectar:** busca páginas recentes até reencontrar a última mensagem conhecida (até 10 páginas; acima disso, descarta o histórico antigo já carregado e guarda o cursor, porque não dá para garantir contiguidade). Eventos que chegam durante a carga inicial são guardados e mesclados.
- **Digitação** (aviso no máximo a cada 2 s, para sozinho em 3 s; a da outra pessoa expira em 4 s sem aviso), **presença** (snapshot na entrada e a cada reconexão; "desconhecido" nunca vira "offline"), **leitura só com a conversa visível** (tela aberta e app em primeiro plano), sem repetir para a mesma mensagem.
- **Lista de conversas** com polling de 30 s só com o app aberto, revalidação ao voltar e ao entrar na aba, selo de não lidas na navegação e atualização local ao enviar, receber e ler. Em telas largas (840+) vira lista + conversa lado a lado.
- **Telas:** bolhas agrupadas por autor e por janela de 5 min com separadores de dia, estado de entrega, banner "Sem conexão" com "Tentar agora", rascunho por conversa que sobrevive a sair e voltar, contador perto do limite de 2000. Nova conversa por busca de pessoas e botão **Mensagem** no perfil.

Verificado: `flutter analyze` sem avisos, 487 testes de unidade/widget, 42 de integração contra o backend real (9 do chat com sockets reais: token recusado e renovado, idempotência, queda com interrupção e reconexão automática com reentrada na sala, presença, digitação, ids inválidos, paginação), builds web e APK debug. Mutações confirmadas: sem a sincronização pós-reconexão, sem o `clientMessageId` e sem a substituição da pendente na mescla, testes falham.

Achados (por teste):
- O crash do backend acima.
- `ref.read` dentro de `onDispose` (proibido no Riverpod 3) fazia o controller nunca deixar a sala ao fechar a tela.
- Falsos positivos que eu mesmo escrevi (relógio real dentro de `fakeAsync`, premissas de lista lazy): ajustados nos testes, sem mudar o app.

Não feito / não verificado:
- **Compatibilidade Flutter ↔ Expo:** não há cliente Expo executável aqui. O contrato do evento foi mantido compatível (campos novos opcionais, envio sem `clientMessageId` testado), mas a interoperabilidade real não foi exercitada.
- **Push de mensagens** e abertura da conversa pelo toque: Etapa 8.
- Execução em emulador/aparelho (o sandbox bloqueia), suspensão real do app e troca de rede em aparelho.
- Presença com mais de uma instância do backend (hoje em memória).
- A visibilidade da conversa considera tela aberta e app em primeiro plano; uma rota empilhada por cima (ex.: perfil) ainda a conta como visível.

## 12. Etapa 8: notificações e push

**Backend** (commit `d8fb38c`, 7 testes `npm test`, contrato em `push_contract.mjs`, migration aditiva `0010`):
- `push_installations` com `PUT/DELETE /api/push/installations/:installationId`, provedores Expo e FCM (`firebase-admin`), desativação de tokens que o provedor declara inexistentes, FCM desligado sem credenciais. `notify` e o chat passam pelo mesmo `sendPushToUser`.
- Payload: `type`, `recipientId`, `notificationId`, `actorId`, `postId`/`conversationId` (só ids). `docs/contract-fixtures/responses/push_payloads.json` foi gravado pelo código real (`backend/scripts/capturePushPayloads.ts`, recusa banco que não seja local) e o app o usa nos testes.

**App:**
- **Central de notificações** (`/notifications`, sino com selo na Biblioteca e na Comunidade): Tudo / Interações / Seguidores, não lidas em destaque, destino por ids, estados vazio/erro/desatualizado. O backend só tem "ler todas", então **abrir uma notificação não marca nada**; a ação é explícita, otimista e volta ao estado anterior se falhar, uma por vez. Polling de 60 s só em primeiro plano, revalidação ao voltar/abrir/receber push, e o polling não atropela uma marcação em andamento (desfaria o "lido"). O backend devolve no máximo 50: com 50 itens a tela avisa "Mostrando as 50 mais recentes". Tipo desconhecido (backend mais novo) é ignorado em vez de quebrar a lista.
- **Push do cliente:** `PushPlatform` (padrão `Noop`), `PushController` (registro com `installationId` persistente, token renovado, nova tentativa ao voltar ao app se falhou, descarte de sessão obsoleta), `pushUnregisterProvider` chamado pelo logout, rota de destino (`resolvePushRoute`) e `pendingPushRouteProvider` consumido pelo app. Configurações mostram o estado (indisponível, desativadas, negadas, falhou, ativadas) com a ação cabível.

Verificado: `flutter analyze` sem avisos, formatação, 554 testes de unidade/widget (27 da central, 40 do push) e 48 de integração contra o backend real (6 novos: seguir gera notificação sem duplicar, marcar todas, 401, registro idempotente, troca de conta, revogar a de outra pessoa sem vazar, id inválido → 400), builds web e APK debug. Mutações confirmadas: sem a checagem de `recipientId` e sem o descarte de sessão obsoleta, testes falham.

Achados (por teste):
- `ref.read` do `PushController` dentro do logout dava `CircularDependencyError` (o controller depende da sessão): a revogação virou um provider sem dependência da sessão.
- A ação "Marcar todas como lidas" e o botão de push estouravam a 360 px com texto a 200% (botão em `AppBar`/`ListTile.trailing`): viraram botão de ícone e coluna.
- Meus primeiros testes liam `fixtureBody` num arquivo sem o formato `{status, body}`: o gerador agora usa o mesmo formato dos demais.

Não feito / não verificado:
- **Entrega real por FCM**: não existe projeto Firebase. O adaptador do cliente não foi escrito (ver ADR-5), então hoje nenhum aparelho se registra e não há push em produção; a central funciona por polling.
- **Interoperabilidade com o app Expo** (mesmo usuário nos dois clientes) não foi exercitada.
- Exibição da notificação do sistema em primeiro plano (hoje só atualiza o selo) e canais de notificação do Android: dependem do adaptador.
- Notificação individual como lida e paginação da central: o backend não oferece.
- Execução em emulador/aparelho (o sandbox bloqueia).

