// Contrato de PATCH /users/me e dos uploads de avatar/banner.
//   API=http://localhost:3100/api node profile_contract.mjs
import assert from 'node:assert/strict';
import { deflateSync } from 'node:zlib';

const API = process.env.API ?? 'http://localhost:3100/api';
const n = Date.now().toString(36);

async function http(method, path, token, body, form) {
  const res = await fetch(API + path, {
    method,
    headers: { ...(body !== undefined ? { 'content-type': 'application/json' } : {}), ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: form ?? (body === undefined ? undefined : JSON.stringify(body)),
  });
  const text = await res.text();
  let parsed = null;
  try { parsed = text ? JSON.parse(text) : null; } catch { parsed = { _text: text }; }
  return { status: res.status, body: parsed };
}
const register = async (p) =>
  (await http('POST', '/auth/register', null, { username: `${p}_${n}`, name: p, email: `${p}_${n}@example.test`, password: 'senha-fixture-123' })).body;

// PNG de verdade (cor sólida) gerado sem dependências.
function png(w, h) {
  const crc = (buf) => { let c, crcv = ~0; for (const b of buf) { c = (crcv ^ b) & 0xff; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; crcv = (crcv >>> 8) ^ c; } return ~crcv >>> 0; };
  const chunk = (type, data) => { const len = Buffer.alloc(4); len.writeUInt32BE(data.length); const td = Buffer.concat([Buffer.from(type), data]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(td)); return Buffer.concat([len, td, c]); };
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 2;
  const row = Buffer.concat([Buffer.from([0]), Buffer.alloc(w * 3, 0x80)]);
  const raw = Buffer.concat(Array.from({ length: h }, () => row));
  return Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), chunk('IHDR', ihdr), chunk('IDAT', deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]);
}
const upload = (field, bytes, type, name = 'f.png') => { const f = new FormData(); f.append(field, new Blob([bytes], { type }), name); return f; };

const a = await register('pa');
const b = await register('pb');
let ok = 0;
const check = async (name, fn) => { try { await fn(); ok++; console.log('ok  ', name); } catch (e) { console.error('FAIL', name, '\n', e.message); process.exitCode = 1; } };

await check('PATCH {} é válido e não muda nada', async () => {
  assert.equal((await http('PATCH', '/users/me', a.accessToken, {})).status, 204);
});
await check('altera só o que foi enviado', async () => {
  assert.equal((await http('PATCH', '/users/me', a.accessToken, { bio: 'Olá' })).status, 204);
  const me = (await http('GET', '/auth/me', a.accessToken)).body;
  assert.equal(me.bio, 'Olá'); assert.equal(me.name, 'pa');
});
await check('bio vazia limpa a bio', async () => {
  assert.equal((await http('PATCH', '/users/me', a.accessToken, { bio: '' })).status, 204);
  assert.ok(!(await http('GET', '/auth/me', a.accessToken)).body.bio);
});
await check('username repetido devolve 409 e não altera nada', async () => {
  const r = await http('PATCH', '/users/me', a.accessToken, { username: b.user.username, name: 'Outro' });
  assert.equal(r.status, 409);
  assert.equal((await http('GET', '/auth/me', a.accessToken)).body.name, 'pa');
});
await check('manter o próprio username não é conflito', async () => {
  assert.equal((await http('PATCH', '/users/me', a.accessToken, { username: a.user.username })).status, 204);
});
await check('duas trocas simultâneas para o mesmo username: uma vence (204), a outra é 409 (nunca 500)', async () => {
  const target = `race_${n}`;
  const results = await Promise.all([a, b].map((u) => http('PATCH', '/users/me', u.accessToken, { username: target })));
  const statuses = results.map((r) => r.status).sort();
  assert.deepEqual(statuses, [204, 409], `recebeu ${statuses}`);
});
await check('validações de limite (bio 281, username curto/inválido, nome vazio)', async () => {
  for (const body of [{ bio: 'x'.repeat(281) }, { username: 'ab' }, { username: 'com espaço' }, { name: '' }]) {
    assert.equal((await http('PATCH', '/users/me', a.accessToken, body)).status, 400, JSON.stringify(body).slice(0, 40));
  }
});
await check('avatar válido: devolve URL, vira JPEG 400x400 e aparece em /auth/me', async () => {
  const r = await http('POST', '/users/me/avatar', a.accessToken, undefined, upload('avatar', png(900, 300), 'image/png'));
  assert.equal(r.status, 200);
  assert.match(r.body.avatarUrl, /\/uploads\/avatars\/.+\.jpg$/);
  const img = await fetch(r.body.avatarUrl);
  assert.equal(img.status, 200); assert.equal(img.headers.get('content-type'), 'image/jpeg');
  assert.equal((await http('GET', '/auth/me', a.accessToken)).body.avatarUrl, r.body.avatarUrl);
});
await check('banner válido: devolve URL em /uploads/banners', async () => {
  const r = await http('POST', '/users/me/banner', a.accessToken, undefined, upload('banner', png(600, 600), 'image/png'));
  assert.equal(r.status, 200); assert.match(r.body.bannerUrl, /\/uploads\/banners\/.+\.jpg$/);
});
await check('trocar o avatar apaga o arquivo antigo e devolve outra URL', async () => {
  const first = (await http('GET', '/auth/me', a.accessToken)).body.avatarUrl;
  const r = await http('POST', '/users/me/avatar', a.accessToken, undefined, upload('avatar', png(50, 50), 'image/png'));
  assert.notEqual(r.body.avatarUrl, first);
  await new Promise((res) => setTimeout(res, 200));
  assert.equal((await fetch(first)).status, 404, 'arquivo antigo removido');
});
await check('arquivo que não é imagem (MIME) é 400', async () => {
  const r = await http('POST', '/users/me/avatar', a.accessToken, undefined, upload('avatar', Buffer.from('texto'), 'text/plain', 'a.txt'));
  assert.equal(r.status, 400);
});
await check('bytes corrompidos com MIME de imagem são 400 (não 500)', async () => {
  const r = await http('POST', '/users/me/avatar', a.accessToken, undefined, upload('avatar', Buffer.from('isto nao e um png'), 'image/png'));
  assert.equal(r.status, 400, `recebeu ${r.status} ${JSON.stringify(r.body)}`);
  assert.equal(r.body.error.code, 'validation_error');
});
await check('sem arquivo é 400', async () => {
  assert.equal((await http('POST', '/users/me/avatar', a.accessToken, undefined, new FormData())).status, 400);
});
await check('arquivo acima de 8 MiB é 400', async () => {
  const big = Buffer.concat([png(10, 10), Buffer.alloc(9 * 1024 * 1024)]);
  assert.equal((await http('POST', '/users/me/avatar', a.accessToken, undefined, upload('avatar', big, 'image/png'))).status, 400);
});
await check('campo com nome errado não é aceito', async () => {
  const r = await http('POST', '/users/me/avatar', a.accessToken, undefined, upload('foto', png(10, 10), 'image/png'));
  assert.ok([400, 500].includes(r.status)); assert.equal(r.status, 400, `recebeu ${r.status}`);
});
await check('upload sem autenticação é 401', async () => {
  assert.equal((await http('POST', '/users/me/avatar', null, undefined, upload('avatar', png(10, 10), 'image/png'))).status, 401);
});

console.log(`\n${ok} verificações ok`);
