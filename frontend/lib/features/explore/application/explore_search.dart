import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../library/application/library_groups.dart';

/// O que Explorar está buscando. A rota aceita `?scope=people`; qualquer outro valor usa Jogos.
enum ExploreScope {
  games,
  people;

  static ExploreScope fromParam(String? value) =>
      value == 'people' ? ExploreScope.people : ExploreScope.games;
}

/// Consulta da barra de Explorar, compartilhada pelas duas abas. Fica só em memória: sobrevive à
/// troca de aba e a abrir um resultado, e é descartada ao sair da conta. Não vai para a URL.
class ExploreQuery extends Notifier<String> {
  @override
  String build() {
    ref.watch(currentUserIdProvider);
    return '';
  }

  void set(String query) => state = query;
}

final exploreQueryProvider = NotifierProvider<ExploreQuery, String>(
  ExploreQuery.new,
);

/// Pesquisas recentes de cada escopo, da mais nova para a mais antiga. Só entram termos enviados
/// de forma explícita (Enter) ou que levaram a abrir um resultado, nunca cada tecla. Em memória,
/// por conta.
class RecentSearches extends Notifier<Map<ExploreScope, List<String>>> {
  static const maxPerScope = 8;

  @override
  Map<ExploreScope, List<String>> build() {
    ref.watch(currentUserIdProvider);
    return const {};
  }

  List<String> of(ExploreScope scope) => state[scope] ?? const [];

  /// Termos com menos de 2 letras não são pesquisas. Repetir um termo (sem diferença de caixa ou
  /// acentos) só o leva para o topo, com a grafia mais recente.
  void record(ExploreScope scope, String term) {
    final text = term.trim();
    if (text.length < 2) return;
    final key = foldText(text);
    final next = [
      text,
      for (final old in of(scope))
        if (foldText(old) != key) old,
    ].take(maxPerScope).toList();
    state = {...state, scope: next};
  }

  void clear(ExploreScope scope) => state = {...state, scope: const []};
}

final recentSearchesProvider =
    NotifierProvider<RecentSearches, Map<ExploreScope, List<String>>>(
      RecentSearches.new,
    );
