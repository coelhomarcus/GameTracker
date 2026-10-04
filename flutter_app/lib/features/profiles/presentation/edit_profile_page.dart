import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/providers.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/design_system/user_avatar.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/network/error_messages.dart';
import '../../../core/network/image_url.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/presentation/auth_form_scaffold.dart';
import '../../auth/presentation/session_state.dart';
import '../application/profile_editor.dart';
import '../application/profile_image_picker.dart';
import '../data/profile_models.dart';

final _usernamePattern = RegExp(r'^[a-zA-Z0-9_]+$');

/// Estado de envio de uma imagem. O backend salva na hora: não existe "desfazer" nem "cancelar".
class _ImageUpload {
  const _ImageUpload({
    this.local,
    this.progress,
    this.error,
    this.done = false,
  });

  /// A imagem escolhida, mostrada como pré-visualização enquanto envia e depois de enviar.
  final PickedImage? local;
  final double? progress;
  final String? error;
  final bool done;

  bool get uploading => progress != null;
}

/// Editar nome, username, bio, foto e capa. Cada imagem é enviada assim que é escolhida;
/// os textos só são salvos em "Salvar".
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _bio;
  late final AuthUser _initial;

  final _uploads = <ProfileImageKind, _ImageUpload>{
    ProfileImageKind.avatar: const _ImageUpload(),
    ProfileImageKind.banner: const _ImageUpload(),
  };

  bool _saving = false;
  bool _saved = false;
  String? _error;
  String? _usernameConflict;

  @override
  void initState() {
    super.initState();
    final session = ref.read(sessionControllerProvider);
    _initial = session is SessionAuthenticated
        ? session.user
        : const AuthUser(id: '', username: '', email: '');
    _name = TextEditingController(text: _initial.name ?? '');
    _username = TextEditingController(text: _initial.username);
    _bio = TextEditingController(text: _initial.bio ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  String? get _bioBefore =>
      (_initial.bio == null || _initial.bio!.trim().isEmpty)
      ? null
      : _initial.bio!.trim();

  ProfileChanges _changes() {
    final name = _name.text.trim();
    final username = _username.text.trim();
    final bio = _bio.text.trim();
    return ProfileChanges(
      name: name != (_initial.name ?? '') ? name : null,
      username: username != _initial.username ? username : null,
      // Bio vazia limpa a bio (o backend guarda ''); só é enviada se mudou de verdade.
      bio: bio != (_bioBefore ?? '') ? bio : null,
    );
  }

  bool get _dirty => !_saved && !_saving && !_changes().isEmpty;

  Future<void> _pickAndUpload(ProfileImageKind kind) async {
    final messenger = ScaffoldMessenger.of(context);
    final PickedImage? image;
    try {
      image = await ref.read(profileImagePickerProvider).pick();
    } on ImagePickException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (image == null || !mounted) return; // cancelou
    await _upload(kind, image);
  }

  Future<void> _upload(ProfileImageKind kind, PickedImage image) async {
    if (image.isTooLarge) {
      setState(
        () => _uploads[kind] = _ImageUpload(
          local: image,
          error: 'A imagem passa de 8 MB. Escolha uma menor.',
        ),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final cancel = CancelToken();
    setState(() => _uploads[kind] = _ImageUpload(local: image, progress: 0));
    try {
      await ref
          .read(profileEditorProvider)
          .uploadImage(
            kind,
            image,
            cancelToken: cancel,
            onProgress: (fraction) {
              if (mounted) {
                setState(
                  () => _uploads[kind] = _ImageUpload(
                    local: image,
                    progress: fraction,
                  ),
                );
              }
            },
          );
      if (!mounted) return;
      setState(() => _uploads[kind] = _ImageUpload(local: image, done: true));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            kind == ProfileImageKind.avatar
                ? 'Foto atualizada'
                : 'Capa atualizada',
          ),
        ),
      );
    } catch (e) {
      // Mantém a imagem escolhida: "Tentar de novo" reenvia sem abrir a galeria.
      if (mounted) {
        setState(
          () => _uploads[kind] = _ImageUpload(
            local: image,
            error: describeUploadError(e),
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _usernameConflict = null);
    if (!_formKey.currentState!.validate()) return;
    if (_uploads.values.any((u) => u.uploading)) {
      setState(() => _error = 'Aguarde o envio da imagem terminar.');
      return;
    }

    final changes = _changes();
    if (changes.isEmpty) {
      _leave();
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(profileEditorProvider).save(changes);
      messenger.showSnackBar(
        const SnackBar(content: Text('Perfil atualizado')),
      );
      if (!mounted) return;
      _finishAndLeave();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isConflict) {
        // Conflito é do campo, não do formulário: o resto continua intacto.
        setState(() => _usernameConflict = _username.text.trim());
        _formKey.currentState!.validate();
      } else {
        setState(() => _error = describeError(e));
      }
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Marca como concluído e sai no frame seguinte: o `PopScope` só enxerga o valor novo de
  /// `canPop` depois de reconstruir, e `pop()` na mesma pilha de chamadas ainda seria barrado.
  void _finishAndLeave() {
    setState(() => _saved = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _leave();
    });
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/me');
    }
  }

  Future<void> _confirmDiscard() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar alterações?'),
        content: const Text(
          'Nome, username e bio não foram salvos. Fotos que você já enviou continuam salvas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuar editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      _finishAndLeave();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: Listenable.merge([_name, _username, _bio]),
      builder: (context, child) => PopScope(
        canPop: !_dirty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _confirmDiscard();
        },
        child: child!,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Editar perfil'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: Space.sm),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Salvar'),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(Space.lg),
                  children: [
                    Text(
                      'As fotos são salvas assim que você as escolhe. Nome, username e bio só são salvos em "Salvar".',
                      style: text.bodyMedium,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: Space.lg),
                      FormErrorBanner(_error!),
                    ],
                    const SizedBox(height: Space.lg),
                    _BannerPicker(
                      currentUrl: _initialBannerUrl,
                      upload: _uploads[ProfileImageKind.banner]!,
                      onPick: () => _pickAndUpload(ProfileImageKind.banner),
                      onRetry: () => _upload(
                        ProfileImageKind.banner,
                        _uploads[ProfileImageKind.banner]!.local!,
                      ),
                    ),
                    const SizedBox(height: Space.lg),
                    _AvatarPicker(
                      name: _initial.displayName,
                      currentUrl: _initialAvatarUrl,
                      upload: _uploads[ProfileImageKind.avatar]!,
                      onPick: () => _pickAndUpload(ProfileImageKind.avatar),
                      onRetry: () => _upload(
                        ProfileImageKind.avatar,
                        _uploads[ProfileImageKind.avatar]!.local!,
                      ),
                    ),
                    const SizedBox(height: Space.xl),
                    TextFormField(
                      controller: _name,
                      enabled: !_saving,
                      decoration: const InputDecoration(labelText: 'Nome'),
                      textInputAction: TextInputAction.next,
                      maxLength: 50,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe seu nome'
                          : null,
                    ),
                    const SizedBox(height: Space.sm),
                    TextFormField(
                      controller: _username,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        helperText: 'Letras, números e _',
                      ),
                      textInputAction: TextInputAction.next,
                      maxLength: 30,
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.length < 3) {
                          return 'Use pelo menos 3 caracteres';
                        }
                        if (!_usernamePattern.hasMatch(value)) {
                          return 'Use apenas letras, números e _';
                        }
                        if (_usernameConflict != null &&
                            value == _usernameConflict) {
                          return 'Esse username já está em uso';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: Space.sm),
                    TextFormField(
                      controller: _bio,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        alignLabelWithHint: true,
                      ),
                      minLines: 3,
                      maxLines: 5,
                      maxLength: 280,
                      keyboardType: TextInputType.multiline,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? get _initialAvatarUrl {
    final session = ref.watch(sessionControllerProvider);
    return session is SessionAuthenticated
        ? session.user.avatarUrl
        : _initial.avatarUrl;
  }

  String? get _initialBannerUrl {
    final session = ref.watch(sessionControllerProvider);
    return session is SessionAuthenticated
        ? session.user.bannerUrl
        : _initial.bannerUrl;
  }
}

/// Mensagem para falha de upload (distingue arquivo recusado de falta de conexão).
String describeUploadError(Object error) {
  if (error is ApiException && error.status == 400) {
    return error.message.isEmpty
        ? 'O servidor recusou a imagem.'
        : error.message;
  }
  return describeError(error);
}

class _UploadStatus extends StatelessWidget {
  const _UploadStatus({required this.upload, required this.onRetry});

  final _ImageUpload upload;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (upload.uploading) {
      return Semantics(
        label: 'Enviando imagem, ${((upload.progress ?? 0) * 100).round()}%',
        child: Padding(
          padding: const EdgeInsets.only(top: Space.sm),
          child: LinearProgressIndicator(
            value: upload.progress == 0 ? null : upload.progress,
          ),
        ),
      );
    }
    if (upload.error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: Space.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                upload.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            if (upload.local != null && !upload.local!.isTooLarge)
              TextButton(
                onPressed: onRetry,
                child: const Text('Tentar de novo'),
              ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// A capa é recortada em 3:1 pelo servidor; a pré-visualização usa a mesma proporção e `cover`.
class _BannerPicker extends StatelessWidget {
  const _BannerPicker({
    required this.currentUrl,
    required this.upload,
    required this.onPick,
    required this.onRetry,
  });

  final String? currentUrl;
  final _ImageUpload upload;
  final VoidCallback onPick;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolved = ImageUrls.resolve(currentUrl);
    final Widget image = upload.local != null
        ? Image.memory(
            Uint8List.fromList(upload.local!.bytes),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                ColoredBox(color: scheme.primaryContainer),
          )
        : resolved != null
        ? Image.network(
            resolved,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                ColoredBox(color: scheme.primaryContainer),
          )
        : ColoredBox(color: scheme.primaryContainer);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(aspectRatio: 3, child: image),
        ),
        const SizedBox(height: Space.sm),
        OutlinedButton.icon(
          onPressed: upload.uploading ? null : onPick,
          icon: const Icon(Icons.image_outlined),
          label: const Text('Alterar capa'),
        ),
        _UploadStatus(upload: upload, onRetry: onRetry),
      ],
    );
  }
}

/// O avatar é recortado em 1:1 (centro) pelo servidor e exibido em círculo.
class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.name,
    required this.currentUrl,
    required this.upload,
    required this.onPick,
    required this.onRetry,
  });

  final String name;
  final String? currentUrl;
  final _ImageUpload upload;
  final VoidCallback onPick;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final resolved = ImageUrls.resolve(currentUrl);
    final preview = upload.local != null
        ? ClipOval(
            child: SizedBox(
              width: 80,
              height: 80,
              child: Image.memory(
                Uint8List.fromList(upload.local!.bytes),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => UserAvatar(name: name, radius: 40),
              ),
            ),
          )
        : UserAvatar(name: name, url: resolved, radius: 40);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Space.lg,
          runSpacing: Space.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            preview,
            OutlinedButton.icon(
              onPressed: upload.uploading ? null : onPick,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Alterar foto'),
            ),
          ],
        ),
        _UploadStatus(upload: upload, onRetry: onRetry),
      ],
    );
  }
}
