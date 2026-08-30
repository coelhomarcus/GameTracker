/** URL pública onde esta API responde — usada pra montar URLs absolutas de si mesma (proxy de imagem, uploads). */
export function getPublicBaseUrl(): string {
  return process.env.PUBLIC_API_URL ?? `http://localhost:${process.env.PORT ?? 3000}`;
}
