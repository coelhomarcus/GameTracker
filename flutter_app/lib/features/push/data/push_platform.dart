import 'dart:async';

enum PushPermission { granted, denied, notDetermined }

/// Mensagem de push já decodificada. `data` carrega só ids e o tipo (nunca texto de usuário).
class PushMessage {
  const PushMessage({required this.data});
  final Map<String, String> data;
}

/// Fronteira com o sistema de push. O app só conhece esta interface; o adaptador FCM
/// (firebase_messaging) entra aqui quando existir um projeto Firebase (ADR-5). Sem ele, o
/// [NoopPushPlatform] mantém o app funcionando com a central de notificações em polling.
abstract interface class PushPlatform {
  /// `false` quando o aparelho/ambiente não recebe push (web, adaptador ausente).
  bool get supported;

  /// Valor de `provider` aceito pelo backend (`fcm`).
  String get provider;

  /// Valor de `platform` aceito pelo backend (`android`).
  String get platformName;

  Future<PushPermission> permission();
  Future<PushPermission> requestPermission();
  Future<String?> token();
  Stream<String> get onTokenRefresh;

  /// Chegou com o app aberto.
  Stream<PushMessage> get onForegroundMessage;

  /// O usuário tocou na notificação com o app em segundo plano.
  Stream<PushMessage> get onOpened;

  /// A notificação que abriu o app do zero (uma vez só).
  Future<PushMessage?> initialMessage();
}

class NoopPushPlatform implements PushPlatform {
  const NoopPushPlatform();

  @override
  bool get supported => false;
  @override
  String get provider => 'fcm';
  @override
  String get platformName => 'android';
  @override
  Future<PushPermission> permission() async => PushPermission.denied;
  @override
  Future<PushPermission> requestPermission() async => PushPermission.denied;
  @override
  Future<String?> token() async => null;
  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
  @override
  Stream<PushMessage> get onForegroundMessage => const Stream.empty();
  @override
  Stream<PushMessage> get onOpened => const Stream.empty();
  @override
  Future<PushMessage?> initialMessage() async => null;
}
