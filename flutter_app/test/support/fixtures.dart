import 'dart:convert';
import 'dart:io';

/// Lê uma resposta real gravada em `docs/contract-fixtures/responses` (só o corpo).
Object? fixtureBody(String name) {
  final file = File('../docs/contract-fixtures/responses/$name.json');
  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return decoded['body'];
}
