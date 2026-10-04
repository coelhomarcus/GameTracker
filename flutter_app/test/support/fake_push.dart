import 'dart:async';

import 'package:gametracker/features/push/data/push_platform.dart';
import 'package:gametracker/features/push/data/push_repository.dart';

class FakePushPlatform implements PushPlatform {
  FakePushPlatform({
    this.supported = true,
    this.currentPermission = PushPermission.granted,
    this.currentToken = 'fcm-token-1',
  });

  @override
  bool supported;
  @override
  String get provider => 'fcm';
  @override
  String get platformName => 'android';

  PushPermission currentPermission;

  /// O que o sistema responde quando o usuário decide no diálogo.
  PushPermission answerOnRequest = PushPermission.granted;
  String? currentToken;
  Completer<void>? tokenGate;
  PushMessage? initial;
  int initialCalls = 0;
  int permissionRequests = 0;

  final _refresh = StreamController<String>.broadcast();
  final _foreground = StreamController<PushMessage>.broadcast();
  final _opened = StreamController<PushMessage>.broadcast();

  @override
  Future<PushPermission> permission() async => currentPermission;

  @override
  Future<PushPermission> requestPermission() async {
    permissionRequests++;
    currentPermission = answerOnRequest;
    return currentPermission;
  }

  @override
  Future<String?> token() async {
    await tokenGate?.future;
    return currentToken;
  }

  @override
  Stream<String> get onTokenRefresh => _refresh.stream;
  @override
  Stream<PushMessage> get onForegroundMessage => _foreground.stream;
  @override
  Stream<PushMessage> get onOpened => _opened.stream;

  @override
  Future<PushMessage?> initialMessage() async {
    initialCalls++;
    final message = initial;
    initial = null;
    return message;
  }

  void refreshToken(String token) => _refresh.add(token);
  void receive(PushMessage message) => _foreground.add(message);
  void open(PushMessage message) => _opened.add(message);
}

PushMessage pushOf(
  String type, {
  String recipientId = 'u1',
  String? postId,
  String? actorId,
  String? conversationId,
}) => PushMessage(
  data: {
    'type': type,
    'recipientId': recipientId,
    'postId': ?postId,
    'actorId': ?actorId,
    'conversationId': ?conversationId,
  },
);

class FakePushRepository implements PushRepository {
  final registered =
      <
        ({
          String installationId,
          String provider,
          String platform,
          String token,
        })
      >[];
  final revoked = <String>[];
  final events = <String>[];
  Object? registerError;
  Object? revokeError;
  Completer<void>? revokeGate;

  @override
  Future<void> register({
    required String installationId,
    required String provider,
    required String platform,
    required String token,
  }) async {
    final error = registerError;
    if (error != null) throw error;
    events.add('register');
    registered.add((
      installationId: installationId,
      provider: provider,
      platform: platform,
      token: token,
    ));
  }

  @override
  Future<void> revoke(String installationId) async {
    events.add('revoke');
    revoked.add(installationId);
    await revokeGate?.future;
    final error = revokeError;
    if (error != null) throw error;
  }
}
