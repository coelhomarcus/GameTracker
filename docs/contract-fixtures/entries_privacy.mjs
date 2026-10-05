// Privacidade das anotações: só o dono vê `notes` em GET /users/:id/game-entries.
//   API=http://localhost:3100/api node entries_privacy.mjs   (backend ISOLADO, com o jogo sintético 900001)
import assert from 'node:assert/strict';

const API = process.env.API ?? 'http://localhost:3100/api';
const n = Date.now().toString(36);
async function http(method, path, token, body) {
  const res = await fetch(API + path, {
    method,
    headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : null };
}
const register = async (p) =>
  (await http('POST', '/auth/register', null, { username: `${p}_${n}`, name: p, email: `${p}_${n}@example.test`, password: 'senha-fixture-123' })).body;

const owner = await register('pv_dono');
const other = await register('pv_outro');
const created = await http('POST', '/game-entries', owner.accessToken, { igdbId: 900001, platform: 'PC', status: 'completed', hoursPlayed: 3, rating: 8, notes: 'anotação pessoal' });
assert.equal(created.status, 201);

const asOwner = await http('GET', `/users/${owner.user.id}/game-entries`, owner.accessToken);
assert.equal(asOwner.body[0].notes, 'anotação pessoal', 'o dono continua vendo as próprias anotações');
const asOther = await http('GET', `/users/${owner.user.id}/game-entries`, other.accessToken);
assert.equal(asOther.status, 200);
assert.equal(asOther.body.length, 1);
assert.equal('notes' in asOther.body[0], false, 'outra pessoa não pode ver as anotações');
assert.equal(asOther.body[0].rating, 8, 'o restante do registro continua público');
assert.equal((await http('GET', `/users/${owner.user.id}/game-entries?status=completed`, other.accessToken)).body[0].notes, undefined);
const mine = await http('GET', '/game-entries/me', owner.accessToken);
assert.equal(mine.body[0].notes, 'anotação pessoal');
console.log('ok   anotações só para o dono (4 verificações)');
