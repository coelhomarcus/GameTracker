// Volume de dados na interface (plano 8.1): 500 registros e 1000 mensagens. Garante que as listas
// são preguiçosas (só constroem o que aparece), chegam ao fim e não repetem nem travam.
// Os tempos só são impressos; o teto é largo (pega travamento). Tempo de parede em suíte paralela é instável.
import 'package:flutter_test/flutter_test.dart';
import 'package:gametracker/core/design_system/game_status.dart';
import 'package:material_ui/material_ui.dart'
    show AxisDirection, ListTile, Scrollable, Size;

import '../support/fake_chat.dart';
import '../support/fake_repos.dart';
import '../support/harness.dart';

final _vertical = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

void main() {
  testWidgets('biblioteca com 500 registros: lista preguiçosa, rola até o fim', (
    tester,
  ) async {
    final entries = [
      for (var i = 0; i < 500; i++)
        fakeEntry(
          id: 'e$i',
          game: fakeGame(
            igdbId: 1000 + i,
            name: 'Jogo ${i.toString().padLeft(3, '0')}',
          ),
          status: GameStatus.values[i % GameStatus.values.length],
          hours: i / 2,
          rating: 1 + i % 10,
          createdAt: DateTime.utc(2026).add(Duration(minutes: 500 - i)),
        ),
    ];
    final h = AppHarness(library: FakeLibraryRepository(entries));
    final openWatch = Stopwatch()..start();
    await h.pump(tester, size: const Size(400, 800));
    openWatch.stop();

    expect(
      find.byType(ListTile).evaluate().length +
          find.textContaining('Jogo ').evaluate().length,
      lessThan(120),
      reason: 'a lista precisa ser preguiçosa',
    );

    final scrollWatch = Stopwatch()..start();
    var frames = 0;
    for (var i = 0; i < 60 && find.text('Jogo 499').evaluate().isEmpty; i++) {
      await tester.fling(_vertical.first, const Offset(0, -2500), 6000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      frames += 2;
    }
    scrollWatch.stop();
    await tester.pumpAndSettle();

    // ignore: avoid_print
    print(
      'VISIBLE: ${find.textContaining('Jogo ').evaluate().map((e) => (e.widget as dynamic).data).toList()}',
    );
    // ignore: avoid_print
    print(
      'abrir 500: ${openWatch.elapsedMilliseconds} ms · rolar até o fim: ${scrollWatch.elapsedMilliseconds} ms ($frames quadros)',
    );
    expect(
      find.text('Jogo 499'),
      findsWidgets,
      reason: 'o último registro precisa ser alcançável',
    );
    expect(tester.takeException(), isNull);
    expect(
      scrollWatch.elapsedMilliseconds / frames,
      lessThan(2000),
      reason: 'travamento: com a carga de uma suíte inteira rodando em paralelo o normal fica abaixo de 300 ms',
    );
  });

  testWidgets(
    'conversa com 1000 mensagens: carrega por páginas até o começo, sem repetir',
    (tester) async {
      final h = AppHarness();
      h.chat.pageSize = 50;
      h.chat.history[convId] = [
        for (var i = 0; i < 1000; i++)
          serverMessage(
            'm${i.toString().padLeft(4, '0')}',
            text: 'mensagem $i',
            minute: i,
            mine: i.isEven,
          ),
      ];
      await h.pump(tester, size: const Size(400, 800));
      await goTo(tester, '/messages/$convId');

      final scrollWatch = Stopwatch()..start();
      var rounds = 0;
      while (find.text('mensagem 0').evaluate().isEmpty && rounds < 120) {
        await tester.fling(
          find.byType(Scrollable).first,
          const Offset(0, 2500),
          6000,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        rounds++;
      }
      scrollWatch.stop();
      await tester.pumpAndSettle();

      // ignore: avoid_print
      print(
        'subir 1000 mensagens: ${scrollWatch.elapsedMilliseconds} ms em $rounds gestos, ${h.chat.messageCalls.length} páginas buscadas',
      );
      expect(
        find.text('mensagem 0'),
        findsOneWidget,
        reason: 'a primeira mensagem precisa ser alcançável',
      );
      // 20 páginas de 50; a primeira é buscada duas vezes de propósito (carga inicial e a
      // sincronização feita ao entrar na sala). Nenhuma outra página repete.
      final cursors = h.chat.messageCalls.map((c) => c.$2).toList();
      expect(cursors.length, 21);
      expect(cursors.where((c) => c == null).length, 2);
      final later = cursors.whereType<String>().toList();
      expect(
        later.toSet().length,
        later.length,
        reason: 'mesma página buscada duas vezes',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
