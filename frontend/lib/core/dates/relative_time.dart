/// Tempo relativo em português para instantes (posts, comentários, mensagens).
/// [createdAt] é um instante e é convertido para o horário local; datas de calendário
/// (início/fim de playthrough) usam `DateOnly`, não esta função.
String formatRelativeTime(DateTime createdAt, {DateTime? now}) {
  final current = (now ?? DateTime.now()).toLocal();
  final local = createdAt.toLocal();
  final diff = current.difference(local);

  if (diff.isNegative || diff.inSeconds < 45) return 'agora';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes.clamp(1, 59)} min';
  if (diff.inHours < 24) return 'há ${diff.inHours} h';

  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(local.year, local.month, local.day);
  final days = today.difference(day).inDays;
  if (days == 1) return 'ontem';
  if (days < 7) return 'há $days dias';

  final dd = local.day.toString().padLeft(2, '0');
  final mm = local.month.toString().padLeft(2, '0');
  return local.year == current.year ? '$dd/$mm' : '$dd/$mm/${local.year}';
}
