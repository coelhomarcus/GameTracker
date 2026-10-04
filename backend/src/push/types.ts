/** O que se envia por push. `data` é só texto (exigência do FCM) e guia a navegação no app. */
export interface PushPayload {
  title: string;
  /** Texto exibido. Sem conteúdo sensível: o app busca o detalhe depois, já autenticado. */
  body: string;
  /**
   * Corpo do cliente legado (Expo). Existe para não mudar o comportamento dele: o chat sempre
   * enviou o texto da mensagem. Os clientes novos usam [body], genérico.
   */
  expoBody?: string;
  data: Record<string, string>;
}

/** Resultado por token. `invalid` = o provedor disse que o token não existe mais: desativar. */
export type PushOutcome = 'ok' | 'invalid' | 'failed';

export interface PushResult {
  token: string;
  outcome: PushOutcome;
}

export interface PushProvider {
  readonly name: 'expo' | 'fcm';
  /** `false` quando faltam credenciais: o provedor é ignorado, sem erro. */
  readonly enabled: boolean;
  send(tokens: string[], payload: PushPayload): Promise<PushResult[]>;
}
