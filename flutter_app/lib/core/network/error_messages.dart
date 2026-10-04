import 'app_exception.dart';

/// Mensagem para o usuário a partir de qualquer falha de leitura ou escrita de dados.
String describeError(Object error) {
  if (error is NetworkException) {
    return 'Sem conexão com o servidor. Verifique a internet e tente de novo.';
  }
  if (error is ApiException) {
    switch (error.code) {
      case 'igdb_not_configured':
        return 'A busca de jogos ainda não está configurada no servidor.';
      case 'igdb_request_failed':
        return 'A base de jogos não respondeu. Tente de novo em instantes.';
    }
    if (error.status == 404) return 'Não encontrado.';
    if (error.status == 403) return 'Você não tem permissão para isso.';
    if (error.isRateLimited || error.isServerError) return error.message;
    if (error.status == 400) return 'Dados inválidos. Revise os campos.';
  }
  return 'Algo deu errado. Tente de novo.';
}
