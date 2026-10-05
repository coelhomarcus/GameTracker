// Testes do push: adaptadores (com clientes falsos) e do serviço (com o banco ISOLADO).
//   npm test
// Os testes de banco só rodam no banco de teste (a trava está em test/helpers/env.ts).
import '../../test/helpers/env';
import assert from 'node:assert/strict';
import { after, afterEach, describe, it } from 'node:test';
import 'dotenv/config';
import { eq, inArray } from 'drizzle-orm';
import { db } from '../db';
import { pushInstallations, users } from '../db/schema';
import * as installations from '../services/pushInstallations.service';
import { ExpoProvider, type ExpoClient } from './expoProvider';
import { createFcmProviderFromEnv, FcmProvider, type FcmMessage, type FcmMessaging } from './fcmProvider';
import { sendPushToUser, setPushProviders } from './pushService';
import type { PushPayload, PushProvider, PushResult } from './types';

const payload: PushPayload = { title: 'Nova curtida', body: 'ana curtiu seu post', expoBody: 'texto legado', data: { type: 'like', postId: 'p1' } };

const EXPO_A = 'ExponentPushToken[aaaaaaaaaaaaaaaaaaaaaa]';
const EXPO_B = 'ExponentPushToken[bbbbbbbbbbbbbbbbbbbbbb]';

describe('ExpoProvider', () => {
  const make = (tickets: unknown, spy: { sent?: unknown[] } = {}) => {
    const client: ExpoClient = {
      async sendPushNotificationsAsync(messages) {
        spy.sent = messages;
        if (tickets instanceof Error) throw tickets;
        return tickets as never;
      },
    };
    return new ExpoProvider(client);
  };

  it('ok quando o ticket é ok; usa o corpo legado e leva os dados', async () => {
    const spy: { sent?: Array<{ body?: string; data?: unknown }> } = {};
    const results = await make([{ status: 'ok', id: '1' }], spy as never).send([EXPO_A], payload);
    assert.deepEqual(results, [{ token: EXPO_A, outcome: 'ok' }]);
    assert.equal(spy.sent![0]!.body, 'texto legado');
    assert.deepEqual(spy.sent![0]!.data, payload.data);
  });

  it('DeviceNotRegistered no ticket vira "invalid"; outros erros viram "failed"', async () => {
    const results = await make([
      { status: 'error', message: 'x', details: { error: 'DeviceNotRegistered' } },
      { status: 'error', message: 'y', details: { error: 'MessageRateExceeded' } },
    ]).send([EXPO_A, EXPO_B], payload);
    assert.deepEqual(results, [
      { token: EXPO_A, outcome: 'invalid' },
      { token: EXPO_B, outcome: 'failed' },
    ]);
  });

  it('token que não tem o formato Expo é inválido e nem é enviado', async () => {
    const spy: { sent?: unknown[] } = {};
    const results = await make([{ status: 'ok', id: '1' }], spy).send(['nao-e-expo', EXPO_A], payload);
    assert.equal(spy.sent!.length, 1);
    assert.deepEqual(results.find((r) => r.token === 'nao-e-expo'), { token: 'nao-e-expo', outcome: 'invalid' });
  });

  it('falha de rede não lança: devolve "failed" (não invalida o token)', async () => {
    const results = await make(new Error('rede')).send([EXPO_A], payload);
    assert.deepEqual(results, [{ token: EXPO_A, outcome: 'failed' }]);
  });

  it('ticket faltando conta como falha', async () => {
    const results = await make([]).send([EXPO_A], payload);
    assert.deepEqual(results, [{ token: EXPO_A, outcome: 'failed' }]);
  });
});

describe('FcmProvider', () => {
  const messaging = (responses: { success: boolean; error?: { code?: string } }[], spy: { sent?: FcmMessage[] } = {}): FcmMessaging => ({
    async sendEach(messages) {
      spy.sent = messages;
      return { responses };
    },
  });

  it('envia texto genérico (sem expoBody), dados e prioridade alta', async () => {
    const spy: { sent?: FcmMessage[] } = {};
    const results = await new FcmProvider(messaging([{ success: true }], spy)).send(['t1'], payload);
    assert.deepEqual(results, [{ token: 't1', outcome: 'ok' }]);
    assert.equal(spy.sent![0]!.notification.body, 'ana curtiu seu post');
    assert.deepEqual(spy.sent![0]!.data, payload.data);
    assert.equal(spy.sent![0]!.android?.priority, 'high');
  });

  it('token não registrado ou inválido vira "invalid"; erro transitório vira "failed"', async () => {
    const results = await new FcmProvider(
      messaging([
        { success: false, error: { code: 'messaging/registration-token-not-registered' } },
        { success: false, error: { code: 'messaging/invalid-registration-token' } },
        { success: false, error: { code: 'messaging/server-unavailable' } },
      ]),
    ).send(['a', 'b', 'c'], payload);
    assert.deepEqual(results.map((r) => r.outcome), ['invalid', 'invalid', 'failed']);
  });

  it('sem credenciais fica desligado e não envia', async () => {
    const provider = new FcmProvider(null);
    assert.equal(provider.enabled, false);
    assert.deepEqual(await provider.send(['t'], payload), []);
  });

  it('exceção do cliente não lança', async () => {
    const provider = new FcmProvider({
      async sendEach() {
        throw new Error('rede');
      },
    });
    assert.deepEqual(await provider.send(['t'], payload), [{ token: 't', outcome: 'failed' }]);
  });

  it('createFcmProviderFromEnv: sem variável ou com JSON inválido, desligado e sem lançar', async () => {
    assert.equal((await createFcmProviderFromEnv({})).enabled, false);
    assert.equal((await createFcmProviderFromEnv({ FCM_SERVICE_ACCOUNT_JSON: 'isto não é json' })).enabled, false);
  });
});

/** Provedor falso que registra o que recebeu e devolve o resultado que o teste mandar. */
class FakeProvider implements PushProvider {
  calls: string[][] = [];
  outcomes = new Map<string, PushResult['outcome']>();
  throws = false;
  constructor(readonly name: 'expo' | 'fcm', public enabled = true) {}
  async send(tokens: string[]): Promise<PushResult[]> {
    if (this.throws) throw new Error('boom');
    this.calls.push([...tokens].sort());
    return tokens.map((token) => ({ token, outcome: this.outcomes.get(token) ?? 'ok' }));
  }
}

describe('sendPushToUser + instalações (banco de teste)', () => {
  const createdUsers: string[] = [];
  const stamp = Date.now().toString(36);
  let n = 0;

  async function newUser(expoPushToken?: string) {
    const username = `pt_${stamp}_${n++}`;
    const [u] = await db.insert(users).values({ username, name: username, email: `${username}@example.test`, passwordHash: 'x', expoPushToken }).returning();
    createdUsers.push(u!.id);
    return u!.id;
  }
  const uuid = () => crypto.randomUUID();

  afterEach(() => setPushProviders(null));
  after(async () => {
    if (createdUsers.length) await db.delete(users).where(inArray(users.id, createdUsers));
  });

  function fakes() {
    const expo = new FakeProvider('expo');
    const fcm = new FakeProvider('fcm');
    setPushProviders({ expo, fcm });
    return { expo, fcm };
  }

  it('envia para vários aparelhos, cada um pelo seu provedor', async () => {
    const { expo, fcm } = fakes();
    const user = await newUser();
    await installations.register(user, uuid(), { provider: 'fcm', platform: 'android', token: `fcm-${stamp}-1` });
    await installations.register(user, uuid(), { provider: 'fcm', platform: 'web', token: `fcm-${stamp}-2` });
    await installations.register(user, uuid(), { provider: 'expo', platform: 'android', token: EXPO_A + stamp });
    await sendPushToUser(user, payload);
    assert.deepEqual(fcm.calls, [[`fcm-${stamp}-1`, `fcm-${stamp}-2`]]);
    assert.deepEqual(expo.calls, [[EXPO_A + stamp]]);
  });

  it('inclui o token Expo legado e não repete se ele também está nas instalações', async () => {
    const { expo } = fakes();
    const legacyOnly = await newUser(EXPO_A + 'L1' + stamp);
    await sendPushToUser(legacyOnly, payload);
    assert.deepEqual(expo.calls, [[EXPO_A + 'L1' + stamp]]);

    expo.calls = [];
    const both = await newUser(EXPO_B + 'L2' + stamp);
    await installations.register(both, uuid(), { provider: 'expo', platform: 'android', token: EXPO_B + 'L2' + stamp });
    await sendPushToUser(both, payload);
    assert.deepEqual(expo.calls, [[EXPO_B + 'L2' + stamp]], 'um envio só para o mesmo token');
  });

  it('provedor desligado é ignorado sem erro', async () => {
    const expo = new FakeProvider('expo');
    const fcm = new FakeProvider('fcm', false);
    setPushProviders({ expo, fcm });
    const user = await newUser();
    await installations.register(user, uuid(), { provider: 'fcm', platform: 'android', token: `fcm-off-${stamp}` });
    await sendPushToUser(user, payload);
    assert.deepEqual(fcm.calls, []);
  });

  it('token que o provedor diz inválido é desativado e não é usado de novo', async () => {
    const { fcm } = fakes();
    const user = await newUser();
    const id = uuid();
    await installations.register(user, id, { provider: 'fcm', platform: 'android', token: `fcm-dead-${stamp}` });
    await installations.register(user, uuid(), { provider: 'fcm', platform: 'android', token: `fcm-live-${stamp}` });
    fcm.outcomes.set(`fcm-dead-${stamp}`, 'invalid');

    await sendPushToUser(user, payload);
    const row = await db.query.pushInstallations.findFirst({ where: eq(pushInstallations.installationId, id) });
    assert.equal(row?.active, false);

    fcm.calls = [];
    await sendPushToUser(user, payload);
    assert.deepEqual(fcm.calls, [[`fcm-live-${stamp}`]], 'só o token válido');
  });

  it('falha transitória não desativa o token', async () => {
    const { fcm } = fakes();
    const user = await newUser();
    const id = uuid();
    await installations.register(user, id, { provider: 'fcm', platform: 'android', token: `fcm-flaky-${stamp}` });
    fcm.outcomes.set(`fcm-flaky-${stamp}`, 'failed');
    await sendPushToUser(user, payload);
    const row = await db.query.pushInstallations.findFirst({ where: eq(pushInstallations.installationId, id) });
    assert.equal(row?.active, true);
  });

  it('Expo inválido limpa também o token legado', async () => {
    const { expo } = fakes();
    const user = await newUser(EXPO_A + 'DEAD' + stamp);
    expo.outcomes.set(EXPO_A + 'DEAD' + stamp, 'invalid');
    await sendPushToUser(user, payload);
    const row = await db.query.users.findFirst({ where: eq(users.id, user), columns: { expoPushToken: true } });
    assert.equal(row?.expoPushToken, null);
  });

  it('um provedor que lança não derruba quem chamou (nem impede o outro)', async () => {
    const { expo, fcm } = fakes();
    expo.throws = true;
    const user = await newUser();
    await installations.register(user, uuid(), { provider: 'expo', platform: 'android', token: EXPO_A + 'T' + stamp });
    await installations.register(user, uuid(), { provider: 'fcm', platform: 'android', token: `fcm-ok-${stamp}` });
    await assert.doesNotReject(sendPushToUser(user, payload));
  });

  it('não envia para instalações inativas nem de outros usuários', async () => {
    const { fcm } = fakes();
    const a = await newUser();
    const b = await newUser();
    const idA = uuid();
    await installations.register(a, idA, { provider: 'fcm', platform: 'android', token: `fcm-a-${stamp}` });
    await installations.register(b, uuid(), { provider: 'fcm', platform: 'android', token: `fcm-b-${stamp}` });
    await db.update(pushInstallations).set({ active: false }).where(eq(pushInstallations.installationId, idA));
    await sendPushToUser(a, payload);
    assert.deepEqual(fcm.calls, [], 'a só tem token inativo');
    await sendPushToUser(b, payload);
    assert.deepEqual(fcm.calls, [[`fcm-b-${stamp}`]]);
  });

  it('trocar de conta no mesmo aparelho: a instalação passa para a conta nova', async () => {
    const { fcm } = fakes();
    const a = await newUser();
    const b = await newUser();
    const installation = uuid();
    await installations.register(a, installation, { provider: 'fcm', platform: 'android', token: `fcm-shared-${stamp}` });
    await installations.register(b, installation, { provider: 'fcm', platform: 'android', token: `fcm-shared-${stamp}` });

    await sendPushToUser(a, payload);
    assert.deepEqual(fcm.calls, [], 'a conta anterior para de receber neste aparelho');
    await sendPushToUser(b, payload);
    assert.deepEqual(fcm.calls, [[`fcm-shared-${stamp}`]]);
  });

  it('o mesmo token em outra instalação tira o token da antiga (um dono só)', async () => {
    const { fcm } = fakes();
    const a = await newUser();
    const b = await newUser();
    await installations.register(a, uuid(), { provider: 'fcm', platform: 'android', token: `fcm-moved-${stamp}` });
    await installations.register(b, uuid(), { provider: 'fcm', platform: 'android', token: `fcm-moved-${stamp}` });
    await sendPushToUser(a, payload);
    assert.deepEqual(fcm.calls, []);
    await sendPushToUser(b, payload);
    assert.equal(fcm.calls.length, 1);
  });

  it('registrar de novo atualiza o token (rotação) e reativa', async () => {
    const { fcm } = fakes();
    const user = await newUser();
    const id = uuid();
    await installations.register(user, id, { provider: 'fcm', platform: 'android', token: `fcm-old-${stamp}` });
    await db.update(pushInstallations).set({ active: false }).where(eq(pushInstallations.installationId, id));
    await installations.register(user, id, { provider: 'fcm', platform: 'android', token: `fcm-new-${stamp}` });
    await sendPushToUser(user, payload);
    assert.deepEqual(fcm.calls, [[`fcm-new-${stamp}`]]);
  });

  it('revogar só vale para o dono; de outra pessoa é um no-op silencioso', async () => {
    const { fcm } = fakes();
    const a = await newUser();
    const b = await newUser();
    const id = uuid();
    await installations.register(a, id, { provider: 'fcm', platform: 'android', token: `fcm-rev-${stamp}` });

    await installations.revoke(b, id);
    await sendPushToUser(a, payload);
    assert.equal(fcm.calls.length, 1, 'b não conseguiu revogar a instalação de a');

    fcm.calls = [];
    await installations.revoke(a, id);
    await sendPushToUser(a, payload);
    assert.deepEqual(fcm.calls, []);
    await assert.doesNotReject(installations.revoke(a, id), 'revogar de novo é idempotente');
  });
});
