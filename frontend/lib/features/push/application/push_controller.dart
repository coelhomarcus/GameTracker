import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/providers.dart';
import '../../../core/client_id.dart';
import '../../notifications/application/notifications_controller.dart';
import '../data/push_platform.dart';
import '../data/push_repository.dart';
import 'push_destination.dart';

final pushPlatformProvider = Provider<PushPlatform>(
  (ref) => const NoopPushPlatform(),
);

final pushRepositoryProvider = Provider<PushRepository>(
  (ref) => RemotePushRepository(ref.watch(apiDioProvider)),
);

/// Estado do push neste aparelho, para a tela de configurações.
enum PushStatus {
  /// Sem suporte (web ou sem adaptador): as notificações aparecem na central.
  unsupported,

  /// Ainda sem permissão (nunca pedida).
  off,

  /// O usuário negou no sistema.
  denied,
  registering,
  on,

  /// Não deu para registrar (rede, servidor ou token indisponível). Tentar de novo é seguro.
  failed,
}

/// Rota pedida por um push tocado, aguardando o app navegar (o app consome e limpa).
class PendingPushRoute extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? route) => state = route;
}

final pendingPushRouteProvider = NotifierProvider<PendingPushRoute, String?>(
  PendingPushRoute.new,
);

const _installationKey = 'push_installation_id';

/// Registro do aparelho para push e tratamento das mensagens. O consentimento é do usuário:
/// só registra com permissão já concedida; o pedido de permissão parte das configurações.
class PushController extends Notifier<PushStatus> {
  /// Um push tocado vale por pouco tempo: depois disso abrir uma tela seria surpresa.
  static const pendingTtl = Duration(minutes: 2);

  PushMessage? _pending;
  DateTime? _pendingAt;
  bool _initialChecked = false;
  int _generation = 0;

  @override
  PushStatus build() {
    final platform = ref.watch(pushPlatformProvider);
    final userId = ref.watch(currentUserIdProvider);
    final generation = ++_generation;

    if (!platform.supported) return PushStatus.unsupported;

    final subscriptions = [
      platform.onForegroundMessage.listen(_onForeground),
      platform.onOpened.listen(_onOpened),
      platform.onTokenRefresh.listen(
        (token) => unawaited(_registerToken(generation, userId, token)),
      ),
    ];
    ref.onDispose(() {
      for (final s in subscriptions) {
        unawaited(s.cancel());
      }
    });

    if (userId != null) {
      Future.microtask(() => _start(generation, userId, platform));
    }
    return PushStatus.off;
  }

  bool _stale(int generation, String? userId) =>
      generation != _generation || ref.read(currentUserIdProvider) != userId;

  /// Id estável desta instalação (sobrevive a logout e troca de conta no mesmo aparelho).
  String installationId() =>
      installationIdOf(ref.read(sharedPreferencesProvider));

  Future<void> _start(
    int generation,
    String userId,
    PushPlatform platform,
  ) async {
    await _sync(generation, userId, platform, prompt: false);
    if (!_initialChecked && !_stale(generation, userId)) {
      _initialChecked = true;
      try {
        final initial = await platform.initialMessage();
        if (initial != null) _hold(initial);
      } catch (_) {}
    }
    _flushPending();
  }

  /// Pede permissão (se ainda não foi pedida) e registra. Chamado pelas configurações.
  Future<void> enable() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    await _sync(
      _generation,
      userId,
      ref.read(pushPlatformProvider),
      prompt: true,
    );
  }

  Future<void> _sync(
    int generation,
    String userId,
    PushPlatform platform, {
    required bool prompt,
  }) async {
    if (_stale(generation, userId)) return;
    state = PushStatus.registering;
    try {
      var permission = await platform.permission();
      if (permission == PushPermission.notDetermined && prompt) {
        permission = await platform.requestPermission();
      }
      if (_stale(generation, userId)) return;
      if (permission != PushPermission.granted) {
        state = permission == PushPermission.denied
            ? PushStatus.denied
            : PushStatus.off;
        return;
      }
      final token = await platform.token();
      if (token == null) {
        if (!_stale(generation, userId)) state = PushStatus.failed;
        return;
      }
      await _registerToken(generation, userId, token);
    } catch (_) {
      if (!_stale(generation, userId)) state = PushStatus.failed;
    }
  }

  Future<void> _registerToken(
    int generation,
    String? userId,
    String token,
  ) async {
    if (userId == null || _stale(generation, userId)) return;
    final platform = ref.read(pushPlatformProvider);
    try {
      await ref
          .read(pushRepositoryProvider)
          .register(
            installationId: installationId(),
            provider: platform.provider,
            platform: platform.platformName,
            token: token,
          );
      if (!_stale(generation, userId)) state = PushStatus.on;
    } catch (_) {
      if (!_stale(generation, userId)) state = PushStatus.failed;
    }
  }

  void _onForeground(PushMessage message) {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || message.data['recipientId'] != userId) return;
    // Com o app aberto o selo atualiza na hora; não há banner do sistema.
    if (isInboxPush(message.data) &&
        ref.exists(notificationsControllerProvider)) {
      ref.read(notificationsControllerProvider.notifier).revalidate();
    }
  }

  void _onOpened(PushMessage message) {
    _hold(message);
    _flushPending();
  }

  void _hold(PushMessage message) {
    _pending = message;
    _pendingAt = ref.read(clockProvider)();
  }

  /// Entrega a rota do push tocado assim que houver sessão. Antes disso (app ainda restaurando
  /// a sessão) fica guardado por [pendingTtl].
  void _flushPending() {
    final message = _pending;
    final at = _pendingAt;
    if (message == null || at == null) return;
    if (ref.read(clockProvider)().difference(at) > pendingTtl) {
      _pending = null;
      return;
    }
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    _pending = null;
    final route = resolvePushRoute(message.data, userId: userId);
    if (route != null) ref.read(pendingPushRouteProvider.notifier).set(route);
  }

  /// Ao voltar ao primeiro plano: tenta de novo um registro que falhou e entrega um push tocado.
  void onResume() {
    final userId = ref.read(currentUserIdProvider);
    final platform = ref.read(pushPlatformProvider);
    if (userId == null || !platform.supported) return;
    if (state == PushStatus.failed) {
      unawaited(_sync(_generation, userId, platform, prompt: false));
    }
    _flushPending();
  }
}

final pushControllerProvider = NotifierProvider<PushController, PushStatus>(
  PushController.new,
);

String? savedInstallationId(SharedPreferences prefs) =>
    prefs.getString(_installationKey);

String installationIdOf(SharedPreferences prefs) {
  final saved = savedInstallationId(prefs);
  if (saved != null) return saved;
  final id = newClientId();
  unawaited(prefs.setString(_installationKey, id));
  return id;
}

/// Revoga este aparelho para a conta atual, chamado antes de sair (precisa do token de acesso).
/// Melhor esforço: sem rede, o logout segue; o servidor transfere a instalação no próximo
/// registro e o cliente descarta pushes de outra conta. É um provider à parte, sem depender da
/// sessão, para o logout poder usá-lo sem ciclo.
final pushUnregisterProvider = Provider<Future<void> Function()>((ref) {
  final platform = ref.watch(pushPlatformProvider);
  final repository = ref.watch(pushRepositoryProvider);
  return () async {
    if (!platform.supported) return;
    final id = savedInstallationId(ref.read(sharedPreferencesProvider));
    if (id == null) return;
    try {
      await repository.revoke(id).timeout(const Duration(seconds: 3));
    } catch (_) {}
  };
});
