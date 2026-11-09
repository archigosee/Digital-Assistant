import 'package:flutter_test/flutter_test.dart';
import 'package:selam/models/assistant_result.dart';
import 'package:selam/services/mock_assistant.dart';
import 'package:selam/services/recorder_service.dart';

void main() {
  group('MockAssistant.classify', () {
    final cases = <String, Intent>{
      'ነገ ጠዋት መድሃኒት እንድወስድ አስታውሰኝ': Intent.setReminder,
      'ለ10 ደቂቃ ሰዓት ቆጣሪ አዘጋጅ': Intent.setTimer,
      'ማስታወሻ ያዝ፦ ወተት ግዛ': Intent.addNote,
      'የአየር ሁኔታ ምን ይመስላል': Intent.weather,
      'የዛሬ ዜና': Intent.news,
      'ዛሬ በኢትዮጵያ አቆጣጠር ስንት ነው': Intent.ethiopianDate,
      'ለአበበ ደውል': Intent.callContact,
      'ለሰላም መልእክት ላክ': Intent.sendSms,
      'search coffee prices': Intent.webSearch,
      'open bbc.com': Intent.openUrl,
      'ቴሌግራም ክፈት': Intent.openApp,
      'ሰላም': Intent.chat,
    };
    cases.forEach((text, intent) {
      test('"$text" -> ${intent.wire}', () {
        final r = MockAssistant.classify(text);
        expect(r.intent, intent);
        expect(r.offline, isTrue);
        expect(r.replyAm, isNotEmpty);
        expect(r.transcriptAm, text);
      });
    });

    test('timer slot parses minutes', () {
      final r = MockAssistant.classify('ለ10 ደቂቃ ሰዓት ቆጣሪ');
      expect(r.slots['duration_seconds'], 600);
    });

    test('note slot keeps text after the colon', () {
      expect(MockAssistant.classify('ማስታወሻ ያዝ፦ ወተት ግዛ').slots['text'],
          'ወተት ግዛ');
    });

    test('call slot extracts the contact name', () {
      expect(MockAssistant.classify('ለአበበ ደውል').slots['contact'], 'አበበ');
    });
  });

  test('audio in mock mode cycles through sample utterances', () async {
    final m = MockAssistant(latency: Duration.zero);
    final a = await m.understandAudio('x.m4a');
    final b = await m.understandAudio('x.m4a');
    expect(a.transcriptAm, MockAssistant.samples[0]);
    expect(b.transcriptAm, MockAssistant.samples[1]);
    expect(b.intent, Intent.setReminder);
  });

  group('AssistantResult.fromJson', () {
    test('parses the proxy contract', () {
      final r = AssistantResult.fromJson({
        'transcript_am': ' ሰላም ',
        'intent': 'set_timer',
        'slots': {'duration_seconds': 300},
        'reply_am': 'እሺ',
      });
      expect(r.transcriptAm, 'ሰላም');
      expect(r.intent, Intent.setTimer);
      expect(r.slots['duration_seconds'], 300);
      expect(r.toJson()['intent'], 'set_timer');
    });

    test('unknown intent and missing fields are tolerated', () {
      final r = AssistantResult.fromJson({'intent': 'fly_to_moon'});
      expect(r.intent, Intent.chat);
      expect(r.slots, isEmpty);
      expect(r.replyAm, '');
    });
  });

  test('RecorderService.normalise maps dBFS to 0..1', () {
    expect(RecorderService.normalise(-60), 0);
    expect(RecorderService.normalise(0), 1);
    expect(RecorderService.normalise(-30), closeTo(0.5, 1e-9));
    expect(RecorderService.normalise(-120), 0);
    expect(RecorderService.normalise(double.negativeInfinity), 0);
  });
}
