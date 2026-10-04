import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/providers.dart';
import '../../../core/design_system/tokens.dart';
import 'auth_form_scaffold.dart';
import 'auth_messages.dart';

/// Limites iguais aos do backend (plano, seção 6.2, regra 7).
final _usernamePattern = RegExp(r'^[a-zA-Z0-9_]+$');
final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key, this.from});

  final String? from;

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .register(
            name: _name.text.trim(),
            username: _username.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
          );
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFormScaffold(
      title: 'Criar conta',
      subtitle: 'Leva menos de um minuto.',
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  FormErrorBanner(_error!),
                  const SizedBox(height: Space.lg),
                ],
                TextFormField(
                  controller: _name,
                  enabled: !_loading,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.next,
                  maxLength: 50,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe seu nome'
                      : null,
                ),
                const SizedBox(height: Space.sm),
                TextFormField(
                  controller: _username,
                  enabled: !_loading,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    helperText: 'Letras, números e _',
                  ),
                  autofillHints: const [AutofillHints.newUsername],
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
                    return null;
                  },
                ),
                const SizedBox(height: Space.sm),
                TextFormField(
                  controller: _email,
                  enabled: !_loading,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                  autofillHints: const [AutofillHints.email],
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) => _emailPattern.hasMatch(v?.trim() ?? '')
                      ? null
                      : 'Informe um e-mail válido',
                ),
                const SizedBox(height: Space.lg),
                TextFormField(
                  controller: _password,
                  enabled: !_loading,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    helperText: 'De 8 a 72 caracteres',
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) {
                    final value = v ?? '';
                    if (value.length < 8) {
                      return 'Use pelo menos 8 caracteres';
                    }
                    if (value.length > 72) {
                      return 'Use no máximo 72 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: Space.xl),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Criar conta'),
                ),
                const SizedBox(height: Space.sm),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => context.go(
                          widget.from == null
                              ? '/login'
                              : '/login?from=${Uri.encodeQueryComponent(widget.from!)}',
                        ),
                  child: const Text('Já tenho conta'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
