import '../models/assistant_result.dart';
import 'assistant_backend.dart';

/// Offline fallback used until the Gemini proxy is configured (or reachable).
///
/// Typed text is matched against Amharic and English keywords. Recorded audio
/// cannot be transcribed offline, so each recording plays the next sample
/// utterance from [samples], which demonstrates the intents end to end.
class MockAssistant implements AssistantBackend {
  MockAssistant({this.latency = const Duration(milliseconds: 600)});

  final Duration latency;
  int _sampleIndex = 0;

  static const samples = <String>[
    'ሰላም፣ እንዴት ነህ?',
    'ነገ ጠዋት 3 ሰዓት መድሃኒት እንድወስድ አስታውሰኝ',
    'ለ5 ደቂቃ ሰዓት ቆጣሪ አዘጋጅ',
    'የአዲስ አበባ የአየር ሁኔታ ምን ይመስላል?',
    'ዛሬ በኢትዮጵያ አቆጣጠር ስንት ነው?',
    'ማስታወሻ ያዝ፦ ወተት እና ዳቦ ግዛ',
    'የዛሬ ዜና አሰማኝ',
    'ለአበበ ደውል',
  ];

  @override
  Future<AssistantResult> understandAudio(String audioPath) async {
    final text = samples[_sampleIndex % samples.length];
    _sampleIndex++;
    return understandText(text);
  }

  @override
  Future<AssistantResult> understandText(String text) async {
    await Future<void>.delayed(latency);
    return classify(text);
  }

  /// Pure keyword classifier, exposed for tests.
  static AssistantResult classify(String text) {
    final t = text.toLowerCase();
    bool has(List<String> words) => words.any(t.contains);
    final number = RegExp(r'\d+').firstMatch(t)?.group(0);

    Intent intent;
    Map<String, dynamic> slots = {};
    String reply;

    if (has(['አስታውሰኝ', 'አስታውስ', 'remind'])) {
      intent = Intent.setReminder;
      slots = {'text': text};
      reply = 'እሺ፣ አስታዋሽ አዘጋጃለሁ።';
    } else if (has(['ሰዓት ቆጣሪ', 'ቆጣሪ', 'timer'])) {
      intent = Intent.setTimer;
      final minutes = int.tryParse(number ?? '') ?? 5;
      slots = {'duration_seconds': minutes * 60};
      reply = 'የ$minutes ደቂቃ ሰዓት ቆጣሪ ጀምሬያለሁ።';
    } else if (has(['ማስታወሻ', 'note'])) {
      intent = Intent.addNote;
      final body = text.split(RegExp(r'[፦:]')).last.trim();
      slots = {'text': body};
      reply = 'ማስታወሻው ተቀምጧል።';
    } else if (has(['አየር', 'weather'])) {
      intent = Intent.weather;
      slots = {'city': has(['ባሕር ዳር', 'bahir dar']) ? 'Bahir Dar' : 'Addis Ababa'};
      reply = 'የአየር ሁኔታውን እያየሁ ነው።';
    } else if (has(['ዜና', 'news'])) {
      intent = Intent.news;
      reply = 'የቅርብ ጊዜ ዜናዎች እነሆ።';
    } else if (has(['አቆጣጠር', 'ቀን', 'date', 'calendar'])) {
      intent = Intent.ethiopianDate;
      reply = 'የዛሬው ቀን በኢትዮጵያ አቆጣጠር እነሆ።';
    } else if (has(['ደውል', 'call'])) {
      intent = Intent.callContact;
      slots = {'contact': _afterLe(text) ?? ''};
      reply = 'ከመደወሌ በፊት እንዲያረጋግጡ እጠይቃለሁ።';
    } else if (has(['መልእክት', 'መልዕክት', 'sms', 'text message'])) {
      intent = Intent.sendSms;
      slots = {'contact': _afterLe(text) ?? '', 'message': ''};
      reply = 'መልእክቱን ከመላኬ በፊት እንዲያረጋግጡ እጠይቃለሁ።';
    } else if (has(['ፈልግ', 'search', 'google'])) {
      intent = Intent.webSearch;
      slots = {'query': text};
      reply = 'በድር ላይ እፈልጋለሁ።';
    } else if (has(['ክፈት', 'open'])) {
      final url = RegExp(r'\S+\.\S+').firstMatch(text)?.group(0);
      intent = url != null ? Intent.openUrl : Intent.openApp;
      slots = url != null ? {'url': url} : {'app': text};
      reply = 'እከፍታለሁ።';
    } else {
      intent = Intent.chat;
      reply = 'ሰላም! እኔ ሰላም ነኝ፣ የአማርኛ ድምፅ ረዳትዎ። አሁን ከመስመር ውጭ ሁነታ ላይ ነኝ።';
    }

    return AssistantResult(
      transcriptAm: text,
      intent: intent,
      slots: slots,
      replyAm: reply,
      offline: true,
    );
  }

  /// "ለአበበ ደውል" -> "አበበ" (Amharic dative prefix ለ).
  static String? _afterLe(String text) {
    final m = RegExp(r'ለ(\S+)').firstMatch(text);
    return m?.group(1);
  }
}
