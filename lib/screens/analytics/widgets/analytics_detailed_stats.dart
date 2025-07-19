import 'package:baby_daily/models/session.dart';
import 'package:flutter/material.dart';

class AnalyticsDetailedStats extends StatelessWidget {
  final List<Session> sessions;
  final DateTime startDate;
  final DateTime endDate;

  const AnalyticsDetailedStats({
    super.key,
    required this.sessions,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detailed Statistics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildDetailedStatRow('Events per Session', _getAvgEventsPerSession()),
            _buildDetailedStatRow('Average Sleep Between Sessions', _getAvgSleepBetweenSessions()),
            if (sessions.isNotEmpty) ...[
              _buildDetailedStatRow('Average Milk per Feed', _getAvgMilkPerFeed()),
              _buildDetailedStatRow('Most Active Times', _getMostActiveTimes()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(
            width: 10,
          ),
          Expanded(
              child: Text(
            value,
            textAlign: TextAlign.start,
          )),
        ],
      ),
    );
  }

  String _getAvgEventsPerSession() {
    if (sessions.isEmpty) return 'N/A';
    final avgPee = sessions.fold<int>(0, (sum, s) => sum + s.peeEntries.length) / sessions.length;
    final avgPoop = sessions.fold<int>(0, (sum, s) => sum + s.poopEntries.length) / sessions.length;
    final avgMilk = sessions.fold<int>(0, (sum, s) => sum + s.milkEntries.length) / sessions.length;
    return 'Pee: 	${avgPee.toStringAsFixed(1)}, Poop: ${avgPoop.toStringAsFixed(1)}, Milk: ${avgMilk.toStringAsFixed(1)}';
  }

  String _getAvgSleepBetweenSessions() {
    if (sessions.length < 2) return 'N/A';
    var totalDuration = Duration.zero;
    var count = 0;
    final sortedSessions = List<Session>.from(sessions)
      ..sort((a, b) => b.wakeUpTime.compareTo(a.wakeUpTime));
    for (int i = 0; i < sortedSessions.length - 1; i++) {
      final newerSession = sortedSessions[i];
      final olderSession = sortedSessions[i + 1];
      if (olderSession.sleepTime != null) {
        final duration = newerSession.wakeUpTime.difference(olderSession.sleepTime!);
        if (duration.inHours >= 0 && duration.inHours <= 24) {
          totalDuration += duration;
          count++;
        }
      }
    }
    if (count == 0) return 'N/A';
    final avgMinutes = totalDuration.inMinutes ~/ count;
    return '${avgMinutes ~/ 60}h ${avgMinutes % 60}m';
  }

  String _getAvgMilkPerFeed() {
    int totalFeeds = 0;
    int totalMilk = 0;
    for (final session in sessions) {
      totalFeeds += session.milkEntries.length;
      totalMilk += session.milkEntries.fold<int>(0, (sum, entry) => sum + entry.amount);
    }
    if (totalFeeds == 0) return 'N/A';
    return '${(totalMilk / totalFeeds).toStringAsFixed(0)} ml';
  }

  String _getMostActiveTimes() {
    if (sessions.isEmpty) return 'N/A';
    final hourCounts = <int, int>{};
    for (final session in sessions) {
      for (final entry in [
        ...session.peeEntries.map((e) => e.time),
        ...session.poopEntries.map((e) => e.time),
        ...session.milkEntries.map((e) => e.time),
      ]) {
        final hour = entry.hour;
        hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
      }
    }
    if (hourCounts.isEmpty) return 'N/A';
    final sortedHours = hourCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (endDate.difference(startDate).inHours <= 24) {
      final topHours = sortedHours
          .where((e) => e.value >= 2)
          .take(3)
          .map((e) => '${e.key.toString().padLeft(2, '0')}:00')
          .join(', ');
      return topHours.isEmpty ? 'N/A' : topHours;
    }
    final maxEvents = sortedHours.first.value;
    final activeHours = sortedHours
        .where((e) => e.value > maxEvents * 0.7)
        .take(5)
        .map((e) => '${e.key.toString().padLeft(2, '0')}:00')
        .join(', ');
    return activeHours.isEmpty ? 'N/A' : activeHours;
  }
}
