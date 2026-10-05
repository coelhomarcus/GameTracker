import '../dates/date_only.dart';

/// Teto absoluto da coluna `numeric(6,1)` do backend.
const maxHoursPlayed = 99999.0;

/// Lê horas digitadas com vírgula ou ponto (`12`, `12,5`, `12.5`).
/// Devolve `null` para vazio ou inválido; use [isBlank] para distinguir.
double? parseHours(String input) {
  final text = input.trim().replaceAll(',', '.');
  if (text.isEmpty) return null;
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(text)) return null;
  final value = double.tryParse(text);
  if (value == null) return null;
  return normalizeHours(value);
}

/// Uma casa decimal, como a coluna do banco.
double normalizeHours(double value) => (value * 10).round() / 10;

/// Exibição: sempre uma casa, vírgula decimal (`20,0`).
String formatHours(double value) =>
    normalizeHours(value).toStringAsFixed(1).replaceAll('.', ',');

/// Para pré-preencher o campo: `20` em vez de `20,0`.
String hoursInputText(double value) {
  final n = normalizeHours(value);
  return n == n.truncateToDouble() ? n.toInt().toString() : formatHours(n);
}

/// Ninguém joga mais horas do que existem entre o início e o fim (ou hoje, se
/// ainda estiver jogando): cada dia de calendário rende no máximo 24 h.
/// Sem data de início, vale o teto absoluto.
double maxPlausibleHours(
  DateOnly? startedAt,
  DateOnly? finishedAt, {
  required DateOnly today,
}) {
  if (startedAt == null) return maxHoursPlayed;
  final days = startedAt.daysThrough(finishedAt ?? today);
  if (days <= 0) return maxHoursPlayed;
  final ceiling = days * 24.0;
  return ceiling < maxHoursPlayed ? ceiling : maxHoursPlayed;
}
