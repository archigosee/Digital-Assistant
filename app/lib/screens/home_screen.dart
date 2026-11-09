import 'package:flutter/material.dart';

import '../chat_controller.dart';
import '../services/mock_assistant.dart';
import '../strings.dart';
import '../widgets/message_bubble.dart';
import '../widgets/mic_button.dart';
import '../widgets/waveform.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.english,
    required this.onToggleLanguage,
  });

  final ChatController controller;
  final bool english;
  final VoidCallback onToggleLanguage;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  int _lastCount = 0;

  ChatController get c => widget.controller;
  S get s => S(widget.english);

  @override
  void initState() {
    super.initState();
    c.addListener(_onChange);
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChange() {
    final problem = c.lastProblem;
    if (problem != null) {
      c.consumeProblem();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(problem == 'mic_denied' ? s.micDenied : s.recordFailed),
      ));
    }
    if (c.messages.length != _lastCount) {
      _lastCount = c.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut);
        }
      });
    }
  }

  void _send() {
    final text = _input.text;
    _input.clear();
    c.sendText(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.appTitle,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            Text(s.subtitle, style: theme.textTheme.labelMedium),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('lang-toggle'),
            onPressed: widget.onToggleLanguage,
            child: Text(s.languageToggle),
          ),
          IconButton(
            tooltip: s.clearChat,
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: c.clear,
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => Column(
            children: [
              Expanded(
                child: c.messages.isEmpty
                    ? _EmptyState(s: s, onExample: c.sendText)
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        itemCount: c.messages.length,
                        itemBuilder: (_, i) =>
                            MessageBubble(message: c.messages[i], s: s),
                      ),
              ),
              _BottomPanel(
                controller: c,
                s: s,
                input: _input,
                onSend: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.s, required this.onExample});
  final S s;
  final ValueChanged<String> onExample;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(Icons.record_voice_over_rounded,
            size: 56, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(s.emptyTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(s.emptyBody,
            textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final ex in MockAssistant.samples.skip(1).take(5))
              ActionChip(label: Text(ex), onPressed: () => onExample(ex)),
          ],
        ),
      ],
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.controller,
    required this.s,
    required this.input,
    required this.onSend,
  });

  final ChatController controller;
  final S s;
  final TextEditingController input;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = controller.state;
    final status = switch (state) {
      MicState.idle => s.tapToSpeak,
      MicState.recording => s.listening,
      MicState.thinking => s.thinking,
    };

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: state == MicState.recording
                  ? Waveform(key: const Key('waveform'), levels: controller.levels)
                  : const SizedBox(height: 48),
            ),
            const SizedBox(height: 8),
            MicButton(
              state: state,
              semanticLabel: status,
              onPressed: controller.toggleMic,
            ),
            const SizedBox(height: 8),
            Text(status, style: theme.textTheme.labelLarge),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  key: const Key('text-input'),
                  controller: input,
                  enabled: state == MicState.idle,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: s.typeHint,
                    isDense: true,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                key: const Key('send-button'),
                onPressed: state == MicState.idle ? onSend : null,
                icon: const Icon(Icons.send_rounded),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
