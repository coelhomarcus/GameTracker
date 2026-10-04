import 'dart:async';
import 'package:dio/dio.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

Future<io.Socket> connect(String? token) {
  final c = Completer<io.Socket>();
  final s = io.io('http://localhost:3100', io.OptionBuilder()
      .setTransports(['websocket'])
      .enableForceNew()
      .disableAutoConnect()
      .disableReconnection()
      .setAuth(token == null ? {} : {'token': token})
      .build());
  s.onConnect((_) => c.complete(s));
  s.onConnectError((e) { if (!c.isCompleted) c.completeError('connect_error: $e'); });
  s.connect();
  return c.future.timeout(const Duration(seconds: 8));
}

Future<void> main() async {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3100/api', validateStatus: (_) => true));
  final n = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  Future<Map> reg(String p) async => (await dio.post('/auth/register', data: {
        'username': '${p}_$n', 'name': p, 'email': '${p}_$n@example.test', 'password': 'senha-fixture-123'
      })).data as Map;
  final a = await reg('sa'), b = await reg('sb');


  try { await connect(null); print('FAIL: sem token conectou'); } catch (e) { print('OK sem token rejeitado: $e'); }

  final sa = await connect(a['accessToken']);
  final sb = await connect(b['accessToken']);
  print('OK conectados com auth.token');

  final conv = (await dio.post('/conversations',
      data: {'userId': b['user']['id']},
      options: Options(headers: {'authorization': 'Bearer ${a['accessToken']}'}))).data as Map;
  final cid = conv['id'];

  Future<dynamic> emitAck(io.Socket s, String ev, dynamic data) {
    final c = Completer();
    s.emitWithAck(ev, data, ack: (r) => c.complete(r));
    return c.future.timeout(const Duration(seconds: 5), onTimeout: () => 'TIMEOUT');
  }

  print('join A: ${await emitAck(sa, 'conversation:join', {'conversationId': cid})}');
  print('join B: ${await emitAck(sb, 'conversation:join', {'conversationId': cid})}');
  print('join inexistente: ${await emitAck(sa, 'conversation:join', {'conversationId': '00000000-0000-0000-0000-000000000000'})}');

  final got = Completer();
  sb.on('message:receive', (m) => got.complete(m));
  final ack = await emitAck(sa, 'message:send', {'conversationId': cid, 'content': 'oi do dart'});
  print('ACK send: $ack');
  print('receive em B: ${await got.future.timeout(const Duration(seconds: 5))}');
  sa.dispose(); sb.dispose();
}
