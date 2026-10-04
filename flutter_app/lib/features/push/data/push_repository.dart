import 'package:dio/dio.dart';

import '../../../core/network/app_exception.dart';

abstract interface class PushRepository {
  /// Idempotente: repetir com os mesmos dados não muda nada. Se a instalação era de outra
  /// conta, passa a ser da conta atual.
  Future<void> register({
    required String installationId,
    required String provider,
    required String platform,
    required String token,
  });

  Future<void> revoke(String installationId);
}

class RemotePushRepository implements PushRepository {
  RemotePushRepository(this._dio);
  final Dio _dio;

  @override
  Future<void> register({
    required String installationId,
    required String provider,
    required String platform,
    required String token,
  }) => guardApi(() async {
    await _dio.put<void>(
      '/push/installations/$installationId',
      data: {'provider': provider, 'platform': platform, 'token': token},
    );
  });

  @override
  Future<void> revoke(String installationId) => guardApi(() async {
    await _dio.delete<void>('/push/installations/$installationId');
  });
}
