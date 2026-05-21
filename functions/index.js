const {onSchedule} = require("firebase-functions/v2/scheduler");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();

/** Same string as lib/fcm_constants.dart */
const TOPIC = "daily_verse_all";

/**
 * Every day 06:00 UTC: notify all app installs subscribed to [TOPIC].
 * Optional copy: Firestore doc daily/{YYYY-MM-DD} (UTC) with verse_of_day / daily_card / devotional_topic.
 */
exports.sendDailyVerseTopic = onSchedule(
  {
    schedule: "0 6 * * *",
    timeZone: "Etc/UTC",
    region: "us-central1",
  },
  async () => {
    const db = getFirestore();
    const now = new Date();
    const y = now.getUTCFullYear();
    const m = String(now.getUTCMonth() + 1).padStart(2, "0");
    const d = String(now.getUTCDate()).padStart(2, "0");
    const dayKey = `${y}-${m}-${d}`;

    const title = "Verse of the day";
    let body = "Open NJ Bible for today’s verse and devotional.";

    try {
      const doc = await db.collection("daily").doc(dayKey).get();
      if (doc.exists) {
        const data = doc.data();
        const v = data && data.verse_of_day;
        if (v && typeof v === "object") {
          const ref = v.reference ? String(v.reference) : "";
          const txt = v.text
            ? String(v.text).replace(/\s+/g, " ").trim()
            : "";
          if (ref && txt) {
            const short = txt.slice(0, 120);
            body = `${ref} — ${short}${txt.length > 120 ? "…" : ""}`;
          } else if (ref) {
            body = ref;
          } else if (txt) {
            body = txt.slice(0, 180) + (txt.length > 180 ? "…" : "");
          }
        }
      }
    } catch (e) {
      console.error("daily doc read failed", e);
    }

    await getMessaging().send({
      topic: TOPIC,
      notification: {
        title,
        body: body.slice(0, 200),
      },
      data: {
        type: "daily_verse",
        dayKey,
      },
    });
  },
);
