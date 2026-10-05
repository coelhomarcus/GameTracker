# Redesign Flutter — registro de execução

Acompanha [`PLANO_REDESIGN_EXPERIENCIA.md`](PLANO_REDESIGN_EXPERIENCIA.md). Um item só é marcado como concluído depois de verificado.

| Etapa | Estado | Observação |
|---|---|---|
| 01 Preparar execução | Concluída, com capturas parciais | Baseline, API de teste e build web OK. Só a captura do login; sem ferramenta para navegar nas telas autenticadas (abaixo) |
| 02 Fundação visual | Concluída (sem inspeção no navegador) | Verificada por testes de widget/golden; ver abaixo |
| 03 Navegação | Concluída (sem inspeção no navegador) | Verificada por testes de widget; ver abaixo |
| 04 Crop de avatar/banner | Concluída, exceto gestos no navegador/aparelho | Verificada por testes e upload real na API de teste; ver abaixo |
| 05 Biblioteca | Concluída (sem inspeção no navegador) | Verificada por testes, goldens e volume de 1.000 registros; ver abaixo |
| 06 Formulário de registro | Concluída (sem inspeção no navegador) | Verificada por testes; corrige regressão da Etapa 03; ver abaixo |
| 07 Pesquisa / Explorar | Concluída (sem inspeção no navegador) | Verificada por testes; ver abaixo |
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

## Etapa 04 — recorte de avatar e banner

**Dependências:** `crop_your_image ^2.0.1` (resolvida 2.0.1) e `image ^4.10.1` (resolvida 4.10.1). O build web compila; o aviso de WebAssembly vem de `socket_io_common` e já existia.

**Arquivos:** novos `profiles/application/profile_image_processor.dart` (preparação, exportação, limites) e `profiles/presentation/profile_image_crop_page.dart` (editor, `ProfileImageCropper`). Alterados: `profile_image_picker.dart` (sem `imageQuality`, para o recorte ser o único passo com perda), `edit_profile_page.dart` (fluxo de recorte e seções).

**Fluxo:** escolher → (arquivo > 8 MiB é recusado sem abrir o editor) → preparar (EXIF, ≤ 2048 px) → recortar → "Salvar foto"/"Salvar capa" → upload com progresso na edição. Cancelar o editor ou a galeria não faz requisição nem muda a foto. Falha de upload guarda os bytes recortados; "Tentar de novo" reenvia os mesmos, sem reabrir o editor.

**Editor:** tela cheia abaixo de 600 dp, diálogo de até 720 dp acima. Imagem se move sob uma moldura fixa (pinça/arrasto/roda, do pacote). Botões e setas do teclado movem a moldura e `+`/`-` a redimensionam, pelo `CropController.cropRect`. Prévia circular (foto) ou 3:1 com o avatar sobreposto (capa), desenhada a partir do mesmo enquadramento e só na tela, nunca no arquivo. Avisos de imagem pequena e de GIF estático. Ações Restaurar/Salvar fixas no rodapé.

**Saída:** JPEG qualidade 85, fundo branco, sem EXIF, 400×400 (foto) ou 1500×500 (capa), ≤ 8 MiB, nome `avatar.jpg`/`banner.jpg`, `image/jpeg`. Entrada: JPEG, PNG, WebP; GIF/WebP animado usa o primeiro quadro; HEIC e formatos fora da lista recebem "Use uma imagem JPG, PNG ou WebP."; mais de 24 milhões de pixels é recusado lendo só o cabeçalho.

**Defeitos encontrados e corrigidos no caminho (todos pegos por teste):**
- O `findDecoderForData` do pacote `image` lança `RangeError` em arquivo curto ou corrompido; agora toda falha de decodificação vira a mensagem de formato não suportado.
- O decodificador JPEG do `image` já aplica a orientação EXIF e zera a tag; o `bakeOrientation` depois é no-op e não gira duas vezes (confirmado com JPEG de orientação 6 e 3 montado à mão, porque o codificador do pacote não grava um EXIF que ele mesmo releia).
- "Restaurar" via `controller.image` não repunha o enquadramento inicial; agora remonta o editor.
- O botão Salvar ficava dentro do painel rolável e podia sair da tela no celular; agora fica fixo.

**Edição de perfil:** seções "Fotos — Salvas ao confirmar o recorte." e "Informações — Salvas no botão Salvar alterações."; o botão do cabeçalho virou "Salvar alterações" no fim do formulário (a Etapa 11 não precisa refazer isso).

**Verificações:** `dart format` OK; `flutter analyze` sem problemas; `flutter test` 814 passaram, 46 pulados (o novo teste de integração é pulado sem API), 0 falhas (+51: processador 20, editor 21 com `Crop` real, edição de perfil +9 etc.); integração 51 passaram na API de teste (porta 3101), incluindo um teste novo que prepara uma foto de 3000×2000, exporta avatar e capa e os envia ao backend real, que os serve como JPEG na proporção certa.

**Cobertura relevante:** orientação EXIF 6 e 3 pelos pixels; GIF animado; WebP com e sem perdas; limite de pixels exatamente no teto (24 MP aceita, 25 MP recusa); arquivo de 8 MiB + 1; transparência sobre branco; dimensões exatas; mover/zoom/restaurar refletidos no arquivo; prévia igual ao arquivo salvo (avatar e capa); alvos de 48 dp; 360 px a 200% sem overflow.

**Não verificado:** os gestos de pinça (aparelho) e roda do mouse (web) vêm do pacote e não foram exercitados num navegador ou aparelho; só botões e teclado têm teste. Android nativo (picker, HEIC convertido pelo sistema) não foi executado. No web o processamento roda na thread principal (`compute` é inline), então a interface pode congelar por cerca de 1 s ao preparar uma foto grande; medido em modo debug: preparar 4000×3000 ≈ 1,0 s, exportar a capa ≈ 0,2–1,2 s.

## Etapa 05 — Biblioteca por jogo, com replays preservados

**Arquivos:** novos `library/application/library_groups.dart` (projeção pura: `buildLibraryOverview`, `LibraryFilter`, `LibraryGroup`, `foldText`) e `library_filter.dart` (filtros em memória por conta e `libraryOverviewProvider`). Alterados: `library_prefs.dart` (ordenação "Nome A–Z" e rótulos novos; as chaves salvas continuam), `library_view.dart` (só o `case` novo; o Perfil ainda usa essas funções até a Etapa 11), `library_page.dart` (reescrita), `entry_actions.dart` (`GameMenuButton`), `status_chip.dart` (`StatusChip.mixed`), `game_card.dart` (selo `badge`). `GameEntry` e a API não mudaram.

**Comportamento:** um cartão por `game.id`, com todos os `entry.id` preservados (mais novo primeiro, desempate por id). Resumo "24 jogos · 31 registros · 3 jogos em andamento" (o terceiro some em zero). "Jogando agora" (até 6, pelo registro `playing` mais recente, só com o registro em andamento) some com busca ou filtro; "Ver todos" aplica Jogando e rola até os resultados. Busca por título sem caixa nem acentos; um status e uma plataforma por vez, e o **mesmo registro** precisa satisfazer os dois (concluído/PC + jogando/PS5 não aparece em jogando/PC). Chips contam jogos distintos depois de busca e plataforma, antes do status escolhido. Ordenação sobre os registros que passaram pelos filtros, desempate por título e id do jogo; horas: soma das conhecidas, ausência por último, zero antes dela. Grade só com capa, selo de replays e menu "Ver registros / Novo registro"; lista com status ("Vários status" quando misturam), plataformas, "2 registros" ou "1 de 2 registros", horas e a nota **só** quando o jogo tem um único registro. Tocar abre o jogo em "Meu progresso" (`?tab=progress`, lido já pela `GamePage`; a Etapa 08 faz o resto das abas). Com texto ≥ 175% a lista assume sem alterar a preferência salva. Vazio total ("Sua biblioteca começa com um jogo" → `/explore`) e vazio filtrado ("Limpar filtros").

**Decisões onde o plano se contradiz:**
- Colunas: a composição pede "três capas por linha" no celular, mas a regra numérica pede duas colunas em 360 dp com cards de pelo menos 132 dp. Segui a numérica (`GameCard.columnsFor`): 2 colunas em 360/390 dp, 8 em 1200.
- "Cartão com status / Vários status": na grade só entram o selo de replays e o rótulo de acessibilidade (a grade não mostra dados fixos); o texto visível fica na lista.
- "Encontrar jogo" leva a Explorar; o FAB/botão do cabeçalho "Adicionar jogo" continua abrindo o seletor.

**Verificações:** `dart format` OK; `flutter analyze` sem problemas; `flutter test` 866 passaram, 46 pulados, 0 falhas; integração 51 passaram. Novos: 28 testes da projeção (`library_groups_test.dart`), ~25 de tela (replays, busca, plataforma, status+plataforma, "1 de 2", limpar, troca de aba, descarte ao sair da conta, prateleira, 360 dp, 200%, ordenação), 2 de volume e 3 goldens (`test/features/library/goldens/`). Os testes de status/remoção que usavam o menu da Biblioteca agora passam pela página do jogo (o registro específico), incluindo um que prova que alterar um replay não envia os outros.

**Volume (1.000 registros, 800 jogos, 200 com replay):** projeção 18 ms; grade preguiçosa (< 60 cartões construídos); rola até o fim sem exceção.

**Observações para a revisão visual:**
- Em 390 px, resumo + prateleira + filtros ocupam a maior parte da primeira tela e a grade começa perto da dobra. É a composição pedida; vale julgar num aparelho real se os chips devem encolher.
- O contorno preto grosso do botão flutuante nos goldens é artefato do renderizador de teste (aparece também com o tema padrão do Flutter).
- A página do jogo lista os registros na ordem da API, não do mais novo ao mais antigo como a Biblioteca. Fica para a Etapa 08.

**Não verificado:** a aparência e a rolagem no navegador e em aparelho.

## Etapa 06 — formulário de registro

**Arquivos:** `tracking_form_page.dart` (reescrita do corpo), `entry_actions.dart` (confirmação de exclusão), `game_page.dart` e `game_entry.dart` (vocabulário), `core/navigation/back_navigation.dart` (correção abaixo). `celebration.dart` não precisou mudar: o convite já só aparece depois da confirmação do servidor e nunca publica sozinho (cobertos por testes existentes).

**Formulário:** título "Novo registro"/"Editar registro"; cabeçalho com capa e nome do jogo; aviso "Você já tem N registros deste jogo. Este será um novo registro." Ordem: **Status** (chips com ícone e texto), **Plataforma** (chips do catálogo + "Outra" para digitar; a API continua aceitando texto livre), **Progresso** (início/fim e horas), **Sua avaliação** (nota e "Notas pessoais", com a legenda "Só você vê."). Nota: chips inteiros de 1 a 10, exibida sempre como `8/10`, e ação "Sem nota" (tocar de novo na nota escolhida também limpa); sem nota nunca vira 0. Salvar ("Salvar registro") e o erro de rede ficam numa barra fixa fora da lista, então ficam acima do teclado e nunca atrás do campo em foco; os valores digitados não são limpos em falha. Validações e regras de horas/datas inalteradas. Exclusão (menu do registro na página do jogo) identifica jogo, plataforma, status e data de criação. Vocabulário: "playthrough" saiu da interface (rotas e código mantêm o nome), incluindo "Registros da comunidade" na aba da página do jogo.

**Defeito da Etapa 03, encontrado e corrigido aqui:** `goBackOr` usava `context.pop()` quando havia pilha, e isso ignora o `PopScope`. O botão de voltar da barra descartava formulários sujos sem perguntar quando a tela tinha sido aberta por navegação normal (só o gesto de voltar do sistema perguntava; os testes da Etapa 03 só cobriam link direto). Agora `goBackOr` sempre passa por `Navigator.maybePop`. Testes de regressão com pilha para registro, publicação e edição de perfil em `navigation_test.dart`.

**Verificações:** `dart format` OK; `flutter analyze` sem problemas; `flutter test` 886 passaram, 46 pulados, 0 falhas; integração 51 passaram. Novos: estrutura e ordem dos blocos, cabeçalho, aviso de replay (0/1/3), "Outra" com validação e troca de volta ao catálogo, nota 1–10 e rótulo de acessibilidade, salvar acima do teclado simulado (600 dp) e sem cobrir o campo, erro de rede junto do botão com campos preservados, erro de campo no próprio campo, toque duplo, nota como alteração a descartar, salvar visível a 360 px e 200%, volta à Biblioteca depois de "Novo registro" com o resumo atualizado, confirmação de exclusão identificando o registro.

**Não verificado:** teclado real em aparelho (simulado por `viewInsets`) e aparência no navegador. Conferi uma captura temporária do formulário a 390 px (fora do repositório).

## Etapa 07 — Explorar com uma barra só

**Arquivos:** novo `explore/application/explore_search.dart` (escopo, consulta e pesquisas recentes); reescritos `explore_page.dart`, `game_search_view.dart` e `people_search_view.dart`; `router.dart` (parâmetro `scope`); `library_filter.dart` (`libraryIgdbIdsProvider`). Nenhuma API mudou.

**Comportamento:** uma barra "Buscar jogos ou pessoas" com as abas Jogos e Pessoas **abaixo** dela. A consulta pertence a Explorar, é a mesma nas duas abas e não vai para a URL; sobrevive à troca de aba, de destino e a abrir um resultado e voltar (junto com a aba), e é descartada ao sair da conta. As visões de resultado recebem a consulta de fora (`query`); sem ela (os seletores em modal de vincular jogo e de iniciar conversa) continuam com o campo próprio e o comportamento de antes. Debounce de 400 ms, mínimo de 2 letras, cancelamento da requisição antiga e descarte da resposta atrasada, como antes, e só a aba ativa consulta o servidor (para não gastar cota da IGDB à toa). `/explore?scope=people` abre Pessoas; valor desconhecido usa Jogos; com a página aberta o link troca de aba, e voltar a `/explore` sem escopo não tira a pessoa da aba.

**Recentes:** até 8 por escopo, em memória por conta, só depois de Enter ou de abrir/adicionar um resultado (nunca por tecla; termo de 1 letra não vale), sem duplicar (ignora caixa e acentos, o repetido sobe ao topo), com "Limpar histórico" por escopo; tocar numa recente refaz a busca. **Início:** Jogos mostra recentes, "Jogando agora" da Biblioteca (até 6) e "Encontrar conversas na Comunidade"; Pessoas mostra recentes e "Conhecer a comunidade"; sem dados, a orientação curta de antes. Sem "Em alta".

**Resultados:** jogo com capa, nome e até duas plataformas mais "+N"; o corpo abre o jogo; sem registro o botão é "Adicionar" (abre o formulário), com registro é "Na biblioteca" (abre Meu progresso). Pessoa com avatar, nome, handle, bio em até duas linhas e Seguir/Seguindo pelo `FollowStore`; tocar abre o perfil. Falta de credenciais da IGDB, falha de rede e zero resultados continuam sendo mensagens diferentes.

**Defeito latente corrigido:** o `SearchBar` do Material gera um nó de acessibilidade externo (toque e foco) sem rótulo ao lado do campo rotulado. Na versão antiga o teste de acessibilidade passava por acidente: esse nó acabava fundido ao painel da aba, que tinha o texto de ajuda como rótulo. Com o novo layout ele ficou solto, então a barra de Explorar agora está em `MergeSemantics`, que dá ao leitor de tela um único elemento. Os dois seletores em modal ainda usam o `SearchBar` sem esse ajuste (fora do alcance dos testes de diretrizes atuais).

**Verificações:** `dart format` OK; `flutter analyze` sem problemas; `flutter test` 921 passaram, 46 pulados, 0 falhas; integração 51 passaram. Novos: 35 testes em `test/features/explore/explore_test.dart` (barra única, consulta compartilhada, só a aba ativa consulta, preservação ao abrir resultado/trocar destino, escopo pela rota, debounce, resposta atrasada descartada com a requisição antiga cancelada, mensagens de erro, resultados de jogo e pessoa, recentes, início, 360 px a 200%, e o seletor em modal intacto). Capturas temporárias do início e dos resultados a 390 px conferidas (fora do repositório).

**Não verificado:** aparência e teclado no navegador/aparelho; o ajuste de `MergeSemantics` foi validado pela diretriz do Flutter, não com leitor de tela real.
