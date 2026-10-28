import "dotenv/config";
import axios from "axios";

const baseUrl = (process.env.TB_BASE_URL || "").replace(/\/$/, "");
const deviceToken = (process.env.TB_DEVICE_ACCESS_TOKEN || "").trim();

if (!baseUrl || !deviceToken) {
  console.error("ต้องตั้ง TB_BASE_URL และ TB_DEVICE_ACCESS_TOKEN ใน server/.env ก่อน");
  process.exit(1);
}

if (!process.stdin.isTTY) {
  console.error("Simulator ต้องรันใน Terminal ที่รับปุ่มคีย์บอร์ดได้");
  process.exit(1);
}

function randomTelemetry() {
  return {
    pga: Number((0.05 + Math.random() * 0.45).toFixed(2)),
    si: Number((0.5 + Math.random() * 5).toFixed(2)),
    temp: Number((25 + Math.random() * 10).toFixed(1)),
    lat: Number((18.1446 + (Math.random() - 0.5) * 0.01).toFixed(6)),
    lng: Number((100.1403 + (Math.random() - 0.5) * 0.01).toFixed(6)),
    location: "Phrae",
    distanceKm: Number((1 + Math.random() * 5).toFixed(2)),
    timestamp: Date.now(),
    events: JSON.stringify({ type: "simulated", source: "spacebar" }),
  };
}

async function sendTelemetry() {
  const telemetry = randomTelemetry();
  const url = `${baseUrl}/api/v1/${deviceToken}/telemetry`;

  try {
    const response = await axios.post(url, telemetry, {
      headers: { "Content-Type": "application/json" },
      timeout: 10_000,
    });
    console.log(`✅ sent ${response.status}:`, telemetry);
  } catch (error) {
    console.error(
      "❌ send failed:",
      error.response?.status,
      error.response?.data || error.message,
    );
  }
}

console.log("🎮 Telemetry simulator พร้อมแล้ว");
console.log("กด Spacebar เพื่อสุ่มค่าและส่งเข้า ThingsBoard | กด q หรือ Ctrl+C เพื่อออก");

process.stdin.setRawMode(true);
process.stdin.resume();
process.stdin.setEncoding("utf8");
process.stdin.on("data", (key) => {
  if (key === "q" || key === "\u0003") {
    process.stdin.setRawMode(false);
    process.exit(0);
  }
  if (key === " ") sendTelemetry();
});
