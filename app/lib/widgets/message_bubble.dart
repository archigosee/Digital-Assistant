import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../strings.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, required this.s});

  final ChatMessage message;
  final S s;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final mine = message.sender == Sender.user;
    final bg = message.isError
        ? scheme.errorContainer
        : mine
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest;
    final fg = message.isError
        ? scheme.onErrorContainer
        : mine
            ? scheme.onPrimaryContainer
            : scheme.onSurface;
    final time =
        '${message.time.hour.toString().padLeft(2, '0')}:${message.time.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 4),
              bottomRight: Radius.circular(mine ? 4 : 18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.intent != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Wrap(spacing: 6, children: [
                    _Chip(label: s.intentLabel(message.intent!), color: scheme.primary),
                    if (message.offline)
                      _Chip(label: s.offlineBadge, color: scheme.tertiary),
                  ]),
                ),
              Text(
                message.isError ? s.errorReply : message.text,
                style: text.bodyLarge?.copyWith(color: fg, height: 1.4),
              ),
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (message.fromVoice) ...[
                  Icon(Icons.graphic_eq, size: 14, color: fg.withValues(alpha: 0.6)),
                  const SizedBox(width: 4),
                ],
                Text(time,
                    style: text.labelSmall
                        ?.copyWith(color: fg.withValues(alpha: 0.6))),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600)),
      );
}
