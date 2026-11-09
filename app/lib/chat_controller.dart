import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models/chat_message.dart';
import 'models/assistant_result.dart';
import 'services/assistant_backend.dart';
import 'services/recorder_service.dart';

enum MicState { idle, recording, thinking }

/// Owns the conversation and the mic state machine:
/// idle -> recording -> thinking -> idle.
class ChatController extends ChangeNotifier {
  ChatController({required this.backend, required this.recorder});

  final AssistantBackend backend;
  final RecorderService recorder;

  final List<ChatMessage> messages = [];
  MicState state = MicState.idle;

  /// Last ~40 input levels for the waveform (0..1).
  final List<double> levels = [];
  StreamSubscription<double>? _levelSub;

  /// Set when something needs a snackbar (permission denied, record failure).
  String? lastProblem;

  Future<void> toggleMic() async {
    switch (state) {
      case MicState.idle:
        await _startRecording();
      case MicState.recording:
        await _stopAndSend();
      case MicState.thinking:
        return;
    }
  }

  Future<void> _startRecording() async {
    if (!await recorder.hasPermission()) {
      lastProblem = 'mic_denied';
      notifyListeners();
      return;
    }
    try {
      await recorder.start();
    } catch (e) {
      debugPrint('record start failed: $e');
      lastProblem = 'record_failed';
      notifyListeners();
      return;
    }
    levels.clear();
    _levelSub = recorder.levels.listen((l) {
      levels.add(l);
      if (levels.length > 40) levels.removeAt(0);
      notifyListeners();
    });
    state = MicState.recording;
    notifyListeners();
  }

  Future<void> _stopAndSend() async {
    await _levelSub?.cancel();
    _levelSub = null;
    final path = await recorder.stop();
    if (path == null) {
      state = MicState.idle;
      lastProblem = 'record_failed';
      notifyListeners();
      return;
    }
    await _run(() => backend.understandAudio(path), fromVoice: true);
  }

  Future<void> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state != MicState.idle) return;
    messages.add(ChatMessage(sender: Sender.user, text: trimmed));
    await _run(() => backend.understandText(trimmed));
  }

  Future<void> _run(Future<AssistantResult> Function() call,
      {bool fromVoice = false}) async {
    state = MicState.thinking;
    notifyListeners();
    try {
      final r = await call();
      if (fromVoice && r.transcriptAm.isNotEmpty) {
        messages.add(ChatMessage(
            sender: Sender.user, text: r.transcriptAm, fromVoice: true));
      }
      messages.add(ChatMessage(
        sender: Sender.assistant,
        text: r.replyAm,
        intent: r.intent,
        offline: r.offline,
      ));
    } catch (e) {
      debugPrint('assistant failed: $e');
      messages.add(ChatMessage(
          sender: Sender.assistant, text: '', isError: true));
    } finally {
      state = MicState.idle;
      notifyListeners();
    }
  }

  void consumeProblem() => lastProblem = null;

  void clear() {
    messages.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _levelSub?.cancel();
    recorder.dispose();
    super.dispose();
  }
}
