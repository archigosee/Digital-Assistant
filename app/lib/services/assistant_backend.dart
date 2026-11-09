import '../models/assistant_result.dart';

/// Turns a user's speech or text into an [AssistantResult].
///
/// Implementations: [MockAssistant] (offline, canned Amharic intents) and,
/// from chunk 2, the Vercel proxy client that calls Gemini.
abstract class AssistantBackend {
  /// [audioPath] is a local m4a file recorded by [RecorderService].
  Future<AssistantResult> understandAudio(String audioPath);

  Future<AssistantResult> understandText(String text);
}

/// Thrown when the backend cannot answer (network, not configured, quota).
class AssistantException implements Exception {
  AssistantException(this.message, {this.notConfigured = false});
  final String message;
  final bool notConfigured;
  @override
  String toString() => 'AssistantException: $message';
}
