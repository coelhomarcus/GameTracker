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
| Curtir e seguir repetidos geram notificações duplicadas | `notifications_list`: 2× `like`, 2× `follow`, `unreadCount: 5` para 3 eventos reais |
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
