import 'assistant_result.dart';

enum Sender { user, assistant }

class ChatMessage {
  ChatMessage({
    required this.sender,
    required this.text,
    this.intent,
    this.fromVoice = false,
    this.offline = false,
    this.isError = false,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  final Sender sender;
  final String text;
  final Intent? intent;
  final bool fromVoice;
  final bool offline;
  final bool isError;
  final DateTime time;
}
