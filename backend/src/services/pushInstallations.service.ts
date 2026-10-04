import { and, eq, ne } from 'drizzle-orm';
import { db } from '../db';
import { pushInstallations } from '../db/schema';

interface Registration {
  provider: 'expo' | 'fcm';
  platform: string;
  token: string;
}

/**
 * Registra (ou atualiza) a instalação do app para o usuário logado. Idempotente.
 *
 * - Se a instalação já existia para outra conta (troca de conta no mesmo aparelho), ela passa a
 *   ser da conta atual: a conta anterior deixa de receber push ali.
 * - Se o mesmo token estava em outra instalação (o sistema reaproveitou o token), essa outra
 *   linha é removida: um token só pode ter um dono.
 */
export async function register(userId: string, installationId: string, input: Registration) {
  await db.transaction(async (tx) => {
    await tx
      .delete(pushInstallations)
      .where(
        and(
          eq(pushInstallations.provider, input.provider),
          eq(pushInstallations.token, input.token),
          ne(pushInstallations.installationId, installationId),
        ),
      );

    await tx
      .insert(pushInstallations)
      .values({ installationId, userId, provider: input.provider, platform: input.platform, token: input.token })
      .onConflictDoUpdate({
        target: pushInstallations.installationId,
        set: {
          userId,
          provider: input.provider,
          platform: input.platform,
          token: input.token,
          active: true,
          updatedAt: new Date(),
        },
      });
  });
}

/**
 * Revoga a instalação, só se for do usuário logado. Instalação inexistente ou de outra pessoa não
 * é erro nem revela nada (a resposta é a mesma): impede revogar a de outro e enumerar ids.
 */
export async function revoke(userId: string, installationId: string) {
  await db
    .delete(pushInstallations)
    .where(and(eq(pushInstallations.installationId, installationId), eq(pushInstallations.userId, userId)));
}
