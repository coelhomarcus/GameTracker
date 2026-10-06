import 'dart:async';

import 'package:flutter/painting.dart' show Size;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' show Scaffold, Scrollable;
import 'package:gametracker/app/app.dart';
import 'package:gametracker/app/providers.dart';
import 'package:gametracker/features/auth/data/auth_repository.dart';
import 'package:gametracker/core/realtime/chat_connection.dart';
import 'package:gametracker/features/chat/application/chat_providers.dart';
import 'package:gametracker/features/chat/data/chat_repository.dart';
import 'package:gametracker/features/feed/data/feed_repository.dart';
import 'package:gametracker/features/notifications/application/notifications_controller.dart';
import 'package:gametracker/features/notifications/data/notifications_repository.dart';
import 'package:gametracker/features/push/application/push_controller.dart';
import 'package:gametracker/features/push/data/push_platform.dart';
import 'package:gametracker/features/push/data/push_repository.dart';
import 'package:gametracker/features/games/data/games_repository.dart';
import 'package:gametracker/core/design_system/filter_toolbar.dart';
import 'package:gametracker/core/design_system/game_card.dart';
import 'package:gametracker/core/design_system/game_status.dart';
import 'package:gametracker/features/profiles/application/profile_image_picker.dart';
import 'package:gametracker/features/profiles/data/profiles_repository.dart';
import 'package:gametracker/features/profiles/presentation/profile_image_crop_page.dart';
import 'package:gametracker/features/library/data/library_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_auth.dart';
import 'fake_chat.dart';
import 'fake_transport.dart';
import 'fake_feed.dart';
import 'fake_notifications.dart';
import 'fake_push.dart';
import 'fake_profiles.dart';
import 'fake_repos.dart';

/// App completo com todos os repositórios substituídos por fakes.
class AppHarness {
  AppHarness({
    FakeAuthRepository? auth,
    FakeLibraryRepository? library,
    FakeGamesRepository? games,
    FakeFeedRepository? feed,
    FakeProfilesRepository? profiles,
    FakeImagePicker? picker,
    FakeImageCropper? cropper,
    FakeNotificationsRepository? notifications,
    FakePushPlatform? pushPlatform,
    FakePushRepository? push,
    FakeChatRepository? chat,
    FakeChatTransport? transport,
    bool signedIn = true,
  }) : auth = auth ?? FakeAuthRepository(),
       library = library ?? FakeLibraryRepository(),
       games = games ?? FakeGamesRepository(),
       feed = feed ?? FakeFeedRepository(),
       profiles = profiles ?? FakeProfilesRepository(),
       picker = picker ?? FakeImagePicker(),
       cropper = cropper ?? FakeImageCropper(),
       notifications = notifications ?? FakeNotificationsRepository(),
       pushPlatform = pushPlatform ?? FakePushPlatform(supported: false),
       push = push ?? FakePushRepository(),
       chat = chat ?? FakeChatRepository(),
       transport = transport ?? FakeChatTransport() {
    chatServer = FakeChatServer(this.transport, this.chat);
    if (signedIn && this.auth.restoreResult is SignedOut) {
      this.auth.restoreResult = Restored(fakeUser());
    }
  }

  final FakeAuthRepository auth;
  final FakeLibraryRepository library;
  final FakeGamesRepository games;
  final FakeFeedRepository feed;
  final FakeProfilesRepository profiles;
  final FakeImagePicker picker;
  final FakeImageCropper cropper;
  final FakeNotificationsRepository notifications;
  final FakePushPlatform pushPlatform;
  final FakePushRepository push;
  final FakeChatRepository chat;
  final FakeChatTransport transport;
  late final FakeChatServer chatServer;

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(400, 900),
    double textScale = 1.0,
    Map<String, Object> prefs = const {},
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    SharedPreferences.setMockInitialValues(prefs);
    final sharedPrefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        retry: noAutomaticRetry,
        overrides: [
          ...fakeAuthOverrides(auth),
          libraryRepositoryProvider.overrideWithValue(
            library as LibraryRepository,
          ),
          gamesRepositoryProvider.overrideWithValue(games as GamesRepository),
          feedRepositoryProvider.overrideWithValue(feed as FeedRepository),
          profilesRepositoryProvider.overrideWithValue(
            profiles as ProfilesRepository,
          ),
          profileImagePickerProvider.overrideWithValue(picker),
          profileImageCropperProvider.overrideWithValue(cropper),
          notificationsRepositoryProvider.overrideWithValue(
            notifications as NotificationsRepository,
          ),
          pushPlatformProvider.overrideWithValue(pushPlatform as PushPlatform),
          pushRepositoryProvider.overrideWithValue(push as PushRepository),
          chatTransportProvider.overrideWithValue(transport),
          chatRepositoryProvider.overrideWithValue(chat as ChatRepository),
          chatConnectionProvider.overrideWith((ref) {
            // Igual ao provider real: sem sessão não há conexão; ao sair, ela é encerrada.
            if (ref.watch(currentUserIdProvider) == null) return null;
            final connection = ChatConnection(
              transport: transport,
              accessToken: () async => 'token',
              refresh: (_) async => TokenRefresh.refreshed,
              backoff: (a) => Duration(seconds: a + 1),
            );
            connection.start();
            ref.onDispose(() => unawaited(connection.stop()));
            return connection;
          }),
          chatRetryDelayProvider.overrideWithValue(
            (attempt) => Duration(seconds: attempt),
          ),
          sharedPreferencesProvider.overrideWithValue(sharedPrefs),
        ],
        child: const GameTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();
  }
}

/// Toca e estabiliza. Só rola quando o alvo está fora da tela: `ensureVisible` dentro de um
/// `TabBarView` chega a trocar de aba, o que não é o que um usuário faria.
Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  final center = tester.getCenter(finder.first);
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final onScreen =
      center.dx >= 0 &&
      center.dy >= 0 &&
      center.dx <= size.width &&
      center.dy <= size.height;
  if (!onScreen) {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Navega por caminho, como um deep link (precisa de uma tela com Navigator na árvore).
Future<void> goTo(WidgetTester tester, String path) async {
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).go(path);
  await tester.pumpAndSettle();
}

/// A capa de um jogo na grade da Biblioteca. A prateleira "Jogando agora" repete as capas dos
/// jogos em andamento, por isso a grade é sempre o último resultado.
Finder libraryGame(String title) =>
    find.byWidgetPredicate((w) => w is GameCard && w.title == title).last;

/// Rola até a capa (a grade começa abaixo do resumo, da prateleira e dos filtros) e abre o jogo
/// na aba "Meu progresso".
Future<void> openLibraryGame(WidgetTester tester, String title) async {
  await tester.ensureVisible(libraryGame(title));
  await tester.pumpAndSettle();
  await tester.tap(libraryGame(title));
  await tester.pumpAndSettle();
}

/// Em Configurações: rola até "Sair" (a página tem várias seções e a lista é preguiçosa) e toca.
Future<void> tapSignOut(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Sair'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tapAndSettle(tester, find.text('Sair'));
}

/// O filtro de status (Biblioteca e Perfil) é um botão com menu: sem filtro mostra "Status"; as
/// contagens ficam dentro do menu.
final statusMenu = find.byTooltip('Filtrar por status');

/// Abre o menu de status e escolhe a opção pelo texto exato, por exemplo `Concluído (2)`.
Future<void> chooseStatus(WidgetTester tester, String option) async {
  await tapAndSettle(tester, statusMenu);
  await tapAndSettle(tester, find.text(option).last);
}

/// Texto que o botão de status mostra agora (`Status` sem filtro, ou a opção escolhida).
Finder statusButtonText(String text) => find.descendant(
  of: find.byType(FilterMenuButton<GameStatus>),
  matching: find.text(text),
);
