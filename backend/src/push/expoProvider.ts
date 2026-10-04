import { Expo, type ExpoPushMessage, type ExpoPushTicket } from 'expo-server-sdk';
import type { PushPayload, PushProvider, PushResult } from './types';

/** Parte do cliente do SDK que usamos (permite trocar por um falso nos testes). */
export interface ExpoClient {
  sendPushNotificationsAsync(messages: ExpoPushMessage[]): Promise<ExpoPushTicket[]>;
}

export class ExpoProvider implements PushProvider {
  readonly name = 'expo' as const;
  readonly enabled = true;

  constructor(private readonly client: ExpoClient = new Expo()) {}

  async send(tokens: string[], payload: PushPayload): Promise<PushResult[]> {
    const valid = tokens.filter((t) => Expo.isExpoPushToken(t));
    // Um token que nem tem o formato de Expo nunca vai funcionar.
    const results: PushResult[] = tokens.filter((t) => !valid.includes(t)).map((token) => ({ token, outcome: 'invalid' as const }));
    if (valid.length === 0) return results;

    const messages: ExpoPushMessage[] = valid.map((to) => ({
      to,
      title: payload.title,
      body: payload.expoBody ?? payload.body,
      data: payload.data,
      sound: 'default',
    }));

    let tickets: ExpoPushTicket[];
    try {
      tickets = await this.client.sendPushNotificationsAsync(messages);
    } catch (err) {
      console.error('[push:expo] falha ao enviar:', err);
      return [...results, ...valid.map((token) => ({ token, outcome: 'failed' as const }))];
    }

    valid.forEach((token, i) => {
      const ticket = tickets[i];
      if (!ticket) {
        results.push({ token, outcome: 'failed' });
      } else if (ticket.status === 'ok') {
        results.push({ token, outcome: 'ok' });
      } else {
        // O ticket de erro diz se o aparelho deixou de existir (app desinstalado).
        results.push({ token, outcome: ticket.details?.error === 'DeviceNotRegistered' ? 'invalid' : 'failed' });
      }
    });
    return results;
  }
}
