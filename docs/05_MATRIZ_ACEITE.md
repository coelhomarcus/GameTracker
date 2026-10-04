# Matriz de aceite do app Flutter (Etapa 9)

Estado em 04/10/2026. "Evidência" é um teste que roda em `flutter test` (T), contra o backend real isolado (I) ou uma conferência manual de build (B). **Nada aqui foi executado em aparelho ou emulador**: o sandbox não tem aceleração para o emulador e não há aparelho conectado. As linhas marcadas **pendente** dependem disso.

Comandos: `flutter test` (unidade, widget e aceite); `flutter test test/integration --dart-define=GT_BACKEND=http://localhost:3100` (backend isolado); `cd backend && npm test`.

## 1. Paridade funcional (inventário do plano, seção 2.3)

| Área | Evidência | Estado |
| --- | --- | --- |
| Login e cadastro, sessão restaurada | T `features/auth/*`, `core/session_test.dart` · I `backend_session_test.dart` (refresh rotativo, reuso recusado, concorrência) | Atendido |
| Explorar: jogos e pessoas, debounce, mínimo de 2 letras | T `features/games/search_test.dart`, `profiles/people_search_test.dart` | Atendido |
| Biblioteca: grade/lista, status, ordenação, adicionar, remover | T `library_page_test.dart`, `library_data_test.dart` · I `backend_library_test.dart` · volume 500 registros (T `acceptance/volume_test.dart`, I `backend_volume_test.dart`) | Atendido |
| Página do jogo: seções, favorito, estatísticas, screenshots | T `games/game_page_test.dart` (galeria abre na imagem tocada) | Atendido |
| Registrar/editar playthrough, replay, nota 1–10, zero horas, limpar campo | T `tracking_form_test.dart` · I `backend_library_test.dart` + `patch_contract.mjs` (PATCH tri-estado) | Atendido |
| Comunidade: feed geral/seguindo, paginação, curtir | T `feed/community_page_test.dart`, `feed_state_test.dart` · I `backend_feed_test.dart` | Atendido |
| Publicar post com jogo/playthrough, rascunho preservado | T `feed/create_post_test.dart` | Atendido |
| Detalhe do post: comentários aninhados, curtir, responder | T `feed/post_detail_test.dart` | Atendido |
| Perfil próprio e de outra pessoa, seguir, mensagem | T `profiles/profile_page_test.dart`, `profile_state_test.dart` · I `backend_profiles_test.dart` | Atendido |
| Editar perfil, avatar e banner, conflito de username | T `profiles/edit_profile_test.dart` · I `backend_profiles_test.dart` (upload real) | Atendido |
| Chat: histórico, ao vivo, digitação, presença, não lida | T `features/chat/*`, `core/chat_connection_test.dart` · I `backend_chat_test.dart` (sockets reais) · volume 1000 mensagens | Atendido |
| Notificações: filtros, contador, ler todas | T `notifications/notifications_test.dart` · I `backend_notifications_test.dart` | Atendido |
| Configurações: sair, tema, versão, push | T `profiles/settings_test.dart`, `push/push_test.dart` | Atendido |
| Seletor de jogo e visualizador de imagens | T `create_post_test.dart` (vincular jogo), `game_page_test.dart` (galeria, zoom/fechar) | Atendido |

## 2. Critérios de liberação (plano 8.3)

| Critério | Evidência | Estado |
| --- | --- | --- |
| Todas as linhas obrigatórias demonstradas | Seção 1 | Atendido (em teste automatizado) |
| Conta antiga acessa os mesmos dados; nada desaparece | Mesmo backend e banco, só migrations aditivas (`0009`, `0010`). I: contratos gravados contra o formato real do backend | Parcial: não foi exercitado com os dados reais de produção |
| Nota, horas e datas mantêm o significado; limpar campo persiste | T/I do item de playthrough; I volume (horas e notas de 500 registros voltam idênticas) | Atendido |
| Múltiplos playthroughs, favoritos, atividades | T/I `library`, `feed`, `game_page` | Atendido |
| Sem dados da conta anterior após logout/login | T `session_test.dart`, `push_test.dart` (troca de conta), escopo por `currentUserIdProvider` em todos os controllers | Atendido |
| Chat: entrega, deduplicação, reconexão; falha não apaga rascunho | T `chat_controller_test.dart`, `message_merge_test.dart` · I `backend_chat_test.dart` | Atendido |
| Push em Android físico, conta ativa, destino válido | T com plataforma falsa; destino e conta conferidos | **Pendente**: sem projeto Firebase nem adaptador FCM (ADR-5) |
| Sem overflow nem ação inacessível nas larguras e escalas acordadas; navegação assistiva | T `acceptance/accessibility_test.dart`: 13 telas × 4 janelas (400, 360 com texto 200%, 800, 1400) × claro/escuro sem overflow; diretrizes de toque 48 dp, rótulo e contraste em todas as telas, claro e escuro | Atendido em teste; **revisão com TalkBack pendente** |
| Sem P0/P1 abertos | Seção 4 | Ver seção 4 |
| CI com formatação, análise, testes e builds | `.github/workflows/flutter.yml` e `flutter-release.yml` (YAML validado; os mesmos passos rodados localmente) | **Pendente**: nunca executado no GitHub |
| Volume persistente, backup, assinatura, procedimento de retorno | Assinatura: seção 3. Backup e volume do banco: infraestrutura, fora do repositório | **Pendente** (dono da infra) |

## 3. Distribuição

| Item | Estado |
| --- | --- |
| Application ID `com.marcuscoelho.gametracker`, versão 1.0.0+1 (`pubspec.yaml`, `appVersion` conferido por teste) | Conferido no APK com `aapt2` |
| Permissões do APK de release | Só `INTERNET` (mais a permissão interna do próprio Flutter para receivers). Sem microfone nem câmera |
| Assinatura de release | `android/key.properties` (fora do git) ou os 4 secrets do workflow. Testado com uma chave **descartável**: o APK saiu com o certificado dela e o script recusa APK assinado com a chave de debug, HTTP, `/api` no fim e ausência de chave |
| URL da API | `--dart-define=API_URL` obrigatório e HTTPS no `tool/build_release.sh`; conferido no binário: a URL passada está no APK e o padrão `10.0.2.2` não |
| Tamanho | APK universal ~58 MiB (3 ABIs). Para distribuição por download usar `flutter build apk --split-per-abi` (cerca de um terço por ABI). Web: 41 MiB, dos quais 36 MiB são o CanvasKit |
| CORS | `CORS_ORIGINS` no backend (lista de origens do app web). Sem a variável, tudo é aceito como antes; **definir em produção** |
| Chave de assinatura real | **Pendente**: o dono precisa gerar (`keytool -genkeypair ...`), guardar fora do repositório e cadastrar os secrets. Perder essa chave impede atualizar o app instalado |
| Atualização por cima do app legado | Não é requisito (ADR-6): nova instalação e novo login |
| Retorno | APK anterior reassinado com versionCode maior; web: restaurar o artefato anterior. Nenhum rollback destrutivo de banco |

## 4. Falhas encontradas nesta etapa e corrigidas

- Estados vazio/erro estouravam a altura em janelas largas e baixas (perfil de outra pessoa a 1400 px de largura): agora se ajustam ao espaço. Tentei antes uma área rolável, mas ela criava um nó de acessibilidade focável sem rótulo cobrindo a tela; descartada.
- Avatar do autor nos posts tinha alvo de toque de 40 dp: agora 48 dp.

## 5. Desempenho

Medido apenas o que o ambiente permite; **não há medição em aparelho** (a meta de 3 s para a primeira tela, 100 ms de resposta e 95% dos quadros em 16,7 ms continua por validar).

| Medida | Resultado | Onde |
| --- | --- | --- |
| Backend: criar 500 registros (10 em paralelo) | ~1,7 s | `backend_volume_test.dart` |
| Backend: listar 500 registros | ~25–40 ms | idem |
| Backend: enviar 1000 mensagens com ACK, uma a uma | ~2,4 s | idem |
| Backend: paginar 1000 mensagens (34 páginas) | ~125 ms; ordem e unicidade conferidas | idem |
| App: biblioteca com 500 registros, lista preguiçosa (menos de 120 widgets construídos), rola até o fim sem exceção | abrir 0,7–2,4 s no ambiente de teste (depende da carga; CPU de desktop, modo debug) | `acceptance/volume_test.dart` |
| App: conversa com 1000 mensagens, sobe até a primeira em 20 páginas, cada uma buscada uma vez | ~2 s no ambiente de teste | idem |

Esses tempos de widget test não representam um aparelho intermediário: servem para pegar custo proporcional ao tamanho da lista, não para validar a meta de quadros.

## 6. O que ainda depende de você ou de um aparelho

1. Gerar a chave de assinatura real e cadastrar os secrets; criar a variável `API_URL` do repositório; definir `CORS_ORIGINS` no backend de produção.
2. Rodar o workflow `Flutter` e depois o `Flutter release` no GitHub (nunca executados).
3. Instalar o APK em um Android físico: login, rolagem das listas, teclado, seletor de imagem, botão voltar, suspensão do app, troca de rede; medir com `flutter run --profile` e o DevTools.
4. Passar o TalkBack nas jornadas principais.
5. Decidir sobre o projeto Firebase para fechar o push (ADR-5).
6. Beta fechado com poucas contas e ensaio de retorno (plano 9.3).
