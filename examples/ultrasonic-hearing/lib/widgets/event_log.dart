import 'package:flutter/material.dart';

import '../utils/constants.dart';

class EventLog extends StatelessWidget {
  final List<String> events;

  const EventLog({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withOpacity(0.85),
        border: Border.all(color: AppColors.surface),
        borderRadius: BorderRadius.circular(4),
      ),
      child: events.isEmpty
          ? const Center(
              child: Text(
                'Awaiting audio events...',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            )
          : ListView.builder(
              itemCount: events.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    events[index],
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 9,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              },
            ),
    );
  }
}
