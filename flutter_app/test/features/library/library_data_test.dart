import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gametracker/app/providers.dart';
import 'package:gametracker/core/dates/date_only.dart';
import 'package:gametracker/core/design_system/game_status.dart';
import 'package:gametracker/core/network/app_exception.dart';
import 'package:gametracker/features/auth/data/auth_repository.dart';
import 'package:gametracker/features/library/application/library_controller.dart';
import 'package:gametracker/features/library/application/library_prefs.dart';
import 'package:gametracker/features/library/application/library_view.dart';
import 'package:gametracker/features/library/data/game_entry.dart';
import 'package:gametracker/features/library/data/library_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_repos.dart';
import '../../support/fixtures.dart';

List<GameEntry> entriesFrom(String fixture) => (fixtureBody(fixture) as List)
    .cast<Map<String, dynamic>>()
    .map(GameEntry.fromJson)
    .toList();

Future<ProviderContainer> makeContainer(
  FakeLibraryRepository library, {
  FakeAuthRepository? auth,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo =
      auth ?? (FakeAuthRepository()..restoreResult = Restored(fakeUser()));
  final c = ProviderContainer(
    retry: noAutomaticRetry,
    overrides: [
      ...fakeAuthOverrides(repo),
      libraryRepositoryProvider.overrideWithValue(library),
      gamesRepositoryProvider.overrideWithValue(FakeGamesRepository()),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  addTearDown(c.dispose);
  c.read(sessionControllerProvider);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  return c;
}

void main() {
  group('contrato: respostas reais do backend', () {
    test(
      'GET /game-entries/me — horas string, datas UTC, replay do mesmo jogo',
      () {
        final list = entriesFrom('entries_list_mine');
        expect(list.length, 3);
        final done = list.firstWhere((e) => e.status == GameStatus.completed);
        expect(done.hoursPlayed, 12.5, reason: 'string "12.5" vira número');
        expect(done.startedAt, const DateOnly(2026, 1, 5));
        expect(done.finishedAt, const DateOnly(2026, 1, 20));
        expect(done.rating, 9);
        expect(done.notes, 'Primeira vez');

        final replay = list.firstWhere(
          (e) => e.game.id == done.game.id && e.id != done.id,
        );
        expect(
          (replay.hoursPlayed, replay.startedAt, replay.rating, replay.notes),
          (null, null, null, null),
        );
        expect(
          replay.id,
          isNot(done.id),
          reason: 'mesmo jogo, registros distintos',
        );
      },
    );

    test('registro com campos limpos mantém as notas vazias do servidor como texto vazio', () {
      final cleared = entriesFrom('entries_list_after_patch')
          .firstWhere((e) => e.status == GameStatus.completed);
      expect(
        (cleared.hoursPlayed, cleared.rating, cleared.finishedAt),
        (null, null, null),
      );
      expect(cleared.startedAt, const DateOnly(2026, 1, 5));
      expect(cleared.notes, '');
    });

    test('zero horas continua zero, não ausência', () {
      final e = GameEntry.fromJson(
        fixtureBody('entries_create_zero_hours') as Map<String, dynamic>,
      );
      expect(e.hoursPlayed, 0.0);
    });

    test('limpar tudo via PATCH null devolve campos nulos', () {
      final e = GameEntry.fromJson(
        fixtureBody('entries_patch_null_clear') as Map<String, dynamic>,
      );
      expect((e.hoursPlayed, e.rating, e.finishedAt), (null, null, null));
    });
  });

  group('corpo das requisições', () {
    final original = entriesFrom('entries_list_mine')
        .firstWhere((e) => e.status == GameStatus.completed);

    EntryDraft same() => EntryDraft.fromEntry(original);

    test('POST omite o que não tem valor, mas envia zero horas', () {
      final body = createBody(
        900001,
        const EntryDraft(
          platform: 'PC',
          status: GameStatus.playing,
          hoursPlayed: 0,
        ),
      );
      expect(body, {
        'igdbId': 900001,
        'platform': 'PC',
        'status': 'playing',
        'hoursPlayed': 0.0,
      });
    });

    test('POST com tudo preenchido; datas no formato do calendário', () {
      final body = createBody(
        1,
        const EntryDraft(
          platform: 'PC',
          status: GameStatus.completed,
          startedAt: DateOnly(2026, 1, 5),
          finishedAt: DateOnly(2026, 1, 20),
          hoursPlayed: 12.5,
          rating: 9,
          notes: '  boa  ',
        ),
      );
      expect(body['startedAt'], '2026-01-05');
      expect(body['finishedAt'], '2026-01-20');
      expect(body['notes'], 'boa');
    });

    test('PATCH sem mudança é vazio (e o repositório não faz requisição)', () {
      expect(updateBody(original, same()), isEmpty);
    });

    test('PATCH envia só o que mudou', () {
      final edited = EntryDraft(
        platform: original.platform,
        status: GameStatus.dropped,
        startedAt: original.startedAt,
        finishedAt: original.finishedAt,
        hoursPlayed: 30,
        rating: original.rating,
        notes: original.notes,
      );
      expect(updateBody(original, edited), {
        'status': 'dropped',
        'hoursPlayed': 30.0,
      });
    });

    test('PATCH limpa campo esvaziado com null', () {
      final edited = EntryDraft(
        platform: original.platform,
        status: original.status,
        startedAt: null,
        finishedAt: original.finishedAt,
        hoursPlayed: null,
        rating: null,
        notes: original.notes,
      );
      expect(updateBody(original, edited), {
        'startedAt': null,
        'hoursPlayed': null,
        'rating': null,
      });
    });

    test('PATCH: zero horas substitui, não limpa', () {
      final edited = EntryDraft(
        platform: original.platform,
        status: original.status,
        hoursPlayed: 0,
        startedAt: original.startedAt,
        finishedAt: original.finishedAt,
        rating: original.rating,
        notes: original.notes,
      );
      expect(updateBody(original, edited), {'hoursPlayed': 0.0});
    });

    test('notas vazias ("") do servidor equivalem a sem nota', () {
      // O servidor guarda '' depois de limpar as notas; o formulário devolve vazio → nada a enviar.
      final cleared = entriesFrom('entries_list_after_patch')
          .firstWhere((e) => e.status == GameStatus.completed);
      expect(updateBody(cleared, EntryDraft.fromEntry(cleared)), isEmpty);
      final blank = EntryDraft(
        platform: cleared.platform,
        status: cleared.status,
        startedAt: cleared.startedAt,
        notes: '   ',
      );
      expect(updateBody(cleared, blank), isEmpty);
    });
  });

  group('ordenação e filtro', () {
    final a = fakeEntry(
      id: 'a',
      status: GameStatus.playing,
      hours: 10,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final b = fakeEntry(
      id: 'b',
      status: GameStatus.completed,
      hours: null,
      createdAt: DateTime.utc(2026, 3, 1),
    );
    final c = fakeEntry(
      id: 'c',
      status: GameStatus.completed,
      hours: 50,
      createdAt: DateTime.utc(2026, 2, 1),
    );
    final d = fakeEntry(
      id: 'd',
      status: GameStatus.playing,
      hours: 0,
      createdAt: DateTime.utc(2026, 4, 1),
    );
    final all = [a, b, c, d];

    List<String> ids(List<GameEntry> l) => l.map((e) => e.id).toList();

    test('recentes e antigos', () {
      expect(ids(applyLibraryView(all, sort: LibrarySort.recent)), [
        'd',
        'b',
        'c',
        'a',
      ]);
      expect(ids(applyLibraryView(all, sort: LibrarySort.oldest)), [
        'a',
        'c',
        'b',
        'd',
      ]);
    });

    test(
      'mais jogados: sem horas vai para o fim, zero fica acima de ausência',
      () {
        expect(ids(applyLibraryView(all, sort: LibrarySort.mostPlayed)), [
          'c',
          'a',
          'd',
          'b',
        ]);
      },
    );

    test('filtro por status', () {
      expect(
        ids(
          applyLibraryView(
            all,
            status: GameStatus.completed,
            sort: LibrarySort.recent,
          ),
        ),
        ['b', 'c'],
      );
    });

    test('contagem por status ignora o filtro', () {
      final counts = countByStatus(all);
      expect(counts[GameStatus.playing], 2);
      expect(counts[GameStatus.dropped], 0);
    });

    test('não altera a lista original', () {
      applyLibraryView(all, sort: LibrarySort.oldest);
      expect(ids(all), ['a', 'b', 'c', 'd']);
    });
  });

  group('LibraryController', () {
    test('carrega a coleção do usuário', () async {
      final repo = FakeLibraryRepository([
        fakeEntry(id: 'a'),
        fakeEntry(id: 'b'),
      ]);
      final c = await makeContainer(repo);
      final list = await c.read(libraryProvider.future);
      expect(list.map((e) => e.id), ['a', 'b']);
    });

    test('create aplica a resposta do servidor sem refetch', () async {
      final repo = FakeLibraryRepository([fakeEntry(id: 'a')]);
      final c = await makeContainer(repo);
      await c.read(libraryProvider.future);

      final created = await c
          .read(libraryProvider.notifier)
          .create(
            900001,
            const EntryDraft(platform: 'PC', status: GameStatus.playing),
          );
      expect(c.read(libraryProvider).value!.first.id, created.id);
      expect(c.read(libraryProvider).value!.length, 2);
      expect(repo.listCalls, 1, reason: 'sem refetch');
    });

    test(
      'dois playthroughs do mesmo jogo convivem; remover um preserva o outro',
      () async {
        final repo = FakeLibraryRepository();
        final c = await makeContainer(repo);
        await c.read(libraryProvider.future);
        final ctl = c.read(libraryProvider.notifier);
        const draft = EntryDraft(platform: 'PC', status: GameStatus.backlog);
        final first = await ctl.create(900001, draft);
        final second = await ctl.create(900001, draft);
        expect(
          c
              .read(libraryProvider)
              .value!
              .where((e) => e.game.igdbId == 900001)
              .length,
          2,
        );

        await ctl.remove(first);
        final left = c.read(libraryProvider).value!;
        expect(left.map((e) => e.id), [second.id]);
      },
    );

    test('edit substitui só o registro editado', () async {
      final a = fakeEntry(id: 'a');
      final b = fakeEntry(id: 'b');
      final repo = FakeLibraryRepository([a, b]);
      final c = await makeContainer(repo);
      await c.read(libraryProvider.future);
      await c
          .read(libraryProvider.notifier)
          .edit(
            a,
            const EntryDraft(
              platform: 'PC',
              status: GameStatus.completed,
              hoursPlayed: 9,
              rating: 7,
            ),
          );
      final list = c.read(libraryProvider).value!;
      expect(list.firstWhere((e) => e.id == 'a').status, GameStatus.completed);
      expect(list.firstWhere((e) => e.id == 'b').status, GameStatus.backlog);
    });

    test('falha de mutação chega ao chamador e não altera a coleção', () async {
      final repo = FakeLibraryRepository([fakeEntry(id: 'a')])
        ..mutationError = const NetworkException();
      final c = await makeContainer(repo);
      await c.read(libraryProvider.future);
      await expectLater(
        c
            .read(libraryProvider.notifier)
            .create(
              1,
              const EntryDraft(platform: 'PC', status: GameStatus.backlog),
            ),
        throwsA(isA<NetworkException>()),
      );
      expect(c.read(libraryProvider).value!.length, 1);
      expect(repo.created, isEmpty, reason: 'sem retry silencioso');
    });

    test(
      'resposta que chega depois do logout não entra na coleção da outra conta',
      () async {
        final auth = FakeAuthRepository()
          ..restoreResult = Restored(fakeUser('u1', 'ana'));
        final repo = FakeLibraryRepository();
        final c = await makeContainer(repo, auth: auth);
        await c.read(libraryProvider.future);

        repo.mutationGate = null;
        final gateRepo = repo..mutationGate = null;
        // A criação fica pendente enquanto a conta troca.
        final gate = Completer0();
        gateRepo.mutationGate = gate.completer;
        final pending = c
            .read(libraryProvider.notifier)
            .create(
              900001,
              const EntryDraft(platform: 'PC', status: GameStatus.backlog),
            );
        await Future<void>.delayed(Duration.zero);

        await c.read(sessionControllerProvider.notifier).logout();
        auth.nextUser = fakeUser('u2', 'beto');
        await c
            .read(sessionControllerProvider.notifier)
            .login('beto', 'senha-longa');
        repo.entries = [];
        await c.read(libraryProvider.future);

        gate.completer.complete();
        await pending;
        expect(
          c.read(libraryProvider).value,
          isEmpty,
          reason: 'coleção do beto não recebe o registro da ana',
        );
      },
    );

    test('sair descarta a coleção', () async {
      final repo = FakeLibraryRepository([fakeEntry(id: 'a')]);
      final c = await makeContainer(repo);
      expect((await c.read(libraryProvider.future)).length, 1);
      await c.read(sessionControllerProvider.notifier).logout();
      expect(await c.read(libraryProvider.future), isEmpty);
    });
  });

  group('preferências persistidas', () {
    test('grade/lista e ordenação sobrevivem a um novo container', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      ProviderContainer make() => ProviderContainer(
        retry: noAutomaticRetry,
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );

      final first = make();
      expect(first.read(libraryPrefsProvider).grid, isTrue);
      first.read(libraryPrefsProvider.notifier)
        ..setGrid(false)
        ..setSort(LibrarySort.mostPlayed);
      first.dispose();

      final second = make();
      addTearDown(second.dispose);
      expect(second.read(libraryPrefsProvider).grid, isFalse);
      expect(second.read(libraryPrefsProvider).sort, LibrarySort.mostPlayed);
    });

    test('valor desconhecido cai no padrão', () async {
      SharedPreferences.setMockInitialValues({'library.sort': 'qualquer'});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        retry: noAutomaticRetry,
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      expect(c.read(libraryPrefsProvider).sort, LibrarySort.recent);
    });
  });
}

/// Pequeno invólucro para um Completer sem importar dart:async em todo lugar.
class Completer0 {
  final completer = Completer<void>();
}
