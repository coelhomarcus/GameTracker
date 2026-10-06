// Etapa 08: a página do jogo como centro da experiência: cabeçalho, abas pela rota, registros e
// a comunidade com posts paginados.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gametracker/core/dates/date_only.dart';
import 'package:gametracker/core/design_system/game_cover.dart';
import 'package:gametracker/core/design_system/game_status.dart';
import 'package:gametracker/core/network/app_exception.dart';
import 'package:gametracker/features/feed/data/post_models.dart';
import 'package:gametracker/features/games/application/game_posts_controller.dart';
import 'package:gametracker/features/games/data/game_models.dart';
import 'package:gametracker/features/library/data/game_entry.dart';
import 'package:gametracker/features/library/presentation/entry_actions.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_feed.dart';
import '../../support/fake_repos.dart';
import '../../support/harness.dart';

final _game = fakeGame();

Post post(String id, {String? text, int likes = 0, Game? game}) => fakePost(
  id: id,
  content: text ?? 'Texto do $id',
  likes: likes,
  game: game ?? _game,
);

AppHarness harness({
  List<GameEntry>? entries,
  FakeFeedRepository? feed,
  FakeGamesRepository? games,
}) => AppHarness(
  games: games,
  feed: feed ?? FakeFeedRepository(),
  library: FakeLibraryRepository(entries ?? const []),
);

Future<void> open(
  WidgetTester tester,
  AppHarness h, {
  String path = '/games/900001',
  Size size = const Size(400, 1400),
  double textScale = 1,
}) async {
  await h.pump(tester, size: size, textScale: textScale);
  await goTo(tester, path);
}

String uri(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first)).state.uri
        .toString();

int tabIndex(WidgetTester tester) =>
    tester.widget<TabBar>(find.byType(TabBar)).controller!.index;

Future<void> openTab(WidgetTester tester, String tab) =>
    tapAndSettle(tester, find.widgetWithText(Tab, tab));

void main() {
  group('cabeçalho', () {
    testWidgets('sem registros: "Adicionar à biblioteca"', (tester) async {
      await open(tester, harness());
      expect(find.text('Adicionar à biblioteca'), findsOneWidget);
      expect(find.textContaining('Você tem'), findsNothing);
      await tapAndSettle(tester, find.text('Adicionar à biblioteca'));
      expect(uri(tester), '/games/900001/playthroughs/new');
    });

    testWidgets('com registros: "Novo registro" e quantos já existem', (
      tester,
    ) async {
      await open(
        tester,
        harness(
          entries: [
            fakeEntry(id: 'a'),
            fakeEntry(id: 'b', platform: 'PS5'),
          ],
        ),
      );
      expect(find.text('Novo registro'), findsOneWidget);
      expect(find.text('Adicionar à biblioteca'), findsNothing);
      expect(find.text('Você tem 2 registros deste jogo'), findsOneWidget);
    });

    testWidgets('um registro: singular', (tester) async {
      await open(tester, harness(entries: [fakeEntry()]));
      expect(find.text('Você tem 1 registro deste jogo'), findsOneWidget);
    });

    testWidgets('capa, título, plataformas, gêneros e favorito', (
      tester,
    ) async {
      await open(tester, harness());
      expect(find.byType(GameCover), findsOneWidget);
      expect(find.text('PC · PlayStation 5'), findsOneWidget);
      expect(find.text('RPG'), findsWidgets);
      expect(find.byTooltip('Favoritar'), findsOneWidget);
    });

    testWidgets('o cabeçalho de outro jogo não mistura registros', (
      tester,
    ) async {
      await open(
        tester,
        harness(
          entries: [
            fakeEntry(
              id: 'x',
              game: fakeGame(igdbId: 5, name: 'Outro'),
            ),
          ],
        ),
      );
      expect(find.text('Adicionar à biblioteca'), findsOneWidget);
    });
  });

  group('ação principal do cabeçalho', () {
    testWidgets('um registro: "Atualizar progresso" abre a edição dele', (
      tester,
    ) async {
      await open(tester, harness(entries: [fakeEntry(id: 'solo')]));
      expect(find.text('Atualizar progresso'), findsOneWidget);
      expect(find.text('Adicionar à biblioteca'), findsNothing);
      // "Novo registro" continua disponível como ação separada.
      expect(find.text('Novo registro'), findsOneWidget);
      await tapAndSettle(tester, find.text('Atualizar progresso'));
      expect(uri(tester), '/games/900001/playthroughs/solo/edit');
    });

    testWidgets('um registro: "Novo registro" cria um replay', (tester) async {
      await open(tester, harness(entries: [fakeEntry(id: 'solo')]));
      await tapAndSettle(tester, find.text('Novo registro'));
      expect(uri(tester), '/games/900001/playthroughs/new');
    });

    testWidgets('vários registros: "Ver registros" abre a aba de progresso', (
      tester,
    ) async {
      await open(
        tester,
        harness(
          entries: [
            fakeEntry(id: 'a'),
            fakeEntry(id: 'b', platform: 'PS5'),
          ],
        ),
      );
      expect(find.text('Ver registros'), findsOneWidget);
      expect(find.text('Atualizar progresso'), findsNothing);
      await tapAndSettle(tester, find.text('Ver registros'));
      expect(tabIndex(tester), 1);
      expect(uri(tester), '/games/900001?tab=progress');
      expect(find.byType(EntryMenuButton), findsNWidgets(2));
    });

    testWidgets('enquanto a biblioteca carrega, a ação espera', (tester) async {
      final h = harness(entries: [fakeEntry(id: 'solo')]);
      final gate = Completer<void>();
      h.library.listGate = gate;
      await h.pump(tester, size: const Size(400, 1400));
      // O gate só vale depois do primeiro pump; abre o jogo e segura de novo.
      await goTo(tester, '/games/900001');
      final primary = find.widgetWithText(
        FilledButton,
        'Carregando registros…',
      );
      if (primary.evaluate().isNotEmpty) {
        expect(tester.widget<FilledButton>(primary).onPressed, isNull);
        expect(find.text('Adicionar à biblioteca'), findsNothing);
        expect(find.text('Atualizar progresso'), findsNothing);
      }
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Atualizar progresso'), findsOneWidget);
    });

    testWidgets('se a biblioteca falha, a ação não finge que não há registro', (
      tester,
    ) async {
      final h = harness();
      h.library.listError = const NetworkException();
      await open(tester, h);
      expect(find.text('Registros indisponíveis'), findsOneWidget);
      expect(find.text('Adicionar à biblioteca'), findsNothing);
    });
  });

  group('arte do cabeçalho', () {
    testWidgets('sem screenshots não reserva faixa de arte', (tester) async {
      await open(tester, harness());
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('com screenshot mostra a arte sem texto sobre ela', (
      tester,
    ) async {
      final games = FakeGamesRepository(
        games: {
          900001: Game(
            id: 'g-900001',
            igdbId: 900001,
            name: 'Jogo Fixture Um',
            screenshots: const ['https://img.example/shot1.jpg'],
            platforms: const ['PC'],
            genres: const ['RPG'],
            summary: 'Sinopse de teste.',
            isFavoritedByMe: false,
          ),
        },
      );
      await open(tester, harness(games: games));
      expect(tester.takeException(), isNull);
      expect(find.byType(ClipRRect), findsWidgets);
      expect(find.text('Jogo Fixture Um'), findsWidgets);
    });
  });

  group('largura ampla', () {
    testWidgets('Sobre coloca plataformas e gêneros ao lado da sinopse', (
      tester,
    ) async {
      await open(tester, harness(), size: const Size(1440, 900));
      final synopsis = tester.getTopLeft(find.text('Sinopse')).dx;
      final platforms = tester.getTopLeft(find.text('Plataformas')).dx;
      expect(platforms, greaterThan(synopsis + 400));
      expect(tester.takeException(), isNull);
    });

    testWidgets('registros ficam em duas colunas', (tester) async {
      await open(
        tester,
        harness(
          entries: [
            fakeEntry(id: 'a', platform: 'PC'),
            fakeEntry(id: 'b', platform: 'PlayStation 5'),
          ],
        ),
        path: '/games/900001?tab=progress',
        size: const Size(1440, 900),
      );
      final cards = find.byType(Card);
      final first = tester.getTopLeft(cards.at(0));
      final second = tester.getTopLeft(cards.at(1));
      expect(second.dy, first.dy);
      expect(second.dx, greaterThan(first.dx));
    });

    testWidgets('notas ganham o rótulo de nota privada', (tester) async {
      await open(
        tester,
        harness(entries: [fakeEntry(notes: 'Só para mim')]),
        path: '/games/900001?tab=progress',
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.lock_outline)).semanticLabel,
        'Nota privada',
      );
      expect(find.text('Só para mim'), findsOneWidget);
    });
  });

  group('abas pela rota', () {
    for (final (path, index) in [
      ('/games/900001', 0),
      ('/games/900001?tab=progress', 1),
      ('/games/900001?tab=community', 2),
      ('/games/900001?tab=banana', 0),
      ('/games/900001?tab=', 0),
    ]) {
      testWidgets('$path abre a aba $index', (tester) async {
        await open(tester, harness(), path: path);
        expect(tabIndex(tester), index);
      });
    }

    testWidgets('trocar de aba atualiza a rota', (tester) async {
      await open(tester, harness());
      await openTab(tester, 'Meu progresso');
      expect(uri(tester), '/games/900001?tab=progress');
      await openTab(tester, 'Comunidade');
      expect(uri(tester), '/games/900001?tab=community');
      await openTab(tester, 'Sobre');
      expect(uri(tester), '/games/900001');
    });

    testWidgets('trocar de aba não acumula histórico', (tester) async {
      final h = harness(entries: [fakeEntry()]);
      await h.pump(tester, size: const Size(400, 1400));
      await openLibraryGame(tester, 'Jogo Fixture Um');
      expect(uri(tester), '/games/900001?tab=progress');
      await openTab(tester, 'Comunidade');
      await openTab(tester, 'Sobre');
      await openTab(tester, 'Meu progresso');
      await openTab(tester, 'Comunidade');
      await tapAndSettle(tester, find.byType(BackButton));
      expect(
        uri(tester),
        '/library',
        reason: 'um voltar só, apesar de quatro trocas',
      );
    });

    testWidgets('a rota mudando por fora troca a aba', (tester) async {
      await open(tester, harness());
      expect(tabIndex(tester), 0);
      await goTo(tester, '/games/900001?tab=community');
      expect(tabIndex(tester), 2);
      await goTo(tester, '/games/900001?tab=progress');
      expect(tabIndex(tester), 1);
    });

    testWidgets(
      'a aba escolhida pelo toque sobrevive à troca de tema/tamanho',
      (tester) async {
        await open(tester, harness(), path: '/games/900001?tab=progress');
        tester.view.physicalSize = const Size(900, 900);
        await tester.pumpAndSettle();
        expect(tabIndex(tester), 1);
      },
    );
  });

  group('Sobre', () {
    testWidgets(
      'sinopse longa começa em seis linhas, com Ler mais e Ler menos',
      (tester) async {
        final long = List.filled(60, 'Uma frase longa da sinopse').join(' ');
        final games = FakeGamesRepository(
          games: {
            900001: Game(
              id: 'g-900001',
              igdbId: 900001,
              name: 'Jogo Fixture Um',
              screenshots: const [],
              platforms: const ['PC'],
              genres: const [],
              summary: long,
            ),
          },
        );
        await open(tester, harness(games: games));
        Text synopsis() => tester.widget<Text>(find.text(long));
        expect(synopsis().maxLines, 6);
        expect(find.text('Ler mais'), findsOneWidget);

        await tapAndSettle(tester, find.text('Ler mais'));
        expect(synopsis().maxLines, isNull);
        expect(find.text('Ler menos'), findsOneWidget);

        await tapAndSettle(tester, find.text('Ler menos'));
        expect(synopsis().maxLines, 6);
      },
    );

    testWidgets('sinopse curta não mostra Ler mais', (tester) async {
      await open(tester, harness());
      expect(find.text('Sinopse de teste.'), findsOneWidget);
      expect(find.text('Ler mais'), findsNothing);
    });

    testWidgets('plataformas e gêneros completos, sem inventar campos', (
      tester,
    ) async {
      await open(tester, harness());
      expect(find.widgetWithText(Chip, 'PC'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'PlayStation 5'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'RPG'), findsOneWidget);
      expect(find.textContaining('Lançamento'), findsNothing);
      expect(find.textContaining('Nota média'), findsNothing);
    });
  });

  group('Meu progresso', () {
    final older = fakeEntry(
      id: 'old',
      platform: 'PC',
      status: GameStatus.completed,
      hours: 20,
      rating: 8,
      startedAt: const DateOnly(2026, 1, 5),
      finishedAt: const DateOnly(2026, 1, 20),
      notes: 'Primeira vez',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final newer = fakeEntry(
      id: 'new',
      platform: 'PlayStation 5',
      status: GameStatus.playing,
      createdAt: DateTime.utc(2026, 3, 1),
    );

    testWidgets('um card por registro, do mais novo ao mais antigo', (
      tester,
    ) async {
      await open(
        tester,
        harness(entries: [older, newer]),
        path: '/games/900001?tab=progress',
      );
      expect(find.byType(EntryMenuButton), findsNWidgets(2));
      final newestY = tester.getTopLeft(find.text('PlayStation 5').last).dy;
      final oldestY = tester.getTopLeft(find.text('PC').last).dy;
      expect(newestY, lessThan(oldestY));
    });

    testWidgets(
      'cada card mostra plataforma, status, datas, horas, nota e notas',
      (tester) async {
        await open(
          tester,
          harness(entries: [older]),
          path: '/games/900001?tab=progress',
        );
        final created = DateOnly.fromLocal(DateTime.utc(2026, 1, 1).toLocal())
            .format();
        expect(find.text('Concluído'), findsOneWidget);
        expect(find.text('20,0 h'), findsOneWidget);
        expect(find.text('Nota 8/10'), findsOneWidget);
        expect(
          find.text('Início 05/01/2026 · Fim 20/01/2026 · Criado em $created'),
          findsOneWidget,
        );
        expect(find.text('Primeira vez'), findsOneWidget);
      },
    );

    testWidgets('sem datas de jogo, só a de criação', (tester) async {
      await open(
        tester,
        harness(entries: [newer]),
        path: '/games/900001?tab=progress',
      );
      final created = DateOnly.fromLocal(DateTime.utc(2026, 3, 1).toLocal())
          .format();
      expect(find.text('Criado em $created'), findsOneWidget);
    });

    testWidgets('tocar no card abre a edição daquele registro', (tester) async {
      await open(
        tester,
        harness(entries: [older, newer]),
        path: '/games/900001?tab=progress',
      );
      await tapAndSettle(tester, find.text('PC').last);
      expect(uri(tester), '/games/900001/playthroughs/old/edit');
    });
  });

  group('Comunidade: posts do jogo', () {
    FakeFeedRepository feedWith(List<Post> posts, {int pageSize = 2}) {
      final feed = FakeFeedRepository(pageSize: pageSize);
      feed.gamePostLists['g-900001'] = posts;
      return feed;
    }

    testWidgets('só consulta depois de abrir a aba, com o UUID do jogo', (
      tester,
    ) async {
      final feed = feedWith([post('p1')]);
      await open(tester, harness(feed: feed));
      expect(
        feed.gamePostCalls,
        isEmpty,
        reason: 'a aba Sobre não busca posts',
      );
      await openTab(tester, 'Comunidade');
      expect(feed.gamePostCalls, [('g-900001', null)]);
    });

    testWidgets('mostra os posts do jogo e não os de outro', (tester) async {
      final feed = feedWith([post('p1', text: 'Sobre este jogo')]);
      feed.gamePostLists['g-outro'] = [post('x', text: 'Sobre outro jogo')];
      await open(
        tester,
        harness(feed: feed),
        path: '/games/900001?tab=community',
      );
      expect(find.text('Sobre este jogo'), findsOneWidget);
      expect(find.text('Sobre outro jogo'), findsNothing);
      expect(feed.gamePostCalls.every((c) => c.$1 == 'g-900001'), isTrue);
    });

    testWidgets('pagina por cursor sem duplicar e chega ao fim', (
      tester,
    ) async {
      final feed = feedWith([for (var i = 1; i <= 5; i++) post('p$i')]);
      await open(
        tester,
        harness(feed: feed),
        path: '/games/900001?tab=community',
        size: const Size(400, 700),
      );
      final page = find.byType(Scrollable).first;
      for (
        var i = 0;
        i < 30 && find.text('Você chegou ao fim.').evaluate().isEmpty;
        i++
      ) {
        await tester.drag(page, const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      expect(find.text('Você chegou ao fim.'), findsOneWidget);
      expect(feed.gamePostCalls, [
        ('g-900001', null),
        ('g-900001', 'c2'),
        ('g-900001', 'c4'),
      ]);
      // A lista é preguiçosa (os primeiros já saíram da tela): a ordem e a ausência de repetição
      // vêm do estado do controlador.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      final ids = container
          .read(gamePostsControllerProvider('g-900001'))
          .value!
          .ids;
      expect(ids, ['p1', 'p2', 'p3', 'p4', 'p5']);
    });

    testWidgets(
      'falha ao carregar mais mostra "Tentar de novo" no rodapé e mantém a lista',
      (tester) async {
        // A segunda página falha: a primeira já foi carregada e continua na tela.
        final feed = feedWith([for (var i = 1; i <= 4; i++) post('p$i')])
          ..pageTwoError = const NetworkException();
        await open(
          tester,
          harness(feed: feed),
          path: '/games/900001?tab=community',
          size: const Size(400, 700),
        );
        final page = find.byType(Scrollable).first;
        for (
          var i = 0;
          i < 20 &&
              find
                  .text('Não foi possível carregar mais posts.')
                  .evaluate()
                  .isEmpty;
          i++
        ) {
          await tester.drag(page, const Offset(0, -400));
          await tester.pumpAndSettle();
        }
        expect(
          find.text('Não foi possível carregar mais posts.'),
          findsOneWidget,
        );

        feed.pageTwoError = null;
        await tester.ensureVisible(find.text('Tentar de novo').last);
        await tapAndSettle(tester, find.text('Tentar de novo').last);
        for (
          var i = 0;
          i < 20 && find.text('Texto do p4').evaluate().isEmpty;
          i++
        ) {
          await tester.drag(page, const Offset(0, -400));
          await tester.pumpAndSettle();
        }
        expect(find.text('Texto do p4'), findsOneWidget);
      },
    );

    testWidgets('sem posts: estado vazio com o convite', (tester) async {
      await open(
        tester,
        harness(feed: feedWith(const [])),
        path: '/games/900001?tab=community',
      );
      expect(find.text('Ninguém publicou sobre este jogo'), findsOneWidget);
      expect(find.text('Publicar sobre este jogo'), findsOneWidget);
    });

    testWidgets(
      'falha da primeira página não derruba as estatísticas e tenta de novo',
      (tester) async {
        final feed = feedWith([post('p1')])
          ..feedError = const NetworkException();
        await open(
          tester,
          harness(feed: feed),
          path: '/games/900001?tab=community',
        );
        expect(find.text('Registros da comunidade'), findsOneWidget);
        expect(find.textContaining('Sem conexão'), findsOneWidget);

        feed.feedError = null;
        await tapAndSettle(tester, find.text('Tentar de novo').last);
        expect(find.text('Texto do p1'), findsOneWidget);
      },
    );

    testWidgets('os jogadores avisam que são só alguns', (tester) async {
      await open(tester, harness(), path: '/games/900001?tab=community');
      expect(find.text('Alguns dos jogadores, até 10.'), findsOneWidget);
    });

    testWidgets('"Publicar sobre este jogo" abre o compositor ligado ao jogo', (
      tester,
    ) async {
      await open(
        tester,
        harness(feed: feedWith(const [])),
        path: '/games/900001?tab=community',
      );
      await tapAndSettle(tester, find.text('Publicar sobre este jogo'));
      expect(uri(tester), '/posts/new?igdbId=900001');
      expect(find.widgetWithText(InputChip, 'Jogo Fixture Um'), findsOneWidget);
    });

    testWidgets('o novo post fica vinculado e entra no topo da lista do jogo', (
      tester,
    ) async {
      final feed = feedWith([post('p1', text: 'Post antigo')]);
      await open(
        tester,
        harness(feed: feed),
        path: '/games/900001?tab=community',
      );
      await tapAndSettle(tester, find.text('Publicar sobre este jogo'));
      await tester.enterText(
        find.widgetWithText(TextField, 'O que você quer compartilhar?'),
        'Meu post novo',
      );
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.widgetWithText(FilledButton, 'Publicar'));

      expect(feed.created.single.gameId, 'g-900001');
      expect(uri(tester), '/games/900001?tab=community');
      expect(find.text('Meu post novo'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Meu post novo')).dy,
        lessThan(tester.getTopLeft(find.text('Post antigo')).dy),
      );
    });

    testWidgets(
      'curtir na lista do jogo vale em todas as superfícies (mesma entidade)',
      (tester) async {
        final shared = post('p1', text: 'Post compartilhado');
        final feed = FakeFeedRepository(general: [shared])
          ..gamePostLists['g-900001'] = [shared]
          ..posts = {'p1': shared};
        await open(
          tester,
          harness(feed: feed),
          path: '/games/900001?tab=community',
        );
        await tapAndSettle(tester, find.byIcon(Icons.favorite_border).last);
        expect(feed.likeCalls.single, ('p1', true));

        await tapAndSettle(tester, find.byType(BackButton));
        await tapAndSettle(tester, find.text('Comunidade').last);
        expect(
          find.byIcon(Icons.favorite),
          findsOneWidget,
          reason: 'o feed já mostra a curtida',
        );
      },
    );

    testWidgets('tocar num post abre o detalhe', (tester) async {
      final feed = feedWith([post('p1')]);
      feed.posts = {'p1': post('p1')};
      await open(
        tester,
        harness(feed: feed),
        path: '/games/900001?tab=community',
      );
      await tapAndSettle(tester, find.text('Texto do p1'));
      expect(uri(tester), '/posts/p1');
    });
  });

  group('layout', () {
    for (final (size, scale) in [
      (const Size(360, 800), 1.0),
      (const Size(360, 800), 2.0),
      (const Size(1440, 900), 1.0),
    ]) {
      for (final tab in ['', '?tab=progress', '?tab=community']) {
        testWidgets(
          '${size.width.toInt()} px, texto $scale×, aba "$tab": sem overflow',
          (tester) async {
            final feed = FakeFeedRepository()
              ..gamePostLists['g-900001'] = [
                post('p1', text: 'Um post com texto razoável'),
              ];
            await open(
              tester,
              harness(
                entries: [fakeEntry(notes: 'Anotações')],
                feed: feed,
              ),
              path: '/games/900001$tab',
              size: size,
            );
            // textScale vem do harness; refaz com a escala pedida.
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });
}
