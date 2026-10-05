import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda só o refresh token. O access token vive em memória (docs/MIGRACAO_FLUTTER.md, decisão 3).
abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String refreshToken);
  Future<void> clear();
}

/// Armazenamento seguro do sistema (Keystore no Android).
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'refresh_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String refreshToken) =>
      _storage.write(key: _key, value: refreshToken);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// Sem persistência. Usado na web (docs/MIGRACAO_FLUTTER.md, decisão 3: novo login ao recarregar) e em testes.
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this._value]);
  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String refreshToken) async => _value = refreshToken;

  @override
  Future<void> clear() async => _value = null;
}
