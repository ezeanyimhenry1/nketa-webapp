const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const fetch = require("node-fetch");
const FormData = require("form-data");

admin.initializeApp();
setGlobalOptions({ region: "us-central1", maxInstances: 10 });

const INTRON_BASE = "https://infer.voice.intron.io";
const FLUTTERWAVE_BASE = "https://api.flutterwave.com/v3";

function cors(res) {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
}

function handleOptions(req, res) {
  cors(res);
  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return true;
  }
  return false;
}

async function readJsonBody(req) {
  if (req.body && typeof req.body === "object") return req.body;
  return {};
}

exports.openaiChat = onRequest({ secrets: ["OPENAI_API_KEY"] }, async (req, res) => {
  if (handleOptions(req, res)) return;
  cors(res);
  try {
    const body = await readJsonBody(req);
    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });
    const json = await response.json();
    res.status(response.status).json(json);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

exports.intronProxy = onRequest({ secrets: ["INTRON_API_KEY"] }, async (req, res) => {
  if (handleOptions(req, res)) return;
  cors(res);
  try {
    const body = await readJsonBody(req);
    const apiKey = process.env.INTRON_API_KEY;
    if (body.method === "STT_UPLOAD") {
      const form = new FormData();
      form.append("audio_file_name", "nketa_recording");
      form.append("use_language_asr_input", body.asrLanguage || "ig");
      form.append("use_disable_llm_corrections", "TRUE");
      form.append("audio_file_blob", Buffer.from(body.audioBase64 || "", "base64"), {
        filename: body.filename || "nketa_recording.wav",
        contentType: "audio/wav",
      });
      const response = await fetch(`${INTRON_BASE}/file/v1/upload/sync`, {
        method: "POST",
        headers: { Authorization: `Bearer ${apiKey}`, ...form.getHeaders() },
        body: form,
      });
      const json = await response.json();
      res.status(response.status).json(json);
      return;
    }

    const method = (body.method || "GET").toUpperCase();
    const path = body.path || "/";
    const response = await fetch(`${INTRON_BASE}${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: method === "GET" ? undefined : JSON.stringify(body.body || {}),
    });
    const json = await response.json();
    res.status(response.status).json(json);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

exports.flutterwaveProxy = onRequest(
  { secrets: ["FLUTTERWAVE_API_KEY"] },
  async (req, res) => {
    if (handleOptions(req, res)) return;
    cors(res);
    try {
      const body = await readJsonBody(req);
      const method = (body.method || "GET").toUpperCase();
      const path = body.path || "/";
      const response = await fetch(`${FLUTTERWAVE_BASE}${path}`, {
        method,
        headers: {
          Authorization: `Bearer ${process.env.FLUTTERWAVE_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: method === "GET" ? undefined : JSON.stringify(body.body || {}),
      });
      const json = await response.json();
      res.status(response.status).json(json);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }
);

exports.registerWebPush = onRequest(async (req, res) => {
  if (handleOptions(req, res)) return;
  cors(res);
  try {
    const body = await readJsonBody(req);
    const token = body.token;
    if (!token) {
      res.status(400).json({ error: "token is required" });
      return;
    }
    const ref = admin.firestore().collection("pushSubscriptions").doc(token);
    if (body.enabled === false) {
      await ref.delete();
      res.json({ ok: true, deleted: true });
      return;
    }
    await ref.set(
      {
        token,
        proverbEnabled: !!body.proverbEnabled,
        eventsEnabled: !!body.eventsEnabled,
        hour: Number(body.hour ?? 8),
        minute: Number(body.minute ?? 0),
        timezone: body.timezone || "Africa/Lagos",
        uid: body.uid || null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

function lagosNow() {
  return new Date(new Date().toLocaleString("en-US", { timeZone: "Africa/Lagos" }));
}

function daysSince2024(date) {
  const start = new Date(Date.UTC(2024, 0, 1));
  const current = Date.UTC(date.getFullYear(), date.getMonth(), date.getDate());
  return Math.floor((current - start.getTime()) / 86400000);
}

async function loadJson(url) {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Failed to fetch ${url}`);
  return response.json();
}

exports.sendScheduledReminders = onSchedule(
  {
    schedule: "every 15 minutes",
    timeZone: "Africa/Lagos",
  },
  async () => {
    const jsonBase =
      process.env.JSON_URL || "https://raw.githubusercontent.com/ezeanyimhenry1/";
    const now = lagosNow();
    const today = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(
      now.getDate()
    ).padStart(2, "0")}`;
    const currentMinutes = now.getHours() * 60 + now.getMinutes();

    const snap = await admin.firestore().collection("pushSubscriptions").get();
    if (snap.empty) return;

    let proverbs = [];
    try {
      proverbs = await loadJson(`${jsonBase}igbo-proverbs/main/proverbs.json`);
    } catch (error) {
      console.error("Failed to load proverbs", error);
    }

    let events = [];
    try {
      events = await loadJson(`${jsonBase}igbo-events/main/events.json`);
    } catch (error) {
      console.error("Failed to load events", error);
    }

    const proverbIndex = proverbs.length
      ? daysSince2024(now) % proverbs.length
      : 0;
    const proverb = proverbs[proverbIndex] || {};
    const proverbBody = `${proverb.igbo || "Proverb of the Day"}\n${proverb.english || ""}`.trim();

    const messaging = admin.messaging();
    const writes = [];

    for (const doc of snap.docs) {
      const data = doc.data();
      const token = data.token || doc.id;
      const scheduled = Number(data.hour ?? 8) * 60 + Number(data.minute ?? 0);
      const inWindow = currentMinutes >= scheduled && currentMinutes < scheduled + 15;

      if (data.proverbEnabled && inWindow && data.lastProverbDate !== today) {
        try {
          await messaging.send({
            token,
            notification: {
              title: "Proverb of the Day",
              body: proverbBody,
            },
            data: {
              type: "proverb_of_the_day",
              url: "/",
            },
            webpush: {
              fcmOptions: { link: "/" },
            },
          });
          writes.push(doc.ref.update({ lastProverbDate: today }));
        } catch (error) {
          console.error("Proverb push failed", token, error.message);
        }
      }

      if (data.eventsEnabled && data.lastEventDate !== today) {
        const todaysEvents = events.filter((event) => {
          const date = event.date || event.startDate || event.day;
          return typeof date === "string" && date.startsWith(today);
        });
        if (todaysEvents.length > 0 && inWindow) {
          const first = todaysEvents[0];
          try {
            await messaging.send({
              token,
              notification: {
                title: first.name || first.title || "Igbo event today",
                body: first.description || "Open Nketa to see today's cultural events.",
              },
              data: {
                type: "event",
                url: "/",
              },
              webpush: {
                fcmOptions: { link: "/" },
              },
            });
            writes.push(doc.ref.update({ lastEventDate: today }));
          } catch (error) {
            console.error("Event push failed", token, error.message);
          }
        }
      }
    }

    await Promise.all(writes);
  }
);
