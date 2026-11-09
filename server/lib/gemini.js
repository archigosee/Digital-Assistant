// Gemini call with structured JSON output: {transcript_am, intent, slots, reply_am}.

export const INTENTS = [
  'chat', 'set_reminder', 'add_note', 'set_timer', 'web_search', 'open_url',
  'weather', 'news', 'ethiopian_date', 'call_contact', 'send_sms', 'open_app',
];

export const DEFAULT_MODEL = 'gemini-flash-latest';

export const RESPONSE_SCHEMA = {
  type: 'OBJECT',
  properties: {
    transcript_am: { type: 'STRING', description: 'Verbatim transcript of what the user said, in Amharic (Ge\'ez script).' },
    intent: { type: 'STRING', enum: INTENTS },
    slots: {
      type: 'OBJECT',
      properties: {
        text: { type: 'STRING', description: 'Reminder or note text.' },
        datetime_iso: { type: 'STRING', description: 'Reminder time, ISO 8601 with +03:00 offset.' },
        duration_seconds: { type: 'INTEGER', description: 'Timer length in seconds.' },
        query: { type: 'STRING', description: 'Web search query.' },
        url: { type: 'STRING', description: 'URL to open, with https://.' },
        city: { type: 'STRING', description: 'City for weather, in English.' },
        contact: { type: 'STRING', description: 'Contact name as spoken.' },
        message: { type: 'STRING', description: 'SMS body.' },
        app: { type: 'STRING', description: 'App name in English, e.g. Telegram, YouTube, Camera.' },
        topic: { type: 'STRING', description: 'News topic, optional.' },
      },
    },
    reply_am: { type: 'STRING', description: 'Short, friendly spoken reply in Amharic (1-2 sentences).' },
  },
  required: ['transcript_am', 'intent', 'slots', 'reply_am'],
  propertyOrdering: ['transcript_am', 'intent', 'slots', 'reply_am'],
};

/** Current time in Addis Ababa (UTC+3, no DST) as ISO with offset. */
export function addisNowIso(now = new Date()) {
  const t = new Date(now.getTime() + 3 * 3600_000);
  return t.toISOString().replace(/\.\d{3}Z$/, '+03:00');
}

export function systemPrompt(now = new Date()) {
  return [
    'You are Selam (ሰላም), a helpful Amharic voice assistant on an Android phone in Ethiopia.',
    'The user speaks Amharic (sometimes mixed with English). Understand the request and classify it into exactly one intent.',
    `Current local time in Addis Ababa: ${addisNowIso(now)} (Gregorian, UTC+3).`,
    'Rules:',
    '- transcript_am: what the user said, in Ge\'ez script. For typed input repeat the text.',
    '- set_reminder: slots.text and slots.datetime_iso (resolve relative times like "ነገ ጠዋት 3 ሰዓት"; Ethiopian clock hours are 6 hours behind: 3 ሰዓት ጠዋት = 09:00).',
    '- set_timer: slots.duration_seconds. add_note: slots.text.',
    '- web_search: slots.query. open_url: slots.url. open_app: slots.app.',
    '- weather: slots.city (default Addis Ababa). news: optional slots.topic. ethiopian_date: no slots.',
    '- call_contact: slots.contact. send_sms: slots.contact and slots.message.',
    '- chat: anything else; answer the question helpfully in reply_am.',
    '- reply_am: natural Amharic, 1-2 short sentences, suitable for text-to-speech. Never claim an action is done; say what you will do.',
    '- Only use slot keys from the schema; omit slots that do not apply.',
  ].join('\n');
}

export function buildRequest({ text, audioBase64, mimeType }, now = new Date()) {
  const parts = [];
  if (audioBase64) {
    parts.push({ inlineData: { mimeType: mimeType || 'audio/mp4', data: audioBase64 } });
    parts.push({ text: 'Transcribe and interpret this Amharic voice request.' });
  } else {
    parts.push({ text: `Typed request: ${text}` });
  }
  return {
    systemInstruction: { parts: [{ text: systemPrompt(now) }] },
    contents: [{ role: 'user', parts }],
    generationConfig: {
      responseMimeType: 'application/json',
      responseSchema: RESPONSE_SCHEMA,
      temperature: 0.3,
      maxOutputTokens: 1024,
    },
  };
}

/** Extracts and validates the structured result from a Gemini response body. */
export function parseResponse(body) {
  const raw = body?.candidates?.[0]?.content?.parts?.map((p) => p.text ?? '').join('');
  if (!raw) throw new Error('empty_response');
  let out;
  try {
    out = JSON.parse(raw);
  } catch {
    throw new Error('invalid_json');
  }
  const slots = out.slots && typeof out.slots === 'object' && !Array.isArray(out.slots) ? out.slots : {};
  return {
    transcript_am: String(out.transcript_am ?? '').slice(0, 2000),
    intent: INTENTS.includes(out.intent) ? out.intent : 'chat',
    slots,
    reply_am: String(out.reply_am ?? '').slice(0, 2000),
  };
}

export async function callGemini(input, { apiKey, model = DEFAULT_MODEL, fetchImpl = fetch, timeoutMs = 25_000 }) {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`;
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const r = await fetchImpl(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
      body: JSON.stringify(buildRequest(input)),
      signal: ctrl.signal,
    });
    const body = await r.json().catch(() => ({}));
    if (!r.ok) {
      const err = new Error(`gemini_${r.status}`);
      err.status = r.status;
      err.detail = body?.error?.message;
      throw err;
    }
    return parseResponse(body);
  } finally {
    clearTimeout(timer);
  }
}
