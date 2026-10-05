import 'package:flutter/foundation.dart';

/// Data de calendário (ano/mês/dia), sem hora nem fuso.
///
/// O backend devolve datas de progresso como instante UTC à meia-noite
/// (`2026-01-05T00:00:00.000Z`). Aplicar o fuso local a isso mostraria o dia
/// anterior em fusos a oeste de UTC; por isso lemos sempre as partes em UTC.
@immutable
class DateOnly implements Comparable<DateOnly> {
  const DateOnly(this.year, this.month, this.day);

  /// Dia local de um [DateTime] (ex.: o valor devolvido pelo date picker).
  factory DateOnly.fromLocal(DateTime value) =>
      DateOnly(value.year, value.month, value.day);

  factory DateOnly.today([DateTime? now]) =>
      DateOnly.fromLocal(now ?? DateTime.now());

  /// Aceita `YYYY-MM-DD` ou o instante UTC emitido pelo backend.
  factory DateOnly.parseApi(String value) {
    if (value.length == 10) {
      final parts = value.split('-');
      return DateOnly(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    }
    final utc = DateTime.parse(value).toUtc();
    return DateOnly(utc.year, utc.month, utc.day);
  }

  final int year;
  final int month;
  final int day;

  /// Formato enviado ao backend.
  String toApi() =>
      '${year.toString().padLeft(4, '0')}-${_two(month)}-${_two(day)}';

  /// Meia-noite local, para alimentar o date picker.
  DateTime toLocalDateTime() => DateTime(year, month, day);

  /// `dd/MM/aaaa`.
  String format() => '${_two(day)}/${_two(month)}/$year';

  /// Dias de calendário entre as datas, contando as duas pontas.
  int daysThrough(DateOnly other) {
    final a = DateTime.utc(year, month, day);
    final b = DateTime.utc(other.year, other.month, other.day);
    return b.difference(a).inDays + 1;
  }

  bool isAfter(DateOnly other) => compareTo(other) > 0;

  @override
  int compareTo(DateOnly other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is DateOnly &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toApi();

  static String _two(int n) => n.toString().padLeft(2, '0');
}
