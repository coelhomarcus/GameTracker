// Grava docs/contract-fixtures/responses/push_payloads.json: o `data` que o backend REALMENTE monta
// para curtida, comentário e seguidor (via notify), com um provedor que só captura.
//   cd backend && DATABASE_URL=postgresql://...@localhost:5433/... npx tsx scripts/capturePushPayloads.ts
// Se recusa a rodar contra um banco que não seja local. Nada sai pela rede.
import 'dotenv/config';
import { writeFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import { eq } from 'drizzle-orm';
import { db } from '../src/db';
import { posts, pushInstallations, users } from '../src/db/schema';
import { notify } from '../src/services/notifications.service';
import { setPushProviders } from '../src/push/pushService';
import type { PushPayload, PushProvider } from '../src/push/types';

if (!/@(localhost|127\.0\.0\.1)[:/]/.test(process.env.DATABASE_URL ?? '')) {
  throw new Error('DATABASE_URL precisa apontar para uma máquina local');
}

const sent: PushPayload[] = [];
const capture = (name: 'expo' | 'fcm'): PushProvider => ({
  name,
  enabled: true,
  async send(tokens, payload) {
    if (name === 'fcm') sent.push(payload);
    return tokens.map((token) => ({ token, outcome: 'ok' as const }));
  },
});
setPushProviders({ expo: capture('expo'), fcm: capture('fcm') });

async function main() {
const n = Date.now().toString(36);
const mk = async (p: string) =>
  (await db.insert(users).values({ username: `${p}_${n}`, email: `${p}_${n}@example.test`, passwordHash: 'x' }).returning())[0]!;
const recipient = await mk('pr');
const actor = await mk('pa');
const [post] = await db.insert(posts).values({ userId: recipient.id, content: 'post de fixture' }).returning();
await db.insert(pushInstallations).values({
  installationId: randomUUID(),
  userId: recipient.id,
  provider: 'fcm',
  platform: 'android',
  token: `fixture-token-${n}`,
});

const out: Record<string, Record<string, string>> = {};
for (const type of ['like', 'comment', 'follow'] as const) {
  sent.length = 0;
  await notify({ userId: recipient.id, actorId: actor.id, type, postId: type === 'follow' ? undefined : post!.id });
  await new Promise((r) => setTimeout(r, 300));
  if (sent.length !== 1) throw new Error(`${type}: esperava 1 push, veio ${sent.length}`);
  out[type] = sent[0]!.data;
}
// O de mensagem é montado em src/socket/chatHandlers.ts com este formato exato.
out.message = {
  type: 'message',
  recipientId: recipient.id,
  conversationId: randomUUID(),
  messageId: randomUUID(),
};

writeFileSync(`${__dirname}/../../docs/contract-fixtures/responses/push_payloads.json`, JSON.stringify({ status: 200, body: out }, null, 2) + '\n');
console.log(out);

await db.delete(users).where(eq(users.id, recipient.id));
await db.delete(users).where(eq(users.id, actor.id));
}

main().then(() => process.exit(0), (e) => { console.error(e); process.exit(1); });
