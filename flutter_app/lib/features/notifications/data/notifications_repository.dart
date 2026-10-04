import 'package:dio/dio.dart';

import '../../../core/network/app_exception.dart';
import 'notification_models.dart';

abstract interface class NotificationsRepository {
  Future<NotificationsData> list();

  /// Marca TODAS como lidas (o backend não tem leitura individual).
  Future<void> markAllRead();
}

class RemoteNotificationsRepository implements NotificationsRepository {
  RemoteNotificationsRepository(this._dio);
  final Dio _dio;

  @override
  Future<NotificationsData> list() => guardApi(() async {
    final r = await _dio.get<Map<String, dynamic>>('/notifications');
    return NotificationsData.fromJson(r.data!);
  });

  @override
  Future<void> markAllRead() => guardApi(() async {
    await _dio.post<void>('/notifications/read-all');
  });
}
