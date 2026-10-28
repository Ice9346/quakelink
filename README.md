# QuakeLink

Flutter earthquake monitoring app with a Node.js backend under `server/`.

## App

```bash
flutter pub get
flutter run --dart-define=QUAKELINK_API_BASE_URL=http://127.0.0.1:8080
```

Use your computer LAN IP instead of `127.0.0.1` when running on a physical device.

## Server

```bash
cd server
cp .env.example .env
npm install
npm run prisma:generate
npm run prisma:migrate
npm run dev
```

The server exposes HTTP and WebSocket on port `8080` by default.

See [server/README.md](server/README.md) for backend routes and environment variables.

## Checks

```bash
flutter test
cd server && npm run check
```
