# Redesign Flutter — registro de execução

Acompanha [`PLANO_REDESIGN_EXPERIENCIA.md`](PLANO_REDESIGN_EXPERIENCIA.md). Um item só é marcado como concluído depois de verificado.

| Etapa | Estado | Observação |
|---|---|---|
| 01 Preparar execução | Parcial | Baseline de testes registrado. API de teste, abertura no Chrome e capturas pendentes (abaixo) |
| 02 Fundação visual | Concluída (sem inspeção no navegador) | Verificada por testes de widget/golden; ver abaixo |
| 03 Navegação | Pendente | |
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

### Limitações

- **API de teste não foi iniciada.** `npm run test:db:up` exige Docker, que está indisponível. A porta 3100 já está ocupada por `npm run dev` (`src/server.ts`) usando o `.env` de desenvolvimento, com banco `gametracker_flutter` (porta 5433, sem sufixo `_test`). Esse banco pode ser compartilhado com produção, então **nenhum teste que escreva dados foi executado contra ele** (regra 19 do plano).
- **`flutter test test/integration` não executado.** Depende da API de teste. Relatar como não executado, não como aprovado.
- **Capturas de baseline (390/1440 px) não feitas.** Dependem de dados sintéticos criados via API de teste. Telas disponíveis sem dados (login/cadastro) podem ser capturadas separadamente.
- Para destravar: iniciar o Docker Desktop e rodar `cd backend && npm run test:db:up && npm run test:seed`, parar o `npm run dev` que ocupa a 3100 e rodar `npm run dev:test`.

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
