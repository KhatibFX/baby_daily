import 'package:baby_daily/models/session.dart';
import 'package:flutter/material.dart';

import 'analytics_stat_card.dart';

class AnalyticsStatCards extends StatelessWidget {
  final List<Session> sessions;
  final DateTime startDate;
  final DateTime endDate;
  final VoidCallback? onMilkTap;
  final VoidCallback? onVitaminTap;
  final VoidCallback? onSleepTap;

  const AnalyticsStatCards({
    super.key,
    required this.sessions,
    required this.startDate,
    required this.endDate,
    this.onMilkTap,
    this.onVitaminTap,
    this.onSleepTap,
  });

  @override
  Widget build(BuildContext context) {
    final totalMilk = sessions.fold<int>(
      0,
      (sum, session) =>
          sum + session.milkEntries.fold<int>(0, (milkSum, entry) => milkSum + (entry.amount ?? 0)),
    );
    var totalSleepDuration = Duration.zero;
    for (int i = 0; i < sessions.length - 1; i++) {
      final newerSession = sessions[i];
      final olderSession = sessions[i + 1];
      if (olderSession.sleepTime != null) {
        totalSleepDuration += newerSession.wakeUpTime.difference(olderSession.sleepTime!);
      }
    }
    final avgSessionsPerDay = sessions.length / (endDate.difference(startDate).inHours / 24);

    int totalPee = 0;
    int totalPoop = 0;
    int totalMilkFeeds = 0;
    int totalVitamins = 0;
    for (final session in sessions) {
      totalPee += session.peeEntries.length;
      totalPoop += session.poopEntries.length;
      totalMilkFeeds += session.milkEntries.length;
      totalVitamins += session.vitaminEntries.length;
    }
    String totalEvents =
        'Pee: $totalPee, Poop: $totalPoop, Milk: $totalMilkFeeds, Vitamins: $totalVitamins';

    return Column(
      children: [
        AnalyticsStatCard(
          title: 'Total Sessions',
          value: '${sessions.length} (${avgSessionsPerDay.toStringAsFixed(1)}/day)',
          icon: Icons.list,
        ),
        const SizedBox(height: 8),
        AnalyticsStatCard(
          title: 'Total Milk Intake',
          value:
              '$totalMilk ml (${(totalMilk / (sessions.isEmpty ? 1 : sessions.length)).toStringAsFixed(0)} ml/session)',
          icon: Icons.local_drink,
          onTap: onMilkTap,
        ),
        const SizedBox(height: 8),
        AnalyticsStatCard(
          title: 'Vitamins taken',
          value: sessions
              .fold<int>(
                0,
                (sum, session) => sum + session.vitaminEntries.length,
              )
              .toString(),
          icon: Icons.medication,
          onTap: onVitaminTap,
        ),
        const SizedBox(height: 8),
        AnalyticsStatCard(
          title: 'Total Sleep Time',
          value: '${totalSleepDuration.inHours}h ${totalSleepDuration.inMinutes % 60}m',
          icon: Icons.bedtime,
          onTap: onSleepTap,
        ),
        const SizedBox(height: 8),
        AnalyticsStatCard(
          title: 'Total Events',
          value: totalEvents,
          icon: Icons.event,
        ),
      ],
    );
  }
}
