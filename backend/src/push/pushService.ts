import { and, eq, inArray } from 'drizzle-orm';
import { db } from '../db';
import { pushInstallations } from '../db/schema';
import { createFcmProviderFromEnv } from './fcmProvider';
import type { PushPayload, PushProvider } from './types';

let provider: PushProvider | null = null;
let loading: Promise<PushProvider> | null = null;

async function getProvider(): Promise<PushProvider> {
  if (provider) return provider;
  loading ??= createFcmProviderFromEnv().then((fcm) => {
    provider = fcm;
    return fcm;
  });
  return loading;
}

/** Troca o provedor (testes). */
export function setPushProvider(next: PushProvider | null) {
  provider = next;
  loading = null;
}

/**
 * Envia um push a todos os aparelhos ativos de um usuário. Nunca lança: uma falha de push não
 * pode derrubar a ação principal (curtir, comentar, mandar mensagem). Tokens que o provedor diz
 * não existirem mais são desativados.
 */
export async function sendPushToUser(userId: string, payload: PushPayload): Promise<void> {
  try {
    const [installations, fcm] = await Promise.all([
      db.query.pushInstallations.findMany({
        where: and(eq(pushInstallations.userId, userId), eq(pushInstallations.active, true)),
        columns: { token: true },
      }),
      getProvider(),
    ]);

    const tokens = [...new Set(installations.map((i) => i.token))];
    if (!fcm.enabled || tokens.length === 0) return;

    const results = await fcm.send(tokens, payload);
    const invalid = results.filter((r) => r.outcome === 'invalid').map((r) => r.token);
    if (invalid.length > 0) {
      await db
        .update(pushInstallations)
        .set({ active: false, updatedAt: new Date() })
        .where(and(eq(pushInstallations.provider, 'fcm'), inArray(pushInstallations.token, invalid)));
    }
  } catch (err) {
    console.error('[push] falha ao enviar push:', err);
  }
}
