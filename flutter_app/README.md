# GameTracker (Flutter)

Frontend Flutter do GameTracker (Android e web). Decisões, histórico e o que falta: [`docs/MIGRACAO_FLUTTER.md`](../docs/MIGRACAO_FLUTTER.md).

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

Estado: autenticação, catálogo, biblioteca, comunidade, perfis, configurações, chat em tempo real e central de notificações reais (Etapas 3 a 8). Build de release assinado: `tool/build_release.sh`; critérios e pendências em `docs/MIGRACAO_FLUTTER.md`. Push com o app fechado está fora desta entrega (sem Firebase); o cliente já tem a interface pronta para o adaptador FCM.
