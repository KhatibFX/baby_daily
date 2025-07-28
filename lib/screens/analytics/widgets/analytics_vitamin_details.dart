import 'package:baby_daily/models/enums/vitamin_enums.dart';
import 'package:baby_daily/models/session.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnalyticsVitaminDetails extends StatelessWidget {
  final List<Session> sessions;

  const AnalyticsVitaminDetails({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    final sortedSessions = List<Session>.from(sessions)
      ..sort((a, b) => a.wakeUpTime.compareTo(b.wakeUpTime));
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vitamin Intake Details', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: sortedSessions.length,
              itemBuilder: (context, index) {
                final session = sortedSessions[index];
                if (session.vitaminEntries.isEmpty) return const SizedBox.shrink();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DateFormat('MMM dd, yyyy').format(session.wakeUpTime),
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        ...session.vitaminEntries.map((entry) {
                          if (entry.type == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.medication,
                                  size: 16,
                                  color: entry.type == VitaminType.ad
                                      ? Colors.orange
                                      : Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(DateFormat('HH:mm').format(entry.time),
                                    style: Theme.of(context).textTheme.bodyMedium),
                                const SizedBox(width: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: entry.type == VitaminType.ad
                                        ? Colors.orange.withOpacity(0.2)
                                        : Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(entry.type!.label,
                                      style: Theme.of(context).textTheme.bodyLarge),
                                ),
                                SizedBox(
                                  width: 10,
                                ),
                                if (entry.notes?.isNotEmpty == true)
                                  Expanded(
                                    child: Text(
                                      entry.notes!,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            fontStyle: FontStyle.italic,
                                            color: Colors.grey[600],
                                          ),
                                      textAlign: TextAlign.start,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
