import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gametracker/core/models/user_summary.dart';
import 'package:gametracker/core/network/app_exception.dart';
import 'package:gametracker/features/auth/data/auth_models.dart';
import 'package:gametracker/features/auth/data/auth_repository.dart';
import 'package:gametracker/features/profiles/application/profile_image_picker.dart';
import 'package:gametracker/features/profiles/data/profile_models.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_feed.dart';
import '../../support/fake_profiles.dart';
import '../../support/harness.dart';

const _me = AuthUser(
  id: 'u1',
  username: 'ana',
  email: 'ana@example.test',
  name: 'Ana Silva',
  bio: 'Minha bio',
);

Finder get nameField => find.widgetWithText(TextFormField, 'Nome');
Finder get usernameField => find.widgetWithText(TextFormField, 'Username');
Finder get bioField => find.widgetWithText(TextFormField, 'Bio');

/// O botão do perfil (o título da tela de edição também diz "Editar perfil").
Finder get profileEditButton =>
    find.widgetWithText(OutlinedButton, 'Editar perfil');
Finder get save => find.widgetWithText(FilledButton, 'Salvar alterações');

/// Abre a edição por cima do perfil (como o usuário chega: Perfil → Editar perfil).
Future<AppHarness> openEdit(
  WidgetTester tester, {
  FakeProfilesRepository? profiles,
  FakeImagePicker? picker,
  FakeImageCropper? cropper,
  FakeAuthRepository? auth,
}) async {
  final a = auth ?? FakeAuthRepository();
  a.restoreResult = Restored(_me);
  final p = profiles ?? FakeProfilesRepository();
  p.profiles['u1'] = fakeProfile(id: 'u1', username: 'ana', name: 'Ana Silva');
  final h = AppHarness(auth: a, profiles: p, picker: picker, cropper: cropper);
  await h.pump(tester);
  await tapAndSettle(tester, find.text('Perfil').last);
  await tapAndSettle(tester, profileEditButton);
  return h;
}

void main() {
  testWidgets('abre com os valores atuais', (tester) async {
    await openEdit(tester);
    expect(
      tester.widget<TextFormField>(nameField).controller!.text,
      'Ana Silva',
    );
    expect(tester.widget<TextFormField>(usernameField).controller!.text, 'ana');
    expect(
      tester.widget<TextFormField>(bioField).controller!.text,
      'Minha bio',
    );
    expect(find.text('Salvas ao confirmar o recorte.'), findsOneWidget);
    expect(find.text('Salvas no botão Salvar alterações.'), findsOneWidget);
  });

  group('textos', () {
    testWidgets('salva só o que mudou e volta ao perfil', (tester) async {
      final h = await openEdit(tester);
      await tester.enterText(bioField, 'Bio nova');
      await tester.pumpAndSettle();
      await tapAndSettle(tester, save);
      expect(h.profiles.updates.single.toJson(), {'bio': 'Bio nova'});
      expect(profileEditButton, findsOneWidget, reason: 'de volta ao perfil');
    });

    testWidgets('apagar a bio envia string vazia (limpa)', (tester) async {
      final h = await openEdit(tester);
      await tester.enterText(bioField, '');
      await tester.pumpAndSettle();
      await tapAndSettle(tester, save);
      expect(h.profiles.updates.single.toJson(), {'bio': ''});
    });

    testWidgets('sem alterações não faz requisição', (tester) async {
      final h = await openEdit(tester);
      await tapAndSettle(tester, save);
      expect(h.profiles.updates, isEmpty);
      expect(profileEditButton, findsOneWidget);
    });

    testWidgets(
      'a identidade nova aparece no perfil, na sessão e nos posts carregados',
      (tester) async {
        final auth = FakeAuthRepository();
        final feed = FakeFeedRepository(
          general: [
            fakePost(
              id: 'p1',
              author: const UserSummary(
                id: 'u1',
                username: 'ana',
                name: 'Ana Silva',
              ),
              content: 'Meu post',
            ),
          ],
        );
        final profiles = FakeProfilesRepository();
        auth.restoreResult = Restored(_me);
        profiles.profiles['u1'] = fakeProfile(
          id: 'u1',
          username: 'ana',
          name: 'Ana Silva',
        );
        final h = AppHarness(auth: auth, profiles: profiles, feed: feed);
        await h.pump(tester);
        await tapAndSettle(tester, find.text('Comunidade').last);
        expect(find.text('Ana Silva'), findsOneWidget);

        await tapAndSettle(tester, find.text('Perfil').last);
        await tapAndSettle(tester, profileEditButton);
        auth.meResult = const AuthUser(
          id: 'u1',
          username: 'ana',
          email: 'ana@example.test',
          name: 'Ana Souza',
        );
        profiles.profiles['u1'] = fakeProfile(
          id: 'u1',
          username: 'ana',
          name: 'Ana Souza',
        );
        await tester.enterText(nameField, 'Ana Souza');
        await tester.pumpAndSettle();
        await tapAndSettle(tester, save);
        expect(h.profiles.updates.single.toJson(), {'name': 'Ana Souza'});
        expect(
          find.text('Ana Souza'),
          findsWidgets,
          reason: 'perfil recarregado',
        );

        await tapAndSettle(tester, find.text('Comunidade').last);
        expect(
          find.text('Ana Souza'),
          findsOneWidget,
          reason: 'post já carregado mostra o nome novo',
        );
        expect(find.text('Ana Silva'), findsNothing);
      },
    );

    testWidgets('username repetido (409) marca o campo e preserva o resto', (
      tester,
    ) async {
      final profiles = FakeProfilesRepository()
        ..updateError = const ApiException(
          409,
          'conflict',
          'Username já está em uso',
        );
      final h = await openEdit(tester, profiles: profiles);
      await tester.enterText(usernameField, 'beto');
      await tester.enterText(bioField, 'Bio que não pode sumir');
      await tester.pumpAndSettle();
      await tapAndSettle(tester, save);

      expect(find.text('Esse username já está em uso'), findsOneWidget);
      expect(
        find.text('Bio que não pode sumir'),
        findsOneWidget,
        reason: 'o resto do formulário continua',
      );
      expect(h.profiles.updates, isEmpty);

      await tester.enterText(usernameField, 'beto2');
      profiles.updateError = null;
      await tester.pumpAndSettle();
      await tapAndSettle(tester, save);
      expect(h.profiles.updates.single.toJson(), {
        'username': 'beto2',
        'bio': 'Bio que não pode sumir',
      });
    });

    testWidgets('falha genérica mostra aviso e preserva tudo', (tester) async {
      final profiles = FakeProfilesRepository()
        ..updateError = const NetworkException();
      await openEdit(tester, profiles: profiles);
      await tester.enterText(nameField, 'Outro Nome');
      await tester.pumpAndSettle();
      await tapAndSettle(tester, save);
      expect(find.textContaining('Sem conexão'), findsWidgets);
      expect(find.text('Outro Nome'), findsOneWidget);
      expect(profileEditButton, findsNothing, reason: 'continua na edição');
    });

    testWidgets('valida nome vazio e username curto ou inválido', (
      tester,
    ) async {
      final h = await openEdit(tester);
      await tester.enterText(nameField, '  ');
      await tester.enterText(usernameField, 'ab');
      await tapAndSettle(tester, save);
      expect(find.text('Informe seu nome'), findsOneWidget);
      expect(find.text('Use pelo menos 3 caracteres'), findsOneWidget);
      await tester.enterText(usernameField, 'com espaço');
      await tapAndSettle(tester, save);
      expect(find.text('Use apenas letras, números e _'), findsOneWidget);
      expect(h.profiles.updates, isEmpty);
    });

    testWidgets('sair com alterações explica o que se perde e o que não', (
      tester,
    ) async {
      final h = AppHarness(
        auth: FakeAuthRepository()..restoreResult = Restored(_me),
        profiles: FakeProfilesRepository()
          ..profiles['u1'] = fakeProfile(
            id: 'u1',
            username: 'ana',
            name: 'Ana Silva',
          ),
      );
      await h.pump(tester);
      await tapAndSettle(tester, find.text('Perfil').last);
      await tapAndSettle(tester, profileEditButton);
      await tester.enterText(bioField, 'rascunho');
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Descartar alterações?'), findsOneWidget);
      expect(
        find.textContaining('Fotos que você já enviou continuam salvas'),
        findsOneWidget,
      );
      await tapAndSettle(tester, find.text('Continuar editando'));
      expect(find.text('rascunho'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('Descartar'));
      expect(profileEditButton, findsOneWidget, reason: 'voltou ao perfil');
    });
  });

  group('foto e capa', () {
    testWidgets('escolher a foto mostra a prévia, envia e avisa', (
      tester,
    ) async {
      final picker = FakeImagePicker()..next = fakeImage();
      final auth = FakeAuthRepository();
      final h = await openEdit(tester, picker: picker, auth: auth);
      auth.meResult = const AuthUser(
        id: 'u1',
        username: 'ana',
        email: 'ana@example.test',
        name: 'Ana Silva',
        avatarUrl: 'http://localhost:3100/uploads/avatars/new.jpg',
      );

      await tapAndSettle(tester, find.text('Alterar foto'));
      expect(h.profiles.uploads.single.$1, ProfileImageKind.avatar);
      expect(
        find.byType(Image),
        findsWidgets,
        reason: 'pré-visualização local',
      );
      expect(find.text('Foto atualizada'), findsOneWidget);
      expect(
        find.byType(LinearProgressIndicator),
        findsNothing,
        reason: 'envio terminou',
      );
    });

    testWidgets('escolher a capa usa o campo da capa', (tester) async {
      final picker = FakeImagePicker()
        ..next = fakeImage(name: 'capa.jpg', mime: 'image/jpeg');
      final h = await openEdit(tester, picker: picker);
      await tapAndSettle(tester, find.text('Alterar capa'));
      expect(h.profiles.uploads.single.$1, ProfileImageKind.banner);
      expect(h.profiles.uploads.single.$2.mimeType, 'image/jpeg');
      expect(find.text('Capa atualizada'), findsOneWidget);
    });

    testWidgets('mostra o progresso enquanto envia e bloqueia novo envio', (
      tester,
    ) async {
      final gate = Completer<void>();
      final picker = FakeImagePicker()..next = fakeImage();
      final profiles = FakeProfilesRepository()..uploadGate = gate;
      await openEdit(tester, picker: picker, profiles: profiles);

      await tester.tap(find.text('Alterar foto'));
      await tester.pump();
      await tester.pump();
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 0.5, reason: 'progresso reportado pelo envio');
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Alterar foto'),
            )
            .onPressed,
        isNull,
      );

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('salvar enquanto uma imagem envia é recusado com aviso', (
      tester,
    ) async {
      final gate = Completer<void>();
      final picker = FakeImagePicker()..next = fakeImage();
      final profiles = FakeProfilesRepository()..uploadGate = gate;
      final h = await openEdit(tester, picker: picker, profiles: profiles);
      await tester.tap(find.text('Alterar foto'));
      await tester.pump();
      await tester.enterText(bioField, 'nova');
      await tester.pump();
      await tester.tap(save);
      await tester.pump();
      expect(find.text('Aguarde o envio da imagem terminar.'), findsOneWidget);
      expect(h.profiles.updates, isEmpty);
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('arquivo acima de 8 MB é recusado antes de enviar', (
      tester,
    ) async {
      final picker = FakeImagePicker()
        ..next = fakeImage(size: PickedImage.maxBytes + 1);
      final h = await openEdit(tester, picker: picker);
      await tapAndSettle(tester, find.text('Alterar foto'));
      expect(
        find.text(
          'A imagem passa de 8 MB. Reduza o tamanho e escolha de novo.',
        ),
        findsOneWidget,
      );
      expect(h.profiles.uploads, isEmpty, reason: 'nem tenta enviar');
      expect(
        h.cropper.calls,
        isEmpty,
        reason: 'nem abre o editor com arquivo acima do limite',
      );
      expect(
        find.text('Tentar de novo'),
        findsNothing,
        reason: 'reenviar o mesmo arquivo não adiantaria',
      );
    });

    group('recorte', () {
      testWidgets('o editor recebe a imagem e o tipo; o envio usa o recorte', (
        tester,
      ) async {
        final original = fakeImage(name: 'original.png');
        final cropped = fakeImage(name: 'avatar.jpg', mime: 'image/jpeg');
        final cropper = FakeImageCropper()..result = cropped;
        final h = await openEdit(
          tester,
          picker: FakeImagePicker()..next = original,
          cropper: cropper,
        );
        await tapAndSettle(tester, find.text('Alterar foto'));

        expect(cropper.calls.single, (original, ProfileImageKind.avatar));
        expect(h.profiles.uploads.single.$1, ProfileImageKind.avatar);
        expect(
          h.profiles.uploads.single.$2,
          same(cropped),
          reason: 'o servidor recebe o arquivo recortado, não o original',
        );
      });

      testWidgets('a capa abre o editor no modo capa', (tester) async {
        final cropper = FakeImageCropper();
        await openEdit(
          tester,
          picker: FakeImagePicker()..next = fakeImage(),
          cropper: cropper,
        );
        await tapAndSettle(tester, find.text('Alterar capa'));
        expect(cropper.calls.single.$2, ProfileImageKind.banner);
      });

      testWidgets('cancelar o recorte não envia nem altera a foto', (
        tester,
      ) async {
        final cropper = FakeImageCropper()..cancel = true;
        final h = await openEdit(
          tester,
          picker: FakeImagePicker()..next = fakeImage(),
          cropper: cropper,
        );
        await tapAndSettle(tester, find.text('Alterar foto'));

        expect(cropper.calls, hasLength(1));
        expect(h.profiles.uploads, isEmpty);
        expect(find.byType(Image), findsNothing, reason: 'sem prévia nova');
        expect(find.textContaining('Foto atualizada'), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsNothing);
      });

      testWidgets('cancelar a galeria nem abre o editor', (tester) async {
        final cropper = FakeImageCropper();
        await openEdit(
          tester,
          picker: FakeImagePicker()..next = null,
          cropper: cropper,
        );
        await tapAndSettle(tester, find.text('Alterar foto'));
        expect(cropper.calls, isEmpty);
      });

      testWidgets('falha no envio reenvia os mesmos bytes recortados', (
        tester,
      ) async {
        final cropped = fakeImage(name: 'avatar.jpg', mime: 'image/jpeg');
        final cropper = FakeImageCropper()..result = cropped;
        final profiles = FakeProfilesRepository()
          ..uploadError = const NetworkException();
        final h = await openEdit(
          tester,
          picker: FakeImagePicker()..next = fakeImage(),
          cropper: cropper,
          profiles: profiles,
        );
        await tapAndSettle(tester, find.text('Alterar foto'));

        profiles.uploadError = null;
        await tapAndSettle(tester, find.text('Tentar de novo'));
        expect(cropper.calls, hasLength(1), reason: 'não reabre o editor');
        expect(h.profiles.uploads, hasLength(2));
        expect(h.profiles.uploads.last.$2, same(cropped));
      });
    });

    testWidgets('fotos e informações são seções separadas', (tester) async {
      await openEdit(tester);
      expect(find.text('Fotos'), findsOneWidget);
      expect(find.text('Informações'), findsOneWidget);
    });

    testWidgets(
      'falha no envio mostra o motivo e tenta de novo sem reabrir a galeria',
      (tester) async {
        final picker = FakeImagePicker()..next = fakeImage();
        final profiles = FakeProfilesRepository()
          ..uploadError = const ApiException(
            400,
            'validation_error',
            'Imagem inválida ou corrompida',
          );
        final h = await openEdit(tester, picker: picker, profiles: profiles);
        await tapAndSettle(tester, find.text('Alterar foto'));
        expect(find.text('Imagem inválida ou corrompida'), findsOneWidget);
        expect(picker.calls, 1);

        profiles.uploadError = null;
        await tapAndSettle(tester, find.text('Tentar de novo'));
        expect(picker.calls, 1, reason: 'reenviou a mesma imagem');
        expect(h.profiles.uploads.length, 2);
        expect(find.text('Foto atualizada'), findsOneWidget);
      },
    );

    testWidgets('sem conexão no envio usa a mensagem de rede', (tester) async {
      final picker = FakeImagePicker()..next = fakeImage();
      final profiles = FakeProfilesRepository()
        ..uploadError = const NetworkException();
      await openEdit(tester, picker: picker, profiles: profiles);
      await tapAndSettle(tester, find.text('Alterar foto'));
      expect(find.textContaining('Sem conexão'), findsOneWidget);
    });

    testWidgets('cancelar a galeria não faz nada', (tester) async {
      final picker = FakeImagePicker()..next = null;
      final h = await openEdit(tester, picker: picker);
      await tapAndSettle(tester, find.text('Alterar foto'));
      expect(picker.calls, 1);
      expect(h.profiles.uploads, isEmpty);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('permissão negada vira aviso claro', (tester) async {
      final picker = FakeImagePicker()
        ..error = const ImagePickException(
          'Sem permissão para acessar as fotos. Libere o acesso nas configurações do aparelho.',
        );
      await openEdit(tester, picker: picker);
      await tapAndSettle(tester, find.text('Alterar foto'));
      expect(
        find.textContaining('Sem permissão para acessar as fotos'),
        findsOneWidget,
      );
    });

    testWidgets('foto já enviada continua salva mesmo descartando os textos', (
      tester,
    ) async {
      final picker = FakeImagePicker()..next = fakeImage();
      final h = await openEdit(tester, picker: picker);
      await tapAndSettle(tester, find.text('Alterar foto'));
      await tester.enterText(bioField, 'descartar isto');
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('Descartar'));
      expect(
        h.profiles.uploads,
        hasLength(1),
        reason: 'o envio já tinha sido feito',
      );
      expect(
        h.profiles.updates,
        isEmpty,
        reason: 'só os textos foram descartados',
      );
    });
  });

  testWidgets('layout a 360 px com texto 200% não estoura', (tester) async {
    final a = FakeAuthRepository()..restoreResult = Restored(_me);
    final p = FakeProfilesRepository()
      ..profiles['u1'] = fakeProfile(
        id: 'u1',
        username: 'ana',
        name: 'Ana Silva',
      );
    final h = AppHarness(auth: a, profiles: p);
    await h.pump(tester, size: const Size(360, 800), textScale: 2.0);
    await goTo(tester, '/me/edit');
    expect(tester.takeException(), isNull);
  });
}
