import 'dart:io';

/// Os goldens do repositório foram gerados no macOS, e o desenho de bordas, sombras e
/// gradientes muda de plataforma para plataforma (o CI roda em Linux). Fora do macOS, a
/// comparação de pixels é pulada com este motivo; o comportamento dessas telas continua
/// coberto pelos demais testes de widget, que rodam em qualquer sistema.
final bool goldenSkip = !Platform.isMacOS;
