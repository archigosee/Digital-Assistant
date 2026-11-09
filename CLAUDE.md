# Selam — Amharic Voice Assistant (Digital-Assistant)

## 1. What it is
- Amharic-first voice assistant for Android: speak, Gemini understands (via our own proxy), the app acts.
- Monorepo: `app/` Flutter Android app, `server/` Vercel serverless proxy (chunk 2, not built yet).
- Goal ("go further"): real Gemini speech understanding, on-device storage, real Android actions, tests, public APK.

## 2. Stack
- Flutter 3.x / Dart ^3.10 (C:\flutter), Material 3, package `selam`, appId `com.archigosee.selam`.
- Packages: record 6 (m4a/AAC 16 kHz mono), path_provider, shared_preferences, http, uuid.
- Font: bundled Noto Sans Ethiopic variable TTF (`app/assets/fonts`, OFL).
- Planned: sqflite/drift, flutter_local_notifications, flutter_tts, url_launcher, flutter_contacts, android_intent_plus.
- Proxy (planned): Vercel functions, Node, Gemini structured output; project `amharic-assistant-api`.

## 3. Commands (run inside `app/`, Git Bash; Flutter first run is slow)
- Install: `/c/flutter/bin/flutter pub get`
- Analyze: `/c/flutter/bin/flutter analyze`
- Test: `/c/flutter/bin/flutter test`
- Debug APK: `/c/flutter/bin/flutter build apk --debug`
- Release APK: `/c/flutter/bin/flutter build apk --release` (debug signing is fine for the demo)
- Emulator: `$LOCALAPPDATA/Android/Sdk/emulator/emulator.exe -avd Medium_Phone_API_36.1 -allow-host-audio`
- Install: `$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe install -r build/app/outputs/flutter-apk/app-debug.apk`

## 4. Key paths
- `app/lib/main.dart`: SelamApp, light/dark theme, language toggle (shared_preferences `english`).
- `app/lib/chat_controller.dart`: mic state machine idle→recording→thinking, message list.
- `app/lib/services/assistant_backend.dart`: `AssistantBackend` interface + `AssistantException`.
- `app/lib/services/mock_assistant.dart`: offline mock (keyword classifier, sample utterances for audio).
- `app/lib/services/recorder_service.dart`: record wrapper, amplitude → 0..1 levels.
- `app/lib/models/assistant_result.dart`: proxy contract + `Intent` enum (wire names).
- `app/lib/screens/home_screen.dart`: chat list, empty state with examples, mic panel, text input.
- `app/lib/widgets/`: mic_button, waveform, message_bubble. `app/lib/strings.dart`: am/en strings.
- `app/test/`: mock classifier + contract tests, widget tests.

## 5. Architecture / contract
- Proxy response (Gemini structured output): `{transcript_am, intent, slots, reply_am}`.
- Intents: chat, set_reminder, add_note, set_timer, web_search, open_url, weather, news,
  ethiopian_date, call_contact, send_sms, open_app. Unknown → chat.
- Slots so far (mock): set_timer.duration_seconds, add_note.text, set_reminder.text,
  weather.city, call_contact.contact, send_sms.{contact,message}, web_search.query, open_url.url, open_app.app.
- App sends audio (m4a) or text to `AssistantBackend`; mock is used until the proxy is configured.
- Planned proxy: `POST /api/understand` (multipart audio or JSON text), header `X-App-Token`
  (per-install uuid), rate limit, CORS; no key → 503 `{error:"not_configured"}` → app falls back to mock.

## 6. Conventions
- UI chrome via `S(english)` in strings.dart; replies stay Amharic (reply_am).
- Widgets get stable `Key`s for tests (mic-button, text-input, send-button, lang-toggle, waveform).
- Errors: controller sets `lastProblem` (snackbar) or adds an `isError` bubble; never crashes.
- Secrets: GEMINI_API_KEY only in Vercel env (Kaleab sets it). Never in app/APK/repo.

## 7. MVP checklist
- [x] Chunk 1: repo scaffold, CLAUDE.md, Flutter app, mic recording + waveform, chat UI, mock mode, tests
- [ ] Chunk 2: Vercel proxy `/server` with Gemini structured output, app token, rate limit; app client + mock fallback
- [ ] Chunk 3: reminders/notes/timers in sqflite + local notifications (exact alarms)
- [ ] Chunk 4: web search/open URL, weather (Open-Meteo), news (BBC Amharic RSS), Ethiopian calendar/time + tests
- [ ] Chunk 5: call/SMS/open app with confirmation sheets, contacts lookup + permissions
- [ ] Chunk 6: TTS (flutter_tts am-ET, fallback text), polish, more tests
- [ ] Chunk 7: release APK + `/download` page on proxy project + README screenshots
- [ ] Chunk 8: portfolio entry (summary, highlights, stack, apk, repo)

## 8. Gotchas
- Mock mode can't transcribe audio: each recording plays the next `MockAssistant.samples` utterance.
- `RecorderService` creates `AudioRecorder` lazily so widget tests run without the plugin.
- Ignore the old private repo `voiceRecognition` (empty skeleton).

## 9. Last updated
- 2026-11-09: chunk 1 (scaffold, mic + chat UI, mock assistant, 22 tests).
