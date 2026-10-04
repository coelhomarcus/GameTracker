import 'package:flutter_test/flutter_test.dart';
import 'package:gametracker/core/network/app_exception.dart';
import 'package:gametracker/features/feed/data/post_models.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_feed.dart';
import '../../support/harness.dart';

Finder get composer => find.widgetWithText(TextField, 'Escreva um comentário');
Finder get sendButton => find.widgetWithIcon(IconButton, Icons.send);

Future<AppHarness> openPost(
  WidgetTester tester,
  FakeFeedRepository feed, {
  String id = 'p1',
  Size size = const Size(400, 900),
}) async {
  final h = AppHarness(feed: feed);
  await h.pump(tester, size: size);
  await goTo(tester, '/posts/$id');
  return h;
}

FakeFeedRepository threadFeed() => FakeFeedRepository()
  ..posts['p1'] = fakePost(
    id: 'p1',
    content: 'Post principal',
    comments: 3,
    likes: 2,
  )
  ..commentTrees['p1'] = [
    fakeComment(
      id: 'a',
      content: 'Raiz A',
      likes: 1,
      replies: [
        fakeComment(
          id: 'b',
          parent: 'a',
          content: 'Resposta B',
          author: ana,
          replies: [fakeComment(id: 'c', parent: 'b', content: 'Resposta C')],
        ),
      ],
    ),
  ];

void main() {
  testWidgets('abre por deep link, mesmo sem o post ter passado pelo feed', (
    tester,
  ) async {
    await openPost(tester, threadFeed());
    expect(find.text('Post principal'), findsOneWidget);
    expect(find.text('Comentários (3)'), findsOneWidget);
  });

  testWidgets('mostra a thread inteira com as respostas aninhadas', (
    tester,
  ) async {
    await openPost(tester, threadFeed());
    expect(find.text('Raiz A'), findsOneWidget);
    expect(find.text('Resposta B'), findsOneWidget);
    expect(find.text('Resposta C'), findsOneWidget);
  });

  testWidgets('thread profunda nunca esconde comentários (só limita o recuo)', (
    tester,
  ) async {
    Comment chain(int depth, int max) => fakeComment(
      id: 'n$depth',
      parent: depth == 0 ? null : 'n${depth - 1}',
      content: 'nível $depth',
      replies: depth == max ? const [] : [chain(depth + 1, max)],
    );
    final feed = FakeFeedRepository()
      ..posts['p1'] = fakePost(id: 'p1', comments: 8)
      ..commentTrees['p1'] = [chain(0, 7)];
    await openPost(tester, feed);
    for (var i = 0; i <= 7; i++) {
      expect(
        find.text('nível $i', skipOffstage: false),
        findsOneWidget,
        reason: 'nível $i visível',
      );
    }
    // O recuo para no limite: níveis 3 e 7 começam no mesmo x.
    final x3 = tester.getTopLeft(find.text('nível 3', skipOffstage: false)).dx;
    final x7 = tester.getTopLeft(find.text('nível 7', skipOffstage: false)).dx;
    expect(x7, x3, reason: 'recuo limitado a 3 níveis');
    final x1 = tester.getTopLeft(find.text('nível 1', skipOffstage: false)).dx;
    expect(x1, lessThan(x3));
  });

  testWidgets(
    'curtir um comentário aninhado é imediato; falha desfaz e avisa',
    (tester) async {
      final feed = threadFeed();
      await openPost(tester, feed);
      final like = find.bySemanticsLabel(
        RegExp('Curtir comentário de beto, 0 curtidas'),
      );
      final semantics = tester.ensureSemantics();
      await tester.pumpAndSettle();
      expect(like, findsWidgets);

      await tapAndSettle(tester, like.last);
      expect(feed.commentLikeCalls.single, ('c', true));
      expect(
        find.bySemanticsLabel(
          RegExp('Descurtir comentário de beto, 1 curtidas'),
        ),
        findsOneWidget,
      );

      feed.likeError = const NetworkException();
      await tapAndSettle(
        tester,
        find.bySemanticsLabel(
          RegExp('Descurtir comentário de beto, 1 curtidas'),
        ),
      );
      expect(
        find.bySemanticsLabel(
          RegExp('Descurtir comentário de beto, 1 curtidas'),
        ),
        findsOneWidget,
        reason: 'desfez a descurtida',
      );
      expect(find.textContaining('Sem conexão'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets('comentar atualiza a thread e o contador', (tester) async {
    final feed = threadFeed();
    await openPost(tester, feed);
    await tester.enterText(composer, 'Meu comentário');
    await tester.pumpAndSettle();
    await tapAndSettle(tester, sendButton);

    expect(feed.addedComments.single.content, 'Meu comentário');
    expect(feed.addedComments.single.parent, isNull);
    expect(find.text('Meu comentário'), findsOneWidget);
    expect(find.text('Comentários (4)'), findsOneWidget);
    expect(
      tester.widget<TextField>(composer).controller!.text,
      isEmpty,
      reason: 'campo limpo no sucesso',
    );
  });

  testWidgets('responder aninha ao comentário escolhido e mostra o alvo', (
    tester,
  ) async {
    final feed = threadFeed();
    await openPost(tester, feed);
    final semantics = tester.ensureSemantics();
    await tapAndSettle(tester, find.bySemanticsLabel('Responder a beto').first);
    expect(find.text('Respondendo a @beto'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Escreva sua resposta'),
      'Concordo',
    );
    await tester.pumpAndSettle();
    await tapAndSettle(tester, sendButton);

    expect(
      feed.addedComments.single.parent,
      'a',
      reason: 'resposta ao primeiro comentário',
    );
    expect(
      find.text('Respondendo a @beto'),
      findsNothing,
      reason: 'alvo limpo depois de enviar',
    );
    expect(find.text('Concordo'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('cancelar a resposta volta a comentar no post', (tester) async {
    final feed = threadFeed();
    await openPost(tester, feed);
    final semantics = tester.ensureSemantics();
    await tapAndSettle(tester, find.bySemanticsLabel('Responder a beto').first);
    await tapAndSettle(tester, find.byTooltip('Cancelar resposta'));
    expect(find.text('Respondendo a @beto'), findsNothing);
    await tester.enterText(composer, 'De novo no post');
    await tester.pumpAndSettle();
    await tapAndSettle(tester, sendButton);
    expect(feed.addedComments.single.parent, isNull);
    semantics.dispose();
  });

  testWidgets('falha ao comentar preserva o texto e o alvo da resposta', (
    tester,
  ) async {
    final feed = threadFeed()..commentError = const NetworkException();
    await openPost(tester, feed);
    final semantics = tester.ensureSemantics();
    await tapAndSettle(tester, find.bySemanticsLabel('Responder a beto').first);
    await tester.enterText(
      find.widgetWithText(TextField, 'Escreva sua resposta'),
      'Texto importante',
    );
    await tester.pumpAndSettle();
    await tapAndSettle(tester, sendButton);

    expect(find.textContaining('Sem conexão'), findsOneWidget);
    expect(
      find.text('Texto importante'),
      findsOneWidget,
      reason: 'texto preservado',
    );
    expect(
      find.text('Respondendo a @beto'),
      findsOneWidget,
      reason: 'alvo preservado',
    );
    expect(feed.addedComments, isEmpty);

    feed.commentError = null;
    await tapAndSettle(tester, sendButton);
    expect(feed.addedComments.single.content, 'Texto importante');
    expect(feed.addedComments.single.parent, 'a');
    semantics.dispose();
  });

  testWidgets('enviar fica desabilitado sem texto', (tester) async {
    await openPost(tester, threadFeed());
    expect(tester.widget<IconButton>(sendButton).onPressed, isNull);
    await tester.enterText(composer, '   ');
    await tester.pumpAndSettle();
    expect(
      tester.widget<IconButton>(sendButton).onPressed,
      isNull,
      reason: 'só espaços não conta',
    );
    await tester.enterText(composer, 'ok');
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(sendButton).onPressed, isNotNull);
  });

  testWidgets('post sem comentários convida a comentar', (tester) async {
    final feed = FakeFeedRepository()..posts['p1'] = fakePost(id: 'p1');
    await openPost(tester, feed);
    expect(find.textContaining('Seja o primeiro'), findsOneWidget);
  });

  testWidgets('post inexistente mostra erro com nova tentativa', (
    tester,
  ) async {
    final feed = FakeFeedRepository()
      ..postError = const ApiException(404, 'not_found', 'Post não encontrado');
    await openPost(tester, feed, id: 'zzz');
    expect(find.text('Não encontrado.'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('falha ao carregar os comentários não derruba o post', (
    tester,
  ) async {
    final feed = threadFeed()..commentsError = const NetworkException();
    await openPost(tester, feed);
    expect(
      find.text('Post principal'),
      findsOneWidget,
      reason: 'o post continua visível',
    );
    expect(find.textContaining('Sem conexão'), findsOneWidget);

    feed.commentsError = null;
    await tapAndSettle(tester, find.text('Tentar de novo'));
    expect(find.text('Raiz A'), findsOneWidget);
  });

  testWidgets('curtir o post no detalhe reflete no feed', (tester) async {
    final feed = FakeFeedRepository(
      general: [fakePost(id: 'p1', content: 'Post do feed', likes: 5)],
    )..posts['p1'] = fakePost(id: 'p1', content: 'Post do feed', likes: 5);
    final h = AppHarness(feed: feed);
    await h.pump(tester);
    await tapAndSettle(tester, find.text('Comunidade').last);
    await tapAndSettle(tester, find.text('Post do feed'));
    await tapAndSettle(tester, find.text('5'));
    expect(find.text('6'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.text('6'),
      findsOneWidget,
      reason: 'o feed mostra a mesma contagem',
    );
    expect(find.text('5'), findsNothing);
  });

  testWidgets('layout a 360 px e texto 200% não estoura', (tester) async {
    await openPost(tester, threadFeed(), size: const Size(360, 800));
    expect(tester.takeException(), isNull);
    final h = AppHarness(feed: threadFeed());
    await h.pump(tester, size: const Size(360, 800), textScale: 2.0);
    await goTo(tester, '/posts/p1');
    expect(tester.takeException(), isNull);
  });
}
