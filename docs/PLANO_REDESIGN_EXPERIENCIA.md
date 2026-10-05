# GameTracker — etapas executáveis do redesign Flutter

**Especificação fechada em 04/10/2026.** Este documento substitui a versão exploratória anterior. Pesquisa, direção visual, prioridades e escolhas de produto já estão resolvidas. O executor deve implementar as etapas na ordem abaixo, validar o resultado e registrar o andamento. Não existe uma etapa prévia de entrevistas, comparação de bibliotecas, criação de Figma ou aprovação de wireframes.

> **Instrução para o modelo executor:** implemente este documento no projeto atual. Use o código existente como base, execute as etapas em ordem, preserve as regras de domínio e atualize os checkboxes apenas após verificar os critérios de aceite. Corrija falhas introduzidas por suas alterações. Se uma ferramenta de validação estiver indisponível, registre a limitação e continue o trabalho independente dela. Não substitua implementação por um novo planejamento.

## Regras fixas para todas as etapas

- App oficial: `frontend/`, Flutter + Material 3 via `material_ui`, Riverpod, `go_router`, Dio e Socket.IO. Preservar essa stack e as versões atuais, exceto as duas dependências de imagem especificadas na etapa 04.
- Escopo: Android e web. Chrome é o ambiente principal de execução e inspeção; não exigir Android físico para desenvolver ou concluir a implementação.
- Navegação: **Biblioteca, Explorar, Comunidade, Mensagens e Perfil**, nessa ordem. Biblioteca continua sendo a tela inicial. Configurações e Notificações são destinos secundários.
- Identidade: biblioteca visual de jogos, violeta `#5D4FE3`, capas em destaque, superfícies Material e texto confortável. Temas claro, escuro e sistema.
- Vocabulário: usar **jogo**, **registro**, **novo registro** e **registros anteriores** na interface. “Playthrough” permanece apenas onde necessário no código/rotas. Nota continua **1–10**, sem conversão para estrelas de cinco pontos.
- Dados: `Game.id` é UUID interno; `igdbId` é inteiro do catálogo; `GameEntry.id` identifica cada registro. Favorito é do jogo, progresso é do registro. Replay nunca pode ser fundido ou sobrescrito ao agrupar capas.
- Preservar datas de calendário, PATCH com omitido/null/valor, zero horas, notas pessoais privadas, estados otimistas com rollback, identidade da conta e idempotência do chat.
- Todas as telas precisam de carregamento, vazio, erro recuperável, conteúdo sem imagem, título longo e fonte a 200%. Alvos de interação ≥48 dp; foco visível e acesso por teclado no web.
- Manter as APIs atuais. A única integração de conteúdo adicional deste plano é usar o endpoint existente de posts por jogo. Não adicionar recomendações, listas customizadas, wishlist, reviews, diário, ranking, edição/exclusão de posts ou push com app fechado.
- Não criar controles decorativos para recursos ausentes. Seguidores/seguindo continuam contadores sem link; notificações continuam com leitura global e limite atual do servidor; não simular recibo de leitura por mensagem.
- Testar dados mutáveis apenas no ambiente local `_test` já existente. A documentação histórica informa que o banco configurado em desenvolvimento pode ser compartilhado com produção.

**Referência funcional já estudada:** o Backloggd distingue jogos e logs, dá ferramentas para filtrar a coleção e usa favoritos/atividade para expressar identidade. Suas mudanças de setembro de 2026 reforçam busca dentro da coleção, filtros com contagem e grade/lista. As decisões acima adaptam esses princípios ao domínio atual do GameTracker. Fontes: [FAQ oficial](https://backloggd.com/about/), [changelog](https://backloggd.com/changelog/) e [perfil de exemplo](https://backloggd.com/u/diary/).

## Etapa 01 — Preparar execução e registrar a situação inicial

**Dependência:** nenhuma. **Resultado:** ambiente web utilizável e registro técnico para comparar as alterações.

**Arquivos de entrada:** `frontend/README.md`, `docs/MIGRACAO_FLUTTER.md`, `frontend/pubspec.yaml`, `frontend/test/`, `backend/package.json`.

- [x] Verificar alterações existentes no git e preservá-las. Não reiniciar o projeto nem recriar runners.
- [x] Executar `flutter pub get`, `flutter analyze` e `flutter test` em `frontend/`. Distinguir falhas preexistentes de regressões posteriores.
- [x] Usar a API de teste em `http://localhost:3100`. Em `backend/`, executar `npm run test:db:up`, `npm run test:seed` e, em processo separado, `npm run dev:test`. Preservar o `.env.test` existente; criar a partir do exemplo somente se ausente. *(feito na porta 3101; a 3100 estava ocupada pelo servidor de desenvolvimento)*
- [ ] Abrir `flutter run -d chrome --dart-define=API_URL=http://localhost:3100`. Se o ambiente não abrir Chrome automaticamente, usar `-d web-server --web-port=8080` e acessar a URL pelo navegador disponível.
- [ ] Registrar capturas das telas atuais a 390 e 1440 px, com dados sintéticos: biblioteca vazia, biblioteca com replay, pesquisa, comunidade, conversa, perfil, edição e configurações.
- [x] Criar `docs/REDESIGN_EXECUCAO.md` com etapa, estado, arquivos alterados, verificações executadas e limitações. Salvar evidências visuais em `docs/redesign/evidencias/` quando a captura estiver disponível.

**Aceite:** app abre no navegador ou o impedimento está identificado com o erro concreto; baseline de testes registrado. Ausência de aparelho, usuários para entrevista, IGDB configurada ou ferramenta de screenshots não bloqueia implementação. A busca IGDB pode ser validada com fakes nos testes; não colocar resultados fictícios no app normal.

## Etapa 02 — Implementar a fundação visual Material 3

**Dependência:** 01. **Resultado:** estilos e peças compartilhadas usados pelas telas seguintes.

**Editar:** `frontend/lib/core/design_system/app_theme.dart`, `tokens.dart`, `game_cover.dart`, `user_avatar.dart`, `status_chip.dart`, `async_content.dart`.
**Criar no mesmo diretório:** `page_container.dart`, `section_header.dart`, `game_card.dart`, `filter_toolbar.dart` e `content_skeleton.dart`. Manter cada componente pequeno e sem acesso direto à API.

- [x] Manter `ColorScheme.fromSeed(seedColor: Color(0xFF5D4FE3))` nos dois temas. Usar cores semânticas do esquema; preservar `DomainColors` para os quatro status. Não espalhar hexadecimais pelas telas.
- [x] Centralizar espaçamentos 4/8/12/16/24/32/48; raios 8 para capas, 12 para controles e 16 para cards; evitar sombra em cada item de uma lista.
- [x] Definir papéis tipográficos: título de página 28/34, seção 20/28, título de item 16/24, corpo 16/24, metadado 14/20 e rótulo auxiliar 12/16 (tamanho/altura de linha). Permitir escala do sistema; não aplicar escala fixa.
- [x] `PageContainer`: padding 16 em telas estreitas e 24 nas largas; largura máxima 680 para texto/formulários, 1200 para biblioteca/perfil. Alinhar conteúdo centralizado sem aumentar fontes conforme a janela.
- [x] `GameCard`: capa 3:4; título até duas linhas; status e quantidade de registros abaixo da capa; nenhuma informação essencial só no hover. Avatar circular com fallback de iniciais; estados de imagem quebrada sem alterar geometria.
- [x] `SectionHeader`: título, contador opcional e uma ação textual. `FilterToolbar`: pesquisa, filtros ativos, ordenação e modo de exibição com layout que quebra em linhas.
- [x] Padronizar estados: skeleton mantém proporção do conteúdo; vazio tem título, explicação e uma ação; erro preserva dados já carregados e oferece retry; snackbar para confirmação breve.
- [x] Aplicar foco/hover/pressed e semântica aos controles. Animações locais de 150–200 ms; desabilitar movimentos não essenciais quando o sistema pedir.

**Aceite:** componentes usados em pelo menos uma tela real, claros/escuros legíveis e sem overflow a 360 px e fonte 200%. Atualizar testes existentes de acessibilidade e adicionar golden somente para a fundação visual e composições críticas, sem snapshots de toda pequena alteração.

## Etapa 03 — Padronizar navegação, cabeçalhos e retorno

**Dependência:** 02.
**Editar:** `frontend/lib/app/shell.dart`, `router.dart` e cabeçalhos dos cinco destinos.

- [x] Manter `StatefulShellRoute.indexedStack`. Janela <600 dp: `NavigationBar`; ≥600: `NavigationRail`; ≥1240: rail expandido com texto.
- [x] Preservar scroll, consulta e aba interna ao trocar destino. Selecionar o destino já ativo retorna à raiz daquele destino, sem apagar busca/filtros. Não adicionar um segundo comportamento de “voltar ao topo” neste redesign.
- [x] Biblioteca, Explorar, Comunidade e Perfil usam app bar com título e sino; Perfil inclui engrenagem. Mensagens mantém cabeçalho próprio sem sobrecarregar a sala de conversa.
- [x] Ação primária por tela: Biblioteca “Adicionar jogo”; Comunidade “Publicar”; Mensagens “Nova conversa”. Em telas estreitas usar FAB estendido; em telas largas usar botão no cabeçalho. Não renderizar os dois simultaneamente.
- [x] Dar `heroTag` exclusivo a FABs que coexistem no IndexedStack e reservar padding inferior para que não cubram o último item.
- [x] Preservar rotas atuais. Subtelas abertas por link sem pilha devem voltar para um destino útil: jogo → Biblioteca; post → Comunidade; edição/configurações → Perfil; conversa → Mensagens.
- [x] Manter autenticação e destino após login. No web, recarregar ainda requer novo login pela política atual de sessão em memória; depois do login restaurar a rota, sem alegar persistência de sessão.
- [x] Tratar nomes/IDs inválidos com erro e saída útil, nunca tela em branco. Rascunhos de formulário pedem confirmação apenas quando há alteração não salva.

**Aceite:** abrir jogo/post/conversa diretamente, autenticar e retornar; trocar entre os cinco destinos sem perder contexto; redimensionar janela sem perder a área selecionada. Verificar `app_shell_test.dart` e testes de redirecionamento.

## Etapa 04 — Entregar crop de avatar e banner

**Dependência:** 02. Executar antes do restante do redesign de Perfil.
**Editar:** `frontend/pubspec.yaml`, `frontend/lib/features/profiles/application/profile_image_picker.dart`, `profile_editor.dart`, `presentation/edit_profile_page.dart`.
**Criar:** `application/profile_image_processor.dart` e `presentation/profile_image_crop_page.dart` dentro da mesma feature.

**Escolha encerrada:** usar `crop_your_image: ^2.0.1` para recorte e `image: ^4.10.1` para orientação/redimensionamento/codificação, com versões resolvidas no lockfile. O pacote de crop recebe bytes e permite proporção fixa, interação e máscara circular; a leitura continua no `image_picker` existente. A API documentada usa `CropController.crop()` e entrega bytes pelo callback `onCropped`; não usar `cropCircle()` para avatar. Fontes: [crop_your_image](https://pub.dev/packages/crop_your_image), [API do controller](https://pub.dev/documentation/crop_your_image/latest/crop_your_image/CropController-class.html) e [image](https://pub.dev/packages/image). A resolução/compilação da dependência será verificada na execução; a pesquisa não equivale a um build já realizado.

- [x] Criar o fluxo **selecionar → preparar → recortar → confirmar envio → upload → sucesso**. Picker ou editor cancelados retornam sem requisição e sem mudar a foto salva.
- [x] Avatar: proporção 1:1, máscara circular de visualização, exportação quadrada 400×400. Banner: proporção 3:1, exportação 1500×500. Título “Ajustar foto”/“Ajustar capa”; ações “Cancelar”, “Restaurar” e **“Salvar foto”/“Salvar capa”**.
- [ ] Editor em tela cheia <600 dp; dialog com largura máxima 720 em telas maiores. Pinça/arrasto no telefone; arrasto/roda no web. Disponibilizar controles acessíveis de enquadramento: mover nas quatro direções e ampliar/reduzir a área, atualizando o retângulo pelo controller e respeitando os limites da imagem.
- [x] Mostrar prévia circular para avatar e prévia de banner com a posição aproximada do avatar sobreposto. Não rasterizar a máscara nem o avatar sobre o arquivo exportado.
- [x] Decodificar o arquivo, aplicar orientação antes da prévia e limitar o lado maior preparado a 2048 px. `image.bakeOrientation` fornece a normalização EXIF ([API oficial](https://pub.dev/documentation/image/latest/image/bakeOrientation.html)).
- [x] Suportar JPEG, PNG e WebP; para GIF usar o primeiro frame e comunicar que a foto será estática. Se o picker converter HEIC para formato suportado, prosseguir; HEIC não decodificável deve mostrar “Use uma imagem JPG, PNG ou WebP”. Não prometer suporte universal a HEIC nem enviar um arquivo que não teve preview.
- [x] Manter limite de entrada de 8 MiB e validar dimensões antes da decodificação completa: máximo 24 milhões de pixels. Recusar arquivos acima do limite com orientação para reduzir a imagem. O teto reduz o risco de travar o editor no web; não presumir que `imageQuality` do picker seja aplicado em todo navegador.
- [x] Exportar JPEG qualidade 85, fundo branco para transparência e sem metadados EXIF. Verificar tamanho final ≤8 MiB e MIME/nome coerentes. Fotos pequenas podem ser ampliadas para o tamanho final, com aviso discreto de baixa resolução; nunca impedir recorte só por tamanho pequeno.
- [x] Manter os endpoints existentes, que validam e redimensionam novamente. Guardar os bytes recortados durante falha de upload; retry reenvia os mesmos bytes. Desabilitar confirmação dupla e refletir progresso.
- [x] Após sucesso, atualizar URL da sessão/perfil e providers dependentes. As URLs novas são únicas no backend; usar a URL retornada e invalidar dados antigos, sem query string aleatória de cache.
- [x] Na edição, separar seção “Fotos — salvas ao confirmar o recorte” de “Informações — salvas no botão Salvar alterações”. Sair depois de upload concluído não deve sugerir que descartar texto desfaz a imagem.

**Aceite:** prévia corresponde ao enquadramento salvo; cancelar não chama upload; rosto fora do centro é reposicionável; erro conserva recorte; orientação EXIF correta; saída com dimensões/MIME exatos; imagem inválida e HEIC sem decoder recebem erro útil. Atualizar `edit_profile_test.dart` e testar bytes de saída do processor, incluindo arquivo rotacionado.

## Etapa 05 — Reestruturar Biblioteca e agrupar replays

**Dependência:** 02–03.
**Editar:** `frontend/lib/features/library/application/library_view.dart`, `library_prefs.dart`, `presentation/library_page.dart`, `entry_actions.dart`.
**Criar:** `application/library_groups.dart` com projeções de leitura; não alterar o modelo/API de `GameEntry`.

**Composição fechada:**

```text
Biblioteca                                      sino / Adicionar jogo
24 jogos · 31 registros · 3 jogos em andamento
Jogando agora                                   Ver todos
[capas dos jogos em andamento, no máximo 6]
Buscar na biblioteca
Todos | Backlog | Jogando | Concluídos | Abandonados
Plataforma / Ordenar por / Grade–Lista / Limpar
24 jogos encontrados
[grade de jogos ou lista]
```

Grade: capas como protagonistas, sem título, plataforma, horas e nota permanentemente abaixo. Apenas um indicador discreto quando houver vários registros do mesmo jogo. Tocar na capa abre o jogo.
Lista: capa pequena, título, status, plataforma, horas, nota e acesso aos registros. É a visualização para consultar informações.
Acima dos resultados: busca, filtros, ordenação e alternância entre grade/lista. Essas ferramentas não ocupam espaço nos cartões.
No celular: começar com três capas por linha, ajustando pela largura disponível. No desktop, aumentar as colunas mantendo uma largura confortável.

- [ ] Agrupar por `game.id`, preservando todos os `entry.id`. Ordenar os registros de cada grupo por `createdAt` decrescente e ID como desempate.
- [ ] Resumo geral usa jogos únicos, total de registros e jogos com pelo menos um registro `playing`. Nunca inferir quantidade de jogos pelo `gameEntryCount` do perfil.
- [ ] Prateleira Jogando agora ordenada pelo registro `playing` mais recente de cada jogo; no máximo 6; “Ver todos” aplica filtro Jogando e leva aos resultados. Ocultar prateleira enquanto houver busca ou filtro ativo.
- [ ] Busca local por título, sem diferença de caixa ou acentos. Filtros: um status por vez e uma plataforma por vez; plataforma vem dos registros, comparada por texto normalizado. Opção “Todas as plataformas”.
- [ ] O mesmo registro precisa satisfazer status **e** plataforma. Só então agrupar os correspondentes. Exemplos: concluído/PC + jogando/PS5 não pode aparecer em jogando/PC.
- [ ] Contagens dos chips representam jogos distintos por status após busca/plataforma, antes do status selecionado. Um jogo pode participar de dois chips; a soma dos chips não é o total único.
- [ ] No cartão, se houver um status entre os registros correspondentes, mostrar esse status; se houver vários, mostrar “Vários status” com ícone neutro. Mostrar “2 registros” quando aplicável; com filtro parcial, “1 de 2 registros”.
- [ ] Sort: “Adicionados recentemente” = maior `createdAt` do grupo; “Adicionados há mais tempo” = menor; “Mais horas registradas” = soma de horas conhecidas dos registros; “Nome A–Z” = nome normalizado. No sort de horas, grupos sem horas vêm por último; zero vem antes de ausência. Calcular chaves sobre os registros correspondentes aos filtros; desempate por título e `game.id`.
- [ ] Grid e sort continuam persistidos nas chaves existentes. Busca/status/plataforma ficam em memória por conta e sobrevivem à troca de aba, sendo descartados no logout.
- [ ] Grade: duas colunas em 360 dp, crescendo pela largura disponível com cards de pelo menos 132 dp e espaçamento 12; medir conteúdo após rail/padding. Com texto a 200%, usar lista automaticamente se a grade ficar ilegível, sem sobrescrever a preferência salva.
- [ ] Tocar no card abre o jogo em “Meu progresso”. Menu: “Ver registros” e “Novo registro”. Edição/exclusão ocorre no registro específico, nunca implicitamente no mais recente.
- [ ] Lista mostra capa pequena, título, plataformas, status, número de registros e horas conhecidas. Não calcular média de notas nem atribuir a nota de um replay a todo o jogo.
- [ ] Vazio total: “Sua biblioteca começa com um jogo” / “Encontrar jogo”. Vazio filtrado: “Nenhum jogo com esses filtros” / “Limpar filtros”. Limpar remove busca/status/plataforma, mantendo grid e sort.

**Aceite:** testar replays com status/plataformas diferentes, busca combinada, null versus zero e contadores únicos. O backend já aceita status/igdbId/sort, mas o cliente atual carrega toda a lista; manter filtragem local completa nesta entrega, sem nova paginação remota. Validar volume com 1.000 registros sintéticos e renderização lazy.

## Etapa 06 — Melhorar formulário de registro e ações de progresso

**Dependência:** 05.
**Editar:** `frontend/lib/features/library/presentation/tracking_form_page.dart`, `entry_actions.dart` e `frontend/lib/features/feed/presentation/celebration.dart`.

- [ ] Cabeçalho com capa/título; título da página “Novo registro” ou “Editar registro”. Se já há registro do jogo, informar “Você já tem N registros deste jogo. Este será um novo registro.”
- [ ] Ordem dos campos: status, plataforma, datas, horas, nota e notas pessoais. Status em chips com ícone+texto; plataforma sugerida pelo catálogo, mantendo entrada manual que a API aceita.
- [ ] Primeiro bloco mostra status/plataforma; bloco “Progresso” reúne datas/horas; bloco “Sua avaliação” reúne nota 1–10 e anotações com legenda “Só você vê”.
- [ ] Nota com seleção inteira 1–10 e ação “Sem nota”; exibição consistente `8/10` em todas as telas. Datas/horas continuam opcionais; preservar regras de validação existentes.
- [ ] Botão de salvar acessível acima do teclado ou no fim visível do formulário, sem ocultar campo focado. Mostrar erro no campo e resumo de erro de rede sem limpar valores.
- [ ] Avisar antes de descartar alteração; exclusão identifica jogo e registro e exige confirmação. Após salvar, voltar ao contexto de origem e atualizar Biblioteca/Perfil/Jogo.
- [ ] Ao concluir, manter convite opcional para publicar somente depois da confirmação do servidor. Nunca publicar automaticamente.

**Aceite:** criar dois registros do mesmo jogo, editar um, limpar nota/data/horas, registrar zero e excluir somente um. Rodar `tracking_form_test.dart` e testes de corpo PATCH existentes.

## Etapa 07 — Unificar Pesquisa e melhorar Explorar

**Dependência:** 02–03, 05.
**Editar:** `frontend/lib/features/explore/presentation/explore_page.dart`, `frontend/lib/features/games/presentation/game_search_view.dart`, `application/game_providers.dart` e `frontend/lib/features/profiles/presentation/people_search_view.dart`.
**Criar:** estado de pesquisa em `features/explore/application/`.

- [ ] Uma barra principal “Buscar jogos ou pessoas”, seguida das abas Jogos/Pessoas. Campo e consulta pertencem a Explorar; resultados das features recebem consulta/controlador externo.
- [ ] Preservar seletores `pickGame`/`pickPerson` usados em postagem/chat: eles continuam podendo mostrar busca própria no modal. Evitar duplicar barras na página Explorar.
- [ ] Manter debounce 400 ms, mínimo 2 caracteres, cancelamento e descarte de resposta antiga. Limpar busca cancela consulta e retorna ao estado inicial.
- [ ] Guardar até 8 pesquisas recentes em memória por conta, somente após envio explícito ou abertura de resultado; deduplicar e mostrar ação “Limpar histórico”. Não gravar cada tecla nem persistir histórico após logout.
- [ ] Início em Jogos: pesquisas recentes, até 6 itens de “Jogando agora” da própria Biblioteca e CTA “Encontrar conversas na Comunidade”. Se não houver dados, orientação curta para buscar por nome. Início em Pessoas: recentes do escopo e CTA “Conhecer a comunidade”.
- [ ] Resultado de jogo: capa, nome, até duas plataformas + indicador de restantes; corpo abre jogo. Sem registro: botão “Adicionar”; com registros: “Na biblioteca”, abrindo Meu progresso. Novo replay fica no detalhe.
- [ ] Resultado de pessoa: avatar, nome, handle, bio até duas linhas, Seguir/Seguindo usando `FollowStore`; tocar na identidade abre perfil.
- [ ] Ao voltar do resultado, preservar consulta, escopo e posição. O escopo Pessoas pode ser aberto por `/explore?scope=people`; valor desconhecido usa Jogos. Não colocar consultas em URL neste redesign.
- [ ] Distinguir falta de credenciais IGDB, falha de rede e zero resultados; manter mensagens existentes de configuração. Não criar seção “Em alta” sem endpoint.

**Aceite:** uma barra por contexto; resultados atrasados não substituem busca recente; consulta preservada na troca de aba; modal de vincular jogo e modal de iniciar conversa continuam funcionando. Atualizar testes de pesquisa e Explorar.

## Etapa 08 — Tornar a página do jogo o centro da experiência

**Dependência:** 05–07.
**Editar:** `frontend/lib/features/games/presentation/game_page.dart`, `frontend/lib/features/feed/data/feed_repository.dart`, `application/post_store.dart`, `presentation/create_post_page.dart` e `frontend/lib/app/router.dart`.
**Criar:** `frontend/lib/features/games/application/game_posts_controller.dart`.

- [ ] Hero com capa, título, plataformas e gêneros, favorito e ação principal. Sem registros: “Adicionar à biblioteca”; com registros: “Novo registro” e indicação do total.
- [ ] Manter três abas: Sobre, Meu progresso e Comunidade. Aceitar `/games/:igdbId?tab=progress` e `?tab=community`; ausência/valor inválido abre Sobre. Trocas de aba atualizam a rota sem acumular um histórico por clique.
- [ ] Sobre: sinopse limitada inicialmente a seis linhas com “Ler mais”, gêneros/plataformas e screenshots existentes com viewer. Não inventar ano, nota média ou outros campos ausentes no modelo.
- [ ] Meu progresso: um card por `entry.id`, identificado por plataforma, status, data de criação e datas de jogo quando existirem. Mostrar nota/horas e menu Editar/Excluir. Anotações só na experiência própria.
- [ ] Adicionar `FeedRepository.gamePosts(String gameId, {String? cursor})` retornando `PostPage`, com GET `/games/:id/posts?limit=20&cursor=...`. Usar UUID interno, não igdbId.
- [ ] Controller de posts por jogo estende `PagedPostsController`; armazenar entidades no `PostStore` e IDs/cursor no controller. Reutilizar deduplicação, erro de rodapé e invalidação por conta.
- [ ] Comunidade: estatísticas rotuladas “Registros da comunidade”, jogadores já disponíveis e lista paginada de posts. Manter no máximo 10 jogadores por consulta e não sugerir que seja uma listagem completa.
- [ ] Botão “Publicar sobre este jogo” abre `/posts/new?igdbId=...`. O composer resolve `byIgdbId` para UUID; `entryId` válido tem precedência se ambos vierem na rota. Falha ao resolver vínculo bloqueia publicação até retry ou remoção explícita do vínculo.
- [ ] Ao publicar, inserir/invalidate a lista do jogo afetado; curtida deve atualizar feed, perfil, jogo e detalhe pela mesma entidade. Atualizar fakes que implementam `FeedRepository`.

**Aceite:** posts aparecem somente no jogo correto, paginação não duplica, novo post fica vinculado, erro no vínculo não gera post genérico silencioso e nenhum dado pessoal vaza. Adicionar teste do repository/controller e fluxo integrado com API de teste.

## Etapa 09 — Redesenhar Comunidade, posts e comentários

**Dependência:** 02–03, 08.
**Editar:** `frontend/lib/features/feed/presentation/community_page.dart`, `post_tiles.dart`, `post_list.dart`, `post_detail_page.dart` e `create_post_page.dart`.

- [ ] Geral/Seguindo permanecem cronológicos; Geral inicial. Não renomear para “Para você”.
- [ ] Feed de largura máxima 680, uma coluna. Post escrito: avatar 40, nome+handle, tempo, texto, bloco compacto do jogo com capa e linha de ações. Atividade: avatar 32, verbo/status histórico e jogo em linha compacta, mantendo acesso a curtidas/comentários.
- [ ] Reutilizar os mesmos componentes em feed/perfil/jogo/detalhe. Não agrupar várias atividades neste ciclo: a diferenciação compacta resolve densidade preservando paginação/ordem sem novo contrato.
- [ ] Manter uma única ação de publicação no FAB/cabeçalho da etapa 03. Composer: texto, contador 500, jogo/registro vinculado visível e removível, enviar desabilitado para vazio/estouro/envio em andamento.
- [ ] Estado vazio de Seguindo: “Acompanhe quem joga com você” e CTA para `/explore?scope=people`. Geral vazio: convite para primeira publicação.
- [ ] No detalhe, post original completo seguido de comentários. Limitar recuo visual a dois níveis; respostas mais profundas mostram “Respondendo a @...” sem reduzir indefinidamente a largura.
- [ ] Composer de resposta mostra pessoa/contexto e “Cancelar resposta”. Falha mantém texto; sucesso limpa e atualiza lista/contadores. Fonte a 200% deve preservar ações.
- [ ] Paginação e retry de rodapé mantêm posição e conteúdo; dados antigos continuam visíveis durante erro de revalidação.

**Aceite:** mesma curtida/reflexo em todas as superfícies; atividade usa status histórico, inclusive após mudança/deleção do registro; publicação e resposta preservadas em falha; nomes longos não cobrem menus. Rodar suíte de feed.

## Etapa 10 — Refinar Mensagens e navegação da conversa

**Dependência:** 02–03.
**Editar:** `frontend/lib/features/chat/presentation/messages_page.dart`, `chat_room_page.dart`, `message_bubble.dart`, `chat_items.dart`, `start_conversation.dart`, `application/chat_drafts.dart` e rotas necessárias.

- [ ] Lista com busca local por nome/username e chips “Todas”/“Não lidas”. Consulta/status em memória por conta. Contador representa **conversas**, pois `ConversationSummary.unread` é booleano.
- [ ] Linha: avatar, nome, até duas linhas da última mensagem, horário e ponto de não lida; prefixar envio próprio com “Você:”. Manter ordenação da lista fornecida pelo controller.
- [ ] Tornar a conversa selecionada refletida na rota `/messages/:conversationId`, inclusive no layout largo, como fonte principal de seleção. A seleção atual só em provider deve ser sincronizada/refatorada para que deep link e redimensionamento abram a mesma conversa, sem dois sockets ou salas duplicadas.
- [ ] Usar `LayoutBuilder` para espaço efetivo após rail. Com conteúdo disponível ≥760 dp, lista de 320 dp + conversa; abaixo, somente lista ou sala conforme rota. Não presumir que janela de 840 dp deixe 840 dp para a feature.
- [ ] Sala: identidade do interlocutor abre perfil; presença e digitando obedecem o socket real. Mensagens próprias usam `primaryContainer`; recebidas usam superfície. Largura máxima de bolha 560 dp ou 80% da coluna.
- [ ] Agrupar visualmente remetentes consecutivos separados por até cinco minutos; manter divisores de dia e chaves estáveis. Estado de envio visível: enviando, confirmado pelo servidor, incerto, falhou.
- [ ] Preservar retry idempotente com `clientMessageId`. “Enviada” não significa lida. Não alterar protocolo do socket nem gerar ID novo ao repetir uma tentativa incerta.
- [ ] Composer fixo com SafeArea e teclado; Enter insere linha, Ctrl/Cmd+Enter envia. Botão de envio permanece acessível. Manter rascunhos em memória por conversa; logout descarta.
- [ ] Nova mensagem não arrasta quem está lendo histórico para o fim; mostrar botão “Novas mensagens”. Se já perto do fim, acompanhar chegada.
- [ ] Vazio da lista: CTA Nova conversa. Busca sem resultado: limpar consulta. Painel sem seleção: “Escolha uma conversa”.

**Aceite:** redimensionar preserva conversa/rascunho, voltar funciona no navegador, não lidas coerentes, reconexão não duplica mensagem e histórico não salta durante leitura. Atualizar testes de chat, merge e shell.

## Etapa 11 — Reorganizar Perfil e edição textual

**Dependência:** 04–05, 09.
**Editar:** `frontend/lib/features/profiles/presentation/profile_page.dart`, `edit_profile_page.dart` e `application/profile_providers.dart`.

- [ ] Banner mantém proporção 3:1 e avatar sobreposto na borda inferior esquerda; nome/handle/bio fora da área da imagem, sobre superfície legível. Avatar 88 dp no telefone e 112 dp em conteúdo largo.
- [ ] Nome até duas linhas, handle separado e bio completa até o limite atual de 280 caracteres. Sem bio, ocultar o espaço; no próprio perfil mostrar convite discreto “Conte um pouco sobre você”.
- [ ] Ações próprias: Editar perfil e engrenagem. Terceiros: Seguir/Seguindo e Mensagem. Contadores de seguidores/seguindo são texto, sem aparência de link.
- [ ] Mostrar jogos únicos calculados da coleção e registros do perfil. Não mostrar zero enquanto carrega; não transformar erro da coleção em contagem zero.
- [ ] Destacar Favoritos (até 6 inicialmente, “Ver todos” expande a seção local) e Jogando agora (até 6, sem repetição de jogo). Usar a ordem fornecida pelos dados e não oferecer drag/reordenação que a API não salva.
- [ ] Abas fixas **Jogos, Atividade, Posts**. Jogos usa agrupamento da etapa 05, filtro de status e grade; sem busca avançada, edição inline ou coluna de notas pessoais.
- [ ] No próprio perfil, incluir “Gerenciar biblioteca” levando à aba Biblioteca. No perfil alheio, cards abrem página do jogo, sem menus de editar registros.
- [ ] Conteúdo ≥1000 dp: identidade/destaques em coluna 280 dp e abas/conteúdo no espaço restante, dentro de 1200; abaixo, fluxo vertical. Evitar scrolls verticais competindo.
- [ ] Edição textual com nome, username e bio; contador 280, validação inline e botão “Salvar alterações”. Preservar todos os valores quando username conflitar ou rede falhar; confirmação de descarte só para texto alterado.
- [ ] Manter fotos salvas separadamente conforme etapa 04. Não adicionar aba Respostas nem novos campos de conta neste ciclo.

**Aceite:** perfil próprio e alheio têm permissões/ações corretas, replays não duplicam destaques e crop aparece igual na edição/cabeçalho/feed. Testar conteúdo longo, sem imagens, coleção em erro e atualização de identidade em superfícies já abertas.

## Etapa 12 — Organizar Configurações, Notificações e telas auxiliares

**Dependência:** 02–04, 09–11.
**Editar:** `frontend/lib/features/profiles/presentation/settings_page.dart`, `frontend/lib/features/notifications/presentation/notifications_page.dart`, `notifications_bell.dart`, `frontend/lib/features/auth/presentation/` e `frontend/lib/app/theme_mode.dart`.

- [ ] Configurações limitada a 680 dp; seções nesta ordem: Aparência, Biblioteca, Notificações, Conta, Sobre.
- [ ] Aparência: três opções Sistema/Claro/Escuro com pequena amostra e seleção clara, usando o provider atual; explicar “Preferência deste aparelho”.
- [ ] Biblioteca: atalhos para modo Grade/Lista e ordenação padrão, reutilizando `libraryPrefsProvider`. Não criar preferências duplicadas que discordem da tela.
- [ ] Notificações: “Abrir central de notificações” e estado do push. Build sem adaptador: “As notificações aparecem na central com o app aberto. Avisos com o app fechado não estão disponíveis nesta versão.” Sem switch inoperante.
- [ ] Conta: nome/handle/email, Editar perfil e Sair. Se houver rascunho de chat, pedir confirmação antes de sair; caso contrário, logout direto. Preservar descarte de sessão, socket e estado da conta.
- [ ] Sobre: nome e versão real via `app_info.dart`; sem links para páginas inexistentes ou ações de exportação/exclusão sem API.
- [ ] Central: linhas consistentes com avatar, ação, contexto e tempo; não lida com indicador acessível. Manter “Marcar todas como lidas” e esclarecer no rodapé que são as últimas 50 quando a lista atingir esse limite. O contador pode incluir outras notificações; não recalculá-lo somente pelas linhas visíveis.
- [ ] Estados de destino removido: informar que o conteúdo não está mais disponível e oferecer retorno. Não adicionar paginação fictícia nem marcar item isolado se só existe leitura global.
- [ ] Aplicar tokens/layout/estados a login, cadastro, restauração de sessão e página não encontrada. Não alterar regras de autenticação nem criar onboarding obrigatório.

**Aceite:** tema muda toda a aplicação, preferências de biblioteca são as mesmas nas duas telas, logout elimina dados de usuário, push não promete suporte inexistente e notificações conservam semântica da API.

## Etapa 13 — Validar a experiência completa e encerrar

**Dependência:** 01–12. **Resultado:** implementação verificável no web, com situação Android informada separadamente.

- [ ] Inspecionar layouts em 360, 390, 600, 840 e 1440 px; temas claro/escuro; texto 100%/200%; mouse/teclado e navegação por Tab. Verificar ambos os lados dos breakpoints com conteúdo realista.
- [ ] Executar cinco percursos: buscar/adicionar jogo; criar e localizar replay; publicar no jogo e comentar; iniciar conversa pelo perfil e voltar; recortar avatar/banner, editar bio e trocar tema.
- [ ] Validar os percursos com conta vazia, muitos registros, títulos/nomes extensos e sem imagem. Simular erro de carregamento/upload, retry e reconexão; não usar produção como banco de teste.
- [ ] Atualizar testes existentes por comportamento; novos testes focam recorte, agrupamento/filtros, navegação da conversa, busca compartilhada e posts do jogo. Não remover asserções de domínio para acomodar regressões.
- [ ] Rodar em `frontend/`:
```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter test test/integration --dart-define=GT_BACKEND=http://localhost:3100
flutter build web --dart-define=API_URL=http://localhost:3100
```
- [ ] A suíte de integração acima usa a API isolada da etapa 01; ela não substitui a inspeção de widgets reais no navegador. Um teste pulado por falta de API deve ser relatado como não executado.
- [ ] Gerar `flutter build apk --debug --dart-define=API_URL=http://10.0.2.2:3100` se o Android SDK estiver disponível. Esse APK é para validação com emulador local; não usá-lo como release de produção.
- [ ] Se houver emulador, validar picker, teclado, botão voltar e scroll nele. Ausência de Android físico não bloqueia a entrega web/implementação; registrar “Android nativo não validado” se não houve execução nativa. Build sozinho não prova comportamento.
- [ ] Atualizar `docs/REDESIGN_EXECUCAO.md` com evidências, comandos/resultados, limitações reais e quais etapas foram concluídas. Acrescentar referência ao redesign na documentação do projeto.
- [ ] Entregar resumo de mudanças, testes e limitações. Nenhuma etapa deve ser marcada concluída por intenção ou apenas porque o código compila.

**Critério final:** todas as telas solicitadas seguem os mesmos componentes e regras; os cinco percursos funcionam no navegador; crop corresponde ao arquivo salvo; replays continuam separados; chat e sessão preservam seus contratos; não há ação sem implementação nem erro visual conhecido nas larguras verificadas.

O uso de Chrome/web-server e build web segue a [documentação oficial de Flutter web](https://docs.flutter.dev/platform-integration/web/building); adaptação deve considerar largura e forma de interação conforme [Flutter adaptativo](https://docs.flutter.dev/ui/adaptive-responsive). A combinação de testes de unidade, widget e integração segue a [documentação de testes](https://docs.flutter.dev/testing/overview). Esses recursos permitem executar o plano sem ter um celular Android.
