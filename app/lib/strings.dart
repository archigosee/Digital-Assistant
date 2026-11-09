import 'models/assistant_result.dart';

/// UI strings. Amharic is the default; [english] flips the chrome to English.
/// (Assistant replies stay in Amharic; the proxy returns reply_am.)
class S {
  const S(this.english);
  final bool english;

  String _t(String am, String en) => english ? en : am;

  String get appTitle => _t('ሰላም', 'Selam');
  String get subtitle => _t('የአማርኛ ድምፅ ረዳት', 'Amharic voice assistant');
  String get tapToSpeak => _t('ለመናገር ይንኩ', 'Tap to speak');
  String get listening => _t('እያዳመጥኩ ነው… ለመጨረስ ይንኩ', 'Listening… tap to finish');
  String get thinking => _t('እያሰብኩ ነው…', 'Thinking…');
  String get typeHint => _t('ወይም እዚህ ይጻፉ…', 'Or type here…');
  String get offlineBadge => _t('ከመስመር ውጭ', 'Offline demo');
  String get emptyTitle => _t('ሰላም! ምን ልርዳዎት?', 'Hi! How can I help?');
  String get emptyBody => _t(
      'ማይክሮፎኑን ይንኩና በአማርኛ ይናገሩ። ለምሳሌ፦',
      'Tap the mic and speak Amharic. For example:');
  String get micDenied => _t(
      'የማይክሮፎን ፈቃድ ያስፈልጋል። በቅንብሮች ውስጥ ይፍቀዱ።',
      'Microphone permission is needed. Allow it in Settings.');
  String get recordFailed =>
      _t('ድምፁን መቅዳት አልተቻለም።', 'Could not record audio.');
  String get errorReply => _t('ይቅርታ፣ አሁን መመለስ አልቻልኩም።',
      'Sorry, I could not answer right now.');
  String get clearChat => _t('ውይይቱን አጽዳ', 'Clear chat');
  String get languageToggle => _t('English', 'አማርኛ');
  String get voice => _t('ድምፅ', 'voice');

  String intentLabel(Intent i) => switch (i) {
        Intent.chat => _t('ውይይት', 'Chat'),
        Intent.setReminder => _t('አስታዋሽ', 'Reminder'),
        Intent.addNote => _t('ማስታወሻ', 'Note'),
        Intent.setTimer => _t('ሰዓት ቆጣሪ', 'Timer'),
        Intent.webSearch => _t('ፍለጋ', 'Web search'),
        Intent.openUrl => _t('ድረ-ገጽ', 'Open link'),
        Intent.weather => _t('የአየር ሁኔታ', 'Weather'),
        Intent.news => _t('ዜና', 'News'),
        Intent.ethiopianDate => _t('ቀን', 'Ethiopian date'),
        Intent.callContact => _t('ጥሪ', 'Call'),
        Intent.sendSms => _t('መልእክት', 'SMS'),
        Intent.openApp => _t('መተግበሪያ', 'Open app'),
      };
}
