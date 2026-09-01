import 'package:flutter/material.dart';

import '../utils/constants.dart';

class AudioVisualizer extends StatelessWidget {
  final List<double> waveformData;
  final bool isActive;

  const AudioVisualizer({
    super.key,
    required this.waveformData,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.surface),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        painter: WaveformPainter(
          waveformData: waveformData,
          isActive: isActive,
        ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final bool isActive;

  WaveformPainter({
    required this.waveformData,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final paint = Paint()
      ..color = AppColors.waveformColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final centerY = size.height / 2;
    final path = Path();

    for (var i = 0; i < waveformData.length; i++) {
      final x = (i / waveformData.length) * size.width;
      final amplitude = waveformData[i].clamp(-1.0, 1.0);
      final y = centerY + (amplitude * centerY);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(path, paint);

    final centerLinePaint = Paint()
      ..color = AppColors.textSecondary.withOpacity(0.3)
      ..strokeWidth = 0.5;

    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      centerLinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.waveformData != waveformData ||
        oldDelegate.isActive != isActive;
  }
}
