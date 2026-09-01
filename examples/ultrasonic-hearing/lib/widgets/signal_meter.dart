import 'package:flutter/material.dart';

import '../utils/constants.dart';

class SignalMeter extends StatelessWidget {
  final double signalLevel;
  final double clarityScore;
  final bool isActive;

  const SignalMeter({
    super.key,
    required this.signalLevel,
    required this.clarityScore,
    required this.isActive,
  });

  Color get _signalColor {
    if (signalLevel > 0.8) return AppColors.danger;
    if (signalLevel > 0.5) return AppColors.warning;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.surface),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SIGNAL STRENGTH',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
              Text(
                '${(signalLevel * 100).toInt()}%',
                style: TextStyle(
                  color: _signalColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: signalLevel.clamp(0.0, 1.0),
            backgroundColor: AppColors.surface,
            color: _signalColor,
            minHeight: 8,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CLARITY',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
              Text(
                '${clarityScore.toInt()}%',
                style: TextStyle(
                  color: clarityScore > 60
                      ? AppColors.primary
                      : AppColors.warning,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (clarityScore / 100).clamp(0.0, 1.0),
            backgroundColor: AppColors.surface,
            color: clarityScore > 60 ? AppColors.primary : AppColors.warning,
            minHeight: 8,
          ),
        ],
      ),
    );
  }
}
