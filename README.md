# GameTracker

App social pra acompanhar os jogos que você tá jogando — trackeie playthroughs (status, horas, nota, plataforma), veja um perfil público com backlog, poste sobre o que tá jogando, siga outras pessoas e converse em tempo real. Trabalho de faculdade.

## Stack

- **Backend**: Node.js, Express, TypeScript, Drizzle ORM (PostgreSQL), Redis + Socket.IO (chat em tempo real), JWT (auth), IGDB (dados dos jogos)
- **App (oficial)**: Flutter (Android e web), Material 3, Riverpod, go_router, Dio, Socket.IO — em [`flutter_app/`](flutter_app/)
- **App legado**: Expo (React Native) em [`mobile/`](mobile/), mantido só como plano de retorno até o encerramento descrito em [`docs/MIGRACAO_FLUTTER.md`](docs/MIGRACAO_FLUTTER.md) (seção 11); não recebe funcionalidades novas

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

### App Flutter

Pré-requisito: Flutter 3.47 (Android SDK para o APK). Veja também [`flutter_app/README.md`](flutter_app/README.md).

```bash
cd flutter_app
flutter pub get
flutter run -d chrome                          # web, contra http://localhost:3100
flutter test                                   # unidade, widget e aceite
flutter test test/integration --dart-define=GT_BACKEND=http://localhost:3100   # backend ISOLADO
```

A URL da API entra no build (`--dart-define=API_URL=https://...`). Nunca rode os testes de integração contra um banco compartilhado ou de produção.

### App legado (Expo)

```bash
cd mobile
cp .env.example .env   # EXPO_PUBLIC_API_URL
npm install
npm start
```

## Build (APK Android do app Flutter)

```bash
cd flutter_app
# precisa de android/key.properties (fora do git) com a chave de assinatura
API_URL=https://api.seudominio.com tool/build_release.sh
```

O script recusa API sem HTTPS e APK assinado com a chave de debug. O mesmo fluxo roda no GitHub Actions (`.github/workflows/flutter-release.yml`, com secrets). O EAS do app legado (`mobile/eas.json`) deixa de ser o caminho de distribuição.

## Documentação

O progresso e as decisões de cada fase do projeto estão registrados em [docs/01_ROADMAP.md](docs/01_ROADMAP.md); a migração para Flutter (decisões, histórico, aceite e o que falta) está em [docs/MIGRACAO_FLUTTER.md](docs/MIGRACAO_FLUTTER.md).
