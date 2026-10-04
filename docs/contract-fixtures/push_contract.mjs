// Contrato das rotas de instalação de push contra um backend ISOLADO.
//   API=http://localhost:3100/api node push_contract.mjs
// Usa só tokens FCM falsos: sem credenciais o FCM fica desligado, então nada sai pela rede.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';

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

const a = await register('pa');
const b = await register('pb');
const put = (token, id, body) => http('PUT', `/push/installations/${id}`, token, body);
const valid = (token) => ({ provider: 'fcm', platform: 'android', token });

let ok = 0;
const check = async (name, fn) => { try { await fn(); ok++; console.log('ok  ', name); } catch (e) { console.error('FAIL', name, '\n', e.message); process.exitCode = 1; } };

await check('registrar é idempotente (204 nas duas vezes)', async () => {
  const id = randomUUID();
  assert.equal((await put(a.accessToken, id, valid(`tok-${n}-1`))).status, 204);
  assert.equal((await put(a.accessToken, id, valid(`tok-${n}-1`))).status, 204);
});
await check('token FCM longo (4096) é aceito; 4097 é recusado', async () => {
  assert.equal((await put(a.accessToken, randomUUID(), valid('x'.repeat(4096)))).status, 204);
  assert.equal((await put(a.accessToken, randomUUID(), valid('y'.repeat(4097)))).status, 400);
});
await check('validações: id não UUID, provedor, plataforma, token vazio', async () => {
  assert.equal((await put(a.accessToken, 'nao-uuid', valid('t'))).status, 400);
  assert.equal((await put(a.accessToken, randomUUID(), { ...valid('t'), provider: 'apns' })).status, 400);
  assert.equal((await put(a.accessToken, randomUUID(), { ...valid('t'), platform: 'windows' })).status, 400);
  assert.equal((await put(a.accessToken, randomUUID(), valid(''))).status, 400);
  assert.equal((await put(a.accessToken, randomUUID(), {})).status, 400);
});
await check('sem autenticação é 401', async () => {
  assert.equal((await put(null, randomUUID(), valid('t'))).status, 401);
  assert.equal((await http('DELETE', `/push/installations/${randomUUID()}`, null)).status, 401);
});
await check('trocar de conta no mesmo aparelho: a instalação muda de dono sem erro', async () => {
  const id = randomUUID();
  assert.equal((await put(a.accessToken, id, valid(`tok-${n}-shared`))).status, 204);
  assert.equal((await put(b.accessToken, id, valid(`tok-${n}-shared`))).status, 204);
});
await check('mesmo token em outra instalação não gera conflito (o token muda de dono)', async () => {
  assert.equal((await put(a.accessToken, randomUUID(), valid(`tok-${n}-same`))).status, 204);
  assert.equal((await put(b.accessToken, randomUUID(), valid(`tok-${n}-same`))).status, 204);
});
await check('revogar: 204, idempotente, e de outra pessoa é 204 sem efeito', async () => {
  const id = randomUUID();
  await put(a.accessToken, id, valid(`tok-${n}-rev`));
  assert.equal((await http('DELETE', `/push/installations/${id}`, b.accessToken)).status, 204, 'b: no-op');
  assert.equal((await http('DELETE', `/push/installations/${id}`, a.accessToken)).status, 204);
  assert.equal((await http('DELETE', `/push/installations/${id}`, a.accessToken)).status, 204, 'de novo');
  assert.equal((await http('DELETE', `/push/installations/${randomUUID()}`, a.accessToken)).status, 204, 'inexistente');
});
await check('revogar com id inválido é 400', async () => {
  assert.equal((await http('DELETE', '/push/installations/xxx', a.accessToken)).status, 400);
});
await check('o fluxo social continua funcionando com instalações FCM e FCM desligado', async () => {
  await put(a.accessToken, randomUUID(), valid(`tok-${n}-social`));
  const post = (await http('POST', '/posts', a.accessToken, { content: 'oi' })).body;
  assert.equal((await http('POST', `/posts/${post.id}/like`, b.accessToken)).status, 204);
  assert.equal((await http('POST', `/posts/${post.id}/comments`, b.accessToken, { content: 'oi' })).status, 201);
  assert.equal((await http('POST', `/users/${a.user.id}/follow`, b.accessToken)).status, 204);
  const list = (await http('GET', '/notifications', a.accessToken)).body;
  assert.deepEqual(list.items.map((i) => i.type).sort(), ['comment', 'follow', 'like']);
});
await check('o endpoint legado de token Expo segue respondendo', async () => {
  assert.equal((await http('POST', '/users/me/push-token', a.accessToken, { token: 'ExponentPushToken[legado]' })).status, 204);
});

console.log(`\n${ok} verificações ok`);
