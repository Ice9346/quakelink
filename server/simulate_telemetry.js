import "dotenv/config";
import axios from "axios";

const baseUrl = (process.env.TB_BASE_URL || "").replace(/\/$/, "");
const deviceToken = (process.env.TB_DEVICE_ACCESS_TOKEN || "").trim();

const THAI_LOCATIONS = [
  ["Bangkok", 13.7563, 100.5018],
  ["Chiang Mai", 18.7883, 98.9853],
  ["Chiang Rai", 19.9105, 99.8406],
  ["Phrae", 18.1446, 100.1403],
  ["Nan", 18.7756, 100.7730],
  ["Phitsanulok", 16.8211, 100.2659],
  ["Khon Kaen", 16.4322, 102.8236],
  ["Udon Thani", 17.4138, 102.7875],
  ["Nakhon Ratchasima", 14.9799, 102.0978],
  ["Ubon Ratchathani", 15.2287, 104.8564],
  ["Ayutthaya", 14.3532, 100.5680],
  ["Chonburi", 13.3611, 100.9847],
  ["Hua Hin", 12.5684, 99.9577],
  ["Surat Thani", 9.1382, 99.3217],
  ["Phuket", 7.8804, 98.3923],
  ["Hat Yai", 7.0084, 100.4747],
];

if (!baseUrl || !deviceToken) {
  console.error("ต้องตั้ง TB_BASE_URL และ TB_DEVICE_ACCESS_TOKEN ใน server/.env ก่อน");
  process.exit(1);
}

if (!process.stdin.isTTY) {
  console.error("Simulator ต้องรันใน Terminal ที่รับปุ่มคีย์บอร์ดได้");
  process.exit(1);
}

function randomTelemetry() {
  const [location, centerLat, centerLng] =
    THAI_LOCATIONS[Math.floor(Math.random() * THAI_LOCATIONS.length)];
  return {
    pga: Number((0.05 + Math.random() * 0.45).toFixed(2)),
    si: Number((0.5 + Math.random() * 5).toFixed(2)),
    temp: Number((25 + Math.random() * 10).toFixed(1)),
    lat: Number((centerLat + (Math.random() - 0.5) * 0.04).toFixed(6)),
    lng: Number((centerLng + (Math.random() - 0.5) * 0.04).toFixed(6)),
    location,
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
