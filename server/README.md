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

## Telemetry simulator

ใส่ Device Access Token ของอุปกรณ์ไว้ใน `.env` ที่ `TB_DEVICE_ACCESS_TOKEN` แล้วรัน:

```bash
npm run simulate
```

กด Spacebar ใน Terminal เพื่อสุ่มค่า telemetry และส่งเข้า ThingsBoard; กด `q` เพื่อออก

ถ้าต้องการจำลองแบบส่งอัตโนมัติทุก 2 นาที ใช้ Python:

```bash
python3 -m pip install -r requirements.txt
python3 simulate_telemetry.py
```

ส่งครั้งเดียวเพื่อทดสอบ:

```bash
python3 simulate_telemetry.py --once
```

## Notes

- `.env` is intentionally ignored because it contains secrets.
- ThingsBoard access token is cached by the backend, refreshed automatically every 2 hours by default, and retried once automatically if ThingsBoard returns `401`. Override with `TB_TOKEN_REFRESH_MS` if needed.
- `node_modules` and latency export files are intentionally ignored.
- Latency CSV logging is off by default. Set `LATENCY_LOG_ENABLE=true` only when measuring ThingsBoard latency.
