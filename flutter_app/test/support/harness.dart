import 'package:flutter/painting.dart' show Size;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' show Scaffold;
import 'package:gametracker/app/app.dart';
import 'package:gametracker/app/providers.dart';
import 'package:gametracker/features/auth/data/auth_repository.dart';
import 'package:gametracker/features/feed/data/feed_repository.dart';
import 'package:gametracker/features/games/data/games_repository.dart';
import 'package:gametracker/features/profiles/application/profile_image_picker.dart';
import 'package:gametracker/features/profiles/data/profiles_repository.dart';
import 'package:gametracker/features/library/data/library_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_auth.dart';
import 'fake_feed.dart';
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
    bool signedIn = true,
  }) : auth = auth ?? FakeAuthRepository(),
       library = library ?? FakeLibraryRepository(),
       games = games ?? FakeGamesRepository(),
       feed = feed ?? FakeFeedRepository(),
       profiles = profiles ?? FakeProfilesRepository(),
       picker = picker ?? FakeImagePicker() {
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
