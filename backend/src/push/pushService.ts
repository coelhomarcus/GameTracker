import { and, eq, inArray } from 'drizzle-orm';
import { db } from '../db';
import { pushInstallations, users } from '../db/schema';
import { createFcmProviderFromEnv } from './fcmProvider';
import { ExpoProvider } from './expoProvider';
import type { PushPayload, PushProvider, PushResult } from './types';

interface Providers {
  expo: PushProvider;
  fcm: PushProvider;
}

let providers: Providers | null = null;
let loading: Promise<Providers> | null = null;

async function getProviders(): Promise<Providers> {
  if (providers) return providers;
  loading ??= createFcmProviderFromEnv().then((fcm) => {
    providers = { expo: new ExpoProvider(), fcm };
    return providers;
  });
  return loading;
}

/** Troca os provedores (testes). */
export function setPushProviders(next: Providers | null) {
  providers = next;
  loading = null;
}

/**
 * Envia um push a todos os aparelhos ativos de um usuário. Nunca lança: uma falha de push não
 * pode derrubar a ação principal (curtir, comentar, mandar mensagem).
 *
 * Considera as instalações novas e o token Expo legado de `users.expo_push_token`, sem repetir o
 * mesmo token. Tokens que o provedor diz não existirem mais são desativados.
 */
export async function sendPushToUser(userId: string, payload: PushPayload): Promise<void> {
  try {
    const [installations, legacy, p] = await Promise.all([
      db.query.pushInstallations.findMany({
        where: and(eq(pushInstallations.userId, userId), eq(pushInstallations.active, true)),
        columns: { provider: true, token: true },
      }),
      db.query.users.findFirst({ where: eq(users.id, userId), columns: { expoPushToken: true } }),
      getProviders(),
    ]);

    const tokens: Record<'expo' | 'fcm', Set<string>> = { expo: new Set(), fcm: new Set() };
    for (const i of installations) tokens[i.provider].add(i.token);
    if (legacy?.expoPushToken) tokens.expo.add(legacy.expoPushToken);

    const results: { provider: 'expo' | 'fcm'; result: PushResult }[] = [];
    for (const name of ['expo', 'fcm'] as const) {
      const provider = p[name];
      if (!provider.enabled || tokens[name].size === 0) continue;
      const sent = await provider.send([...tokens[name]], payload);
      results.push(...sent.map((result) => ({ provider: name, result })));
    }

    await deactivateInvalid(userId, results);
  } catch (err) {
    console.error('[push] falha ao enviar push:', err);
  }
}

async function deactivateInvalid(userId: string, results: { provider: 'expo' | 'fcm'; result: PushResult }[]) {
  for (const provider of ['expo', 'fcm'] as const) {
    const invalid = results.filter((r) => r.provider === provider && r.result.outcome === 'invalid').map((r) => r.result.token);
    if (invalid.length === 0) continue;
    await db
      .update(pushInstallations)
      .set({ active: false, updatedAt: new Date() })
      .where(and(eq(pushInstallations.provider, provider), inArray(pushInstallations.token, invalid)));
    if (provider === 'expo') {
      // O token legado também deixa de valer.
      for (const token of invalid) {
        await db.update(users).set({ expoPushToken: null }).where(and(eq(users.id, userId), eq(users.expoPushToken, token)));
      }
    }
  }
}
