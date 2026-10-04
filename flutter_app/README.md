# GameTracker (Flutter)

Frontend Flutter do GameTracker (Android e web). Plano e decisões: [`docs/`](../docs/02_PLANO_MIGRACAO_FLUTTER.md).

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome          # web
flutter build apk --debug      # Android
```

Testes de integração contra um backend **isolado** (nunca produção):

```bash
flutter test test/integration --dart-define=GT_BACKEND=http://localhost:3100
```

URL da API no app: `--dart-define=API_URL=https://...` (padrão: `http://localhost:3100`, ou `http://10.0.2.2:3100` no emulador Android).

Estado: autenticação, catálogo e biblioteca reais (Etapas 3 e 4). Comunidade, perfis, chat e notificações ainda são placeholders.
