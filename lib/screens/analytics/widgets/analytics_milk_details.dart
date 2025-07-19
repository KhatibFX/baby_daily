import 'package:baby_daily/models/session.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnalyticsMilkDetails extends StatelessWidget {
  final List<Session> sessions;

  const AnalyticsMilkDetails({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    final sortedSessions = List<Session>.from(sessions)
      ..sort((a, b) => a.wakeUpTime.compareTo(b.wakeUpTime));
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Milk Intake Details', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: sortedSessions.length,
              itemBuilder: (context, index) {
                final session = sortedSessions[index];
                if (session.milkEntries.isEmpty) return const SizedBox.shrink();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DateFormat('MMM dd, yyyy').format(session.wakeUpTime),
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        ...session.milkEntries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                            child: Row(
                              children: [
                                Text(DateFormat('HH:mm').format(entry.time),
                                    style: Theme.of(context).textTheme.bodyMedium),
                                const SizedBox(width: 16),
                                Text('${entry.amount} ml',
                                    style: Theme.of(context).textTheme.bodyLarge),
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
