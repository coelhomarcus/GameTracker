import 'dart:async';
import 'dart:convert';

import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Adaptador HTTP roteirizado para testes: sem rede, com controle de tempo.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(int status, Object? body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

ResponseBody errorResponse(int status, String code, String message) =>
    jsonResponse(status, {
      'error': {'code': code, 'message': message},
    });
