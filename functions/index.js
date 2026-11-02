const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();

const TIMEZONE = "Asia/Jerusalem";
const TOPIC = "staff";
const LOGS_COLLECTION = "notificationLogs";

function getLocalDateParts(date, timeZone) {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);

  const map = {};
  for (const p of parts) {
    if (p.type === "year" || p.type === "month" || p.type === "day") {
      map[p.type] = Number(p.value);
    }
  }
  return { year: map.year, month: map.month, day: map.day };
}

function addDays(parts, delta) {
  const d = new Date(Date.UTC(parts.year, parts.month - 1, parts.day + delta));
  return {
    year: d.getUTCFullYear(),
    month: d.getUTCMonth() + 1,
    day: d.getUTCDate(),
  };
}

function toYmd(parts) {
  const mm = String(parts.month).padStart(2, "0");
  const dd = String(parts.day).padStart(2, "0");
  return `${parts.year}-${mm}-${dd}`;
}

function dateToYmdInTz(date, timeZone) {
  return toYmd(getLocalDateParts(date, timeZone));
}

function makeLogId(type, bookingId, ymd) {
  return `${type}_${bookingId}_${ymd}`;
}

async function wasAlreadySent(type, bookingId, ymd) {
  const ref = db.collection(LOGS_COLLECTION).doc(makeLogId(type, bookingId, ymd));
  const snap = await ref.get();
  return snap.exists;
}

async function markAsSent(type, bookingId, ymd) {
  const ref = db.collection(LOGS_COLLECTION).doc(makeLogId(type, bookingId, ymd));
  await ref.set(
    {
      type,
      bookingId,
      targetYmd: ymd,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

async function loadDogNames(dogIds) {
  if (!dogIds.length) return new Map();
  const refs = dogIds.map((id) => db.collection("dogs").doc(id));
  const snaps = await db.getAll(...refs);
  const map = new Map();
  snaps.forEach((snap) => {
    if (!snap.exists) return;
    const data = snap.data() || {};
    map.set(snap.id, data.name || "כלב");
  });
  return map;
}

function formatDogNames(names) {
  if (!names.length) return "כלב";
  if (names.length === 1) return names[0];
  return names.join(", ");
}

function addYearsYmd(parts, years) {
  const shifted = new Date(Date.UTC(parts.year + years, parts.month - 1, parts.day));
  return {
    year: shifted.getUTCFullYear(),
    month: shifted.getUTCMonth() + 1,
    day: shifted.getUTCDate(),
  };
}

function compareYmd(a, b) {
  if (a.year !== b.year) return a.year - b.year;
  if (a.month !== b.month) return a.month - b.month;
  return a.day - b.day;
}

function dogContractCoversDate(dog, targetParts) {
  const contract = dog && dog.contract;
  if (!contract) return false;
  const urls = Array.isArray(contract.photoUrls)
    ? contract.photoUrls.filter((url) => typeof url === "string" && url.trim())
    : [];
  if (!urls.length) return false;
  if (!contract.uploadedAt || typeof contract.uploadedAt.toDate !== "function") return false;
  const start = getLocalDateParts(contract.uploadedAt.toDate(), TIMEZONE);
  const end = addYearsYmd(start, 1);
  return compareYmd(targetParts, start) >= 0 && compareYmd(targetParts, end) <= 0;
}

async function loadDogs(dogIds) {
  if (!dogIds.length) return new Map();
  const refs = dogIds.map((id) => db.collection("dogs").doc(id));
  const snaps = await db.getAll(...refs);
  const map = new Map();
  snaps.forEach((snap) => {
    if (!snap.exists) return;
    map.set(snap.id, snap.data() || {});
  });
  return map;
}

async function sendTopicNotification({ title, body, type, bookingId, targetYmd }) {
  const alreadySent = await wasAlreadySent(type, bookingId, targetYmd);
  if (alreadySent) return false;

  await admin.messaging().send({
    topic: TOPIC,
    notification: { title, body },
    data: {
      bookingId,
      type,
      targetYmd,
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
        },
      },
    },
    android: {
      notification: {
        sound: "default",
        channelId: "haver_bahatzer_default",
        priority: "high",
      },
    },
  });

  await markAsSent(type, bookingId, targetYmd);
  return true;
}

async function getBookingsByDateField({ field, targetYmd, minDate, maxDate }) {
  const snap = await db
    .collection("bookings")
    .where(field, ">=", admin.firestore.Timestamp.fromDate(minDate))
    .where(field, "<=", admin.firestore.Timestamp.fromDate(maxDate))
    .get();

  return snap.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((b) => b.type === "boarding")
    .filter((b) => b[field] && typeof b[field].toDate === "function")
    .filter((b) => dateToYmdInTz(b[field].toDate(), TIMEZONE) === targetYmd);
}

async function processTomorrowArrivals(now) {
  const localToday = getLocalDateParts(now, TIMEZONE);
  const target = addDays(localToday, 1);
  const targetYmd = toYmd(target);

  // Wide UTC window, then exact date-only filtering in Israel timezone.
  const targetUtc = new Date(Date.UTC(target.year, target.month - 1, target.day));
  const minDate = new Date(targetUtc.getTime() - 36 * 60 * 60 * 1000);
  const maxDate = new Date(targetUtc.getTime() + 36 * 60 * 60 * 1000);

  const bookings = await getBookingsByDateField({
    field: "startDate",
    targetYmd,
    minDate,
    maxDate,
  });

  const allDogIds = [...new Set(bookings.flatMap((b) => (Array.isArray(b.dogIds) ? b.dogIds : [])))];
  const dogNamesById = await loadDogNames(allDogIds);

  let sentCount = 0;
  for (const booking of bookings) {
    const names = (booking.dogIds || []).map((id) => dogNamesById.get(id) || "כלב");
    const dogsText = formatDogNames(names);
    const body = `איזה כיף! מחר ${dogsText} מגיע/ים אלינו, שלח הודעת תזכורת לבעלים שלו/ה.`;
    const sent = await sendTopicNotification({
      title: "כלב חדש מגיע מחר!",
      body,
      type: "arrival_tomorrow",
      bookingId: booking.id,
      targetYmd,
    });
    if (sent) sentCount += 1;
  }

  logger.info("Tomorrow arrivals reminder finished", {
    targetYmd,
    checked: bookings.length,
    sent: sentCount,
  });
}

async function processContractReminder(now) {
  const localToday = getLocalDateParts(now, TIMEZONE);
  const target = addDays(localToday, 7);
  const targetYmd = toYmd(target);

  const targetUtc = new Date(Date.UTC(target.year, target.month - 1, target.day));
  const minDate = new Date(targetUtc.getTime() - 36 * 60 * 60 * 1000);
  const maxDate = new Date(targetUtc.getTime() + 36 * 60 * 60 * 1000);

  const bookings = await getBookingsByDateField({
    field: "startDate",
    targetYmd,
    minDate,
    maxDate,
  });

  const allDogIds = [...new Set(bookings.flatMap((b) => (Array.isArray(b.dogIds) ? b.dogIds : [])))];
  const dogsById = await loadDogs(allDogIds);
  const needsContract = bookings.filter((booking) => {
    const ids = Array.isArray(booking.dogIds) ? booking.dogIds : [];
    if (!ids.length) return false;
    return ids.some((id) => !dogContractCoversDate(dogsById.get(id), target));
  });

  let sentCount = 0;
  for (const booking of needsContract) {
    const ids = Array.isArray(booking.dogIds) ? booking.dogIds : [];
    const names = ids
      .filter((id) => !dogContractCoversDate(dogsById.get(id), target))
      .map((id) => (dogsById.get(id) && dogsById.get(id).name) || "כלב");
    const dogsText = formatDogNames(names);
    const body = `תזכורת להחתים את הבעלים של ${dogsText} על חוזה לקראת ההגעה שלו/ה בשבוע הבא.`;
    const sent = await sendTopicNotification({
      title: "הבעלים חתם על חוזה?",
      body,
      type: "contract_week_before",
      bookingId: booking.id,
      targetYmd,
    });
    if (sent) sentCount += 1;
  }

  logger.info("Contract reminder finished", {
    targetYmd,
    checked: bookings.length,
    candidates: needsContract.length,
    sent: sentCount,
  });
}

async function processReceiptReminder(now) {
  const localToday = getLocalDateParts(now, TIMEZONE);
  const target = addDays(localToday, -2);
  const targetYmd = toYmd(target);

  const targetUtc = new Date(Date.UTC(target.year, target.month - 1, target.day));
  const minDate = new Date(targetUtc.getTime() - 36 * 60 * 60 * 1000);
  const maxDate = new Date(targetUtc.getTime() + 36 * 60 * 60 * 1000);

  const bookings = await getBookingsByDateField({
    field: "endDate",
    targetYmd,
    minDate,
    maxDate,
  });

  const allDogIds = [...new Set(bookings.flatMap((b) => (Array.isArray(b.dogIds) ? b.dogIds : [])))];
  const dogNamesById = await loadDogNames(allDogIds);

  let sentCount = 0;
  for (const booking of bookings) {
    const names = (booking.dogIds || []).map((id) => dogNamesById.get(id) || "כלב");
    const dogsText = formatDogNames(names);
    const body = `הכלב/ה ${dogsText} עזב/ה לפני יומיים, זו תזכורת להוציא קבלה לבעלים שלו/ה.`;
    const sent = await sendTopicNotification({
      title: "הוצאת קבלה",
      body,
      type: "receipt_two_days_after",
      bookingId: booking.id,
      targetYmd,
    });
    if (sent) sentCount += 1;
  }

  logger.info("Receipt reminder finished", {
    targetYmd,
    checked: bookings.length,
    sent: sentCount,
  });
}

exports.newDogArrivesTomorrowReminder = onSchedule(
  {
    schedule: "0 12 * * *",
    timeZone: TIMEZONE,
    retryCount: 0,
  },
  async () => {
    await processTomorrowArrivals(new Date());
  }
);

exports.ownerSignedContractReminder = onSchedule(
  {
    schedule: "0 17 * * *",
    timeZone: TIMEZONE,
    retryCount: 0,
  },
  async () => {
    await processContractReminder(new Date());
  }
);

exports.receiptIssueReminder = onSchedule(
  {
    schedule: "0 16 * * *",
    timeZone: TIMEZONE,
    retryCount: 0,
  },
  async () => {
    await processReceiptReminder(new Date());
  }
);
