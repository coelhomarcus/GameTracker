import 'package:dio/dio.dart';

import '../../../core/data/patch.dart';
import '../../../core/network/app_exception.dart';
import 'game_entry.dart';

abstract interface class LibraryRepository {
  /// Toda a coleção do usuário (o backend não pagina), mais recentes primeiro.
  Future<List<GameEntry>> listMine();
  Future<GameEntry> create(int igdbId, EntryDraft draft);

  /// Envia só o que mudou em relação a [original]; sem mudança, não faz requisição.
  Future<GameEntry> update(GameEntry original, EntryDraft edited);
  Future<void> delete(String entryId);
}

/// Corpo do POST: campos sem valor são omitidos (o backend não aceita `null` na criação).
Map<String, Object?> createBody(int igdbId, EntryDraft d) => {
  'igdbId': igdbId,
  'platform': d.platform,
  'status': d.status.apiValue,
  if (d.startedAt != null) 'startedAt': d.startedAt!.toApi(),
  if (d.finishedAt != null) 'finishedAt': d.finishedAt!.toApi(),
  if (d.hoursPlayed != null) 'hoursPlayed': d.hoursPlayed,
  if (d.rating != null) 'rating': d.rating,
  if (d.notes != null && d.notes!.trim().isNotEmpty) 'notes': d.notes!.trim(),
};

/// Corpo do PATCH: omitido mantém, `null` limpa, valor substitui. Vazio quando nada mudou.
Map<String, Object?> updateBody(GameEntry original, EntryDraft edited) {
  final body = <String, Object?>{};
  if (edited.platform != original.platform) body['platform'] = edited.platform;
  if (edited.status != original.status) body['status'] = edited.status.apiValue;
  Patch.diff(
    original.startedAt,
    edited.startedAt,
  ).putInto(body, 'startedAt', (v) => v.toApi());
  Patch.diff(
    original.finishedAt,
    edited.finishedAt,
  ).putInto(body, 'finishedAt', (v) => v.toApi());
  Patch.diff(
    original.hoursPlayed,
    edited.hoursPlayed,
  ).putInto(body, 'hoursPlayed', (v) => v);
  Patch.diff(original.rating, edited.rating).putInto(body, 'rating', (v) => v);
  final notes = edited.notes?.trim();
  Patch.diff(
    (original.notes == null || original.notes!.isEmpty) ? null : original.notes,
    (notes == null || notes.isEmpty) ? null : notes,
  ).putInto(body, 'notes', (v) => v);
  return body;
}

class RemoteLibraryRepository implements LibraryRepository {
  RemoteLibraryRepository(this._dio);
  final Dio _dio;

  @override
  Future<List<GameEntry>> listMine() => guardApi(() async {
    final r = await _dio.get<List<dynamic>>(
      '/game-entries/me',
      queryParameters: {'sort': 'recent'},
    );
    return r.data!
        .cast<Map<String, dynamic>>()
        .map(GameEntry.fromJson)
        .toList();
  });

  @override
  Future<GameEntry> create(int igdbId, EntryDraft draft) => guardApi(() async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/game-entries',
      data: createBody(igdbId, draft),
    );
    return GameEntry.fromJson(r.data!);
  });

  @override
  Future<GameEntry> update(GameEntry original, EntryDraft edited) async {
    final body = updateBody(original, edited);
    if (body.isEmpty) return original;
    return guardApi(() async {
      final r = await _dio.patch<Map<String, dynamic>>(
        '/game-entries/${original.id}',
        data: body,
      );
      return GameEntry.fromJson(r.data!);
    });
  }

  @override
  Future<void> delete(String entryId) => guardApi(() async {
    await _dio.delete<void>('/game-entries/$entryId');
  });
}
