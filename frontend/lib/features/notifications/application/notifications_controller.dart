import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/notification_models.dart';
import '../data/notifications_repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => RemoteNotificationsRepository(ref.watch(apiDioProvider)),
);

/// Central de notificações. O selo do sino vem daqui. Como não há evento em tempo real, ela é
/// revalidada ao voltar para o app, ao abrir a central, quando chega um push com o app aberto e por
/// polling leve enquanto o app está em primeiro plano.
class NotificationsController extends AsyncNotifier<NotificationsData> {
  static const pollInterval = Duration(seconds: 60);
  static const maxAge = Duration(seconds: 30);

  Timer? _poll;
  bool _foreground = true;
  DateTime? _loadedAt;
  bool _markingAll = false;

  @override
  Future<NotificationsData> build() async {
    final userId = ref.watch(currentUserIdProvider);
    ref.onDispose(() => _poll?.cancel());
    if (userId == null) {
      return const NotificationsData(items: [], unreadCount: 0);
    }

    final data = await ref.watch(notificationsRepositoryProvider).list();
    _loadedAt = ref.read(clockProvider)();
    _schedulePoll();
    return data;
  }

  void _schedulePoll() {
    _poll?.cancel();
    if (!_foreground) return;
    _poll = Timer.periodic(pollInterval, (_) => revalidate());
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    if (foreground) {
      revalidateIfStale();
      _schedulePoll();
    } else {
      _poll?.cancel();
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Refaz a consulta mantendo a lista na tela (uma falha não apaga nada).
  void revalidate() {
    if (state.isLoading || _markingAll) return;
    ref.invalidateSelf();
  }

  void revalidateIfStale() {
    final loadedAt = _loadedAt;
    if (loadedAt == null) return;
    if (ref.read(clockProvider)().difference(loadedAt) > maxAge) revalidate();
  }

  /// Marca tudo como lido na hora e confirma no servidor; se falhar, volta ao estado anterior e
  /// relança para a tela avisar. Uma chamada por vez.
  Future<void> markAllRead() async {
    final before = state.value;
    if (before == null || before.unreadCount == 0 || _markingAll) return;
    final userId = ref.read(currentUserIdProvider);

    _markingAll = true;
    state = AsyncData(before.allRead());
    try {
      await ref.read(notificationsRepositoryProvider).markAllRead();
    } catch (_) {
      if (ref.read(currentUserIdProvider) == userId) state = AsyncData(before);
      rethrow;
    } finally {
      _markingAll = false;
    }
  }
}

final notificationsControllerProvider =
    AsyncNotifierProvider<NotificationsController, NotificationsData>(
      NotificationsController.new,
    );

/// Quantas notificações não lidas (para o selo do sino).
final unreadNotificationsProvider = Provider<int>(
  (ref) => ref.watch(notificationsControllerProvider).value?.unreadCount ?? 0,
);
