#!/usr/bin/env python3
"""ส่ง telemetry จำลองเข้า ThingsBoard ทุกช่วงเวลาที่กำหนด"""

import argparse
import json
import random
import ssl
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

import certifi


def load_env():
    values = {}
    env_path = Path(__file__).with_name(".env")
    if not env_path.exists():
        return values

    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in ('"', "'"):
            value = value[1:-1]
        values[key.strip()] = value
    return values


env = load_env()
base_url = env.get("TB_BASE_URL", "").rstrip("/")
device_token = env.get("TB_DEVICE_ACCESS_TOKEN", "").strip()

THAI_LOCATIONS = [
    ("Bangkok", 13.7563, 100.5018),
    ("Chiang Mai", 18.7883, 98.9853),
    ("Chiang Rai", 19.9105, 99.8406),
    ("Phrae", 18.1446, 100.1403),
    ("Nan", 18.7756, 100.7730),
    ("Phitsanulok", 16.8211, 100.2659),
    ("Khon Kaen", 16.4322, 102.8236),
    ("Udon Thani", 17.4138, 102.7875),
    ("Nakhon Ratchasima", 14.9799, 102.0978),
    ("Ubon Ratchathani", 15.2287, 104.8564),
    ("Ayutthaya", 14.3532, 100.5680),
    ("Chonburi", 13.3611, 100.9847),
    ("Hua Hin", 12.5684, 99.9577),
    ("Surat Thani", 9.1382, 99.3217),
    ("Phuket", 7.8804, 98.3923),
    ("Hat Yai", 7.0084, 100.4747),
]


def make_telemetry():
    location, center_lat, center_lng = random.choice(THAI_LOCATIONS)
    return {
        "pga": round(random.uniform(0.05, 0.50), 2),
        "si": round(random.uniform(0.50, 5.50), 2),
        "temp": round(random.uniform(25.0, 35.0), 1),
        "lat": round(center_lat + random.uniform(-0.02, 0.02), 6),
        "lng": round(center_lng + random.uniform(-0.02, 0.02), 6),
        "location": location,
        "distanceKm": round(random.uniform(1.0, 6.0), 2),
        "timestamp": int(time.time() * 1000),
        "events": json.dumps({"type": "simulated", "source": "python"}),
    }


def send_telemetry():
    payload = make_telemetry()
    url = f"{base_url}/api/v1/{device_token}/telemetry"
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        tls_context = ssl.create_default_context(cafile=certifi.where())
        with urllib.request.urlopen(request, timeout=10, context=tls_context) as response:
            print(
                f"✅ {datetime.now(timezone.utc).isoformat()} "
                f"sent HTTP {response.status}: {payload}",
                flush=True,
            )
    except urllib.error.HTTPError as error:
        print(f"❌ ThingsBoard HTTP {error.code}: {error.read().decode(errors='replace')}", flush=True)
    except urllib.error.URLError as error:
        print(f"❌ ThingsBoard connection failed: {error.reason}", flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--interval", type=int, default=120, help="วินาทีระหว่างการส่ง (default: 120)")
    parser.add_argument("--once", action="store_true", help="ส่งเพียงครั้งเดียวแล้วจบ")
    args = parser.parse_args()

    if not base_url or not device_token:
        raise SystemExit("ต้องตั้ง TB_BASE_URL และ TB_DEVICE_ACCESS_TOKEN ใน server/.env ก่อน")
    if args.interval < 1:
        raise SystemExit("--interval ต้องมากกว่า 0")

    print(f"🎮 Python simulator เริ่มทำงาน: ส่งทุก {args.interval} วินาที", flush=True)
    try:
        while True:
            send_telemetry()
            if args.once:
                return
            print("รอรอบถัดไป... (กด Ctrl+C เพื่อหยุด)", flush=True)
            time.sleep(args.interval)
    except KeyboardInterrupt:
        print("\nหยุด simulator แล้ว", flush=True)


if __name__ == "__main__":
    main()
