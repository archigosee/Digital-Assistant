# Selam — Amharic Voice Assistant

Selam (ሰላም) is an Amharic-first voice assistant for Android. You tap the mic and speak Amharic.
The app records the audio and sends it to a small serverless proxy, which asks Google Gemini for
a structured answer: the transcript, the intent, its slots and an Amharic reply. The app then
acts on the intent.

> Status: work in progress. The Flutter app (mic recording, waveform, chat UI, offline mock mode)
> is done. The Gemini proxy, on-device reminders/notes/timers, web and phone actions, TTS and the
> APK release are next.

## Repo layout

| Path | What |
|------|------|
| `app/` | Flutter Android app (`com.archigosee.selam`) |
| `server/` | Vercel serverless proxy for Gemini (coming next) |

## Run the app

Requires Flutter 3.x and the Android SDK.

```bash
cd app
flutter pub get
flutter test
flutter run            # on a device or emulator
```

Without a configured proxy the app runs in **offline demo mode**. Typed text is classified with
Amharic/English keywords, and each voice recording plays the next built-in sample sentence, so
every intent can be tried without an API key.

## Intents

`chat`, `set_reminder`, `add_note`, `set_timer`, `web_search`, `open_url`, `weather`, `news`,
`ethiopian_date`, `call_contact`, `send_sms`, `open_app`.

Calls and SMS always show a confirmation sheet first; nothing is sent automatically.

## Security

The Gemini API key is never in the app, the APK or this repo. It lives only in the proxy's Vercel
environment variables.

## License / credits

Noto Sans Ethiopic is © The Noto Project Authors, under the SIL Open Font License
(`app/assets/fonts/OFL.txt`).
