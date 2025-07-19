import 'package:baby_daily/models/session.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnalyticsSleepDetails extends StatelessWidget {
  final List<Session> sessions;

  const AnalyticsSleepDetails({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> sleepPeriods = [];
    if (sessions.isNotEmpty) {
      for (int i = sessions.length - 1; i > 0; i--) {
        final currentSession = sessions[i];
        final nextSession = sessions[i - 1];
        if (currentSession.sleepTime != null) {
          final sessionDuration = currentSession.sleepTime!.difference(currentSession.wakeUpTime);
          final sleepDuration = nextSession.wakeUpTime.difference(currentSession.sleepTime!);
          sleepPeriods.add({
            'sleepTime': currentSession.sleepTime!,
            'currentWakeUpTime': currentSession.wakeUpTime,
            'sessionDuration': sessionDuration,
            'sleepDuration': sleepDuration,
          });
        }
      }
      final newestSession = sessions.first;
      if (newestSession.sleepTime != null) {
        final sessionDuration = newestSession.sleepTime!.difference(newestSession.wakeUpTime);
        sleepPeriods.add({
          'sleepTime': newestSession.sleepTime!,
          'currentWakeUpTime': newestSession.wakeUpTime,
          'sessionDuration': sessionDuration,
        });
      }
    }
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sleep Details', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: sleepPeriods.length,
              separatorBuilder: (context, index) {
                if (index == sleepPeriods.length - 1) return const SizedBox(height: 4);
                final period = sleepPeriods[index];
                final sleepDuration = period['sleepDuration'] as Duration?;
                if (sleepDuration == null) return const SizedBox(height: 4);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 2,
                        height: 40,
                        color: Theme.of(context).primaryColor.withOpacity(0.5),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.bedtime,
                          size: 16, color: Theme.of(context).primaryColor.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text(
                        '${sleepDuration.inHours}h ${sleepDuration.inMinutes % 60}m of sleep',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                );
              },
              itemBuilder: (context, index) {
                final period = sleepPeriods[index];
                final wakeUpTime = period['currentWakeUpTime'] as DateTime;
                final sleepTime = period['sleepTime'] as DateTime;
                final sessionDuration = period['sessionDuration'] as Duration;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DateFormat('MMM dd, yyyy').format(wakeUpTime),
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('Wake: '),
                                  Text(DateFormat('HH:mm').format(wakeUpTime),
                                      style: Theme.of(context).textTheme.bodyLarge)
                                ],
                              ),
                              Row(
                                children: [
                                  const Text('Sleep: '),
                                  Text(DateFormat('HH:mm').format(sleepTime),
                                      style: Theme.of(context).textTheme.bodyLarge)
                                ],
                              ),
                              Row(
                                children: [
                                  const Text('Session: '),
                                  Text(
                                      '${sessionDuration.inHours}h ${sessionDuration.inMinutes % 60}m',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge!
                                          .copyWith(color: Theme.of(context).colorScheme.primary))
                                ],
                              ),
                            ],
                          ),
                        ),
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
