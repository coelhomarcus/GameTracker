import type { PushPayload, PushProvider, PushResult } from './types';

/** Parte do `firebase-admin/messaging` que usamos. */
export interface FcmMessaging {
  sendEach(messages: FcmMessage[]): Promise<{ responses: { success: boolean; error?: { code?: string } }[] }>;
}

export interface FcmMessage {
  token: string;
  notification: { title: string; body: string };
  data: Record<string, string>;
  android?: { priority: 'high' | 'normal' };
}

/** Códigos do FCM que significam "este token não existe mais". */
const INVALID_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

export class FcmProvider implements PushProvider {
  readonly name = 'fcm' as const;

  constructor(private readonly messaging: FcmMessaging | null) {}

  get enabled() {
    return this.messaging != null;
  }

  async send(tokens: string[], payload: PushPayload): Promise<PushResult[]> {
    if (!this.messaging || tokens.length === 0) return [];

    const messages: FcmMessage[] = tokens.map((token) => ({
      token,
      notification: { title: payload.title, body: payload.body },
      data: payload.data,
      android: { priority: 'high' },
    }));

    try {
      const { responses } = await this.messaging.sendEach(messages);
      return tokens.map((token, i) => {
        const r = responses[i];
        if (!r) return { token, outcome: 'failed' as const };
        if (r.success) return { token, outcome: 'ok' as const };
        return { token, outcome: INVALID_TOKEN_CODES.has(r.error?.code ?? '') ? ('invalid' as const) : ('failed' as const) };
      });
    } catch (err) {
      console.error('[push:fcm] falha ao enviar:', err);
      return tokens.map((token) => ({ token, outcome: 'failed' as const }));
    }
  }
}

/**
 * Cria o provedor a partir de `FCM_SERVICE_ACCOUNT_JSON` (o JSON da conta de serviço do Firebase).
 * Sem a variável, o FCM fica desligado e o resto do backend funciona normalmente.
 */
export async function createFcmProviderFromEnv(env: NodeJS.ProcessEnv = process.env): Promise<FcmProvider> {
  const raw = env.FCM_SERVICE_ACCOUNT_JSON;
  if (!raw) return new FcmProvider(null);

  try {
    const { initializeApp, cert, getApps } = await import('firebase-admin/app');
    const { getMessaging } = await import('firebase-admin/messaging');
    const app = getApps()[0] ?? initializeApp({ credential: cert(JSON.parse(raw)) });
    return new FcmProvider(getMessaging(app) as unknown as FcmMessaging);
  } catch (err) {
    console.error('[push:fcm] credenciais inválidas; FCM desligado:', err);
    return new FcmProvider(null);
  }
}
