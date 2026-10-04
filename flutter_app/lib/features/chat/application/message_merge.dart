import '../data/chat_models.dart';

/// Junta mensagens novas (do histórico, de um evento ou de um ACK) à lista atual SEM duplicar.
///
/// - Uma mensagem confirmada que traz o `clientMessageId` de uma pendente a substitui, mesmo que
///   o evento tenha chegado antes do ACK (ou o ACK nunca chegue).
/// - A mesma mensagem (mesmo `id`) vinda por dois caminhos vira uma só.
/// - Confirmadas ficam em ordem do servidor (`createdAt`, `id`); as pendentes ficam depois, na
///   ordem em que foram escritas.
List<ChatMessage> mergeMessages(
  List<ChatMessage> current,
  Iterable<ChatMessage> incoming,
) {
  final byId = <String, ChatMessage>{};
  final pending = <ChatMessage>[]; // sem id (ainda não confirmadas)
  final pendingByCid = <String, int>{};

  for (final m in current) {
    if (m.id != null) {
      byId[m.id!] = m;
    } else {
      pendingByCid[m.clientMessageId ?? m.key] = pending.length;
      pending.add(m);
    }
  }

  final stillPending = {for (var i = 0; i < pending.length; i++) i: pending[i]};

  for (final m in incoming) {
    final id = m.id;
    if (id == null) {
      // Pendente nova (ainda sem id): entra no fim, sem duplicar o mesmo envio.
      final cid = m.clientMessageId ?? m.key;
      if (!pendingByCid.containsKey(cid) &&
          !byId.values.any((c) => c.clientMessageId == cid)) {
        pendingByCid[cid] = pending.length;
        stillPending[pending.length] = m;
        pending.add(m);
      }
      continue;
    }
    // Confirmada: se havia uma pendente com o mesmo clientMessageId, ela é substituída.
    final cid = m.clientMessageId;
    if (cid != null && pendingByCid.containsKey(cid)) {
      stillPending.remove(pendingByCid[cid]);
    }
    byId[id] = m.copyWith(status: MessageStatus.sent, attempts: 0, error: null);
  }

  final confirmed = byId.values.toList()
    ..sort((a, b) {
      final byTime = a.createdAt.compareTo(b.createdAt);
      return byTime != 0 ? byTime : a.id!.compareTo(b.id!);
    });
  final rest = stillPending.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return [...confirmed, ...rest.map((e) => e.value)];
}

/// Id da mensagem confirmada mais recente, ou `null` se não há nenhuma.
String? latestConfirmedId(List<ChatMessage> messages) {
  for (var i = messages.length - 1; i >= 0; i--) {
    if (messages[i].id != null) return messages[i].id;
  }
  return null;
}
