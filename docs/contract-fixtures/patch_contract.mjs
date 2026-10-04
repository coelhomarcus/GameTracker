// Contrato do PATCH /game-entries/:id: omitido = manter, null = limpar, valor = substituir.
// Requer backend isolado no ar e o jogo 900001 no cache (criado por capture.mjs).
//   API=http://localhost:3100/api node patch_contract.mjs
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

const reg = await http('POST', '/auth/register', null, {
  username: `pc_${n}`, name: 'Patch', email: `pc_${n}@example.test`, password: 'senha-fixture-123',
});
const tok = reg.body.accessToken;

const created = await http('POST', '/game-entries', tok, {
  igdbId: 900001, platform: 'PC', status: 'completed',
  startedAt: '2026-01-05', finishedAt: '2026-01-20', hoursPlayed: 12.5, rating: 9, notes: 'nota',
});
assert.equal(created.status, 201);
const id = created.body.id;
const patch = (body) => http('PATCH', `/game-entries/${id}`, tok, body);
const get = async () => (await http('GET', '/game-entries/me?igdbId=900001', tok)).body.find((e) => e.id === id);

let ok = 0;
const check = (name, fn) => fn().then(() => { ok++; console.log('ok  ', name); }, (e) => { console.error('FAIL', name, '\n', e.message); process.exitCode = 1; });

await check('PATCH {} é válido e não muda nada (cliente legado)', async () => {
  assert.equal((await patch({})).status, 200);
  const e = await get();
  assert.equal(e.hoursPlayed, '12.5'); assert.equal(e.rating, 9); assert.equal(e.notes, 'nota');
  assert.equal(e.startedAt, '2026-01-05T00:00:00.000Z');
});

await check('campo omitido mantém os demais valores', async () => {
  assert.equal((await patch({ platform: 'Switch' })).status, 200);
  const e = await get();
  assert.equal(e.platform, 'Switch'); assert.equal(e.rating, 9); assert.equal(e.hoursPlayed, '12.5');
});

await check('valor substitui', async () => {
  await patch({ hoursPlayed: 20, rating: 7, notes: 'outra', startedAt: '2026-02-01' });
  const e = await get();
  assert.equal(e.hoursPlayed, '20.0'); assert.equal(e.rating, 7); assert.equal(e.notes, 'outra');
  assert.equal(e.startedAt, '2026-02-01T00:00:00.000Z');
});

await check('zero horas é valor, não ausência', async () => {
  await patch({ hoursPlayed: 0 });
  assert.equal((await get()).hoursPlayed, '0.0');
});

for (const field of ['hoursPlayed', 'rating', 'notes', 'startedAt', 'finishedAt']) {
  await check(`null limpa ${field} sem tocar nos outros`, async () => {
    await patch({ hoursPlayed: 5, rating: 6, notes: 'x', startedAt: '2026-03-01', finishedAt: '2026-03-09' });
    const r = await patch({ [field]: null });
    assert.equal(r.status, 200);
    const e = await get();
    assert.equal(e[field], null, `${field} deveria ser null`);
    for (const other of ['hoursPlayed', 'rating', 'notes', 'startedAt', 'finishedAt'].filter((f) => f !== field)) {
      assert.notEqual(e[other], null, `${other} não deveria ser limpo`);
    }
    assert.ok(e.startedAt === null || !String(e.startedAt).startsWith('1970'), 'data não vira 1970');
  });
}

await check('null em tudo de uma vez limpa todos os opcionais', async () => {
  const r = await patch({ hoursPlayed: null, rating: null, notes: null, startedAt: null, finishedAt: null });
  assert.equal(r.status, 200);
  const e = await get();
  assert.deepEqual([e.hoursPlayed, e.rating, e.notes, e.startedAt, e.finishedAt], [null, null, null, null, null]);
  assert.equal(e.platform, 'Switch'); assert.equal(e.status, 'completed');
});

await check('platform e status não aceitam null', async () => {
  assert.equal((await patch({ platform: null })).status, 400);
  assert.equal((await patch({ status: null })).status, 400);
});

await check('rating fora de 1–10 continua rejeitado', async () => {
  assert.equal((await patch({ rating: 0 })).status, 400);
  assert.equal((await patch({ rating: 11 })).status, 400);
});

await check('resposta do PATCH reflete o estado salvo', async () => {
  await patch({ rating: 4 });
  const r = await patch({ rating: null });
  assert.equal(r.body.rating, null);
});

console.log(`\n${ok} verificações ok`);
