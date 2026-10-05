import 'package:dio/dio.dart';

/// Falhas de acesso a dados, já em termos de domínio (docs/MIGRACAO_FLUTTER.md).
sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Resposta HTTP de erro. `code` vem do envelope `{ error: { code, message } }`
/// ou, quando o corpo não segue o envelope (ex.: rate limiter), é derivado do status.
class ApiException extends AppException {
  const ApiException(this.status, this.code, super.message);
  final int status;
  final String code;

  bool get isUnauthorized => status == 401;
  bool get isConflict => status == 409;
  bool get isRateLimited => status == 429;
  bool get isServerError => status >= 500;
}

/// Sem resposta: offline, DNS, timeout ou conexão recusada.
class NetworkException extends AppException {
  const NetworkException([super.message = 'Sem conexão com o servidor']);
}

/// Requisição descartada de propósito (ex.: resposta de uma sessão anterior).
class CancelledException extends AppException {
  const CancelledException([super.message = 'Requisição cancelada']);
}

AppException mapDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.cancel:
      return const CancelledException();
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const NetworkException();
    case DioExceptionType.badResponse:
      return _fromResponse(e.response);
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      final inner = e.error;
      if (inner is AppException) return inner;
      return const NetworkException();
  }
}

ApiException _fromResponse(Response<dynamic>? response) {
  final status = response?.statusCode ?? 0;
  final data = response?.data;
  if (data is Map && data['error'] is Map) {
    final error = data['error'] as Map;
    final code = error['code'];
    final message = error['message'];
    if (code is String && message is String) {
      return ApiException(status, code, message);
    }
  }
  // Corpo fora do envelope (rate limiter, proxy, HTML de erro): usa só o status.
  return ApiException(
    status,
    _codeForStatus(status),
    _messageForStatus(status),
  );
}

String _codeForStatus(int status) => switch (status) {
  400 => 'bad_request',
  401 => 'unauthorized',
  403 => 'forbidden',
  404 => 'not_found',
  409 => 'conflict',
  429 => 'rate_limited',
  >= 500 => 'server_error',
  _ => 'unknown',
};

String _messageForStatus(int status) => switch (status) {
  429 => 'Muitas tentativas. Aguarde um pouco e tente de novo.',
  >= 500 => 'O servidor está com problemas. Tente de novo em instantes.',
  _ => 'Não foi possível concluir a operação.',
};

/// Executa uma chamada Dio e devolve só [AppException] para o resto do app.
Future<T> guardApi<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    throw mapDioException(e);
  } on FormatException {
    throw const ApiException(
      0,
      'invalid_response',
      'Resposta inválida do servidor.',
    );
  }
}
