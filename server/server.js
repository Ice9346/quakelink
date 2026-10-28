// server.js (updated: multi-ThingsBoard devices + /tb/latest-all + WS realtime sensors)
// ✅ copy-paste ได้เลย

import dotenv from "dotenv";
import XLSX from "xlsx";
import fs from "fs";
import path from "path";
import http from "http";
import express from "express";
import cors from "cors";
import { WebSocketServer, WebSocket } from "ws";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import OpenAI from "openai";
import prisma from "./prismaClient.js";

// ✅ OAuth deps
import axios from "axios";
import { OAuth2Client } from "google-auth-library";

dotenv.config();

const CSV_PATH = path.resolve("tb_latency_log.csv");
const LATENCY_LOG_ENABLE =
  String(process.env.LATENCY_LOG_ENABLE || "false").toLowerCase() === "true";

function exportLatencyToExcel() {
  const csvPath = path.resolve("tb_latency_log.csv");
  const excelPath = path.resolve("tb_latency_log.xlsx");

  if (!fs.existsSync(csvPath)) {
    console.log("❌ CSV file not found");
    return;
  }

  // อ่าน CSV
  const csvData = fs.readFileSync(csvPath, "utf8");

  // แปลงเป็น workbook
  const workbook = XLSX.read(csvData, { type: "string" });

  // เขียนเป็นไฟล์ Excel
  XLSX.writeFile(workbook, excelPath);

  console.log("✅ Exported to Excel:", excelPath);
}
// สร้าง header ถ้ายังไม่มีไฟล์
if (LATENCY_LOG_ENABLE && !fs.existsSync(CSV_PATH)) {
  fs.writeFileSync(
    CSV_PATH,
    "deviceName,deviceTimestamp,tbUpdatedAt,serverReceiveTime,latencyMs\n"
  );
}
console.log("Has prisma.user?", !!prisma.user);

const app = express();
app.use(cors());
app.use(express.json({ limit: "2mb" }));

// ✅ OpenAI client
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

// --- HTTP server ---
const server = http.createServer(app);

// --- WS server ---
const wss = new WebSocketServer({ server });

// -------------------- helpers --------------------
function broadcast(obj) {
  const msg = JSON.stringify(obj);
  for (const client of wss.clients) {
    if (client.readyState === WebSocket.OPEN) client.send(msg);
  }
}

function nowIso() {
  return new Date().toISOString();
}

/**
 * Normalize timestamp into ISO string WITH timezone always (e.g. ...Z)
 * - If input has no TZ, treat it as UTC and append Z
 */
function toIsoTimestamp(input) {
  if (!input) return new Date().toISOString();
  if (input instanceof Date) return input.toISOString();

  if (typeof input === "string") {
    const s = input.trim();
    const hasTZ = /Z$|[+\-]\d{2}:\d{2}$/.test(s);
    const normalized = hasTZ ? s : `${s}Z`;
    const d = new Date(normalized);
    if (!Number.isNaN(d.getTime())) return d.toISOString();
  }
  return new Date().toISOString();
}

/**
 * ทำให้ข้อความ "เหมือนภาษาพูด" มากขึ้นสำหรับ TTS
 * (TTS จะอ่าน bullet/สัญลักษณ์แปลก ๆ)
 */
function humanizeForSpeech(text = "") {
  let t = String(text || "").trim();
  if (!t) return "ครับ";

  // ลบ bullet นำหน้า
  t = t.replace(/^\s*[-•]\s*/gm, "");

  t = t.replace(/\n+/g, " … ");
  t = t.replace(/\s{2,}/g, " ");
  t = t.replace(/ค่ะ/g, "ครับ");
  t = t.replace(/ครับครับ/g, "ครับ");
  t = t.replace(/\.{3,}/g, "…");
  t = t.replace(/\.\s*/g, "… ");
  t = t.replace(/\!\s*/g, "! ");
  t = t.replace(/\?\s*/g, "? ");

  if (!/(ครับ|ครับ\W*)$/.test(t)) t = `${t} ครับ`;
  return t.trim();
}

/**
 * ✅ Robust extractor สำหรับ OpenAI Responses API (text)
 */
function extractTextFromResponse(resp) {
  if (!resp) return "";
  if (typeof resp.output_text === "string" && resp.output_text.trim()) {
    return resp.output_text.trim();
  }

  const out = Array.isArray(resp.output) ? resp.output : [];
  const texts = [];
  for (const item of out) {
    const content = Array.isArray(item.content) ? item.content : [];
    for (const part of content) {
      if (!part) continue;
      if (
        (part.type === "output_text" || part.type === "text") &&
        typeof part.text === "string" &&
        part.text.trim()
      ) {
        texts.push(part.text.trim());
      }
    }
  }
  return texts.join("\n").trim();
}

// -------------------- ThingsBoard client --------------------
// ✅ ตั้งค่าใน .env:
// TB_BASE_URL=http://202.xxx.xxx.xxx:8080
// TB_USERNAME=... (email)
// TB_PASSWORD=...
// TB_DEVICE_NAME=EarthquakeSensor001
// ✅ เพิ่ม (หลายตัว): TB_DEVICE_NAMES=EarthquakeSensor001,EarthquakeSensor002,EarthquakeSensor003,EarthquakeSensor004
const TB_BASE_URL = process.env.TB_BASE_URL || "";
const TB_USERNAME = process.env.TB_USERNAME || "";
const TB_PASSWORD = process.env.TB_PASSWORD || "";
const TB_DEVICE_NAME = process.env.TB_DEVICE_NAME || "EarthquakeSensor001";

// ✅ NEW: device list (ถ้าไม่ใส่ TB_DEVICE_NAMES จะ fallback ไป TB_DEVICE_NAME)
const TB_DEVICE_NAMES = (process.env.TB_DEVICE_NAMES || TB_DEVICE_NAME || "EarthquakeSensor001")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);

let tbToken = null;
let tbTokenExp = 0;

async function tbLogin() {
  if (!TB_BASE_URL || !TB_USERNAME || !TB_PASSWORD) {
    throw new Error("ThingsBoard env missing (TB_BASE_URL/TB_USERNAME/TB_PASSWORD)");
  }
  const now = Date.now();
  if (tbToken && now < tbTokenExp - 30_000) return tbToken;

  const res = await axios.post(`${TB_BASE_URL}/api/auth/login`, {
    username: TB_USERNAME,
    password: TB_PASSWORD,
  });

  tbToken = res.data?.token || null;
  tbTokenExp = now + 10 * 60 * 1000; // 10 นาที
  if (!tbToken) throw new Error("ThingsBoard login failed: token missing");
  return tbToken;
}

async function tbGetDeviceIdByName(deviceName) {
  const token = await tbLogin();
  const res = await axios.get(
    `${TB_BASE_URL}/api/tenant/devices?deviceName=${encodeURIComponent(deviceName)}`,
    { headers: { "X-Authorization": `Bearer ${token}` } }
  );
  return res.data?.id?.id || null; // deviceId
}

async function tbGetLatestTelemetry(deviceId, keys) {
  const token = await tbLogin();
  const res = await axios.get(
    `${TB_BASE_URL}/api/plugins/telemetry/DEVICE/${deviceId}/values/timeseries?keys=${encodeURIComponent(keys.join(","))}`,
    { headers: { "X-Authorization": `Bearer ${token}` } }
  );
  return res.data; // { key: [{ts,value}], ... }
}

function tbLatest(raw, key) {
  return raw?.[key]?.[0]?.value ?? null;
}
function tbLatestTs(raw, key) {
  return raw?.[key]?.[0]?.ts ?? null;
}

// ✅ NEW: parser รวม (ลดโค้ดซ้ำ)
function parseTbTelemetry(raw) {
  // parse events (JSON string)
  let eventsObj = null;
  const eventsStr = tbLatest(raw, "events");
  if (eventsStr) {
    try {
      eventsObj = JSON.parse(eventsStr);
    } catch (_) {
      eventsObj = null;
    }
  }

  const telemetry = {
    id: tbLatest(raw, "id"),
    pga: Number(tbLatest(raw, "pga") ?? 0),
    si: Number(tbLatest(raw, "si") ?? 0),
    temp: Number(tbLatest(raw, "temp") ?? 0),
    timestamp: Number(tbLatest(raw, "timestamp") ?? 0),
    lat: tbLatest(raw, "lat") != null ? Number(tbLatest(raw, "lat")) : null,
    lng: tbLatest(raw, "lng") != null ? Number(tbLatest(raw, "lng")) : null,
    location: tbLatest(raw, "location"),
    distanceKm: tbLatest(raw, "distanceKm") != null ? Number(tbLatest(raw, "distanceKm")) : null,
    events: eventsObj,
  };

  const updatedAtTs =
    tbLatestTs(raw, "events") ||
    tbLatestTs(raw, "pga") ||
    tbLatestTs(raw, "si") ||
    tbLatestTs(raw, "temp") ||
    tbLatestTs(raw, "timestamp") ||
    null;

  return { telemetry, updatedAtTs };
}

function deriveSeverityFromPgaSi(pga, si) {
  // ✅ ปรับ threshold ตามเกณฑ์จริงได้
  if (pga >= 1.5 || si >= 80) return "severe";
  if (pga >= 0.8 || si >= 40) return "moderate";
  return "caution";
}

// ✅ แปลง TB telemetry -> alert payload (ให้เข้ากับระบบเดิม)
function tbToAlert({ deviceName, telemetry }) {
  const pga = Number(telemetry.pga ?? 0);
  const si = Number(telemetry.si ?? 0);
  const temp = Number(telemetry.temp ?? 0);

  const severity = deriveSeverityFromPgaSi(pga, si);

  const location = telemetry.location ? String(telemetry.location) : "Unknown";
  const lat = telemetry.lat != null ? Number(telemetry.lat) : 0;
  const lng = telemetry.lng != null ? Number(telemetry.lng) : 0;

  const deviceEpoch = Number(telemetry.timestamp ?? 0);
  const tsIso = deviceEpoch ? new Date(deviceEpoch).toISOString() : nowIso();

  return normalizeAlert({
    type: "alert",
    alertId: `TB-${deviceName}-${deviceEpoch || Date.now()}`,
    timestamp: tsIso,
    severity,
    magnitude: pga, // ✅ ชั่วคราว: ใช้ pga แทน magnitude
    location,
    description: `TB update: pga=${pga}, si=${si}, temp=${temp}`,
    distanceKm: telemetry.distanceKm != null ? Number(telemetry.distanceKm) : null,
    lat,
    lng,
    nodeId: deviceName,
  });
}

// -------------------- AUTH (JWT) --------------------
const JWT_SECRET = process.env.JWT_SECRET || "dev_secret_change_me";
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || "7d";

function signAccessToken(userId) {
  return jwt.sign({ sub: userId }, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
}

function requireAuth(req, res, next) {
  const header = req.headers.authorization || "";
  if (!header.startsWith("Bearer ")) {
    return res.status(401).json({ ok: false, message: "Missing token" });
  }

  const token = header.slice("Bearer ".length);
  try {
    const payload = jwt.verify(token, JWT_SECRET);
    if (!payload?.sub) return res.status(401).json({ ok: false, message: "Invalid token" });

    req.userId = payload.sub;
    next();
  } catch (_e) {
    return res.status(401).json({ ok: false, message: "Invalid/expired token" });
  }
}

// ✅ helper: select user แบบไม่พังถ้า schema ยังไม่มี lastLoginAt
async function safeSelectUser(userId) {
  try {
    return await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        name: true,
        province: true,
        role: true,
        createdAt: true,
        lastLoginAt: true,
      },
    });
  } catch (_e) {
    return await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        name: true,
        province: true,
        role: true,
        createdAt: true,
      },
    });
  }
}

// -------------------- OAUTH (Google/Facebook/GitHub) --------------------
// ✅ Google: รองรับหลาย audience
const GOOGLE_CLIENT_ID_IOS = process.env.GOOGLE_CLIENT_ID_IOS || "";
const GOOGLE_CLIENT_ID_ANDROID = process.env.GOOGLE_CLIENT_ID_ANDROID || "";
const GOOGLE_CLIENT_ID_WEB = process.env.GOOGLE_CLIENT_ID_WEB || "";

const GOOGLE_AUDIENCES = [GOOGLE_CLIENT_ID_IOS, GOOGLE_CLIENT_ID_ANDROID, GOOGLE_CLIENT_ID_WEB]
  .map((s) => String(s || "").trim())
  .filter(Boolean);

const googleClient = new OAuth2Client();

const FACEBOOK_APP_ID = process.env.FACEBOOK_APP_ID || "";
const FACEBOOK_APP_SECRET = process.env.FACEBOOK_APP_SECRET || "";
const GITHUB_CLIENT_ID = process.env.GITHUB_CLIENT_ID || "";
const GITHUB_CLIENT_SECRET = process.env.GITHUB_CLIENT_SECRET || "";
const GITHUB_REDIRECT_URI = process.env.GITHUB_REDIRECT_URI || "";

async function upsertOAuthLogin({ provider, providerId, email, name, avatarUrl }) {
  const existedAcc = await prisma.oAuthAccount.findUnique({
    where: { provider_providerId: { provider, providerId } },
    include: { user: true },
  });

  if (existedAcc?.user) {
    try {
      await prisma.oAuthAccount.update({
        where: { id: existedAcc.id },
        data: {
          email: email ?? existedAcc.email,
          name: name ?? existedAcc.name,
          avatarUrl: avatarUrl ?? existedAcc.avatarUrl,
        },
      });
    } catch (_) {}
    return existedAcc.user;
  }

  let user = null;
  if (email) user = await prisma.user.findUnique({ where: { email } });

  if (!user) {
    user = await prisma.user.create({
      data: {
        email: email ?? null,
        name: name ?? null,
      },
    });
  }

  await prisma.oAuthAccount.create({
    data: {
      provider,
      providerId,
      email: email ?? null,
      name: name ?? null,
      avatarUrl: avatarUrl ?? null,
      userId: user.id,
    },
  });

  return user;
}

// ✅ Google OAuth: รับ idToken จาก Flutter
app.post("/auth/google", async (req, res) => {
  try {
    const { idToken } = req.body || {};
    if (!idToken) return res.status(400).json({ ok: false, message: "idToken is required" });
    if (GOOGLE_AUDIENCES.length === 0) {
      return res.status(500).json({ ok: false, message: "GOOGLE_CLIENT_ID_IOS/ANDROID/WEB missing" });
    }

    try {
      const parts = String(idToken).split(".");
      if (parts.length >= 2) {
        const payloadJson = Buffer.from(parts[1], "base64").toString("utf8");
        console.log("🔎 Google idToken payload:", payloadJson);
      }
    } catch (_) {}

    const ticket = await googleClient.verifyIdToken({
      idToken,
      audience: GOOGLE_AUDIENCES,
    });

    const payload = ticket.getPayload();
    if (!payload?.sub) return res.status(401).json({ ok: false, message: "Invalid Google token" });

    const user = await upsertOAuthLogin({
      provider: "google",
      providerId: payload.sub,
      email: payload.email || null,
      name: payload.name || null,
      avatarUrl: payload.picture || null,
    });

    try {
      await prisma.user.update({ where: { id: user.id }, data: { lastLoginAt: new Date() } });
    } catch (_) {}

    const accessToken = signAccessToken(user.id);
    return res.json({
      ok: true,
      user: { id: user.id, email: user.email, name: user.name },
      accessToken,
    });
  } catch (e) {
    console.error("POST /auth/google FAILED:", e);
    return res.status(500).json({ ok: false, message: e?.message ?? "Internal error" });
  }
});

// ✅ Facebook OAuth: รับ accessToken จาก Flutter
app.post("/auth/facebook", async (req, res) => {
  try {
    const { accessToken } = req.body || {};
    if (!accessToken) return res.status(400).json({ ok: false, message: "accessToken is required" });
    if (!FACEBOOK_APP_ID || !FACEBOOK_APP_SECRET) {
      return res.status(500).json({ ok: false, message: "FACEBOOK_APP_ID/SECRET missing" });
    }

    const appToken = `${FACEBOOK_APP_ID}|${FACEBOOK_APP_SECRET}`;
    const debugUrl =
      `https://graph.facebook.com/debug_token?` +
      `input_token=${encodeURIComponent(accessToken)}&access_token=${encodeURIComponent(appToken)}`;
    const debug = await axios.get(debugUrl);

    const data = debug?.data?.data;
    if (!data?.is_valid) return res.status(401).json({ ok: false, message: "Invalid Facebook token" });
    if (String(data.app_id) !== String(FACEBOOK_APP_ID)) {
      return res.status(401).json({ ok: false, message: "Facebook token not issued for this app" });
    }

    const meUrl =
      `https://graph.facebook.com/me?fields=id,name,email,picture.type(large)` +
      `&access_token=${encodeURIComponent(accessToken)}`;
    const me = await axios.get(meUrl);

    const id = me?.data?.id;
    if (!id) return res.status(401).json({ ok: false, message: "Cannot fetch Facebook user" });

    const user = await upsertOAuthLogin({
      provider: "facebook",
      providerId: String(id),
      email: me?.data?.email || null,
      name: me?.data?.name || null,
      avatarUrl: me?.data?.picture?.data?.url || null,
    });

    try {
      await prisma.user.update({ where: { id: user.id }, data: { lastLoginAt: new Date() } });
    } catch (_) {}

    const accessTokenApp = signAccessToken(user.id);
    return res.json({
      ok: true,
      user: { id: user.id, email: user.email, name: user.name },
      accessToken: accessTokenApp,
    });
  } catch (e) {
    console.error("POST /auth/facebook FAILED:", e?.response?.data || e);
    return res.status(500).json({ ok: false, message: e?.message ?? "Internal error" });
  }
});

// ✅ GitHub OAuth: รับ "code" จาก Flutter แล้ว backend แลก token
app.post("/auth/github", async (req, res) => {
  try {
    const { code } = req.body || {};
    if (!code) return res.status(400).json({ ok: false, message: "code is required" });
    if (!GITHUB_CLIENT_ID || !GITHUB_CLIENT_SECRET || !GITHUB_REDIRECT_URI) {
      return res.status(500).json({ ok: false, message: "GITHUB env missing" });
    }

    const tokenRes = await axios.post(
      "https://github.com/login/oauth/access_token",
      {
        client_id: GITHUB_CLIENT_ID,
        client_secret: GITHUB_CLIENT_SECRET,
        code,
        redirect_uri: GITHUB_REDIRECT_URI,
      },
      { headers: { Accept: "application/json" } }
    );

    const ghToken = tokenRes?.data?.access_token;
    if (!ghToken) return res.status(401).json({ ok: false, message: "GitHub token exchange failed" });

    const headers = { Authorization: `Bearer ${ghToken}`, Accept: "application/vnd.github+json" };

    const me = await axios.get("https://api.github.com/user", { headers });
    const providerId = String(me?.data?.id);
    const name = me?.data?.name || me?.data?.login || null;
    const avatarUrl = me?.data?.avatar_url || null;

    let email = me?.data?.email || null;
    if (!email) {
      const emails = await axios.get("https://api.github.com/user/emails", { headers });
      const arr = Array.isArray(emails?.data) ? emails.data : [];
      const primary = arr.find((x) => x.primary) || arr.find((x) => x.verified) || arr[0];
      email = primary?.email || null;
    }

    if (!providerId) return res.status(401).json({ ok: false, message: "Cannot fetch GitHub user" });

    const user = await upsertOAuthLogin({
      provider: "github",
      providerId,
      email,
      name,
      avatarUrl,
    });

    try {
      await prisma.user.update({ where: { id: user.id }, data: { lastLoginAt: new Date() } });
    } catch (_) {}

    const accessTokenApp = signAccessToken(user.id);
    return res.json({
      ok: true,
      user: { id: user.id, email: user.email, name: user.name },
      accessToken: accessTokenApp,
    });
  } catch (e) {
    console.error("POST /auth/github FAILED:", e?.response?.data || e);
    return res.status(500).json({ ok: false, message: e?.message ?? "Internal error" });
  }
});

// ======================================================================
// ✅ NEW: WS realtime for /tb/latest-all (sensor snapshots)
// - broadcast type: "tb_latest_all"
// - send snapshot on connect
// - fingerprint กันสแปม setState
// ======================================================================

let lastTbLatestAllFp = "";
let lastTbLatestAllPayload = null;
async function fetchTbLatestAll() {
  try {
    const results = [];

    for (const deviceName of TB_DEVICE_NAMES) {

      const deviceId = await tbGetDeviceIdByName(deviceName);
      if (!deviceId) continue;

      const start = Date.now();

      const raw = await tbGetLatestTelemetry(deviceId, [
        "events",
        "pga",
        "si",
        "temp",
        "timestamp",
        "id",
        "lat",
        "lng",
        "location",
        "distanceKm",
      ]);

      const end = Date.now();

      const tbApiLatencyMs = end - start;
      const serverReceiveTs = end;

      const { telemetry, updatedAtTs } = parseTbTelemetry(raw);

      // Latency debug logs kept for future testing. Uncomment when measuring TB latency.
      // console.log("================================");
      // console.log("Device:", deviceName);
      // console.log("TB timestamp (updatedAtTs):", updatedAtTs);
      // console.log("Device timestamp field:", telemetry.timestamp);
      // console.log("Server receive time:", new Date(serverReceiveTs).toISOString());
      // console.log("Latency (ms):", tbApiLatencyMs);
      // console.log("================================");
      if (LATENCY_LOG_ENABLE) {
        const serverReceiveIso = new Date(serverReceiveTs).toISOString();
        const deviceTimestamp = telemetry.timestamp ?? "";
        const tbUpdatedIso = updatedAtTs ? new Date(updatedAtTs).toISOString() : "";
        const csvLine =
          `${deviceName},${deviceTimestamp},${tbUpdatedIso},${serverReceiveIso},${tbApiLatencyMs}\n`;

        fs.appendFileSync(CSV_PATH, csvLine);
      }
      results.push({
        ok: true,
        deviceName,
        deviceId,
        updatedAtTs,
        serverReceiveTs,
        tbApiLatencyMs,
        telemetry,
      });
    }

    return results;
  } catch (err) {
    console.error("TB latest-all WS poll FAILED:", err.message);
    return [];
  }
}
function buildTbLatestAllFingerprint(list) {
  return list
    .map((x) => {
      const t = x.telemetry || {};
      return `${x.deviceName}:${x.updatedAtTs || 0}:${x.serverReceiveTs || 0}:${t.pga ?? ""}:${t.si ?? ""}`;
    })
    .join("|");
}

async function pollTbLatestAllAndBroadcast() {
  try {
    if (!TB_BASE_URL) return;

    const list = await fetchTbLatestAll();
    const fp = buildTbLatestAllFingerprint(list);
    if (fp === lastTbLatestAllFp) return;

    lastTbLatestAllFp = fp;

    lastTbLatestAllPayload = {
      type: "tb_latest_all",
      timestamp: nowIso(),
      data: list,
    };

    broadcast(lastTbLatestAllPayload);
  } catch (e) {
    console.error("TB latest-all WS poll FAILED:", e?.response?.data || e?.message || e);
  }
}

// -------------------- WS connect --------------------
wss.on("connection", (ws) => {
  console.log("✅ client connected");
  ws.send(JSON.stringify({ type: "hello", timestamp: nowIso() }));

  // ✅ ส่ง snapshot ล่าสุดทันที (ถ้ามี cache)
  if (lastTbLatestAllPayload) {
    ws.send(JSON.stringify(lastTbLatestAllPayload));
  }

  ws.on("message", async (data) => {
    const text = data.toString();
    console.log("⬅️ ws message:", text);

    try {
      const obj = JSON.parse(text);

      // ✅ client ขอ snapshot sensors
      if (obj.type === "subscribe_sensors" || obj.type === "get_tb_latest_all") {
        const list = await fetchTbLatestAll();
        const payload = { type: "tb_latest_all", timestamp: nowIso(), data: list };
        ws.send(JSON.stringify(payload));
        return;
      }

      // ✅ เดิม: alert broadcast
      if ((obj.type ?? "alert") === "alert") {
        const alert = normalizeAlert(obj);

        try {
          const saved = await saveAlertToDb(alert);
          broadcast(rowToPayload(saved)); // ✅ ส่งจาก DB
        } catch (e) {
          console.error("❌ DB save failed:", e?.message || e);
          broadcast(alert); // fallback
        }
      } else {
        const msg = { ...obj };
        if (!msg.timestamp) msg.timestamp = nowIso();
        broadcast(msg);
      }
    } catch (_e) {
      ws.send(JSON.stringify({ type: "error", message: "Invalid JSON" }));
    }
  });

  ws.on("close", () => console.log("❌ client disconnected"));
});

// payload ตัวอย่าง (เวลา demo)
function makeMockAlert(overrides = {}) {
  const presets = [
    { location: "Chiang Mai", lat: 18.7883, lng: 98.9853 },
    { location: "Bangkok", lat: 13.7563, lng: 100.5018 },
    { location: "Phuket", lat: 7.8804, lng: 98.3923 },
    { location: "Khon Kaen", lat: 16.4419, lng: 102.835 },
  ];
  const p = presets[Math.floor(Math.random() * presets.length)];

  const mags = [3.1, 4.2, 5.8, 6.2];
  const magnitude = overrides.magnitude ?? mags[Math.floor(Math.random() * mags.length)];

  let severity = "caution";
  if (magnitude >= 5.5) severity = "severe";
  else if (magnitude >= 4.0) severity = "moderate";

  return {
    type: "alert",
    alertId: overrides.alertId ?? `AL-${Date.now()}`,
    timestamp: overrides.timestamp ?? nowIso(),
    severity: overrides.severity ?? severity,
    magnitude,
    location: overrides.location ?? p.location,
    description: overrides.description ?? `Earthquake detected near ${overrides.location ?? p.location}`,
    distanceKm: overrides.distanceKm ?? Number((Math.random() * 150 + 2).toFixed(1)),
    lat: overrides.lat ?? p.lat,
    lng: overrides.lng ?? p.lng,
    nodeId: overrides.nodeId ?? `node-${String(Math.floor(Math.random() * 4) + 1).padStart(3, "0")}`,
  };
}

// ---- helper: validate/normalize alert payload ----
function normalizeAlert(payload = {}) {
  const alert = payload?.type === "alert" ? { ...payload } : { type: "alert", ...payload };
  if (!alert.alertId) alert.alertId = `AL-${Date.now()}`;

  alert.timestamp = toIsoTimestamp(alert.timestamp ?? nowIso());

  if (alert.magnitude != null) alert.magnitude = Number(alert.magnitude);
  if (alert.lat != null) alert.lat = Number(alert.lat);
  if (alert.lng != null) alert.lng = Number(alert.lng);
  if (alert.distanceKm != null) alert.distanceKm = Number(alert.distanceKm);

  if (alert.severity != null) alert.severity = String(alert.severity);
  if (alert.location != null) alert.location = String(alert.location);
  if (alert.description != null) alert.description = String(alert.description);
  if (alert.nodeId != null) alert.nodeId = String(alert.nodeId);

  return alert;
}

/**
 * ✅ สำคัญ:
 * - schema: alertId เป็น @unique
 * - ส่ง alertId ซ้ำ = update แถวเดิม
 * - timestamp = เวลาที่ server รับเสมอ => "Latest" จะล่าสุดจริง
 */
async function saveAlertToDb(alert) {
  const ts = new Date();

  const row = await prisma.alert.upsert({
    where: { alertId: alert.alertId },
    update: {
      timestamp: ts,
      severity: alert.severity,
      magnitude: alert.magnitude,
      location: alert.location,
      description: alert.description ?? "",
      distanceKm: alert.distanceKm ?? null,
      lat: alert.lat,
      lng: alert.lng,
      nodeId: alert.nodeId ?? null,
    },
    create: {
      alertId: alert.alertId,
      timestamp: ts,
      severity: alert.severity,
      magnitude: alert.magnitude,
      location: alert.location,
      description: alert.description ?? "",
      distanceKm: alert.distanceKm ?? null,
      lat: alert.lat,
      lng: alert.lng,
      nodeId: alert.nodeId ?? null,
    },
  });

  return row;
}

function rowToPayload(row) {
  return {
    type: "alert",
    ...row,
    timestamp: row.timestamp?.toISOString?.() ?? nowIso(),
    createdAt: row.createdAt?.toISOString?.() ?? undefined,
  };
}

// -------------------- REST endpoints --------------------
// ================= MOCK TB -> WS (FOR HISTORY REALTIME TEST) =================
// ยิงแล้วจะ broadcast type: "tb_latest_all" ให้ HistoryScreen อัปเดตการ์ดทันที
app.post("/mock/tb", async (req, res) => {
  try {
    const body = req.body || {};

    const deviceName = String(body.deviceName || "EarthquakeSensor001");

    // รองรับทั้ง pga/si/temp และ fallback
    const pga = Number(body.pga ?? 0);
    const si = Number(body.si ?? 0);
    const temp = Number(body.temp ?? 0);

    // optional
    const lat = body.lat != null ? Number(body.lat) : null;
    const lng = body.lng != null ? Number(body.lng) : null;
    const location = body.location != null ? String(body.location) : null;
    const distanceKm = body.distanceKm != null ? Number(body.distanceKm) : null;

    // ✅ สำคัญ: ทำให้ updatedAtTs "ใหม่ทุกครั้ง" แม้ค่าซ้ำ -> History จะเปลี่ยนการ์ดทุกครั้ง
    const ts = Date.now();

    // ✅ สร้าง list ครบทุกตัว เพื่อให้ UI ไม่หาย (device อื่นยังคงเดิม)
    // - ใช้ cache เดิมถ้ามี
    // - แล้วแทนค่าเฉพาะ deviceName ที่ยิงมา
    const prev = Array.isArray(lastTbLatestAllPayload?.data) ? lastTbLatestAllPayload.data : [];

    // map จากของเดิม
    const map = new Map();
    for (const x of prev) {
      if (x && x.deviceName) map.set(String(x.deviceName), x);
    }

    // สร้าง record ใหม่ของตัวที่ยิงมา
    map.set(deviceName, {
      ok: true,
      deviceName,
      deviceId: deviceName,
      updatedAtTs: ts, // ✅ key point
      telemetry: {
        id: deviceName,
        pga,
        si,
        temp,
        timestamp: ts, // ✅ ให้เปลี่ยนทุกครั้งด้วย
        lat,
        lng,
        location,
        distanceKm,
        events: body.events ?? null,
      },
    });

    // ✅ ทำให้ output มีครบตาม TB_DEVICE_NAMES ก่อน (ถ้าใน env กำหนดไว้)
    // ถ้าตัวไหนยังไม่มีข้อมูล ให้สร้าง placeholder ให้ UI ยังแสดงการ์ดได้
    const list = TB_DEVICE_NAMES.map((name) => {
      const existed = map.get(name);
      if (existed) return existed;
      return {
        ok: false,
        deviceName: name,
        deviceId: null,
        updatedAtTs: null,
        telemetry: {
          id: null,
          pga: 0,
          si: 0,
          temp: 0,
          timestamp: 0,
          lat: null,
          lng: null,
          location: null,
          distanceKm: null,
          events: null,
        },
      };
    });

    // sort stable by deviceName (เหมือน fetchTbLatestAll)
    list.sort((a, b) => String(a.deviceName).localeCompare(String(b.deviceName)));

    // ✅ ตั้ง cache + broadcast
    lastTbLatestAllPayload = {
      type: "tb_latest_all",
      timestamp: nowIso(),
      data: list,
    };

    // ✅ ไม่ทำ fingerprint กันซ้ำ เพราะ History ต้องเห็นทุกครั้งแม้ค่าเหมือนเดิม
    lastTbLatestAllFp = `${Date.now()}`; // แค่ทำให้ไม่ล็อกซ้ำ

    broadcast(lastTbLatestAllPayload);
    return res.json({ ok: true, sent: lastTbLatestAllPayload });
  } catch (e) {
    return res.status(500).json({ ok: false, message: e?.message ?? String(e) });
  }
});

// ✅ Health check
app.get("/health", (_req, res) => {
  res.json({ ok: true, service: "quakelink-api", ts: nowIso() });
});
app.get("/export-latency", (req, res) => {
  try {
    exportLatencyToExcel();

    const excelPath = path.resolve("tb_latency_log.xlsx");

    if (!fs.existsSync(excelPath)) {
      return res.status(404).json({ ok: false, message: "Excel file not found" });
    }

    return res.download(excelPath);
  } catch (e) {
    return res.status(500).json({ ok: false, message: e.message });
  }
});
// ✅ ThingsBoard latest (ให้ Flutter เรียก)
app.get("/tb/latest", requireAuth, async (req, res) => {
  try {
    const deviceName = (req.query.deviceName || TB_DEVICE_NAME).toString();
    const deviceId = await tbGetDeviceIdByName(deviceName);
    if (!deviceId)
      return res.status(404).json({ ok: false, message: "Device not found" });

    const start = Date.now();
    const raw = await tbGetLatestTelemetry(deviceId, [
      "events",
      "pga",
      "si",
      "temp",
      "timestamp",
      "id",
      "lat",
      "lng",
      "location",
      "distanceKm",
    ]);
    const end = Date.now();

    const tbApiLatencyMs = end - start;
    const serverReceiveTs = end;

    const { telemetry, updatedAtTs } = parseTbTelemetry(raw);
    // Latency debug logs kept for future testing. Uncomment when measuring TB latency.
    // console.log("================================");
    // console.log("Device:", deviceName);
    // console.log("TB timestamp (updatedAtTs):", updatedAtTs);
    // console.log("Server receive time:", end);
    // console.log("Latency (ms):", end - start);
    // console.log("Telemetry:", telemetry);
    // console.log("================================");
    res.json({
      ok: true,
      deviceName,
      deviceId,
      updatedAtTs,        // เวลา TB
      serverReceiveTs,    // ✅ เวลา backend ได้จริง
      tbApiLatencyMs,     // ✅ เวลาที่ call TB
      telemetry,
    });
  } catch (e) {
    console.error("GET /tb/latest FAILED:", e?.response?.data || e);
    res.status(500).json({ ok: false, message: e?.message ?? "Internal error" });
  }
});

// ✅ ThingsBoard latest (ALL devices)
app.get("/tb/latest-all", requireAuth, async (_req, res) => {
  try {
    const results = await fetchTbLatestAll();

    // เดิมของหนู: sort newest
    const newest = [...results].sort((a, b) => (b.updatedAtTs || 0) - (a.updatedAtTs || 0));
    const latest = newest.find((x) => x.ok && x.telemetry);

    res.json({
      ok: true,
      count: results.length,
      deviceNames: TB_DEVICE_NAMES,
      latestDeviceName: latest?.deviceName ?? null,
      latestUpdatedAtTs: latest?.updatedAtTs ?? null,
      data: newest,
    });
  } catch (e) {
    console.error("GET /tb/latest-all FAILED:", e?.response?.data || e);
    res.status(500).json({ ok: false, message: e?.message ?? "Internal error" });
  }
});

// ✅ (optional) TB -> alert แล้ว broadcast/เก็บ DB
// เปิดใช้งานด้วย TB_POLL_ENABLE=true ใน .env
let lastTbEpoch = 0;
async function pollThingsboardAndEmit() {
  try {
    if (!TB_BASE_URL) return;

    // ✅ เลือก device ที่ "อัปเดตล่าสุด" จากหลายตัว แล้วค่อย emit (แบบ B)
    const keys = ["pga", "si", "temp", "timestamp", "id", "lat", "lng", "location", "distanceKm"];

    const fetched = await Promise.all(
      TB_DEVICE_NAMES.map(async (deviceName) => {
        try {
          const deviceId = await tbGetDeviceIdByName(deviceName);
          if (!deviceId) return null;

          const raw = await tbGetLatestTelemetry(deviceId, keys);
          const { telemetry, updatedAtTs } = parseTbTelemetry(raw);
          return { deviceName, deviceId, telemetry, updatedAtTs };
        } catch (_) {
          return null;
        }
      })
    );

    const list = fetched.filter(Boolean);
    if (list.length === 0) return;

    list.sort((a, b) => (b.updatedAtTs || 0) - (a.updatedAtTs || 0));
    const picked = list[0];

    const epoch = picked.telemetry?.timestamp || 0;
    if (epoch && epoch <= lastTbEpoch) return;
    if (epoch) lastTbEpoch = epoch;

    const alert = tbToAlert({ deviceName: picked.deviceName, telemetry: picked.telemetry });
    const saved = await saveAlertToDb(alert);
    broadcast(rowToPayload(saved));
  } catch (e) {
    console.error("TB poll FAILED:", e?.response?.data || e?.message || e);
  }
}

// ✅ Register (local)
app.post("/auth/register", async (req, res) => {
  try {
    const { email, password, name, province } = req.body || {};
    const normalizedEmail = typeof email === "string" ? email.trim().toLowerCase() : "";
    const normalizedName = typeof name === "string" ? name.trim() : "";

    if (!normalizedEmail) return res.status(400).json({ ok: false, message: "email is required" });
    if (!password || typeof password !== "string" || password.length < 6)
      return res.status(400).json({ ok: false, message: "password must be at least 6 chars" });
    if (!normalizedName) return res.status(400).json({ ok: false, message: "name is required" });

    const existed = await prisma.user.findUnique({ where: { email: normalizedEmail } });
    if (existed) return res.status(409).json({ ok: false, message: "Email already exists" });

    const passwordHash = await bcrypt.hash(password, 12);

    const user = await prisma.user.create({
      data: {
        email: normalizedEmail,
        passwordHash,
        name: normalizedName,
        province: province ? String(province).trim() : null,
      },
      select: { id: true, email: true, name: true, province: true, role: true, createdAt: true },
    });

    const accessToken = signAccessToken(user.id);
    return res.status(201).json({ ok: true, user, accessToken });
  } catch (e) {
    console.error("POST /auth/register FAILED:", e);
    return res.status(500).json({ ok: false, message: e?.message ?? "Internal error" });
  }
});

// ✅ Login (local)
app.post("/auth/login", async (req, res) => {
  try {
    const { email, password } = req.body || {};
    const normalizedEmail = typeof email === "string" ? email.trim().toLowerCase() : "";

    if (!normalizedEmail) return res.status(400).json({ ok: false, message: "email is required" });
    if (!password || typeof password !== "string") return res.status(400).json({ ok: false, message: "password is required" });

    let user = await prisma.user.findUnique({ where: { email: normalizedEmail } });
    if (!user) return res.status(401).json({ ok: false, message: "Invalid credentials" });
    if (!user.passwordHash) {
      return res.status(401).json({
        ok: false,
        message: "This account uses social login. Please sign in with the original provider.",
      });
    }

    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) return res.status(401).json({ ok: false, message: "Invalid credentials" });

    try {
      user = await prisma.user.update({ where: { id: user.id }, data: { lastLoginAt: new Date() } });
    } catch (e) {
      console.warn("⚠️ lastLoginAt update skipped:", e?.message || e);
    }

    const accessToken = signAccessToken(user.id);

    return res.json({
      ok: true,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        province: user.province,
        role: user.role,
        lastLoginAt: user.lastLoginAt,
      },
      accessToken,
    });
  } catch (e) {
    console.error("POST /auth/login FAILED:", e);
    return res.status(500).json({ ok: false, message: e?.message ?? "Internal error" });
  }
});

// ✅ Protected example
app.get("/me", requireAuth, async (req, res) => {
  try {
    const user = await safeSelectUser(req.userId);
    return res.json({ ok: true, user });
  } catch (e) {
    console.error("GET /me FAILED:", e);
    return res.status(500).json({ ok: false, message: e?.message ?? "Internal error" });
  }
});

// -------------------- AI intent --------------------
function detectIntent(text = "") {
  const t = text.trim().toLowerCase();

  const isGreeting =
    /^(สวัสดี|หวัดดี|hello|hi|ดีครับ|ดีค่ะ|เฮลโหล)[!. ]*$/.test(t) ||
    (t.length <= 12 && /^(สวัสดี|หวัดดี|hi|hello)/.test(t));

  const asksLatest = /(ล่าสุด|เกิดอะไรขึ้น|มีเหตุการณ์ไหม|แจ้งเตือนล่าสุด|สรุปล่าสุด)/i.test(text);

  const quakeKeywords =
    /(แผ่นดินไหว|เตือน|แจ้งเตือน|แรงสั่น|ริกเตอร์|แมกนิจูด|ศูนย์กลาง|อาฟเตอร์ช็อก|caution|severe|moderate|ระดับความรุนแรง|พิกัด|เซนเซอร์|node|aftershock|epicenter)/i.test(
      text
    );

  const weatherKeywords = /(อากาศ|พยากรณ์|ฝน|ร้อน|หนาว|อุณหภูมิ|ความชื้น|pm2\.5|ฝุ่น|ลม|พายุ)/i.test(text);

  if (isGreeting && !quakeKeywords && !asksLatest) return "GREETING";
  if (quakeKeywords || asksLatest) return "QUAKE";
  if (weatherKeywords) return "WEATHER";
  return "GENERAL";
}

async function buildChatPrompt(message) {
  const intent = detectIntent(message);

  if (intent === "QUAKE") {
    const latestRow = await prisma.alert.findFirst({ orderBy: { timestamp: "desc" } });

    if (!latestRow) {
      const system = `
คุณคือ QuakeLink AI (ภาษาไทย) น้ำเสียงเป็นมิตร แบบภาษาคน และลงท้ายด้วย "ครับ"
กติกาสำคัญ: ห้ามเดาข้อมูลแผ่นดินไหว
ถ้าไม่มีข้อมูลในระบบ ให้บอกตรงๆว่า "ยังไม่มีข้อมูลแผ่นดินไหวล่าสุดในระบบครับ"
แล้วเสนอสิ่งที่ช่วยได้ต่อ: วิธีเอาตัวรอด, อธิบายระดับ Caution/Moderate/Severe, วิธีใช้งานแอป
`.trim();

      return { intent, usesDb: true, system, user: `ผู้ใช้ถาม: ${message}\nตอบให้กระชับครับ` };
    }

    const payload = rowToPayload(latestRow);
    const context = `CONTEXT(JSON):\n${JSON.stringify(payload, null, 2)}`;

    const system = `
คุณคือ QuakeLink AI ผู้ช่วยสรุปเหตุแผ่นดินไหวและแนะนำความปลอดภัย (ภาษาไทย)
กติกา (สำคัญมาก):
- ใช้ข้อมูลจาก CONTEXT เท่านั้น ห้ามเดา/ห้ามแต่งข้อมูล
- ถ้า CONTEXT ไม่มีค่าใด ให้บอกว่า "ไม่มีข้อมูลในระบบ"
สไตล์คำตอบ:
- ตอบตรงคำถามก่อน 1-2 ประโยค
- ถ้าถาม "ล่าสุด" ให้สรุปสั้นๆ: ขนาด/ที่/เวลา/ระดับ (เท่าที่มีใน CONTEXT)
- ต่อด้วยคำแนะนำ 3-6 ข้อ แบบ bullet สั้นๆ
- เป็นมิตร และลงท้ายด้วยครับ
`.trim();

    return { intent, usesDb: true, system, user: `${context}\n\nคำถามผู้ใช้: ${message}\n` };
  }

  if (intent === "WEATHER") {
    const system = `
คุณคือ QuakeLink AI (ภาษาไทย) น้ำเสียงเป็นมิตร เป็นธรรมชาติ และลงท้ายด้วยครับ
ข้อจำกัด: คุณไม่สามารถรู้ "สภาพอากาศจริงตอนนี้" ได้เองถ้าไม่ได้รับข้อมูลจาก API/ระบบ
กติกา:
- ถ้าผู้ใช้ถาม "สภาพอากาศวันนี้/ตอนนี้" ให้ถามกลับสั้นๆว่า "อยู่จังหวัด/อำเภอไหนครับ" และเสนอว่า "ถ้าต่อ Weather API ได้จะบอกให้แบบเรียลไทม์"
- ระหว่างนี้ให้ช่วยได้: อธิบายแนวโน้มทั่วไปตามฤดูกาลในไทย, วิธีเตรียมตัวเมื่อฝนตก/ร้อนจัด, เช็ค PM2.5 ยังไง, อุปกรณ์ควรพก
ห้ามแต่งตัวเลขอุณหภูมิ/ฝน/ความชื้นแบบมั่ว
`.trim();

    return { intent, usesDb: false, system, user: message };
  }

  const system = `
คุณคือ QuakeLink AI ผู้ช่วยสนทนาและช่วยเหลือผู้ใช้ (ภาษาไทย)
สไตล์: ภาษาคน เป็นมิตร ตอบตรงคำถาม ไม่เวิ่น ไม่แข็ง และลงท้ายด้วยครับ
แนวทาง:
- ถ้าผู้ใช้ทักทาย ให้ทักกลับสั้นๆ แล้วเสนอ 2-3 ตัวเลือกที่ช่วยได้
- ถ้าถามเรื่องความปลอดภัย/เอาตัวรอด ให้ตอบแบบขั้นตอนสั้นๆ
- ถ้าผู้ใช้ถามเรื่องทั่วไป ให้ตอบแบบคุยได้จริง ไม่เป็นหุ่นยนต์
`.trim();

  return { intent, usesDb: false, system, user: message };
}

// -------------------- AI routes --------------------
app.post("/chat", requireAuth, async (req, res) => {
  try {
    const message = (req.body?.message ?? "").toString().trim();
    if (!message) return res.status(400).json({ ok: false, message: "message is required" });

    const { intent, usesDb, system, user } = await buildChatPrompt(message);

    const response = await openai.responses.create({
      model: "gpt-4.1-mini",
      temperature: intent === "GENERAL" ? 0.5 : 0.3,
      max_output_tokens: 200,
      input: [
        { role: "system", content: system },
        { role: "user", content: user },
      ],
    });

    const reply = extractTextFromResponse(response);
    return res.json({
      ok: true,
      reply: reply || "ขอโทษครับ ตอนนี้ไม่สามารถตอบได้",
      sources: { db: usesDb, llm: "openai" },
      intent,
    });
  } catch (e) {
    console.error("POST /chat FAILED:", e);
    return res.status(500).json({
      ok: false,
      error: { code: "CHAT_FAILED", message: e?.message ?? String(e) },
    });
  }
});

app.post("/voice-chat", requireAuth, async (req, res) => {
  try {
    const message = (req.body?.message ?? "").toString().trim();
    if (!message) return res.status(400).json({ ok: false, message: "message is required" });

    const { intent, usesDb, system, user } = await buildChatPrompt(message);

    const response = await openai.responses.create({
      model: "gpt-4.1-mini",
      temperature: intent === "GENERAL" ? 0.55 : 0.3,
      max_output_tokens: 420,
      input: [
        {
          role: "system",
          content:
            system +
            "\n\nเพิ่มเติมสำหรับโหมดเสียง: เขียนให้พูดง่าย เป็นประโยคสั้นๆ ไม่ยาวเกินไป และลงท้ายด้วยครับ",
        },
        { role: "user", content: user },
      ],
    });

    const replyText = extractTextFromResponse(response) || "ขอโทษครับ ตอนนี้ไม่สามารถตอบได้";
    const speakText = humanizeForSpeech(replyText);

    const speech = await openai.audio.speech.create({
      model: "gpt-4o-mini-tts",
      voice: "alloy",
      format: "mp3",
      input: speakText,
    });

    const buffer = Buffer.from(await speech.arrayBuffer());
    const audioBase64 = buffer.toString("base64");

    return res.json({
      ok: true,
      replyText,
      audioBase64,
      mime: "audio/mpeg",
      sources: { db: usesDb, llm: "openai", tts: "openai" },
      intent,
    });
  } catch (e) {
    console.error("POST /voice-chat FAILED:", e);
    return res.status(500).json({
      ok: false,
      error: { code: "VOICE_CHAT_FAILED", message: e?.message ?? String(e) },
    });
  }
});

// -------------------- emit / alerts --------------------
app.post("/emit", async (req, res) => {
  try {
    const alert = normalizeAlert(req.body || {});
    if (alert.type !== "alert") alert.type = "alert";

    if (alert.magnitude == null || Number.isNaN(alert.magnitude)) {
      return res.status(400).json({ ok: false, message: "magnitude is required" });
    }
    if (alert.lat == null || Number.isNaN(alert.lat) || alert.lng == null || Number.isNaN(alert.lng)) {
      return res.status(400).json({ ok: false, message: "lat/lng is required" });
    }
    if (!alert.location) {
      return res.status(400).json({ ok: false, message: "location is required" });
    }
    if (!alert.severity) alert.severity = "caution";

    const saved = await saveAlertToDb(alert);
    const payload = rowToPayload(saved);

    broadcast(payload);
    res.json({ ok: true, data: payload });
  } catch (e) {
    console.error("POST /emit FAILED:", e);
    res.status(500).json({ ok: false, message: e?.message ?? "Internal error" });
  }
});

app.post("/emit/mock", async (req, res) => {
  try {
    const alert = normalizeAlert(makeMockAlert(req.body || {}));
    const saved = await saveAlertToDb(alert);
    const payload = rowToPayload(saved);

    broadcast(payload);
    res.json({ ok: true, data: payload });
  } catch (e) {
    console.error("POST /emit/mock FAILED:", e);
    res.status(500).json({ ok: false, message: e?.message ?? "Internal error" });
  }
});

// ✅ Alerts list
app.get("/alerts", async (req, res) => {
  try {
    const take = Math.min(Math.max(parseInt(req.query.take ?? "50", 10) || 50, 1), 200);
    const skip = Math.max(parseInt(req.query.skip ?? "0", 10) || 0, 0);

    const rows = await prisma.alert.findMany({
      orderBy: { timestamp: "desc" },
      take,
      skip,
    });

    const data = rows.map((r) => ({
      ...r,
      timestamp: r.timestamp.toISOString(),
      createdAt: r.createdAt.toISOString(),
    }));

    res.json({ ok: true, data });
  } catch (e) {
    console.error("GET /alerts FAILED:", e);
    res.status(500).json({
      ok: false,
      message: e?.message ?? String(e),
      code: e?.code,
      meta: e?.meta,
    });
  }
});

// landing
app.get("/", (_req, res) => {
  res.send("QuakeLink WS Server is running ✅");
});

const PORT = process.env.PORT || 8080;

// ✅ เริ่ม TB poller (optional)
const TB_POLL_ENABLE = String(process.env.TB_POLL_ENABLE || "").toLowerCase() === "true";
const TB_POLL_MS = Math.max(parseInt(process.env.TB_POLL_MS || "3000", 10) || 3000, 1000);

if (TB_POLL_ENABLE) {
  console.log(`🛰️ ThingsBoard polling enabled: every ${TB_POLL_MS} ms`);
  setInterval(pollThingsboardAndEmit, TB_POLL_MS);
}

// ✅ NEW: TB latest-all -> WS broadcast (recommended)
const TB_LATESTALL_WS_ENABLE =
  String(process.env.TB_LATESTALL_WS_ENABLE || "true").toLowerCase() === "true";
const TB_LATESTALL_WS_MS = Math.max(parseInt(process.env.TB_LATESTALL_WS_MS || "5000", 10) || 5000, 3000);

if (TB_LATESTALL_WS_ENABLE) {
  console.log(`📡 TB latest-all WS broadcast enabled: every ${TB_LATESTALL_WS_MS} ms`);
  setInterval(pollTbLatestAllAndBroadcast, TB_LATESTALL_WS_MS);

  // ยิงครั้งแรกเพื่อให้มี cache ไว้ส่งตอน client connect
  pollTbLatestAllAndBroadcast().catch(() => {});
}

server.listen(PORT, "0.0.0.0", () => {
  console.log(`🚀 HTTP: http://localhost:${PORT}`);
  console.log(`🔌 WS : ws://localhost:${PORT}`);
});

process.on("SIGINT", async () => {
  console.log("\n🧹 shutting down...");
  try {
    await prisma.$disconnect();
  } finally {
    process.exit(0);
  }
});
