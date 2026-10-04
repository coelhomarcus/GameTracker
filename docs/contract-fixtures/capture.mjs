// Captura fixtures JSON reais do backend (Etapa 0 do plano de migração Flutter).
//
// Uso (contra um ambiente ISOLADO — nunca o banco compartilhado/produção):
//   API=http://localhost:3100/api PG_CONTAINER=gt-flutter-pg node capture.mjs
//
// Cria usuários e jogos sintéticos (sem dados pessoais), exercita as rotas e
// grava cada resposta em ./responses/<nome>.json com { status, body }.
// Tokens e hashes são mascarados.
import { execFileSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const API = process.env.API ?? 'http://localhost:3100/api';
const PG = process.env.PG_CONTAINER ?? 'gt-flutter-pg';
const OUT = join(dirname(fileURLToPath(import.meta.url)), 'responses');
mkdirSync(OUT, { recursive: true });

const suffix = Date.now().toString(36).slice(-5);

function sql(query) {
  execFileSync(
    'docker',
    ['exec', PG, 'psql', '-U', 'gametracker', '-d', 'gametracker_flutter', '-v', 'ON_ERROR_STOP=1', '-c', query],
    { stdio: 'pipe' },
  );
}

function mask(value) {
  if (Array.isArray(value)) return value.map(mask);
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([k, v]) =>
        /token|password/i.test(k) && typeof v === 'string' ? [k, '<masked>'] : [k, mask(v)],
      ),
    );
  }
  return value;
}

async function call(name, method, path, { token, body, save = true } = {}) {
  const res = await fetch(API + path, {
    method,
    headers: {
      ...(body ? { 'content-type': 'application/json' } : {}),
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let parsed;
  try {
    parsed = text ? JSON.parse(text) : null;
  } catch {
    parsed = { _nonJson: text };
  }
  if (save) {
    writeFileSync(join(OUT, `${name}.json`), JSON.stringify({ status: res.status, body: mask(parsed) }, null, 2) + '\n');
  }
  console.log(String(res.status).padEnd(4), method.padEnd(6), path, '→', name);
  return { status: res.status, body: parsed };
}

// --- Jogos sintéticos no cache local (IGDB não é acessível/configurado) -----
sql(`
INSERT INTO games (igdb_id, name, cover_url, summary, screenshots, platforms, genres) VALUES
 (900001, 'Jogo Fixture Um', NULL, 'Sinopse de teste.', ARRAY[]::text[], ARRAY['PC','PlayStation 5'], ARRAY['RPG']),
 (900002, 'Jogo Fixture Dois', NULL, NULL, ARRAY[]::text[], ARRAY['PC'], ARRAY[]::text[])
ON CONFLICT (igdb_id) DO NOTHING;`);

// --- Auth -------------------------------------------------------------------
const pw = 'senha-fixture-123';
const a = { username: `fixa_${suffix}`, name: 'Ana Fixture', email: `fixa_${suffix}@example.test`, password: pw };
const b = { username: `fixb_${suffix}`, name: 'Beto Fixture', email: `fixb_${suffix}@example.test`, password: pw };

const regA = await call('auth_register', 'POST', '/auth/register', { body: a });
const regB = await call('auth_register_b', 'POST', '/auth/register', { body: b, save: false });
await call('auth_register_duplicate', 'POST', '/auth/register', { body: a });
await call('auth_register_invalid', 'POST', '/auth/register', { body: { username: 'x', name: '', email: 'nope', password: '1' } });
const loginA = await call('auth_login', 'POST', '/auth/login', { body: { identifier: a.username, password: pw } });
await call('auth_login_wrong_password', 'POST', '/auth/login', { body: { identifier: a.username, password: 'errada-errada' } });

const tokA = loginA.body.accessToken;
const tokB = regB.body.accessToken;
const refreshA = loginA.body.refreshToken;
const idA = regA.body.user.id;
const idB = regB.body.user.id;

await call('auth_me', 'GET', '/auth/me', { token: tokA });
await call('auth_me_unauthorized', 'GET', '/auth/me');
await call('auth_refresh', 'POST', '/auth/refresh', { body: { refreshToken: refreshA } });
await call('auth_refresh_reused_token', 'POST', '/auth/refresh', { body: { refreshToken: refreshA } });

// --- Catálogo ---------------------------------------------------------------
const game1 = await call('games_by_igdb', 'GET', '/games/igdb/900001', { token: tokA });
const gameId = game1.body.id ?? game1.body.game?.id;
await call('games_by_id', 'GET', `/games/${gameId}`, { token: tokA });
await call('games_by_igdb_incomplete', 'GET', '/games/igdb/900002', { token: tokA });
await call('games_not_found', 'GET', '/games/00000000-0000-0000-0000-000000000000', { token: tokA });

// --- Biblioteca: dois playthroughs, horas/datas/nota ------------------------
const e1 = await call('entries_create_full', 'POST', '/game-entries', {
  token: tokA,
  body: { igdbId: 900001, platform: 'PC', status: 'completed', startedAt: '2026-01-05', finishedAt: '2026-01-20', hoursPlayed: 12.5, rating: 9, notes: 'Primeira vez' },
});
await call('entries_create_replay_minimal', 'POST', '/game-entries', { token: tokA, body: { igdbId: 900001, platform: 'PC' } });
await call('entries_create_zero_hours', 'POST', '/game-entries', { token: tokA, body: { igdbId: 900002, platform: 'PC', hoursPlayed: 0 } });
await call('entries_create_invalid_rating', 'POST', '/game-entries', { token: tokA, body: { igdbId: 900001, platform: 'PC', rating: 0 } });
const entryId = e1.body.id ?? e1.body.entry?.id;
await call('entries_list_mine', 'GET', '/game-entries/me', { token: tokA });
await call('entries_list_filtered', 'GET', '/game-entries/me?igdbId=900001&sort=oldest', { token: tokA });
await call('entries_patch_values', 'PATCH', `/game-entries/${entryId}`, { token: tokA, body: { hoursPlayed: 20, rating: 8 } });
// Limpar campo: null limpa (antes era 400). Contrato completo em patch_contract.mjs.
await call('entries_patch_null_clear', 'PATCH', `/game-entries/${entryId}`, { token: tokA, body: { finishedAt: null, rating: null, hoursPlayed: null } });
await call('entries_patch_empty_notes', 'PATCH', `/game-entries/${entryId}`, { token: tokA, body: { notes: '' } });
await call('entries_list_after_patch', 'GET', '/game-entries/me?igdbId=900001', { token: tokA });
await call('entries_patch_forbidden', 'PATCH', `/game-entries/${entryId}`, { token: tokB, body: { rating: 1 } });

// --- Favoritos / stats / jogadores -----------------------------------------
await call('favorite_add', 'POST', `/games/${gameId}/favorite`, { token: tokA });
await call('favorite_add_again', 'POST', `/games/${gameId}/favorite`, { token: tokA });
await call('user_favorites', 'GET', `/users/${idA}/favorites`, { token: tokB });
await call('game_stats', 'GET', `/games/${gameId}/stats`, { token: tokA });
await call('game_players', 'GET', `/games/${gameId}/players?limit=10`, { token: tokB });

// --- Social -----------------------------------------------------------------
await call('follow', 'POST', `/users/${idA}/follow`, { token: tokB });
await call('follow_again', 'POST', `/users/${idA}/follow`, { token: tokB });
const post = await call('posts_create_linked_entry', 'POST', '/posts', { token: tokA, body: { content: 'Terminei!', gameEntryId: entryId } });
const postId = post.body.id ?? post.body.post?.id;
await call('posts_create_game_only', 'POST', '/posts', { token: tokA, body: { content: 'Quero jogar', gameId } });
await call('posts_create_too_long', 'POST', '/posts', { token: tokA, body: { content: 'x'.repeat(501) } });
await call('post_like', 'POST', `/posts/${postId}/like`, { token: tokB });
await call('post_like_again', 'POST', `/posts/${postId}/like`, { token: tokB });
const c1 = await call('comment_create', 'POST', `/posts/${postId}/comments`, { token: tokB, body: { content: 'Parabéns' } });
const commentId = c1.body.id ?? c1.body.comment?.id;
await call('comment_reply', 'POST', `/posts/${postId}/comments`, { token: tokA, body: { content: 'Valeu', parentCommentId: commentId } });
await call('comment_like', 'POST', `/comments/${commentId}/like`, { token: tokA });
await call('post_detail', 'GET', `/posts/${postId}`, { token: tokB });
await call('post_comments', 'GET', `/posts/${postId}/comments`, { token: tokB });
await call('feed_following', 'GET', '/feed?scope=following', { token: tokB });
await call('feed_general', 'GET', '/feed?scope=general&limit=1', { token: tokB });
await call('feed_default_scope', 'GET', '/feed', { token: tokB });
await call('game_posts', 'GET', `/games/${gameId}/posts`, { token: tokB });
await call('users_search', 'GET', `/users/search?q=fix`, { token: tokB });
await call('user_profile', 'GET', `/users/${idA}`, { token: tokB });
await call('user_profile_not_found', 'GET', '/users/00000000-0000-0000-0000-000000000000', { token: tokB });
await call('user_posts_activity', 'GET', `/users/${idA}/posts?type=activity`, { token: tokB });
await call('user_comments', 'GET', `/users/${idB}/comments`, { token: tokA });
await call('user_game_entries', 'GET', `/users/${idA}/game-entries?status=completed`, { token: tokB });
await call('profile_update', 'PATCH', '/users/me', { token: tokA, body: { bio: 'Bio de teste', name: 'Ana F.' } });
await call('profile_update_username_conflict', 'PATCH', '/users/me', { token: tokA, body: { username: b.username } });
await call('notifications_list', 'GET', '/notifications', { token: tokA });
await call('notifications_read_all', 'POST', '/notifications/read-all', { token: tokA });

// --- Conversas --------------------------------------------------------------
const conv = await call('conversations_create', 'POST', '/conversations', { token: tokA, body: { userId: idB } });
const convId = conv.body.id ?? conv.body.conversation?.id;
await call('conversations_create_again', 'POST', '/conversations', { token: tokA, body: { userId: idB }, save: false });
await call('conversations_list', 'GET', '/conversations', { token: tokB });
await call('conversation_messages_empty', 'GET', `/conversations/${convId}/messages`, { token: tokA });
await call('conversation_read', 'POST', `/conversations/${convId}/read`, { token: tokA });

// --- Limpeza de relações / logout ------------------------------------------
await call('post_unlike', 'DELETE', `/posts/${postId}/like`, { token: tokB });
await call('unfollow', 'DELETE', `/users/${idA}/follow`, { token: tokB });
await call('favorite_remove', 'DELETE', `/games/${gameId}/favorite`, { token: tokA });
await call('entries_delete', 'DELETE', `/game-entries/${entryId}`, { token: tokA });
await call('user_posts_after_entry_deleted', 'GET', `/users/${idA}/posts?type=activity`, { token: tokB });
await call('auth_logout', 'POST', '/auth/logout', { body: { refreshToken: refreshA } });
await call('push_token_legacy', 'POST', '/users/me/push-token', { token: tokA, body: { token: 'ExponentPushToken[fixture]' } });
await call('health', 'GET', '/health');

console.log(`\nFixtures gravadas em ${OUT}`);
