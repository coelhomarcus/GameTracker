import 'package:dio/dio.dart';

import 'session_manager.dart';

/// Chaves de `RequestOptions.extra`.
abstract final class RequestFlags {
  /// Rotas de autenticação não levam Bearer nem disparam refresh.
  static const skipAuth = 'skipAuth';
  static const retried = 'authRetried';
  static const _usedToken = 'usedAccessToken';
  static const _generation = 'sessionGeneration';
}

/// Anexa o Bearer, renova a sessão em 401 (no máximo uma repetição) e descarta
/// respostas que chegam depois de um logout ou troca de conta.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.session, required this.dio});

  final SessionManager session;

  /// Cliente usado para repetir a requisição (o mesmo que tem este interceptor).
  final Dio dio;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra[RequestFlags.skipAuth] != true) {
      final token = session.accessToken;
      options.extra[RequestFlags._usedToken] = token;
      options.extra[RequestFlags._generation] = session.generation;
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (_isFromPreviousSession(response.requestOptions)) {
      handler.reject(_cancelled(response.requestOptions));
      return;
    }
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final isAuthRoute = options.extra[RequestFlags.skipAuth] == true;
    if (err.response?.statusCode != 401 ||
        isAuthRoute ||
        options.extra[RequestFlags.retried] == true) {
      handler.next(err);
      return;
    }
    if (_isFromPreviousSession(options)) {
      handler.reject(_cancelled(options));
      return;
    }

    final outcome = await session.refreshAfterUnauthorized(
      options.extra[RequestFlags._usedToken] as String?,
    );
    switch (outcome) {
      case RefreshOutcome.refreshed:
        try {
          final retry = options.copyWith(
            extra: {...options.extra, RequestFlags.retried: true},
          );
          handler.resolve(await dio.fetch<dynamic>(retry));
        } on DioException catch (e) {
          handler.next(e);
        }
      case RefreshOutcome.discarded:
        handler.reject(_cancelled(options));
      case RefreshOutcome.invalid:
      case RefreshOutcome.unavailable:
      case RefreshOutcome.noSession:
        handler.next(err);
    }
  }

  bool _isFromPreviousSession(RequestOptions options) {
    final generation = options.extra[RequestFlags._generation];
    return generation is int && generation != session.generation;
  }

  DioException _cancelled(RequestOptions options) => DioException(
    requestOptions: options,
    type: DioExceptionType.cancel,
    error: 'Resposta de uma sessão anterior',
  );
}
