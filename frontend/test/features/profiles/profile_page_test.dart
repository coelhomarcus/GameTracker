import 'package:flutter_test/flutter_test.dart';
import 'package:gametracker/core/design_system/game_status.dart';
import 'package:gametracker/core/network/app_exception.dart';
import 'package:gametracker/features/feed/data/post_models.dart';
import 'package:gametracker/features/library/data/game_entry.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_feed.dart';
import '../../support/fake_profiles.dart';
import '../../support/fake_repos.dart';
import '../../support/harness.dart';

/// Viewport alta: a lista de registros é lazy e começa abaixo das prateleiras.
const tall = Size(400, 2000);

GameEntry _entry(
  String id,
  String name,
  GameStatus status, {
  double? hours,
  int? rating,
  String? notes,
  int igdb = 1,
}) => fakeEntry(
  id: id,
  game: fakeGame(igdbId: igdb, name: name),
  status: status,
  hours: hours,
  rating: rating,
  notes: notes,
);

Future<AppHarness> openProfile(
  WidgetTester tester, {
  FakeProfilesRepository? profiles,
  FakeFeedRepository? feed,
  FakeLibraryRepository? library,
  String userId = 'u-beto',
  Size size = const Size(400, 900),
}) async {
  final h = AppHarness(profiles: profiles, feed: feed, library: library);
  await h.pump(tester, size: size);
  await goTo(tester, '/users/$userId');
  return h;
}

FakeProfilesRepository withBeto({bool followed = false, int followers = 3}) =>
    FakeProfilesRepository()
      ..profiles['u-beto'] = fakeProfile(
        name: 'Beto Silva',
        bio: 'Gosto de RPG',
        followers: followers,
        following: 1,
        entries: 1,
        followed: followed,
      );

void main() {
  group('perfil de outra pessoa', () {
    testWidgets(
      'mostra identidade, bio e contadores como rótulos (sem links)',
      (tester) async {
        await openProfile(tester, profiles: withBeto());
        expect(find.text('Beto Silva'), findsWidgets);
        expect(find.text('@beto'), findsOneWidget);
        expect(find.text('Gosto de RPG'), findsOneWidget);
        expect(find.textContaining('3 seguidores'), findsOneWidget);
        expect(find.textContaining('1 seguindo'), findsOneWidget);
        expect(
          find.textContaining('1 registro'),
          findsOneWidget,
          reason: 'conta playthroughs, no singular',
        );
        expect(find.text('Editar perfil'), findsNothing);
        expect(find.widgetWithText(FilledButton, 'Seguir'), findsOneWidget);
      },
    );

    testWidgets('sem nome usa o username; sem bio não mostra bio', (
      tester,
    ) async {
      final profiles = FakeProfilesRepository()
        ..profiles['u-beto'] = fakeProfile(name: null, bio: '');
      await openProfile(tester, profiles: profiles);
      expect(find.text('beto'), findsWidgets);
      expect(find.text('Gosto de RPG'), findsNothing);
    });

    testWidgets('seguir é imediato (+1 seguidor); falha desfaz e avisa', (
      tester,
    ) async {
      final profiles = withBeto();
      await openProfile(tester, profiles: profiles);

      await tapAndSettle(tester, find.widgetWithText(FilledButton, 'Seguir'));
      expect(find.text('Seguindo'), findsOneWidget);
      expect(find.textContaining('4 seguidores'), findsOneWidget);
      expect(profiles.followCalls.single, ('u-beto', true));

      profiles.followError = const NetworkException();
      await tapAndSettle(tester, find.text('Seguindo'));
      expect(
        find.text('Seguindo'),
        findsOneWidget,
        reason: 'desfez o "deixar de seguir"',
      );
      expect(find.textContaining('4 seguidores'), findsOneWidget);
      expect(find.textContaining('Sem conexão'), findsOneWidget);
    });

    testWidgets(
      'já seguindo mostra "Seguindo" e deixar de seguir tira 1 seguidor',
      (tester) async {
        final profiles = withBeto(followed: true);
        await openProfile(tester, profiles: profiles);
        expect(find.text('Seguindo'), findsOneWidget);
        await tapAndSettle(tester, find.text('Seguindo'));
        expect(find.widgetWithText(FilledButton, 'Seguir'), findsOneWidget);
        expect(find.textContaining('2 seguidores'), findsOneWidget);
        expect(profiles.followCalls.single, ('u-beto', false));
      },
    );

    testWidgets('perfil inexistente mostra erro com nova tentativa', (
      tester,
    ) async {
      final profiles = FakeProfilesRepository()
        ..profileError = const ApiException(
          404,
          'not_found',
          'Usuário não encontrado',
        );
      await openProfile(tester, profiles: profiles);
      expect(find.text('Não encontrado.'), findsOneWidget);
      profiles
        ..profileError = null
        ..profiles['u-beto'] = fakeProfile();
      await tapAndSettle(tester, find.text('Tentar de novo'));
      expect(find.text('@beto'), findsOneWidget);
    });

    testWidgets(
      'o próprio usuário é redirecionado para o perfil canônico (/me)',
      (tester) async {
        final profiles = FakeProfilesRepository()
          ..profiles['u1'] = fakeProfile(
            id: 'u1',
            username: 'ana',
            name: 'ANA',
          );
        await openProfile(tester, profiles: profiles, userId: 'u1');
        expect(find.text('Editar perfil'), findsOneWidget);
        expect(find.byTooltip('Configurações'), findsOneWidget);
        expect(
          find.byType(NavigationBar),
          findsOneWidget,
          reason: 'dentro da navegação principal',
        );
      },
    );
  });

  group('coleção pública', () {
    FakeProfilesRepository rich() {
      final p = withBeto();
      p.favoritesByUser['u-beto'] = [
        fakeGame(igdbId: 7, name: 'Favorito Sete'),
      ];
      p.collectionByUser['u-beto'] = [
        _entry('a', 'Jogando Agora', GameStatus.playing, igdb: 1, hours: 3.5),
        _entry(
          'b',
          'Concluído Bom',
          GameStatus.completed,
          igdb: 2,
          hours: 20,
          rating: 9,
          notes: 'NOTA-PRIVADA-DO-BETO',
        ),
        _entry('c', 'Abandonado Ruim', GameStatus.dropped, igdb: 900001),
      ];
      return p;
    }

    testWidgets(
      'mostra favoritos, jogando agora, concluídos e todos os registros',
      (tester) async {
        await openProfile(tester, profiles: rich(), size: tall);
        expect(find.text('Favoritos'), findsOneWidget);
        expect(find.text('Jogando agora'), findsOneWidget);
        expect(find.text('Concluídos'), findsOneWidget);
        expect(find.text('Todos os registros (3)'), findsOneWidget);
        expect(
          find.widgetWithText(ListTile, 'Abandonado Ruim'),
          findsOneWidget,
        );
        expect(find.text('3,5 h'), findsOneWidget);
        expect(find.text('Nota 9/10'), findsOneWidget);
      },
    );

    testWidgets('nunca mostra as notas pessoais de outra pessoa', (
      tester,
    ) async {
      await openProfile(tester, profiles: rich(), size: tall);
      expect(find.textContaining('NOTA-PRIVADA'), findsNothing);
    });

    testWidgets('filtro por status com contagem; tocar de novo limpa', (
      tester,
    ) async {
      await openProfile(tester, profiles: rich(), size: tall);
      expect(
        find.byType(ListTile),
        findsNWidgets(3),
        reason: 'um por registro',
      );

      await tapAndSettle(
        tester,
        find.widgetWithText(FilterChip, 'Abandonado (1)'),
      );
      expect(find.byType(ListTile), findsNWidgets(1));
      expect(find.widgetWithText(ListTile, 'Abandonado Ruim'), findsOneWidget);

      await tapAndSettle(
        tester,
        find.widgetWithText(FilterChip, 'Jogando (1)'),
      );
      expect(find.byType(ListTile), findsNWidgets(1));
      expect(find.widgetWithText(ListTile, 'Jogando Agora'), findsOneWidget);

      await tapAndSettle(
        tester,
        find.widgetWithText(FilterChip, 'Jogando (1)'),
      );
      expect(
        find.byType(ListTile),
        findsNWidgets(3),
        reason: 'tocar de novo limpa o filtro',
      );
    });

    testWidgets(
      'é somente leitura: sem menu de edição no registro de outra pessoa',
      (tester) async {
        await openProfile(tester, profiles: rich(), size: tall);
        expect(
          find.byTooltip('Ações do registro de Abandonado Ruim'),
          findsNothing,
        );
      },
    );

    testWidgets('tocar em um jogo abre a página dele', (tester) async {
      await openProfile(tester, profiles: rich(), size: tall);
      await tapAndSettle(
        tester,
        find.widgetWithText(ListTile, 'Abandonado Ruim'),
      );
      expect(find.text('Meu progresso'), findsOneWidget);
    });

    testWidgets('coleção e favoritos vazios mostram estado vazio', (
      tester,
    ) async {
      await openProfile(tester, profiles: withBeto());
      expect(find.text('Coleção vazia'), findsOneWidget);
    });

    testWidgets('falha ao carregar a coleção mostra erro e tenta de novo', (
      tester,
    ) async {
      final p = rich()..collectionError = const NetworkException();
      await openProfile(tester, profiles: p, size: tall);
      expect(find.textContaining('Sem conexão'), findsOneWidget);
      p.collectionError = null;
      await tapAndSettle(tester, find.text('Tentar de novo'));
      expect(find.text('Todos os registros (3)'), findsOneWidget);
    });
  });

  group('perfil próprio', () {
    testWidgets(
      'a coleção é a mesma da Biblioteca e a edição fica no próprio perfil',
      (tester) async {
        final library = FakeLibraryRepository([
          _entry('a', 'Meu Jogo', GameStatus.playing, hours: 1),
        ]);
        final profiles = FakeProfilesRepository()
          ..profiles['u1'] = fakeProfile(
            id: 'u1',
            username: 'ana',
            name: 'ANA',
            entries: 1,
          );
        final h = AppHarness(library: library, profiles: profiles);
        await h.pump(tester);
        await tapAndSettle(tester, find.text('Perfil').last);
        expect(find.text('Editar perfil'), findsOneWidget);
        expect(find.text('Meu Jogo'), findsWidgets);
        expect(find.text('Todos os registros (1)'), findsOneWidget);
        expect(
          profiles.collectionCalls,
          0,
          reason: 'o próprio usuário usa a coleção da Biblioteca, sem outra consulta',
        );
      },
    );

    testWidgets('um registro novo aparece no perfil próprio sem recarregar', (
      tester,
    ) async {
      final library = FakeLibraryRepository([
        _entry('a', 'Primeiro', GameStatus.playing),
      ]);
      final profiles = FakeProfilesRepository()
        ..profiles['u1'] = fakeProfile(id: 'u1', username: 'ana', name: 'ANA');
      final h = AppHarness(library: library, profiles: profiles);
      await h.pump(tester);
      await goTo(tester, '/games/900001/playthroughs/new');
      await tapAndSettle(
        tester,
        find.widgetWithText(FilledButton, 'Salvar registro'),
      );
      await goTo(tester, '/me');
      expect(find.text('Todos os registros (2)'), findsOneWidget);
    });
  });

  group('atividades e posts', () {
    testWidgets('abas mostram só o que pertence a cada uma', (tester) async {
      final feed = FakeFeedRepository();
      feed.userPostLists['u-beto:activity'] = [
        fakePost(
          id: 'a1',
          author: beto,
          type: PostType.activity,
          activityStatus: GameStatus.completed,
          content: 'zerou Algum Jogo',
          game: fakeGame(),
        ),
      ];
      feed.userPostLists['u-beto:post'] = [
        fakePost(id: 'p1', author: beto, content: 'Meu post publicado'),
      ];
      await openProfile(tester, profiles: withBeto(), feed: feed);

      await tapAndSettle(tester, find.text('Atividades'));
      expect(find.textContaining('zerou Algum Jogo'), findsOneWidget);
      expect(find.text('Meu post publicado'), findsNothing);

      await tapAndSettle(tester, find.text('Posts'));
      expect(find.text('Meu post publicado'), findsOneWidget);
      expect(feed.userPostCalls.map((c) => c.$2).toSet(), {true, false});
    });

    testWidgets('sem atividades e sem posts mostram estado vazio', (
      tester,
    ) async {
      await openProfile(tester, profiles: withBeto());
      await tapAndSettle(tester, find.text('Atividades'));
      expect(find.text('Ainda não há atividades'), findsOneWidget);
      await tapAndSettle(tester, find.text('Posts'));
      expect(find.text('Ainda não há posts'), findsOneWidget);
    });

    testWidgets('curtir um post do perfil usa a mesma contagem do feed', (
      tester,
    ) async {
      final feed = FakeFeedRepository(
        general: [
          fakePost(id: 'p1', author: beto, content: 'Compartilhado', likes: 2),
        ],
      );
      feed.userPostLists['u-beto:post'] = [
        fakePost(id: 'p1', author: beto, content: 'Compartilhado', likes: 2),
      ];
      final h = AppHarness(profiles: withBeto(), feed: feed);
      await h.pump(tester);
      await tapAndSettle(tester, find.text('Comunidade').last);
      expect(find.text('2'), findsOneWidget);

      await goTo(tester, '/users/u-beto');
      await tapAndSettle(tester, find.text('Posts'));
      await tapAndSettle(tester, find.text('2'));
      expect(find.text('3'), findsOneWidget);

      await goTo(tester, '/community');
      expect(
        find.text('3'),
        findsOneWidget,
        reason: 'o feed mostra a curtida feita no perfil',
      );
    });
  });

  group('imagens do perfil', () {
    testWidgets('sem foto nem capa não há o que ampliar (sem erro)', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await openProfile(tester, profiles: withBeto());
      await tester.tap(find.bySemanticsLabel('Sem foto'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsNothing);
      semantics.dispose();
    });

    testWidgets('tocar na foto abre a visualização ampliada e fecha', (
      tester,
    ) async {
      final profiles = FakeProfilesRepository()
        ..profiles['u-beto'] = fakeProfile(
          avatarUrl: 'http://localhost:3100/uploads/avatars/a.jpg',
          bannerUrl: 'http://localhost:3100/uploads/banners/b.jpg',
        );
      final semantics = tester.ensureSemantics();
      await openProfile(tester, profiles: profiles);
      await tapAndSettle(tester, find.bySemanticsLabel('Ampliar foto de Beto'));
      expect(find.text('1 de 1'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tapAndSettle(tester, find.byTooltip('Fechar'));
      expect(find.text('1 de 1'), findsNothing);

      await tapAndSettle(tester, find.bySemanticsLabel('Ampliar capa de Beto'));
      expect(find.text('1 de 1'), findsOneWidget);
      semantics.dispose();
    });
  });

  testWidgets('layout a 360 px com texto 200% não estoura', (tester) async {
    final p = withBeto();
    p.favoritesByUser['u-beto'] = [
      fakeGame(name: 'Favorito com nome muito comprido'),
    ];
    p.collectionByUser['u-beto'] = [
      _entry(
        'a',
        'Um nome de jogo extremamente comprido para testar',
        GameStatus.playing,
        hours: 3,
      ),
    ];
    final h = AppHarness(profiles: p);
    await h.pump(tester, size: const Size(360, 800), textScale: 2.0);
    await goTo(tester, '/users/u-beto');
    expect(tester.takeException(), isNull);
  });
}
