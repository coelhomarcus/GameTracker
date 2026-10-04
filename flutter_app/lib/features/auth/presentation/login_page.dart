import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/design_system/tokens.dart';

/// Apenas visual na Etapa 2; a autenticação real é a Etapa 3.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.sports_esports,
                        size: 56,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: Space.lg),
                      Text(
                        'GameTracker',
                        style: text.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        'Sua biblioteca de jogos, com comunidade.',
                        style: text.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: Space.xxl),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'E-mail ou username',
                        ),
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Informe seu e-mail ou username'
                            : null,
                      ),
                      const SizedBox(height: Space.lg),
                      TextFormField(
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          suffixIcon: IconButton(
                            tooltip: _obscure
                                ? 'Mostrar senha'
                                : 'Ocultar senha',
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        autofillHints: const [AutofillHints.password],
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Informe sua senha'
                            : null,
                      ),
                      const SizedBox(height: Space.xl),
                      FilledButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            context.go('/library');
                          }
                        },
                        child: const Text('Entrar'),
                      ),
                      const SizedBox(height: Space.sm),
                      TextButton(
                        onPressed: () => context.go('/register'),
                        child: const Text('Criar conta'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
