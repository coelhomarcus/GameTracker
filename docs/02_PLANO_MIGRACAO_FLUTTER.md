# GameTracker — Plano de migração do frontend para Flutter

**Data:** 03/10/2026  
**Estado:** plano de execução; implementação ainda não iniciada.  
**Base analisada:** código disponível no repositório, commit `d4f1dc8`, e documentação oficial consultada nesta data.  
**Objetivo:** substituir o frontend React Native/Expo por uma aplicação Flutter com uma nova experiência visual baseada em Material Design 3, preservando os dados e as funcionalidades da plataforma.

## 1. Direção recomendada

Construir um aplicativo Flutter novo em `flutter_app/`, por funcionalidades completas, mantendo `mobile/` como referência funcional e cliente temporariamente suportado. Reutilizar o backend Express, PostgreSQL/Drizzle, Redis, integração IGDB e protocolo Socket.IO. Fazer apenas as evoluções de backend necessárias para a nova aplicação, compatibilidade e correção de contratos.

A migração será de produto e experiência, não uma tradução de componentes React Native para widgets. Os comportamentos úteis devem permanecer; navegação, organização das telas, formulários, tipografia, cores e componentes serão redesenhados com Material 3.

Decisões propostas para orientar a execução:

| Tema | Direção |
| --- | --- |
| Frontend definitivo | Flutter/Dart; remover React Native e Expo ao concluir a transição |
| Plataformas | Android e web responsiva; iOS fora de escopo (decisão de 03/10/2026); Android como primeiro marco de distribuição |
| Backend | Manter Node/Express, Drizzle, PostgreSQL, Redis e IGDB |
| Interface | Material 3, temas claro/escuro/sistema e componentes padronizados |
| Arquitetura | Organização por funcionalidade, apresentação separada de acesso a dados |
| Estado | Riverpod; regras explícitas para cache, invalidação e atualizações otimistas |
| Navegação | `go_router`, rotas reconstruíveis por ID e estado preservado entre destinos |
| HTTP | Dio, modelos tipados e tratamento central de autenticação/erros |
| Chat | Socket.IO existente, cliente Dart e reconciliação com histórico REST |
| Push | Firebase Cloud Messaging no Flutter; adaptador Expo durante a coexistência |
| Dados existentes | Continuam no mesmo backend; não haverá recadastro nem cópia de coleções |
| Transição de sessão | Prever um novo login na atualização; migração silenciosa de tokens é opcional e depende de prova técnica |
| Estratégia de entrega | Fatias verticais, beta, substituição gradual e retirada verificável do legado |

As escolhas de bibliotecas são recomendações deste plano. A combinação exata de versões será fixada após uma prova de compatibilidade; não usar dependências flutuantes como política de produção.

## 2. Análise da plataforma atual

### 2.1. Escopo e limites da análise

Foram examinados navegação, as 16 telas do frontend, componentes e tema, modelos TypeScript, clientes HTTP, hooks de dados, sessão, upload, chat, push, rotas, schemas de validação, serviços, schema Drizzle, migrations e configuração de build/infraestrutura.

Esta análise é estática. Não foram executados fluxos em dispositivos, chamadas ao ambiente de produção, migrations ou testes de carga. Estado das lojas, credenciais de assinatura, infraestrutura ativa, qualidade visual renderizada e número de usuários precisam ser levantados na etapa 0.

Referências principais do repositório:

| Área | Evidências |
| --- | --- |
| Histórico e execução | [README](../README.md), [roadmap histórico](01_ROADMAP.md) |
| Stack e distribuição | [package.json mobile](../mobile/package.json), [app.json](../mobile/app.json), [EAS](../mobile/eas.json) |
| Navegação | [MainTabs](../mobile/src/navigation/MainTabs.tsx), [RootNavigator](../mobile/src/navigation/RootNavigator.tsx), [rotas tipadas](../mobile/src/navigation/types.ts) |
| Contratos frontend | [modelos](../mobile/src/types/models.ts), [clientes HTTP](../mobile/src/api/) |
| Experiência visual | [tema](../mobile/src/theme/), [componentes](../mobile/src/components/), [telas](../mobile/src/screens/) |
| Dados e regras | [schema Drizzle](../backend/src/db/schema.ts), [schemas de entrada](../backend/src/schemas/), [serviços](../backend/src/services/) |
| HTTP e erros | [app Express](../backend/src/app.ts), [rotas](../backend/src/routes/), [errorHandler](../backend/src/middlewares/errorHandler.ts) |
| Tempo real e push | [socket](../backend/src/socket/), [push Expo](../backend/src/lib/push.ts), [notificações](../backend/src/services/notifications.service.ts) |
| Infraestrutura | [Dockerfile](../backend/Dockerfile), [Compose de desenvolvimento](../docker-compose.dev.yml) |

### 2.2. Arquitetura encontrada

- **Frontend:** Expo 57 e React Native 0.86 declarados no manifesto; React Navigation, TanStack Query, Zustand, Axios e cliente Socket.IO. A interface também tem execução web.
- **Design:** tema escuro próprio, destaque violeta, cores de status, Manrope, JetBrains Mono e Space Grotesk. Existem tokens centralizados e componentes reutilizáveis, mas não um sistema Material.
- **Backend:** Express 5, TypeScript, Drizzle/PostgreSQL, Zod, JWT, bcrypt, uploads com Multer/Sharp e Socket.IO com Redis adapter.
- **Catálogo:** IGDB/Twitch consultados pelo backend; jogos cacheados no PostgreSQL; capas e screenshots passam pelo proxy da API.
- **Persistência local:** refresh token em Expo SecureStore no nativo; `localStorage` na web; preferência lista/grade em AsyncStorage. O cache de consultas está em memória.
- **Distribuição:** configuração EAS para desenvolvimento, preview APK e produção. Backend em Docker; o roadmap descreve Dokploy/Traefik e volume de uploads que precisa ser conferido.
- **Qualidade:** não foi encontrada suíte automatizada do projeto nem workflow de CI versionado. `backend/package.json` tem um script `test` de placeholder. O histórico registra verificações de tipagem/bundle e várias limitações de validação em aparelho.

### 2.3. Inventário funcional e destino

Todas as linhas abaixo fazem parte da paridade da primeira versão completa, exceto as observações explicitamente classificadas como extensão.

| Área / telas atuais | Comportamento existente | Destino Flutter |
| --- | --- | --- |
| `LoginScreen`, `RegisterScreen` | Login por email ou username; cadastro com nome, username, email e senha; sessão persistida | Formulários Material, autofill, validação e restauração de sessão |
| `SearchScreen` | Jogos e usuários na mesma busca; debounce de 400 ms; mínimo de 2 caracteres na UI; seguir e abrir conversa | Destino Explorar, `SearchBar` e abas Jogos/Pessoas |
| `MyGamesScreen` | Grade/lista persistida, quatro status, ordenação recentes/antigos/mais jogados, adicionar, mudar status e remover | Destino Biblioteca com grade adaptável, filtros e seleção explícita de status |
| `GameFocusScreen` | Capa, sinopse, gêneros, plataformas, screenshots, favoritos, estatísticas, jogadores, amigos, playthroughs e posts | Página de jogo com seções Sobre, Meu progresso e Comunidade |
| `TrackingFormScreen` | Criar/editar playthrough, inclusive replay; plataforma, status, datas, horas, nota e observações | Formulário Material por seções; nota inteira de 1 a 10; campos opcionais realmente removíveis |
| `FeedScreen` | Feed geral e seguindo, paginação, posts e atividades compactas, curtir e abrir detalhe | Destino Comunidade com abas Geral/Seguindo e FAB Publicar |
| `CreatePostScreen` | Texto de até 500 caracteres, vínculo opcional com jogo ou playthrough, texto inicial de celebração | Composição Material com seletor de jogo e preservação do rascunho em falhas |
| `PostDetailScreen` | Post, comentários, respostas aninhadas, curtir comentário e responder a um alvo | Thread legível, recuo visual limitado e composer acessível |
| `ProfileScreen`, `UserProfileScreen` | Perfil compartilhado; coleção, atividades e posts; favoritos, jogando agora, completos; seguir e mensagem | Uma experiência de perfil com capacidades determinadas pela identidade |
| `EditProfileScreen` | Nome, username editável, bio, avatar e banner | Formulário com preview de imagens, progresso e tratamento de conflito de username |
| `ConversationsScreen`, `ChatRoomScreen` | Conversas 1:1, histórico paginado, mensagens ao vivo, digitação, presença e indicador de não lida | Mensagens com estados de conexão/envio, reconexão e lista/detalhe em telas amplas |
| `NotificationsScreen` | Curtidas, comentários e seguidores; filtros; contador; marcação global de leitura | Central pelo sino, `Badge`, filtros e ação explícita de marcar todas como lidas |
| `SettingsScreen` | Sair da conta | Sair + tema e informações do aplicativo; novas preferências identificadas como melhoria |
| `GamePickerModal`, `ImageViewerModal` | Selecionar jogo e resolver seu ID; visualizar imagens a partir da selecionada | Busca em sheet/tela e galeria com índice correto, zoom e fechamento acessível |

### 2.4. Diferenças entre histórico e código que afetam o escopo

1. A busca de pessoas já está em `SearchScreen`; não há `FindUsersScreen` na base atual.
2. O perfil atual tem **Coleção, Atividades e Posts**. A aba Respostas citada no roadmap não está na UI, embora `GET /users/:id/comments` continue no backend. Mantê-la disponível como contrato; reintroduzir a aba é extensão, não requisito de paridade.
3. Notificações são uma rota da pilha. As cinco entradas inferiores atuais são Feed, Busca, Jogos, Chat e Perfil. Perfil intercepta o toque e abre outra rota, sem ser uma aba selecionada de verdade.
4. O tema atual já evoluiu além do preto puro e da paleta do X descritos em fases antigas.
5. O código atual gera atividade também ao abandonar um jogo; a descrição antiga que excluía `dropped` não representa a implementação atual.
6. Configurações hoje oferece apenas logout. Recuperação de senha, login social, bloqueio, denúncia, anexos de chat e edição/exclusão de posts não devem ser apresentados como recursos já existentes.
7. `review` e `imageUrl` existem no contrato de posts, mas o composer atual não oferece um fluxo dedicado de review ou upload de imagem. Renderizar dados existentes; novas interfaces de criação ficam para evolução posterior.

### 2.5. Pontos de atenção encontrados

| Achado | Impacto na migração | Tratamento proposto |
| --- | --- | --- |
| Push depende de `users.expoPushToken` e `expo-server-sdk` | Token FCM não funciona no caminho atual | Novo registro por instalação e adaptadores FCM/Expo |
| Edição omite campos esvaziados; schemas PATCH não definem remoção por `null` | Limpar datas, horas ou nota pode não limpar o valor salvo; `z.coerce.date()` requer atenção com `null` | Contrato explícito omitido/manter, `null`/limpar, valor/substituir |
| Bootstrap descarta token em qualquer erro | Falha temporária de rede pode forçar logout | Separar sessão inválida de indisponibilidade e permitir tentar novamente |
| Cache global não é explicitamente limpo no logout | Risco de dados de uma conta aparecerem na seguinte | Escopo de dados por sessão e descarte completo na troca de conta |
| Chat entra na sala ao montar, sem procedimento completo de reentrada/reconciliação | Mensagens podem deixar de chegar após reconexão | Reautenticar, aguardar ACK de join e reconciliar histórico |
| ACK de envio não alimenta a lista atual; texto é limpo antes da confirmação | Timeout/erro pode parecer perda de mensagem | Estados pendente/enviado/incerto/falhou e rascunho recuperável |
| Presença é contada por processo e só há eventos de transição | Não há snapshot confiável ao abrir a conversa; Redis adapter não resolve o contador local | Snapshot autorizado para uma instância; armazenamento compartilhado antes de escalar |
| Lista de conversas não recebe eventos de uma sala pessoal | Badge global não pode depender apenas de mensagens da conversa aberta | Refetch no retorno/push e polling limitado; evento por usuário como melhoria de backend |
| Curtir/seguir evita duplicar relação, mas ainda pode gerar nova notificação em repetição | Repetir mutações automaticamente causa efeitos colaterais | Não aplicar retry genérico a mutações; notificar só quando houver inserção |
| Coleções, favoritos, comentários e conversas não são paginados | Apenas usar widgets lazy não reduz o volume transferido | Medir em fixtures grandes; paginação de backend se o orçamento for excedido |
| Notificações retorna as últimas 50, contador global e `read-all` global | Contador e lista podem abranger conjuntos diferentes | Expor a semântica corretamente; leitura por item/cursor é evolução |
| Estatísticas de jogo e `gameEntryCount` contam playthroughs | Replay não equivale a outra pessoa ou jogo único | Rótulos precisos; contagem distinta exige mudança de contrato |
| “Completos recentemente” usa lista ordenada por criação do registro | Não representa necessariamente a data de conclusão | Renomear inicialmente para “Concluídos”; criar ordenação por término se desejada |
| Roadmap informa banco compartilhado entre dev e produção | Testes/migrations podem atingir dados reais | Ambientes isolados antes de testes integrados; não assumir `.env` descartável |

Esses achados são inferências sustentadas pelo código, não falhas reproduzidas em produção nesta análise.

## 3. Escopo da nova aplicação

### 3.1. Obrigatório na migração

- Preservar autenticação, contas existentes, jogos, replays, favoritos, posts, comentários, relações sociais e histórico de chat.
- Entregar todos os fluxos ativos do inventário, com tratamento de carregamento, vazio, erro, retry e ausência de conexão.
- Reorganizar navegação e telas; manter acessíveis as capacidades existentes.
- Implantar Material 3, temas claro/escuro/sistema, português do Brasil e acessibilidade desde os componentes básicos.
- Manter Android e web como alvos verificados (iOS fora de escopo). A web já é utilizada para teste; sua promoção a canal público depende do endurecimento de sessão descrito adiante.
- Substituir notificações remotas Expo por FCM no novo cliente.
- Produzir builds reproduzíveis, testes de contratos e uma estratégia de substituição/retorno.

### 3.2. Melhorias que acompanham a migração

- Biblioteca como entrada principal, perfil como destino real e experiência adaptada à largura disponível.
- Seleção direta de status, evitando o ciclo automático `completed → dropped`.
- Preservação de formulários em falhas, remoção efetiva de campos opcionais e consistência entre cache de biblioteca/perfil/jogo/feed.
- Histórico de chat recuperável, mensagens sem duplicação por evento/ACK e estado de envio compreensível.
- Datas sem mudança acidental de dia por fuso, horas com vírgula decimal e notas claramente em escala de 10.
- Preferência de tema e identidade visual coerente em todas as telas.

### 3.3. Fora da primeira entrega

Clientes iOS, nativos Windows/macOS/Linux, sincronização offline de escritas, grupos de chat, áudio/vídeo, anexos de mensagens, recomendações algorítmicas, gamificação, importação Steam/PSN/Xbox, pagamentos, autenticação social e reescrita do backend. Recuperação de senha, moderação e exclusão de conta devem ter planejamento próprio caso a expansão pública exija esses fluxos; não inventar endpoints durante a implementação do frontend.

## 4. Nova experiência com Material Design 3

### 4.1. Conceito visual

**Uma biblioteca pessoal de jogos com comunidade ao redor.** As capas dão personalidade; o restante da interface usa superfícies, tipografia, navegação e estados Material consistentes.

O Material 3 será a base de componentes e comportamento. A documentação atual do Flutter já apresenta a biblioteca oficial `material_ui` separada do framework; o guia descreve a adoção a partir do Flutter 3.47. Validar essa combinação no bootstrap e registrar SDK, dependências e eventuais bridges de compatibilidade, em vez de copiar imports de tutoriais antigos. Fontes: [catálogo Material](https://docs.flutter.dev/ui/widgets/material), [guia da separação de bibliotecas](https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui).

### 4.2. Sistema de design

| Fundação | Especificação proposta |
| --- | --- |
| Cores | `ColorScheme.fromSeed` claro/escuro; experimentar violeta como identidade inicial, sem obrigatoriedade de preservar o hex atual |
| Superfícies | Papéis `surface`, containers e `onSurface`; diferenciação por hierarquia e elevação, não por bordas em todo bloco |
| Cores de domínio | Extensão de tema para backlog, jogando, concluído, abandonado, nota e curtida; texto/ícone acompanhando a cor |
| Tipografia | Escala `TextTheme`; uma família principal na primeira versão; avaliar Manrope como personalização após validar legibilidade |
| Espaçamento | Tokens de 4, 8, 12, 16, 24 e 32 unidades lógicas; margens compactas de 16 e amplas de 24 |
| Formas | Formas padrão dos componentes; personalização central por tema, sem raios inventados em cada tela |
| Ícones | Uma família Material; preenchido/contorno para seleção; tooltip e rótulo semântico em ações sem texto |
| Capas | Proporção de apresentação uniforme, fallback, limite de resolução decodificada e placeholder sem salto de layout |
| Movimento | Transições curtas e funcionais; respeitar redução de movimento; animações sem bloquear resposta ao toque |
| Feedback | Estados de foco, hover, toque, seleção, desabilitado, carregando e erro documentados |

O esquema gerado é ponto de partida; contraste de cores personalizadas, imagens e estados deve ser medido. A API de geração de esquema integra a orientação Material do Flutter. [Referência de cores Material 3](https://docs.flutter.dev/release/breaking-changes/material-3-migration).

Criar um catálogo interno de componentes em modo desenvolvimento, com os dois temas, textos longos, ausência de imagens, dados incompletos e diferentes escalas de texto. Começar com widgets Material e encapsular apenas padrões de produto recorrentes.

| Padrão do produto | Base Material / Flutter | Regra de uso |
| --- | --- | --- |
| Estrutura de página | `Scaffold`, `AppBar`, `SliverAppBar`, `SafeArea` | Um padrão de header por hierarquia; ações consistentes |
| Destinos principais | `NavigationBar` / `NavigationRail` | Mesmos destinos em qualquer largura |
| Abas de conteúdo | `TabBar` | Geral/Seguindo, Jogos/Pessoas e seções do perfil |
| Busca | `SearchBar`, `SearchAnchor` | Debounce e submissão por teclado; erro distinto de lista vazia |
| Ação principal | `FilledButton`, `FloatingActionButton.extended` | Uma ação predominante por contexto |
| Ação secundária | `FilledButton.tonal`, `OutlinedButton`, `TextButton`, `IconButton` | Hierarquia por intenção, sem estilos locais divergentes |
| Filtro / seleção | `FilterChip`, `ChoiceChip`, `SegmentedButton` | Status em chips; lista/grade em seletor; ordenação em menu |
| Formulários | `Form`, `TextFormField`, `DropdownMenu`, date picker, `Slider` | Rótulo persistente, ajuda, erro e teclado adequados |
| Cards e linhas | `Card`, `ListTile`, `Divider` | Cards para objetos; linhas para listas densas |
| Diálogos e seleção | `AlertDialog`, modal bottom sheet | Confirmação de exclusão; seletores adequados à largura |
| Feedback | `SnackBar`, `Badge`, progress indicators | Mensagem acionável; sucesso não interrompe fluxo |
| Galeria | `PageView`, `InteractiveViewer` | Abrir a imagem tocada; zoom e teclado; preservar proporção |

O catálogo oficial reúne os componentes Material usados como base; a composição e as regras da tabela são decisões específicas do GameTracker. [Biblioteca oficial](https://pub.dev/packages/material_ui).

Componentes de produto previstos: `GameCover`, `GameCard`, `PlaythroughTile`, `StatusChip`, `RatingField`, `UserAvatar`, `PostTile`, `ActivityTile`, `CommentThread`, `MessageBubble`, `AsyncContent` e `GamePicker`. Evitar criar um segundo framework de botões, diálogos ou navegação sobre o Material.

### 4.3. Arquitetura de informação e navegação

Destinos permanentes propostos, nesta ordem:

1. **Biblioteca:** jogos do usuário; destino inicial após autenticação.
2. **Explorar:** busca de jogos e pessoas.
3. **Comunidade:** feed Geral e Seguindo.
4. **Mensagens:** conversas e seus indicadores.
5. **Perfil:** identidade e coleção pública do próprio usuário.

Notificações fica no sino do app bar, com badge; Configurações parte do perfil. O perfil próprio deve ser selecionável e permanecer dentro da estrutura principal. Ao abrir o próprio autor em um post, resolver para a experiência canônica do usuário autenticado.

Não chamar o feed geral de recomendação personalizada: o backend entrega posts cronológicos, sem algoritmo de recomendação. A mudança de nome para **Geral** deixa isso claro.

Rotas propostas:

| Rota | Conteúdo / comportamento |
| --- | --- |
| `/login`, `/register` | Públicas; redirect ao destino solicitado depois de autenticar |
| `/library`, `/explore`, `/community`, `/messages`, `/me` | Cinco destinos com histórico e rolagem preservados |
| `/games/:igdbId` | Detalhe reconstruído pelo identificador IGDB |
| `/games/:igdbId/playthroughs/new` | Criação; consultar os dados do jogo na entrada |
| `/games/:igdbId/playthroughs/:entryId/edit` | Edição; resolver pelo endpoint de coleção filtrada e verificar existência/posse |
| `/posts/new`, `/posts/:postId` | Composição e detalhe; contexto opcional não substitui recuperação por ID |
| `/users/:userId` | Perfil de terceiros ou redirecionamento ao próprio |
| `/messages/:conversationId` | Resolver participantes pela lista de conversas; nunca depender só de nome/avatar passados na navegação |
| `/notifications`, `/me/edit`, `/settings` | Rotas secundárias |

Os caminhos são uma proposta de contrato de navegação, não rotas já existentes. Deep links devem sobreviver a recarregamento da página, sessão ainda não hidratada e entrada a partir de push. Destinos inexistentes ou não autorizados mostram uma saída útil. Não incluir tokens em URL.

### 4.4. Telas redesenhadas

- **Biblioteca:** título e resumo da coleção; filtros por status; ordenação em menu; grade/lista; FAB “Adicionar jogo”. Menu do registro oferece “Alterar status”, “Editar” e “Remover”. “Novo playthrough” é distinto de editar o registro anterior.
- **Explorar:** busca no topo, Jogos/Pessoas, resultados com informação essencial. Selecionar um jogo abre sua página; ação secundária permite adicionar. Não criar uma home de “tendências” sem fonte de dados.
- **Jogo:** capa, nome, plataformas, favoritar e CTA de progresso; seções para informações/screenshots, registros pessoais e comunidade. Carregar seções independentes sem bloquear a página inteira por falha de uma delas.
- **Registro de jogo:** identificação, status, plataforma, período, horas, nota e notas pessoais. Nota com valor numérico e seletor discreto 1–10, além de “Sem nota”. Suportar vírgula e ponto nas horas. Datas limpas devem continuar vazias ao reabrir.
- **Comunidade:** feed com linhas de post e atividades compactas; sem header com blur obrigatório. Curtidas refletem imediatamente com rollback em erro. A atividade automática e uma publicação voluntária de celebração são conteúdos distintos.
- **Post/thread:** preservar a árvore de respostas, limitando o recuo visual para o texto continuar legível. “Ver respostas” pode abrir contexto próprio em threads profundas. Nunca cortar comentários do modelo por limitação visual.
- **Perfil:** banner/avatar, nome, username, bio e contadores; Coleção/Atividades/Posts. Coleção mostra favoritos e seções de progresso, seguidas da grade filtrável. Dono edita; visitante segue/conversa. Não tornar contadores links sem tela/API correspondentes.
- **Editar perfil:** imagens com preview e upload explícito. Como os endpoints atuais salvam imagens imediatamente, explicar esse comportamento e manter sucesso/erro por imagem; “Cancelar” os textos não promete desfazer um upload já concluído. Salvamento atômico completo é mudança futura de backend.
- **Mensagens:** lista com última mensagem e não lida; sala com agrupamento por autor/tempo, separadores de dia, composer acima do teclado e indicação de conexão. Em falha, preservar texto e oferecer ação segura.
- **Notificações:** manter filtros Tudo/Interações/Seguidores e distinguir não lidas; propor “Marcar todas como lidas” explícito, coerente com o endpoint global. Mensagens de chat continuam separadas dessas três categorias.
- **Configurações:** tema sistema/claro/escuro, versão e sair. Preferência de tema é local; não anunciar configuração de push no servidor sem implementá-la.

### 4.5. Responsividade e acessibilidade

Breakpoints propostos em largura lógica, sujeitos a validação com conteúdo real:

| Largura | Composição |
| --- | --- |
| Menor que 600 | `NavigationBar`, coluna única, formulários e seletores adequados a teclado |
| 600–839 | `NavigationRail`, maior área de conteúdo; grade calculada por largura mínima de capa |
| A partir de 840 | Rail expandido quando couber; lista/detalhe para mensagens; conteúdo textual com largura limitada |

Definir grade pela largura do container, não por quatro colunas fixas. Proposta inicial: capa de 100–140 unidades lógicas conforme contexto, com fallback em telas muito estreitas e escala de texto alta. Feed/formulários têm largura máxima aproximada de 680; biblioteca pode ocupar área maior. Validar redimensionamento sem perder seleção, rascunho ou posição de leitura.

O Flutter recomenda adaptar ao espaço disponível, preservar estado e considerar diferentes formas de entrada. Os valores acima são escolhas do projeto. [Design adaptável](https://docs.flutter.dev/ui/adaptive-responsive/best-practices).

Critérios de produto: alvos de toque de pelo menos 48 unidades lógicas, texto até 200% sem ações inacessíveis, foco visível, navegação por teclado, TalkBack, labels de imagens e ações, status acompanhado de texto/ícone e contraste medido nos dois temas. Respeitar safe areas, teclado, gesto de voltar e convenções do sistema; não travar orientação sem necessidade demonstrada. [Adaptações de plataforma](https://docs.flutter.dev/ui/adaptive-responsive/platform-adaptations).

## 5. Arquitetura Flutter proposta

### 5.1. Estrutura

```text
flutter_app/
  lib/
    app/                 # bootstrap, router, configuração e composição
    core/
      network/           # HTTP, refresh, erros e conectividade observada
      storage/           # credenciais e preferências por plataforma
      realtime/          # transporte Socket.IO e ciclo de conexão
      notifications/     # registro push e resolução de destino
      design_system/     # temas, tokens e padrões compartilhados
    features/
      auth/
      games/
      library/
      feed/
      profiles/
      chat/
      notifications/
      settings/
        data/            # API, DTOs e implementações de repository
        domain/          # modelos/regras quando necessários
        presentation/    # páginas, widgets e controllers
    l10n/                # textos pt-BR e recursos de localização
  test/
  integration_test/
  assets/
  android/
  web/
```

O padrão `data/domain/presentation` vale para cada funcionalidade que dele precisar; a árvore o ilustra sob `settings/`. Não criar camadas vazias ou um use case por requisição simples.

Fluxo de responsabilidade: **widget → controller → repository → serviço HTTP/socket/storage**. Widgets compõem interface; controllers coordenam estado e ações; repositories encapsulam acesso e consistência dos dados. Modelos imutáveis e dependências substituíveis facilitam testes com fakes. Essa separação acompanha as [recomendações de arquitetura do Flutter](https://docs.flutter.dev/app-architecture/recommendations); Riverpod e a organização por funcionalidade são escolhas deste plano.

### 5.2. Dependências

| Responsabilidade atual | Escolha Flutter proposta | Observação |
| --- | --- | --- |
| React Native / Expo | Flutter stable + Dart correspondente | Fixar versão do SDK e lockfile |
| UI própria | Biblioteca Material oficial compatível com o SDK | Validar `material_ui`, localização e plugins no bootstrap |
| React Navigation | [`go_router`](https://pub.dev/packages/go_router) | Shell com estado por destino, guards e deep links |
| Zustand + coordenação de queries | [`flutter_riverpod`](https://pub.dev/packages/flutter_riverpod) | Providers/controllers; cache não é reprodução automática do TanStack Query |
| Axios | [`dio`](https://pub.dev/packages/dio) | Interceptors, timeout, cancelamento e multipart |
| Interfaces TypeScript | Modelos Dart imutáveis + serialização gerada quando útil | Não compartilhar interfaces TS diretamente; documentar JSON |
| SecureStore | [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage) no nativo | Isolar implementação web; nenhuma garantia automática de leitura dos dados Expo |
| AsyncStorage | [`shared_preferences`](https://pub.dev/packages/shared_preferences) | Tema e modo de exibição; não guardar segredos |
| `socket.io-client` | [`socket_io_client`](https://pub.dev/packages/socket_io_client) | Validar matriz contra servidor 4.8.x; não substituir por WebSocket puro |
| Image picker | [`image_picker`](https://pub.dev/packages/image_picker) | Arquivos/bytes por plataforma, MIME e recuperação após interrupção |
| `expo-notifications` | `firebase_core` + `firebase_messaging` | Configuração nativa/web; backend envia por FCM |
| Fontes Expo | Assets de fontes ou tipografia padrão | Sem dependência de download de fonte em runtime |
| Calendário/diálogos próprios | Componentes Material | Localização e acessibilidade comuns |
| Imagens | Widget compartilhado sobre APIs Flutter | Cache em memória inicialmente; cache persistente só após medir necessidade |

Validar versões, licenças, manutenção, plataformas e compatibilidade Material em uma única matriz da etapa 0. Adicionar bibliotecas de geração, notificações locais ou diagnóstico apenas quando houver necessidade concreta e teste no conjunto escolhido.

### 5.3. Estado, cache e erros

- **Sessão:** estados iniciando, autenticado, não autenticado e restauração indisponível. Não tratar qualquer falha como credencial expirada.
- **Estado remoto:** providers parametrizados por usuário, ID, filtro e cursor. Descarta-se todo estado sensível ao encerrar a sessão.
- **Estado local:** texto digitado, seleção, foco, galeria e scroll ficam próximos da tela; preferências de tema/grade são persistidas.
- **Paginação:** `items + nextCursor`, cursor opaco, uma carga de próxima página por vez, deduplicação por ID e erro de rodapé recuperável.
- **Cache inicial proposto:** 30 segundos para dados sociais, alguns minutos para metadados de jogo; revalidar ao retornar ao app. Definir esses tempos no repository, sem pressupor comportamento automático do Riverpod.
- **Otimismo:** curtir, seguir e favoritar podem ter resposta imediata com snapshot/rollback e serialização por entidade. Criar post, registro e mensagem exige confirmação/reconciliação; não repetir silenciosamente.
- **Sem conexão:** mostrar dados já disponíveis com indicação de desatualização; guardar rascunho da sessão; desabilitar/rejeitar escritas com explicação. Persistência offline completa fica fora desta fase.
- **Erros:** mapear `error.code/message`, HTTP 400/401/403/404/409/429/5xx, timeouts e JSON inválido para estados de domínio. O rate limiter pode não usar o envelope padrão; o parser deve ter fallback.

Matriz mínima de consistência:

| Mutação | Atualizar / invalidar |
| --- | --- |
| Criar/editar/remover playthrough | Biblioteca, registros do jogo, coleção do perfil, contadores, estatísticas/jogadores e atividades |
| Concluir jogo | Mesmas consultas; oferecer publicação voluntária somente após sucesso |
| Curtir post | Detalhe, ambos os feeds, posts do perfil e posts do jogo |
| Comentar/responder | Thread, contador do post e todas as listas que exibem esse post |
| Curtir comentário | Entidade correspondente na árvore, mantendo expansão |
| Seguir/deixar de seguir | Perfil, resultados de pessoas, contadores e feed Seguindo |
| Favoritar | Detalhe do jogo e favoritos do perfil |
| Editar perfil / imagem | Sessão e representações visíveis do autor, perfil, busca e conversa |
| Mensagem / leitura | Histórico e lista de conversas, última mensagem e badge |

A criação automática de atividade é assíncrona e best-effort no backend: invalidar o feed imediatamente pode anteceder a inserção. Prever revalidação ao foco ou evento posterior; nunca sintetizar um post permanente no cliente nem prometer atomicidade inexistente.

## 6. Contratos de backend e integração

### 6.1. Inventário HTTP

Prefixo `/api`, salvo `/uploads`. Rotas de negócio exigem Bearer JWT, inclusive os perfis chamados de públicos. “Público” significa visível a outros usuários autenticados, não acesso anônimo.

| Domínio | Rotas existentes | Particularidades |
| --- | --- | --- |
| Saúde | `GET /health` | Disponibilidade básica |
| Auth | `POST /auth/register`, `/login`, `/refresh`, `/logout`; `GET /auth/me` | Login usa `identifier`; refresh rotaciona o token; login/cadastro têm limite de tentativas |
| Catálogo | `GET /games/search?q=`, `/games/igdb/:igdbId`, `/games/:id` | Busca retorna ID IGDB; detalhe resolve UUID interno |
| Jogo social | `GET /games/:id/stats`, `/players?status=&scope=&limit=`, `/posts?cursor=&limit=` | Estatísticas por registro; jogadores com limite, posts paginados |
| Favoritos | `POST`/`DELETE /games/:id/favorite`; `GET /users/:id/favorites` | Favorito pertence ao jogo, independente de playthrough |
| Biblioteca | `POST /game-entries`; `GET /game-entries/me?status=&igdbId=&sort=`; `PATCH`/`DELETE /game-entries/:id` | Lista sem paginação; replay permitido; apenas dono altera |
| Feed | `GET /feed?scope=general|following&cursor=&limit=` | Default do servidor é `following`; cliente deve enviar escopo explicitamente |
| Posts | `POST /posts`; `GET /posts/:id`; `POST`/`DELETE /posts/:id/like` | Vínculo opcional com jogo/registro; sem rotas de editar/apagar post |
| Comentários | `GET`/`POST /posts/:id/comments`; `POST`/`DELETE /comments/:id/like` | Árvore inteira; `parentCommentId` na criação de resposta |
| Pessoas | `GET /users/search?q=`; `GET /users/:id`; `POST`/`DELETE /users/:id/follow` | Busca exclui próprio usuário e tem limite 20 |
| Conteúdo de perfil | `GET /users/:id/posts?type=activity|post&cursor=`; `/comments?cursor=`; `/game-entries?status=` | Comentários do perfil seguem no backend; ordenação pública não expõe todo o comportamento da coleção própria |
| Editar perfil | `PATCH /users/me`; `POST /users/me/avatar`; `POST /users/me/banner` | JSON para textos; multipart `avatar`/`banner`; operações separadas |
| Push legado | `POST /users/me/push-token` | Um token Expo por usuário; requer substituição compatível |
| Notificações | `GET /notifications`; `POST /notifications/read-all` | Últimas 50 e contador global; sem paginação/leitura individual |
| Conversas | `GET`/`POST /conversations`; `GET /conversations/:id/messages?cursor=&limit=`; `POST /conversations/:id/read` | Histórico REST; envio de mensagem exclusivamente por socket |
| Imagens | `GET /images/cover?url=`; arquivos em `/uploads/*` | Proxy valida host IGDB; URLs públicas, sem Bearer |

Produzir na execução um contrato OpenAPI ou fixtures JSON versionadas com requisições, respostas, nullability, erros e exemplos. A matriz acima resume; schemas e serviços atuais são a autoridade até que o contrato seja validado por testes.

### 6.2. Regras de domínio que precisam sobreviver

1. **Identificadores distintos:** `igdbId` é inteiro; `game.id`, `entry.id`, `user.id` e demais IDs internos são UUIDs. Favoritar/vincular post usa UUID de jogo; criar registro usa ID IGDB.
2. **Replay:** vários registros do mesmo jogo podem existir para um usuário, inclusive na mesma plataforma. Chave de uma coleção de registros é `entry.id`, não `gameId`.
3. **Status:** `backlog`, `playing`, `completed`, `dropped`; não trocar valores de API quando mudar rótulos.
4. **Horas:** resposta pode ser string decimal por causa de `numeric(6,1)`; entrada é número. Normalizar uma casa decimal, validar 0–99999 e regras plausíveis de período. Zero é valor válido, diferente de ausência.
5. **Nota:** inteiro 1–10 ou ausente; não converter para cinco estrelas com arredondamento nem enviar zero para “sem nota”.
6. **Datas de progresso:** são datas de calendário. Capturar o JSON real emitido pelo driver/Express e criar conversor para preservar ano/mês/dia, sem deslocamento ao aplicar fuso. `createdAt` de posts/chat é instante e pode ser convertido para horário local.
7. **Limites:** username 3–30, letras/números/underscore; nome 1–50; senha de cadastro 8–72; bio até 280; post/comentário até 500; mensagem até 2000; notas até 2000; plataforma 1–50.
8. **Posts vinculados:** se houver `gameEntryId`, backend verifica dono e deriva jogo; senão aceita `gameId` válido sem exigir registro pessoal.
9. **Atividade histórica:** renderizar `activityStatus`, não o status atual do playthrough. Excluir um registro pode deixar `gameEntry` nulo sem apagar o post.
10. **Feed Seguindo:** mostra quem o usuário segue, excluindo seus próprios posts pela relação normal; vazio quando não segue ninguém.
11. **Perfil:** nome usa fallback para username; username é editável, portanto rotas e identidade devem usar ID.
12. **Coleção pública:** é leitura; não expor botões de editar registro de terceiros.

### 6.3. Autenticação e armazenamento

No nativo, guardar refresh token no armazenamento seguro e access token em memória. Implementar refresh com uma única operação em andamento: várias respostas 401 aguardam o mesmo resultado, persistem o novo refresh token e repetem no máximo uma vez a requisição autorizada. Login/refresh não entram nesse interceptor recursivamente.

Não repetir um POST após timeout/5xx sem garantia de idempotência. O retry após 401 só é aceitável quando a autenticação rejeitou a requisição antes da execução. Logout limpa dados locais mesmo sem rede, encerra socket e descarta respostas pendentes da sessão anterior. Impedir que um refresh tardio restaure a conta depois do logout.

**Atualização do app instalado:** manter identificadores e assinatura não garante compatibilidade dos formatos de armazenamento Expo e Flutter. Plano base: pedir login uma vez; todos os dados remotos permanecem. Se continuidade de sessão se tornar requisito, criar teste de atualização real e, se necessário, uma versão intermediária do legado. Não prometer migração automática de Keychain/Keystore/AsyncStorage.

**Web:** não considerar `localStorage` um cofre. A implementação atual é descrita como conveniência de teste. Para web pública persistente, propor refresh em cookie `HttpOnly`, `Secure` e política `SameSite` apropriada, com endpoint/adaptador web, proteção CSRF quando aplicável, CORS por origem e bootstrap que obtém access token em memória. Manter o contrato JSON nativo/legado. Até essa etapa, usar sessão web em memória com novo login após recarga e registrar a limitação; web pública persistente é bloqueada até validação dessa solução.

### 6.4. Chat e ciclo de vida

Socket.IO possui protocolo próprio. O pacote Dart declara a série 3.x compatível com servidores Socket.IO 4.7.x–4.x; provar interoperabilidade com o servidor 4.8.x do projeto em Android e navegador. Usar `auth.token`, como o middleware atual exige; headers arbitrários de WebSocket não são uma alternativa portátil no navegador. [Cliente Dart e compatibilidade](https://pub.dev/packages/socket_io_client).

| Evento | Payload / resposta atual | Comportamento Flutter |
| --- | --- | --- |
| Handshake | `auth: { token }` | Obter token válido em cada conexão |
| `conversation:join` | `{ conversationId }` → `{ ok: true }` ou `{ error }` | Aguardar confirmação antes de assumir inscrição |
| `conversation:leave` | `{ conversationId }` | Remover inscrição quando necessário |
| `message:send` | `{ conversationId, content }` → `{ message }` ou `{ error }` | Timeout, estado de envio e incorporação do ACK |
| `message:receive` | Objeto `Message` | Mesclar por `id`, inclusive se já veio no ACK |
| `typing:start/stop` | Envio com conversa; recepção com conversa e usuário | Throttle, timeout local e limpeza ao sair |
| `presence:online/offline` | `{ userId }` | Indicação transitória; não prova de presença inicial |

Na reconexão: atualizar credencial, reinscrever salas, buscar páginas recentes até reencontrar o último ID conhecido ou alcançar o fim, mesclar e restaurar posição de leitura. Uma única primeira página não recupera necessariamente tudo que chegou durante uma longa desconexão. Em histórico carregado simultaneamente com socket, mesclar em vez de sobrescrever a lista.

Para envio robusto, adicionar `clientMessageId` opcional ao servidor e restrição única por remetente/conversa/ID do cliente; persistir e devolver o mesmo resultado quando repetido. Compatível com o legado que omite o campo. Deduplicar só por ID retornado resolve evento+ACK, mas não impede duplicação de duas gravações quando o ACK se perde.

Sem esse contrato, timeout significa “confirmação pendente”; consultar histórico e manter rascunho, sem retry automático nem promessa de entrega exatamente uma vez. A etapa de chat deve decidir e testar esse comportamento antes do beta.

Presença exige snapshot autorizado e contador correto; não inferir “offline” só porque nenhum evento chegou. Validar participação também em eventos de digitação. Para backend com múltiplas réplicas, mover presença para mecanismo compartilhado com expiração. Sala pessoal/evento de conversa é uma evolução útil; inicialmente, revalidar conversas ao foco, ao push e por polling limitado enquanto a lista estiver visível.

### 6.5. Push: alteração necessária de backend

Plano de transição:

1. Criar tabela `push_installations` com instalação, usuário, provider (`expo`/`fcm`), plataforma, token, atualização e estado ativo. Guardar tokens com capacidade apropriada ao provider, sem reaproveitar cegamente o limite atual de 255.
2. Adicionar operações autenticadas de registrar/atualizar e revogar instalação. Associar ao usuário da sessão, impedir revogação de instalação alheia e tratar troca de conta/dispositivo.
3. Preservar `POST /users/me/push-token` e `expoPushToken` durante a coexistência. Suportar fallback legado com deduplicação; tokens Expo não podem ser convertidos em FCM.
4. Centralizar envio em um serviço por usuário/destinatário, com adaptadores Expo e FCM. Atualizar tanto notificações sociais quanto envio de chat, que hoje acessam diretamente o campo Expo.
5. Configurar projeto Firebase, app Android e credenciais de servidor. Não confundir FCM com migração para Firebase Auth ou Firestore.
6. Flutter registra o token após permissão e login, acompanha rotação e revoga associação ao sair. Quando revogação remota falhar, registrar a limitação e executar limpeza local; payloads não devem expor conteúdo sensível desnecessário.
7. Acrescentar dados de navegação (`type`, IDs de post/ator/conversa e identificador do evento). Hoje o push contém apenas título/corpo/som, insuficientes para abrir um destino específico.
8. Tratar foreground, background e inicialização por notificação; adiar navegação até sessão e router estarem prontos. Evitar dupla notificação local/remota para o mesmo evento.
9. Invalidar tokens definitivamente rejeitados; tratar indisponibilidade de push sem falhar a ação principal. Só retirar adaptador Expo após encerrar suporte ao cliente legado.

O setup Flutter/FCM e os estados de recepção são específicos por plataforma. Na web, push exige configuração própria de service worker e credenciais web; não é pré-requisito para preservar a atual central in-app. [Configuração FCM](https://firebase.google.com/docs/cloud-messaging/flutter/get-started), [recepção no Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).

### 6.6. Uploads, catálogo e imagens

- Manter campos multipart `avatar` e `banner`; teto atual de 8 MiB. Usar bytes/arquivo com nome e MIME correto, deixando a biblioteca produzir o boundary.
- Validar foto escolhida, cancelamento, acesso negado, orientação, HEIC e arquivo acima do limite; o suporte efetivo depende do dispositivo e da conversão/Sharp. Testar uma matriz real de formatos.
- Backend continua responsável por conversão: avatar 400×400 e banner 1500×500 em JPEG. Preview deve respeitar o recorte aplicado no servidor.
- Reutilizar as URLs de proxy recebidas; não contornar o proxy IGDB, pois ele existe para redes onde o domínio original é bloqueado.
- Verificar `PUBLIC_API_URL`, HTTPS e CORS de imagens no navegador. URLs absolutas antigas em dados cacheados podem exigir correção de dados se o domínio mudar; migração Flutter sozinha não deve mudar esse domínio.
- Confirmar volume persistente e backup de uploads no ambiente real antes da substituição. Não substituir storage por outro serviço como requisito artificial da migração.

### 6.7. Backlog de backend separado do frontend

| Prioridade | Item | Momento |
| --- | --- | --- |
| Obrigatório | Contrato de limpeza de campos opcionais e testes | Antes do tracker completo |
| Obrigatório | Providers/instalações push, rotação/revogação e payload de destino | Antes do beta com push |
| Obrigatório para envio com retry | `clientMessageId` e idempotência de mensagens | Etapa de chat |
| Obrigatório para web pública persistente | Sessão web com cookie e proteções correspondentes | Antes de publicar esse canal |
| Correção de confiabilidade | Refresh atômico para evitar duas rotações concorrentes do mesmo token | Fundação de sessão; testar concorrência e múltiplas abas |
| Correção de consistência | Notificação de like/follow apenas quando a relação for criada | Antes de automatizar testes/retries sociais |
| Correção de chat | Snapshot de presença e validação de participação no typing | Antes de oferecer indicador confiável |
| Condicional à escala medida | Paginação de coleções/comentários/conversas; presença distribuída | Conforme volumes e topologia |
| Evolução opcional | Eventos pessoais de conversa, leitura individual de notificações, ordenação por término | Após paridade ou se exigido pelos critérios de aceite |

Para PATCH, não basta adicionar `.nullable()` ao schema: adaptar conversão de horas, persistência e serialização para `null` não virar `undefined` ou data de época. Testar regressão no cliente antigo com campo omitido.

## 7. Etapas de execução

Cada etapa encerra com uma demonstração funcional, evidências de teste e atualização da matriz de paridade. Os responsáveis abaixo são papéis, que podem ser exercidos pela mesma pessoa. Mudanças de backend permanecem compatíveis enquanto houver cliente Expo ativo.

### Etapa 0 — Baseline, contratos e provas técnicas

**Responsável:** frontend + backend. **Esforço:** 2–3 dias úteis. **Dependência:** nenhuma.

- [ ] Registrar fluxos atuais e fixtures sem dados pessoais; conferir inventário deste documento.
- [ ] Levantar distribuição real: APK instalado, lojas, domínio web, assinatura e números de versão.
- [ ] Preparar banco/Redis/uploads exclusivos de desenvolvimento e staging; nunca testar no banco compartilhado descrito no roadmap.
- [ ] Fixar matriz candidata Flutter/Dart/Material/plugins e plataformas mínimas suportadas pelo conjunto.
- [ ] Provar build básico nas três plataformas, HTTP autenticado, upload e conexão Socket.IO.
- [ ] Provar configuração push em dispositivo cedo, mesmo antes da UI final, para descobrir bloqueios de credenciais.
- [ ] Registrar ADRs curtas para stack, sessão web, design, push e transição de app instalado.

**Saída:** riscos externos conhecidos, contratos amostrados e combinação tecnológica viável. Instalação do SDK e acesso às credenciais ainda precisam ser verificados; não foram realizados na elaboração deste plano.

### Etapa 1 — Design system e protótipo das jornadas

**Responsável:** design/produto + frontend. **Esforço:** 3–5 dias. **Dependência:** 0.

- [ ] Criar tema claro/escuro, tipografia, formas e cores de domínio.
- [ ] Montar catálogo de componentes e estados, sem lógica de negócio duplicada.
- [ ] Prototipar Biblioteca → Jogo → Registro, Comunidade → Post e Mensagens → Conversa.
- [ ] Validar a nova ordem de navegação, ações, nomenclatura e estados vazios.
- [ ] Conferir larguras 360/600/840/1280, texto ampliado e teclado.

**Saída:** direção visual concreta, três jornadas revisáveis e componentes suficientes para a primeira fatia vertical. Não redesenhar 16 telas isoladamente antes de validar os padrões comuns.

### Etapa 2 — Fundação Flutter e qualidade contínua

**Responsável:** frontend. **Esforço:** 3–5 dias. **Dependências:** 0–1.

- [ ] Criar `flutter_app/`, estrutura por funcionalidades e ambientes dev/staging/prod.
- [ ] Configurar Material, localização pt-BR, router, providers, HTTP, storage e erros.
- [ ] Configurar formatter, analyzer, testes e builds de CI; ambiente de CI não depende de `.env` pessoal.
- [ ] Criar shell adaptável, rotas, guard de sessão e tratamento de destino inexistente.
- [ ] Configurar ícone/splash inicial, identificação do app e permissões estritamente necessárias.

**Saída:** shell navega e compila em Android/web; CI gera artefato de teste e valida contratos de base.

### Etapa 3 — Autenticação e sessão

**Responsável:** frontend + backend para ajustes de sessão. **Esforço:** 3–5 dias. **Dependência:** 2.

- [ ] Implementar cadastro, login por email/username, bootstrap, refresh serializado e logout.
- [ ] Tratar rede indisponível sem apagar credenciais válidas e tratar sessão revogada sem loop.
- [ ] Limpar providers/socket/dados sensíveis na troca de conta; descartar respostas atrasadas.
- [ ] Implementar política web definida na etapa 0 e testar atualização de app instalado com novo login.
- [ ] Ajustar concorrência do refresh no backend se demonstrada a condição de dupla emissão.

**Saída:** fluxos de sessão validados, inclusive vários 401 simultâneos, logout durante refresh e troca entre duas contas.

### Etapa 4 — Catálogo e biblioteca: primeira fatia completa

**Responsável:** frontend + backend para PATCH. **Esforço:** 6–9 dias. **Dependência:** 3.

- [ ] Busca de jogos, resolução de IDs, detalhe, proxy de imagens e galeria.
- [ ] CRUD de registros, replays, filtros, ordenação, lista/grade e preferência local.
- [ ] Formulário de progresso, horas, nota, datas e limpeza de campos persistidos.
- [ ] Favoritos, estatísticas e consulta de jogadores com rótulos corretos.
- [ ] Consistência de cache após cada mutação e convite para publicar após conclusão bem-sucedida.

**Saída:** usuário existente entra, encontra jogo, cria dois playthroughs, edita/limpa campos, filtra, favorita e remove um registro sem perder o outro. Primeiro APK Flutter utilizável do tracker; ainda não substitui a aplicação social completa.

### Etapa 5 — Comunidade, posts e comentários

**Responsável:** frontend + backend para consistência. **Esforço:** 5–8 dias. **Dependência:** 4.

- [ ] Feed Geral/Seguindo, paginação e atividades com snapshot histórico.
- [ ] Criar post sem vínculo, com jogo e com registro; preservar texto em erro.
- [ ] Curtidas consistentes em todas as superfícies; falhas com rollback.
- [ ] Detalhe, comentários, respostas profundas e curtidas de comentário.
- [ ] Testar notificações geradas uma única vez em repetição de like/follow.

**Saída:** interação de duas contas reproduz fluxos atuais e mantém contadores e threads coerentes.

### Etapa 6 — Pessoas, perfis e uploads

**Responsável:** frontend. **Esforço:** 4–6 dias. **Dependências:** 4–5.

- [ ] Buscar pessoas, seguir/deixar de seguir e resolver próprio perfil.
- [ ] Coleção pública, favoritos, em andamento, concluídos, atividades e posts.
- [ ] Editar nome/username/bio, tratar conflito 409 e atualizar identidade visível.
- [ ] Avatar/banner com preview, upload, progresso, erro e visualização ampliada.
- [ ] Configurações de tema e logout.

**Saída:** perfil próprio é consistente em qualquer entrada; edições e uploads funcionam no nativo e navegador; visitante não altera coleção alheia.

### Etapa 7 — Chat confiável

**Responsável:** frontend + backend. **Esforço:** 5–8 dias. **Dependências:** 3 e 6; prova técnica iniciada em 0.

- [ ] Lista e criação/reuso de conversa 1:1; paginação de histórico.
- [ ] Ciclo de conexão autenticado, ACK de sala, envio e deduplicação.
- [ ] `clientMessageId`, recuperação de envio incerto e preservação de rascunho.
- [ ] Digitação, presença conforme contrato e leitura apenas quando conversa estiver visível.
- [ ] Reconectar após perda de rede, suspensão, troca de token e reinício do servidor.
- [ ] Validar mensagens com Flutter ↔ Expo, além de Flutter ↔ Flutter, durante coexistência.

**Saída:** duas contas conversam sem perda/duplicação nos cenários cobertos, incluindo ACK perdido e histórico carregando junto com eventos.

### Etapa 8 — Notificações in-app e push

**Responsável:** frontend + backend/infra. **Esforço:** 4–6 dias. **Dependências:** 5–7; credenciais/prova iniciadas em 0.

- [ ] Central in-app, filtros, badge e leitura global explícita.
- [ ] Tabela de instalações, registro/revogação e dois adaptadores de envio.
- [ ] Configuração Firebase e ciclo de token no Flutter.
- [ ] Destinos de push e abertura com app fechado, em background e foreground.
- [ ] Testar permissão negada, token inválido, múltiplos dispositivos e troca de conta.

**Saída:** eventos sociais e mensagens disparam pelo provider correto; toque abre o destino autorizado; falha de push não interrompe postagem/chat. Push web pode seguir em incremento próprio, sem bloquear central web.

### Etapa 9 — Validação de produto, desempenho e distribuição

**Responsável:** frontend + QA/produto + infra. **Esforço:** 5–8 dias. **Dependências:** 4–8.

- [ ] Executar matriz de paridade integral, testes de contratos e jornadas de integração.
- [ ] Conferir acessibilidade, claro/escuro, tablet, teclado, gesto de voltar e web.
- [ ] Medir builds de profile/release em aparelho intermediário; corrigir gargalos demonstrados.
- [ ] Testar instalação limpa e atualização por cima de build assinado do legado.
- [ ] Gerar APK/AAB e web; conferir ambientes, assinatura, versão e URLs.
- [ ] Executar beta fechado e ensaiar retorno para o cliente anterior.

**Saída:** candidato de lançamento com checklist atendido, limitações registradas e nenhuma falha bloqueadora nos fluxos essenciais.

### Etapa 10 — Substituição e encerramento do legado

**Responsável:** produto + frontend + backend/infra. **Esforço:** 2–3 dias de trabalho, além da janela de observação. **Dependência:** 9.

- [ ] Distribuir gradualmente; observar autenticação, falhas, chat, uploads e push.
- [ ] Manter backend compatível e build Expo recuperável durante a janela acordada.
- [ ] Confirmar ausência de regressões bloqueadoras e adoção do novo cliente.
- [x] Arquivar referência do legado em tag (`legacy-expo-final`, local até ser enviada).
- [ ] Remover `mobile/` da árvore ativa quando dispensável (procedimento e critérios em `docs/06_ENCERRAMENTO_LEGADO.md`).
- [ ] Retirar EAS, Metro, pacotes React Native/Expo e documentação obsoleta da aplicação ativa.
- [ ] Retirar campo/endpoint/adaptador Expo apenas em uma fase posterior, após encerrar a janela de compatibilidade.
- [x] Atualizar README (Flutter oficial, legado marcado); CI do Flutter e de release criados. Roadmap e instruções de contribuição: após a fase A.

**Saída:** Flutter é o frontend oficial e único em manutenção; não há dependência operacional de React Native/Expo, com histórico e artefatos antigos preservados para consulta.

### 7.1. Esforço e caminho crítico

Estimativa preliminar: **42–66 dias úteis de trabalho**, somando as faixas das etapas; reservar aproximadamente 25% para integração e ajustes, totalizando **53–83 dias úteis**. Para uma pessoa dedicada, aproximadamente **11–17 semanas**, mais espera externa de distribuição/credenciais. Se a equipe estiver aprendendo Dart/Flutter, prever treinamento adicional e recalibrar após a primeira fatia completa. Não é compromisso de prazo.

Caminho principal: **baseline → design/fundação → sessão → tracker → social/perfis → chat/push → beta → substituição**. Preparação de credenciais, contratos, fixtures e backend push pode avançar enquanto as telas são construídas por responsáveis diferentes. A prova de chat/push começa cedo para não descobrir incompatibilidade no fim.

Marcos:

- **M1:** shell Material validado nas três plataformas.
- **M2:** tracker completo com dados reais de staging.
- **M3:** paridade social, perfis e uploads.
- **M4:** chat/push completos e interoperabilidade com legado.
- **M5:** candidato aprovado pela matriz de aceite.
- **M6:** Flutter oficial e legado desativado.

## 8. Testes e critérios de aceite

### 8.1. Estratégia

Usar testes unitários para regras/serialização/controllers, testes de widget para interação e layout, goldens selecionados para padrões visuais e integração para jornadas completas. Não comparar pixels com React Native: o design foi deliberadamente renovado. A divisão entre unitários, widget e integração acompanha a [documentação de testes Flutter](https://docs.flutter.dev/testing/overview).

| Camada | Cenários de maior valor |
| --- | --- |
| Contratos JSON | IDs IGDB/UUID, horas string, ausência/null, datas, erros e cursor opaco |
| Sessão | Refresh concorrente, offline, revogação, logout durante request e troca de conta |
| Regras do tracker | Replay, nota 1–10, zero horas, vírgula decimal, datas e remoção de campos |
| Estado remoto | Filtros, paginação sem duplicatas, rollback e invalidação cruzada |
| Widgets | Formulários, teclado, texto ampliado, foco, dialogs, chips, themes e estados vazios/erro |
| Integração | Login → buscar → registrar → concluir → publicar; seguir → feed; comentar → responder |
| Tempo real | Duas contas/dispositivos, envio repetido, ACK perdido, suspensão, reconnect e token rotacionado |
| Push | Permissão negada, rotação/revogação, app aberto/fechado e deep link após login |
| Distribuição | Build assinado, atualização do legado, API correta, imagens e retorno de versão |

Fixtures devem incluir usuário sem dados, usuário com mais de um playthrough do mesmo jogo, metadados incompletos, textos longos, avatar ausente, conversa extensa e thread profunda. Para volume, começar com coleção de 500 registros e histórico de 1000 mensagens em ambiente isolado; os números são carga de teste proposta, não volume observado da plataforma.

### 8.2. Matriz de plataformas

| Ambiente | Validação mínima |
| --- | --- |
| Android físico intermediário | Instalação/atualização, desempenho, teclado, picker, voltar, suspensão e push |
| Emuladores/simuladores | Regressão de layout, versões mínimas e testes automatizados disponíveis |
| Web Chrome | Login, refresh/deep link, CORS, uploads, imagens, teclado, histórico do navegador e resize |
| Tablet / janela ampla | Rail, colunas de chat, grade adaptável, orientação e preservação de estado |

Push e atualização de armazenamento precisam de teste físico/assinatura; apenas `flutter test` ou build de simulador não os comprova.

### 8.3. Critérios de liberação

- [ ] Todas as linhas obrigatórias do inventário demonstradas e ligadas a teste/evidência.
- [ ] Conta antiga acessa os mesmos dados; nenhum registro desaparece pela migração.
- [ ] Nota, horas e datas mantêm o significado; limpar campo persiste a remoção.
- [ ] Múltiplos playthroughs, favoritos e atividades históricas estão corretos.
- [ ] Não há dados da conta anterior após logout/login.
- [ ] Chat passa pelos cenários de entrega, deduplicação e reconexão; falha não apaga o rascunho.
- [ ] Push funciona em Android físico, respeita conta ativa e abre destino válido.
- [ ] Nenhum overflow ou ação inacessível nas larguras/escala de texto acordadas; navegação assistiva revisada.
- [ ] Sem P0/P1 abertos: perda/exposição de dados, impossibilidade de login, crash recorrente ou falha de fluxo essencial.
- [ ] CI passa com formatação, análise, testes e builds previstos; artefatos e versões reproduzíveis.
- [ ] Volume persistente, backup, assinatura e procedimento de retorno conferidos.

Metas iniciais de desempenho, a calibrar no M2: primeira tela útil em até 3 s no aparelho de referência e rede controlada; interação local com feedback em até 100 ms; pelo menos 95% dos frames dentro do orçamento de 16,7 ms em rolagem a 60 Hz. Medir profile/release, separar tempo de rede de renderização e não declarar sucesso com base apenas no hot reload.

## 9. Build, ambientes e transição operacional

### 9.1. Ambientes e CI

- `dev`: API e banco isolados; fixtures controladas; nenhum teste presume que `.env` atual é seguro.
- `staging`: backend, banco, Redis e uploads próprios; credenciais push de teste; builds de distribuição interna.
- `prod`: infraestrutura existente validada, HTTPS, assinatura final e configuração auditável.
- Configuração Flutter com URL da API e ambiente fornecidos no build; esses valores são públicos. Segredos IGDB, banco, JWT e credenciais de servidor FCM nunca entram no app.
- Variar identificadores de staging para coexistir com produção; manter o identificador final `com.marcuscoelho.gametracker` quando a intenção for atualizar a instalação existente.
- CI proposta no provedor do repositório: checagem Dart e testes a cada PR; Android/web por build candidato. Nenhum workflow existente foi presumido.
- Versionar `pubspec.lock`, versão do SDK e configurações necessárias. Certificados/chaves e senhas ficam no mecanismo de secrets.
- Remover a permissão de microfone herdada do manifesto atual se não houver função que a utilize.

A distribuição passa a usar builds Flutter assinados para Android e artefato web estático, substituindo o fluxo EAS do cliente. Consultar os requisitos de SDK/loja no momento da entrega. [Android](https://docs.flutter.dev/deployment/android), [web](https://docs.flutter.dev/deployment/web).

### 9.2. Compatibilidade de dados e atualização

Não migrar PostgreSQL para outro banco. Evoluções de schema devem seguir **expandir → coexistir → retirar**: novos campos/tabelas/rotas primeiro, clientes antigos continuam funcionando, remoções só depois. Nunca resetar banco para trocar frontend.

No Android, conferir application ID, certificado de assinatura real do APK/EAS e version code. A existência de configuração EAS não comprova posse das chaves nem publicação em loja. Se assinatura antiga estiver indisponível, a atualização direta pode não ser possível e isso altera o plano de distribuição; descobrir na etapa 0.

Tema e preferência de grade podem voltar ao padrão se não houver migração de armazenamento. Comunicar esse comportamento junto do novo login. Não copiar caches antigos como fonte de verdade.

### 9.3. Lançamento e retorno

1. Criar tag e preservar artefato assinado recuperável do Expo antes de substituí-lo.
2. Implantar alterações aditivas de backend e verificar o cliente antigo.
3. Executar beta fechado Flutter em staging, seguido de piloto de produção com contas autorizadas.
4. Se houver loja, ampliar rollout por grupos, por exemplo 10% → 25% → 100%, conforme volume e evidências. Se a distribuição for APK manual, usar pequenos grupos e canais de download explícitos; não simular rollout remoto inexistente.
5. Observar por pelo menos uma semana e até cobrir as jornadas essenciais. Em base pequena, usar sessões assistidas e erros absolutos; percentuais sozinhos não dão confiança.
6. Retirar o legado após estabilidade e decisão de encerramento do suporte.

Gatilhos de interrupção: perda/inconsistência de dados, sessão cruzada entre contas, falha sistemática de login, envio duplicado de chat ou crashes que bloqueiem uso. Comparar métricas por versão/ambiente: sessões sem crash, falhas de API, refresh, ACK/reconexão, upload e push. Registrar eventos técnicos sem tokens, senha, texto privado de chat ou dados desnecessários.

**Retorno:** pausar distribuição e manter API compatível. Na web, restaurar o artefato anterior e verificar cache/service worker. Em aplicativos instalados, normalmente o retorno exige publicar código anterior com número de build superior e assinatura correta; não presumir downgrade imediato. No banco, preservar dados gravados pelo Flutter e evitar rollback destrutivo de schema; preferir correção aditiva.

## 10. Riscos, decisões pendentes e controle de escopo

| Risco / decisão | Resposta e momento de resolução |
| --- | --- |
| Aprendizado Flutter maior que o previsto | Primeira fatia vertical antes de ampliar backlog; recalibrar prazo em M2 |
| SDK/Material/plugins em transição | Matriz de compatibilidade fixada em 0; builds dos três alvos antes de desenvolver telas em volume |
| Falta de assinatura/conta Apple/Firebase | Inventário em 0; tratar acesso como dependência de distribuição, não deixar para 9 |
| Perda de sessão na atualização | Novo login como comportamento planejado; migração silenciosa só com prova |
| Push só funcionar no legado | Adaptadores por provider e beta nativo com token real |
| Chat parecer funcional mas perder dados em reconexão | Testes de ACK perdido, reentrada, histórico concorrente e idempotência |
| UI nova omitir função pouco visível | Matriz por fluxo e não apenas lista de telas; homologar com duas contas |
| Requests/DTOs incompatíveis | Contratos versionados, fixtures e verificação junto do backend |
| Crescimento de escopo com redesign | Usar recursos Material e capacidades da API; novas features em backlog separado |
| Sobrecarga do backend com novos layouts | Carregar seções sob demanda; medir requisições por jornada e corrigir consultas demonstradas |
| Testes alterarem produção | Ambientes dedicados; nunca seed/reset automático no banco compartilhado |
| Coexistência longa com duas UIs | Congelar novidades no Expo, aplicar apenas correções necessárias e definir data após beta |

Informações a levantar durante a etapa 0, sem impedir que este plano seja adotado:

- Canal atual de distribuição e prioridade de lançamento Android.
- Se web continuará ferramenta de teste ou será canal público com sessão persistente.
- Quantidade/disponibilidade de pessoas e familiaridade com Dart/Flutter.
- Acesso às chaves existentes, Firebase e aparelhos físicos.
- Topologia real do backend, volume de dados e observabilidade disponível.
- Preferência visual final da marca e prioridade da Biblioteca como destino inicial.

As premissas deste documento são: Android primeiro, web preservada, iOS fora de escopo, novo login aceitável na atualização, backend reaproveitado e design Material com Biblioteca em destaque. Ajustar essas premissas altera a ordem/estimativa, sem exigir refazer o inventário técnico.

## 11. Primeiro lote de trabalho

O início recomendado é executar as etapas 0–2: contratos e provas técnicas, design system e shell Flutter. O primeiro resultado revisável deve conter login visual, navegação real, temas claro/escuro, Biblioteca com dados de fixture e uma página de jogo responsiva, acompanhado de conexão autenticada e socket comprovados em ambiente isolado.

Depois, entregar **login → buscar jogo → criar playthrough → editar → concluir** com backend de staging. Essa sequência valida tecnologia, design, regras e contratos antes da expansão para toda a rede social.

Este documento conclui o planejamento solicitado. Não cria ainda o projeto Flutter, não modifica a aplicação atual e não executa alterações na infraestrutura.
