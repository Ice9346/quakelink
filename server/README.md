# QuakeLink Server

Backend API, WebSocket bridge, ThingsBoard telemetry bridge, and AI endpoints for the QuakeLink Flutter app.

## Setup

```bash
cd server
cp .env.example .env
npm install
npm run prisma:generate
npm run prisma:migrate
npm run dev
```

Default HTTP and WebSocket port is `8080`.

## App URL

Run the Flutter app with the same backend URL:

```bash
flutter run --dart-define=QUAKELINK_API_BASE_URL=http://127.0.0.1:8080
```

Use your machine LAN IP for a physical device.

## Main Routes

- `GET /health`
- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/google`
- `POST /auth/facebook`
- `POST /auth/github`
- `GET /me`
- `GET /alerts`
- `GET /tb/latest`
- `GET /tb/latest-all`
- `POST /chat`
- `POST /voice-chat`
- WebSocket: `ws://host:8080`

## Notes

- `.env` is intentionally ignored because it contains secrets.
- `node_modules` and latency export files are intentionally ignored.
- Latency CSV logging is off by default. Set `LATENCY_LOG_ENABLE=true` only when measuring ThingsBoard latency.
