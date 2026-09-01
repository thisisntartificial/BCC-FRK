import 'package:flutter/material.dart';

import '../utils/constants.dart';

class FrequencyAnalyzer extends StatelessWidget {
  final Map<String, double> frequencyBands;
  final double dominantFrequency;

  const FrequencyAnalyzer({
    super.key,
    required this.frequencyBands,
    required this.dominantFrequency,
  });

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'FREQUENCY ANALYSIS',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
              Text(
                '${dominantFrequency.toStringAsFixed(0)} Hz',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: frequencyBands.entries.map((entry) {
              final isActive = entry.value > 0;
              return Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 30,
                      height: 60,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary.withOpacity(0.3)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color:
                              isActive ? AppColors.primary : AppColors.surface,
                        ),
                      ),
                      child: isActive
                          ? Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                height: 60 * entry.value,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.vertical(
                                    bottom: Radius.circular(3),
                                  ),
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.key,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isActive
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontSize: 9,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
