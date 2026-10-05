/// Estado de um campo opcional em um PATCH: manter, limpar ou substituir.
/// Espelha o contrato do backend (omitido = manter, `null` = limpar).
sealed class Patch<T> {
  const Patch();

  /// Compara o valor original com o editado e escolhe o estado.
  factory Patch.diff(T? original, T? edited) {
    if (edited == original) return Keep<T>();
    if (edited == null) return Clear<T>();
    return Replace<T>(edited);
  }

  bool get isKeep => this is Keep<T>;
}

final class Keep<T> extends Patch<T> {
  const Keep();
}

final class Clear<T> extends Patch<T> {
  const Clear();
}

final class Replace<T> extends Patch<T> {
  const Replace(this.value);
  final T value;
}

extension PatchJson<T> on Patch<T> {
  /// Adiciona o campo ao corpo JSON só quando há mudança.
  void putInto(
    Map<String, Object?> body,
    String key,
    Object? Function(T value) encode,
  ) {
    switch (this) {
      case Keep<T>():
        break;
      case Clear<T>():
        body[key] = null;
      case Replace<T>(:final value):
        body[key] = encode(value);
    }
  }
}
