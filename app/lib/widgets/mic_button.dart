import 'package:flutter/material.dart';

import '../chat_controller.dart';

/// The big round mic button. Pulses while recording, spins while thinking.
class MicButton extends StatefulWidget {
  const MicButton({super.key, required this.state, required this.onPressed, required this.semanticLabel});

  final MicState state;
  final VoidCallback onPressed;
  final String semanticLabel;

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didUpdateWidget(MicButton old) {
    super.didUpdateWidget(old);
    if (widget.state == MicState.recording) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final recording = widget.state == MicState.recording;
    final thinking = widget.state == MicState.thinking;
    final bg = recording ? scheme.error : scheme.primary;
    final fg = recording ? scheme.onError : scheme.onPrimary;

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: bg.withValues(alpha: 0.35),
                blurRadius: 12 + 18 * _pulse.value,
                spreadRadius: 2 + 10 * _pulse.value,
              ),
            ],
          ),
          child: child,
        ),
        child: Material(
          color: bg,
          shape: const CircleBorder(),
          child: InkWell(
            key: const Key('mic-button'),
            customBorder: const CircleBorder(),
            onTap: thinking ? null : widget.onPressed,
            child: Center(
              child: thinking
                  ? SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                          strokeWidth: 3, color: fg),
                    )
                  : Icon(recording ? Icons.stop_rounded : Icons.mic_rounded,
                      size: 44, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}
