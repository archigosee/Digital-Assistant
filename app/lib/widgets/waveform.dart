import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Live input-level bars shown while recording.
class Waveform extends StatelessWidget {
  const Waveform({super.key, required this.levels, this.height = 48});

  final List<double> levels;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WavePainter(
          levels: List.of(levels),
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.levels, required this.color});
  final List<double> levels;
  final Color color;

  static const bars = 40;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(2, size.width / bars * 0.55);
    final step = size.width / bars;
    final mid = size.height / 2;
    // Right-align the most recent samples.
    final offset = bars - levels.length;
    for (var i = 0; i < bars; i++) {
      final idx = i - offset;
      final level = idx >= 0 ? levels[idx] : 0.0;
      final h = math.max(3.0, level * size.height * 0.9) / 2;
      final x = step * i + step / 2;
      canvas.drawLine(Offset(x, mid - h), Offset(x, mid + h), paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.levels != levels || old.color != color;
}
