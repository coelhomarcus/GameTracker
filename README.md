# GameTracker

App social pra acompanhar os jogos que você tá jogando — trackeie playthroughs (status, horas, nota, plataforma), veja um perfil público com backlog, poste sobre o que tá jogando, siga outras pessoas e converse em tempo real. Trabalho de faculdade.

## Stack

- **Backend**: Node.js, Express, TypeScript, Drizzle ORM (PostgreSQL), Redis + Socket.IO (chat em tempo real), JWT (auth), IGDB (dados dos jogos)
- **Mobile**: Expo (React Native), TypeScript, React Navigation, TanStack Query, Zustand

## Rodando localmente

Pré-requisitos: Node 22+, Docker (opcional, só pro Postgres/Redis locais), uma conta na [IGDB/Twitch Developer](https://api-docs.igdb.com/#getting-started) pra buscar jogos.

### Backend

```bash
cd backend
cp .env.example .env   # preencha DATABASE_URL, JWT_ACCESS_SECRET, IGDB_CLIENT_ID/SECRET
npm install
npm run db:migrate     # aplica as migrations
npm run dev            # sobe em http://localhost:3000
```

Se não tiver um Postgres/Redis próprios, tem um `docker-compose.dev.yml` na raiz do projeto pra subir os dois localmente.

### Mobile

```bash
cd mobile
cp .env.example .env   # aponte EXPO_PUBLIC_API_URL pro backend (IP da rede local se for testar em dispositivo físico)
npm install
npm start              # abre o Metro — escaneie o QR code com o Expo Go, ou pressione i/a pro simulador
```

## Build (APK Android)

O projeto já tem o EAS configurado. Pra gerar um APK completo (bundle já embutido, instala direto sem precisar do Metro rodando):

```bash
cd mobile
npx eas-cli login
npx eas-cli build --platform android --profile preview
```

Ao terminar, o EAS dá um link/QR code pra baixar o `.apk` direto no celular.

## Documentação

O progresso e as decisões de cada fase do projeto estão registrados em [ROADMAP.md](ROADMAP.md).
