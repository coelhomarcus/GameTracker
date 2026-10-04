import 'package:material_ui/material_ui.dart';

import '../../../core/design_system/placeholder_page.dart';

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderPage(
    title: 'Mensagens',
    icon: Icons.chat_bubble_outline,
    message: 'Conversas em tempo real chegam na Etapa 7.',
  );
}
