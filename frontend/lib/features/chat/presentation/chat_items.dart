import '../data/chat_models.dart';

/// Mensagens seguidas do mesmo autor, com menos que isto entre uma e outra, formam um grupo.
const groupWindow = Duration(minutes: 5);

sealed class ChatItem {
  const ChatItem();
}

/// "Hoje", "Ontem" ou a data, entre dias diferentes.
class DaySeparator extends ChatItem {
  const DaySeparator(this.day);
  final DateTime day;
}

class MessageItem extends ChatItem {
  const MessageItem({
    required this.message,
    required this.mine,
    required this.firstInGroup,
    required this.lastInGroup,
  });

  final ChatMessage message;
  final bool mine;

  /// Primeira do grupo: mostra o avatar/nome da outra pessoa.
  final bool firstInGroup;

  /// Última do grupo: mostra o horário e o estado de entrega.
  final bool lastInGroup;
}

DateTime _dayOf(DateTime instant) {
  final local = instant.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Monta a lista da tela em ordem de leitura (mais antiga primeiro). Mensagens pendentes ficam
/// no fim; o dia delas é o de hoje. [meId] decide de que lado cada mensagem aparece.
List<ChatItem> buildChatItems(
  List<ChatMessage> messages, {
  required String meId,
}) {
  final items = <ChatItem>[];
  DateTime? currentDay;

  for (var i = 0; i < messages.length; i++) {
    final message = messages[i];
    final previous = i > 0 ? messages[i - 1] : null;
    final next = i < messages.length - 1 ? messages[i + 1] : null;
    final day = _dayOf(message.createdAt);

    if (currentDay == null || day != currentDay) {
      items.add(DaySeparator(day));
      currentDay = day;
    }

    bool sameGroup(ChatMessage a, ChatMessage b) =>
        a.sender.id == b.sender.id &&
        _dayOf(a.createdAt) == _dayOf(b.createdAt) &&
        b.createdAt.difference(a.createdAt).abs() < groupWindow;

    items.add(
      MessageItem(
        message: message,
        mine: message.sender.id == meId,
        firstInGroup: previous == null || !sameGroup(previous, message),
        lastInGroup: next == null || !sameGroup(message, next),
      ),
    );
  }
  return items;
}

/// Rótulo do separador: Hoje, Ontem ou dd/MM(/aaaa).
String dayLabel(DateTime day, {required DateTime now}) {
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hoje';
  if (diff == 1) return 'Ontem';
  final dd = day.day.toString().padLeft(2, '0');
  final mm = day.month.toString().padLeft(2, '0');
  return day.year == now.year ? '$dd/$mm' : '$dd/$mm/${day.year}';
}

String clockLabel(DateTime instant) {
  final local = instant.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
