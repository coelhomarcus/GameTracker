import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:gametracker/app/providers.dart';
import 'package:gametracker/core/storage/token_store.dart';
import 'package:gametracker/features/auth/data/auth_models.dart';
import 'package:gametracker/features/auth/data/auth_repository.dart';

AuthUser fakeUser([String id = 'u1', String username = 'ana']) => AuthUser(
  id: id,
  username: username,
  email: '$username@example.test',
  name: username.toUpperCase(),
);

class FakeAuthRepository implements AuthRepository {
  RestoreResult restoreResult = const SignedOut();
  Object? loginError;
  Object? registerError;
  AuthUser nextUser = fakeUser();
  Completer<void>? loginGate;
  int logoutCalls = 0;
  int restoreCalls = 0;
  final loginCalls = <(String, String)>[];

  @override
  Future<AuthUser> login(String identifier, String password) async {
    loginCalls.add((identifier, password));
    await loginGate?.future;
    final error = loginError;
    if (error != null) {
      throw error;
    }
    return nextUser;
  }

  @override
  Future<AuthUser> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    final error = registerError;
    if (error != null) {
      throw error;
    }
    return nextUser;
  }

  @override
  Future<RestoreResult> restore() async {
    restoreCalls++;
    return restoreResult;
  }

  @override
  Future<void> logout() async => logoutCalls++;
}

List<Override> fakeAuthOverrides(FakeAuthRepository repo) => [
  authRepositoryProvider.overrideWithValue(repo),
  tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
];
