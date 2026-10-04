import 'api_config.dart';

/// URLs de imagem do backend (`/api/images/...` e `/uploads/...`) vêm montadas com
/// `PUBLIC_API_URL`. Em desenvolvimento isso aponta para `localhost`, que não é o
/// servidor visto de dentro do emulador. Estas rotas são reescritas para o host
/// que o app realmente usa; qualquer outra URL passa sem mudança.
abstract final class ImageUrls {
  static String? resolve(String? url, {String? baseUrl}) {
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return url;
    final isBackendPath =
        uri.path.startsWith('/api/images/') || uri.path.startsWith('/uploads/');
    if (!isBackendPath) return url;

    final base = Uri.parse(baseUrl ?? ApiConfig.baseUrl);
    // Reconstruir (e não `replace`): `replace(port: null)` manteria a porta original.
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: uri.path,
      query: uri.hasQuery ? uri.query : null,
    ).toString();
  }
}
