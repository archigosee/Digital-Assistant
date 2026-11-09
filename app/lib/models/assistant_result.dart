/// The structured result the assistant returns for one user turn.
///
/// Mirrors the proxy contract: `{transcript_am, intent, slots, reply_am}`.
class AssistantResult {
  const AssistantResult({
    required this.transcriptAm,
    required this.intent,
    required this.slots,
    required this.replyAm,
    this.offline = false,
  });

  final String transcriptAm;
  final Intent intent;
  final Map<String, dynamic> slots;
  final String replyAm;

  /// True when produced by the on-device mock instead of the Gemini proxy.
  final bool offline;

  factory AssistantResult.fromJson(Map<String, dynamic> json,
      {bool offline = false}) {
    final slots = json['slots'];
    return AssistantResult(
      transcriptAm: (json['transcript_am'] as String?)?.trim() ?? '',
      intent: Intent.parse(json['intent'] as String?),
      slots: slots is Map ? Map<String, dynamic>.from(slots) : const {},
      replyAm: (json['reply_am'] as String?)?.trim() ?? '',
      offline: offline,
    );
  }

  Map<String, dynamic> toJson() => {
        'transcript_am': transcriptAm,
        'intent': intent.wire,
        'slots': slots,
        'reply_am': replyAm,
      };
}

/// Every intent the assistant understands. [wire] is the JSON value.
enum Intent {
  chat('chat'),
  setReminder('set_reminder'),
  addNote('add_note'),
  setTimer('set_timer'),
  webSearch('web_search'),
  openUrl('open_url'),
  weather('weather'),
  news('news'),
  ethiopianDate('ethiopian_date'),
  callContact('call_contact'),
  sendSms('send_sms'),
  openApp('open_app');

  const Intent(this.wire);
  final String wire;

  /// Unknown or missing values fall back to [Intent.chat].
  static Intent parse(String? value) => Intent.values.firstWhere(
        (i) => i.wire == value,
        orElse: () => Intent.chat,
      );
}
