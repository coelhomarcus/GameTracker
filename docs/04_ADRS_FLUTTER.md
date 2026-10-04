# ADRs — migração para Flutter

**Data:** 04/10/2026. Registros curtos das decisões da Etapa 0 do [plano](02_PLANO_MIGRACAO_FLUTTER.md). Evidências em [03_ETAPA_0_BASELINE.md](03_ETAPA_0_BASELINE.md).

## ADR-1 — Stack do frontend

**Status:** aceita.  
**Decisão:** Flutter 3.47.6 / Dart 3.13.5, `material_ui` 1.5.0, Riverpod 3.4.3, `go_router` 18.0.2, Dio 5.11.1, `socket_io_client` 3.1.6, `flutter_secure_storage` 11.2.0, `shared_preferences` 2.5.5, `image_picker` 1.2.3, `firebase_messaging` 16.7.0.  
**Porquê:** o conjunto resolveu sem conflitos e compilou para Android (debug) e web. Socket.IO interoperou com o servidor 4.8.x.  
**Consequência:** versões fixadas pelo `pubspec.lock`, sem `any` nem dependências flutuantes. Qualquer atualização de SDK exige repetir os builds.

## ADR-2 — Plataformas

**Status:** aceita (decisão do dono do projeto em 03/10/2026).  
**Decisão:** Android e web. iOS fora de escopo; sem APNs, runner macOS ou pasta `ios/`.  
**Consequência:** push só via FCM Android. Se iOS voltar, é uma nova etapa, não um ajuste.

## ADR-3 — Sessão

**Status:** aceita para nativo; **provisória** para web.  
**Decisão (Android):** refresh token no armazenamento seguro, access token só em memória. Refresh serializado: vários 401 esperam a mesma operação.  
**Porquê:** o refresh token é de uso único (reuso devolve 401 `invalid_refresh_token`), então duas renovações concorrentes derrubam a sessão.  
**Decisão (web):** sessão só em memória, com novo login ao recarregar, até existir cookie `HttpOnly` no backend. Muda se a web virar canal público.  
**Consequência:** logout descarta o socket (`enableForceNew()` ao criar outro) e todos os providers de dados.

## ADR-4 — Contratos e datas

**Status:** aceita.  
**Decisão:** o cliente trata datas de progresso como datas de calendário lidas em UTC (o backend devolve `…T00:00:00.000Z`) e `createdAt` como instante convertido para horário local. Horas chegam como string decimal e são normalizadas para uma casa.  
**Decisão:** limpar campo opcional exige mudança no backend (hoje `null` dá 400). Até lá, o formulário não promete remover valores salvos, exceto `notes` (vira `""`).  
**Consequência:** as fixtures em `docs/contract-fixtures/` viram testes de contrato do cliente Dart.

## ADR-5 — Push

**Status:** aceita para backend e cliente; o adaptador FCM do cliente está **pendente** porque não existe projeto Firebase (informado em 04/10/2026; há uma VPS, e criar o projeto, gratuito, ainda precisa ser decidido pelo dono).  
**Decisão:**
- Backend: tabela `push_installations` (uma linha por instalação do app, `installationId` gerado no cliente), provedores Expo e FCM atrás de um serviço único, tokens inválidos desativados, FCM desligado sem credenciais. Trocar de conta no aparelho transfere a instalação; um token só tem um dono.
- Payload `data` só com `type` e ids (`recipientId`, `actorId`, `postId`, `conversationId`...). O texto exibido é genérico (`Nova mensagem`), nunca o conteúdo; o cliente legado (Expo) continua recebendo o texto, como sempre recebeu.
- Cliente: interface `PushPlatform` (permissão, token, mensagens em primeiro plano, toque, mensagem inicial). O padrão é `NoopPushPlatform`, sem dependência do Firebase: o app compila, roda e a central de notificações funciona por polling. O adaptador `firebase_messaging` é um arquivo novo que implementa a interface, mais `google-services.json` e o plugin do Gradle; nada mais muda.
- Consentimento do usuário: só registra com a permissão já concedida; o pedido parte das Configurações. Ao sair, revoga a instalação **antes** de encerrar a sessão (precisa do token de acesso), com limite de 3 s e sem bloquear o logout.
- Destino do toque montado só de ids que são UUID e só se `recipientId` for a conta atual; push de outra conta, tipo desconhecido ou id inválido não abre nada. Toque antes de a sessão restaurar espera até 2 minutos.

**Consequência:** o fluxo de push do cliente está testado com uma plataforma falsa (registro, renovação de token, troca de conta, logout, toque, mensagem inicial), mas a entrega real por FCM não foi exercitada. Push do legado continua intacto.

## ADR-6 — Transição do app instalado

**Status:** aceita. Distribuição confirmada em 04/10/2026: apenas APK manual, trabalho de faculdade, sem loja. Keystore do build EAS anterior declarada irrelevante pelo dono do projeto (04/10/2026).  
**Decisão:** assumir novo login na atualização e mesmo application ID `com.marcuscoelho.gametracker`. O app novo pode entrar como instalação separada; atualizar por cima do legado não é requisito.  
**Consequência:** sem loja, rollout gradual e AAB deixam de valer; a Etapa 9 gera só APK assinado e artefato web.

## ADR-7 — Design

**Status:** aceita como ponto de partida.  
**Decisão:** Material 3 com `ColorScheme.fromSeed` (violeta), temas claro/escuro/sistema, Biblioteca como destino inicial. Cores de domínio de status (backlog, jogando, concluído, abandonado) em extensão de tema, sempre acompanhadas de texto ou ícone.  
**Consequência:** a identidade final é validada na Etapa 1 com protótipo; o hex atual do legado (`#5D4FE3`) não é obrigatório.
