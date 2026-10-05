import '../../../core/network/app_exception.dart';

/// Mensagem para o usuário a partir da falha de uma ação de autenticação.
String authErrorMessage(Object error) {
  if (error is NetworkException) {
    return 'Sem conexão com o servidor. Verifique a internet e tente de novo.';
  }
  if (error is ApiException) {
    if (error.code == 'invalid_credentials') {
      return 'E-mail, username ou senha incorretos.';
    }
    if (error.isConflict) {
      return 'Username ou e-mail já cadastrado.';
    }
    if (error.isRateLimited || error.isServerError) {
      return error.message;
    }
    if (error.status == 400) {
      return 'Dados inválidos. Revise os campos.';
    }
  }
  return 'Não foi possível concluir. Tente de novo.';
}
