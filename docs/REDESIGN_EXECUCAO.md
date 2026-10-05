# Redesign Flutter — registro de execução

Acompanha [`PLANO_REDESIGN_EXPERIENCIA.md`](PLANO_REDESIGN_EXPERIENCIA.md). Um item só é marcado como concluído depois de verificado.

| Etapa | Estado | Observação |
|---|---|---|
| 01 Preparar execução | Concluída, com capturas parciais | Baseline, API de teste e build web OK. Só a captura do login; sem ferramenta para navegar nas telas autenticadas (abaixo) |
| 02 Fundação visual | Concluída (sem inspeção no navegador) | Verificada por testes de widget/golden; ver abaixo |
| 03 Navegação | Concluída (sem inspeção no navegador) | Verificada por testes de widget; ver abaixo |
| 04 Crop de avatar/banner | Pendente | |
| 05 Biblioteca | Pendente | |
| 06 Formulário de registro | Pendente | |
| 07 Pesquisa / Explorar | Pendente | |
| 08 Página do jogo | Pendente | |
| 09 Comunidade | Pendente | |
| 10 Mensagens | Pendente | |
| 11 Perfil | Pendente | |
| 12 Configurações / auxiliares | Pendente | |
| 13 Validação final | Pendente | |

## Etapa 01 — situação inicial (05/10/2026)

**Git:** árvore limpa, exceto o próprio plano (`docs/PLANO_REDESIGN_EXPERIENCIA.md`, não versionado). Nada preexistente a preservar.

**Ferramentas:** Flutter 3.47.6 (stable), Node em `/usr/local/bin/node`. Docker instalado, mas o daemon não responde.

**Baseline em `frontend/`:**

| Comando | Resultado |
|---|---|
| `flutter pub get` | OK (10 pacotes com versão mais nova, incompatíveis com as restrições; sem ação) |
| `flutter analyze` | Nenhum problema |
| `flutter test` | 708 passaram, 45 pulados, 0 falhas |

Qualquer falha a partir daqui é regressão.

### Ambiente de teste (atualizado após abrir o Docker)

- `npm run test:db:up` e `npm run test:seed` OK (banco `gametracker_test`, Postgres 5434, Redis 6381; migrations aplicadas).
- **API de teste na porta 3101, não 3100.** A 3100 continua ocupada pelo `npm run dev` do desenvolvedor (banco `gametracker_flutter`, que pode ser compartilhado com produção), então não o derrubei. Comando: `cd backend && PORT=3101 PUBLIC_API_URL=http://localhost:3101 npm run dev:test`. A trava de `test/helpers/env.ts` recusa qualquer banco não local ou sem sufixo `_test`.
- `flutter test test/integration --dart-define=GT_BACKEND=http://localhost:3101`: **50 passaram**, 0 falhas.
- `flutter build web --dart-define=API_URL=http://localhost:3101`: OK.

### Capturas

- `docs/redesign/evidencias/baseline-login-1440x900.png`: login em 1440 px, tema escuro (o Chrome headless prefere escuro). Feita com Chrome headless sobre o build web.
- **Não feitas:** biblioteca vazia/com replay, pesquisa, comunidade, conversa, perfil, edição e configurações, e todas as de 390 px. Não há ferramenta de automação de navegador nesta sessão, e o Chrome headless impõe largura mínima de janela (a captura de 390 px saiu cortada e foi descartada). Essas telas exigem navegação manual ou um driver de navegador.

## Etapa 02 — fundação visual Material 3

**Arquivos (frontend/lib/core/design_system/):** `tokens.dart` (acrescenta `Space.xxxl`, `Radii`, `ContentWidth`, `Motion`, `Breakpoints.railExtended`), `app_theme.dart` (papéis tipográficos, raios 12/16, cards sem sombra, alvo de toque 48 dp, snackbar flutuante), `game_cover.dart` (raio 8), `user_avatar.dart` (inicial sem escala de fonte), `status_chip.dart` (contraste do texto). Novos: `page_container.dart`, `section_header.dart`, `game_card.dart`, `filter_toolbar.dart` (também `SortMenu` e `ViewModeToggle`), `content_skeleton.dart`.

**Uso em telas reais:** Biblioteca (`PageContainer` largo, `GameCard` no lugar do cartão antigo, `FilterToolbar` com os chips, ordenação e grade/lista que estavam na app bar, `ContentSkeleton` no carregamento) e Configurações (`PageContainer` de leitura e `SectionHeader` nas quatro seções). A Biblioteca ainda lista registros, não jogos agrupados: isso é a Etapa 05. A busca do `FilterToolbar` ainda não aparece em nenhuma tela; entra na Etapa 05.

**Defeito corrigido no caminho:** `StatusChip` ficava com contraste de 3,97–4,45:1 (mínimo 4,5) com texto de 12 px sobre o fundo tingido. O texto agora puxa 35% para a cor do conteúdo; o ícone mantém a cor do status. Os testes antigos de acessibilidade não pegavam isso.

**Decisão:** o esqueleto de carregamento é estático (sem shimmer), então não depende de "reduzir movimento" e não atrapalha `pumpAndSettle`.

**Verificações:**

| Comando | Resultado |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | OK |
| `flutter analyze` | Nenhum problema |
| `flutter test` | 735 passaram, 45 pulados, 0 falhas (+27 novos em `test/core/design_system_test.dart`) |

Os novos testes cobrem: papéis tipográficos, margens e larguras do `PageContainer`, semântica/foco/toque do `GameCard`, busca e "Limpar" do `FilterToolbar`, skeletons a 360 dp com texto a 200%, movimento reduzido e a composição em claro/escuro a 360 (200%), 390 e 1440 px, com as diretrizes de toque, rótulo e contraste. Dois goldens (`test/core/goldens/foundation_{light,dark}.png`).

**Não verificado:** a aparência no navegador (sem API de teste, ver Etapa 01). A Etapa 02 foi checada só em testes de widget. Layouts a 360 px e 200% estão cobertos por teste; hover e foco por teclado no Chrome não foram vistos.

## Etapa 03 — navegação, cabeçalhos e retorno

**Arquivos:** novos `core/navigation/back_navigation.dart` (`FallbackBackButton`, `goBackOr`) e `core/design_system/primary_action.dart` (`PrimaryAction`). Alterados: `app/shell.dart` (usa `Breakpoints.railExtended`), Biblioteca, Comunidade, Mensagens, Explorar, Perfil, página do jogo, post, criação de post, edição de perfil, formulário de registro, conversa, notificações, configurações e `post_list.dart`.

- **Ação principal adaptativa:** Biblioteca ("Adicionar jogo"), Comunidade ("Publicar") e Mensagens ("Nova conversa") mostram FAB estendido abaixo de 600 dp e botão no cabeçalho a partir daí, nunca os dois. Em Mensagens o botão largo é só ícone (a lista tem 360 dp; o texto não cabe a 200%). `heroTag` próprio por destino e `PrimaryAction.fabClearance` (96) no fim das listas.
- **Sino** agora também em Explorar e no Perfil próprio (antes de Configurações). Mensagens mantém o cabeçalho próprio.
- **Voltar sem pilha:** jogo → Biblioteca, post e novo post → Comunidade, edição e configurações → Perfil, conversa → Mensagens, registro → jogo. Antes, jogo, post, criação de post, edição de perfil e registro não tinham botão de voltar em link direto.
- **Id inválido de jogo** (`/games/abc`): "Jogo não encontrado" com saída para a Biblioteca, sem consulta.
- **Defeito evitado no caminho:** um voltar com `go()` ignoraria o `PopScope` e descartaria um formulário não salvo em silêncio. `goBackOr` consulta `Navigator.maybePop` antes; há teste do diálogo de descarte em link direto.

**Verificações:** `dart format` OK; `flutter analyze` sem problemas; `flutter test` 763 passaram, 45 pulados, 0 falhas (+31 em `test/navigation_test.dart`); `flutter test test/integration` (API de teste, porta 3101) 50 passaram.

**Cobertura nova:** voltar em sete links diretos e com pilha; formulário sujo; post/usuário/conversa inexistentes; link direto sem sessão → login → destino → voltar; FAB/cabeçalho em 390/599/600/900 dp para as três ações; sino por destino; rail expandido em 1239 vs 1240; redimensionar mantém o destino; tocar no destino ativo preserva o filtro e volta à raiz.

**Não verificado:** rolagem preservada entre destinos (vem do `IndexedStack`, sem teste dedicado) e a aparência no navegador. No web, a recarga continua exigindo novo login (política de sessão em memória), e o destino é restaurado depois do login.
