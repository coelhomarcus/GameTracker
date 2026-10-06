import 'dart:io';

import 'package:flutter/services.dart';

/// Os goldens do repositório foram gerados no macOS, e o desenho de bordas, sombras e
/// gradientes muda de plataforma para plataforma (o CI roda em Linux). Fora do macOS, a
/// comparação de pixels é pulada com este motivo; o comportamento dessas telas continua
/// coberto pelos demais testes de widget, que rodam em qualquer sistema.
final bool goldenSkip = !Platform.isMacOS;

const goldenFontFamily = 'Roboto';
bool _fontsLoaded = false;

/// Usa a Roboto distribuída com o próprio Flutter. Assim as capturas mostram texto legível sem
/// adicionar uma fonte ao bundle do aplicativo, que continua usando a fonte do sistema.
Future<void> loadGoldenFonts() async {
  if (goldenSkip || _fontsLoaded) return;

  var directory = File(Platform.resolvedExecutable).parent;
  File? font;
  for (var i = 0; i < 8; i++) {
    final candidate = File(
      '${directory.path}/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
    );
    if (candidate.existsSync()) {
      font = candidate;
      break;
    }
    directory = directory.parent;
  }
  if (font == null) {
    throw StateError('Roboto-Regular.ttf não encontrada no SDK do Flutter.');
  }

  final bytes = await font.readAsBytes();
  final loader = FontLoader(goldenFontFamily)
    ..addFont(Future.value(bytes.buffer.asByteData()));
  await loader.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
  _fontsLoaded = true;
}
