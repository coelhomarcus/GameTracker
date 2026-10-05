import 'dart:convert';
import 'dart:io';

/// Lê uma resposta real do backend guardada em `test/fixtures/<nome>.json` (só o corpo).
/// Veja `test/fixtures/README.md`.
Object? fixtureBody(String name) {
  final file = File('test/fixtures/$name.json');
  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return decoded['body'];
}
