import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';

import '../models/session.dart';
import '../providers/session_provider.dart';
import '../shared/widgets/photo_view.dart';

class AnalyticsScreen extends StatefulWidget {
  @override
  _AnalyticsScreenState createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  List<Session> _sessions = [];

  @override
  void initState() {
    super.initState();
    _initializeDates();
    _loadSessions();
  }

  void _initializeDates() {
    // Calculate the last 7:20 AM that occurred
    _startDate = DateTime.now().hour >= 7 && DateTime.now().minute >= 20
        ? DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
            7,
            20,
          )
        : DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day - 1,
            7,
            20,
          );

    // End time is always 24 hours after start time
    _endDate = _startDate.add(Duration(days: 1));
  }

  Future<void> _loadSessions() async {
    final provider = Provider.of<SessionProvider>(context, listen: false);
    final sessions = await provider.getClosedSessionsInRange(_startDate, _endDate);
    setState(() {
      _sessions = sessions;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateRangePicker(context),
          SizedBox(height: 16),
          _buildStatisticsCards(context),
          if (_sessions.isNotEmpty) ...[
            SizedBox(height: 16),
            _buildDetailedStats(context),
            SizedBox(height: 16),
            _buildRandomPhoto(),
          ],
        ],
      ),
    );
  }

  Widget _buildDateRangePicker(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date Range',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${DateFormat('MMM dd, yyyy HH:mm').format(_startDate)} - '
                    '${DateFormat('MMM dd, yyyy HH:mm').format(_endDate)}',
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final DateTimeRange? dateRange = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020), // Allow selecting dates from 2020
                      lastDate: DateTime(2030), // Allow selecting dates until 2030
                      initialDateRange: DateTimeRange(
                        start: _startDate,
                        end: _endDate,
                      ),
                    );

                    if (dateRange != null) {
                      final TimeOfDay? startTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_startDate),
                      );

                      if (startTime != null) {
                        final TimeOfDay? endTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(_endDate),
                        );

                        if (endTime != null) {
                          setState(() {
                            _startDate = DateTime(
                              dateRange.start.year,
                              dateRange.start.month,
                              dateRange.start.day,
                              startTime.hour,
                              startTime.minute,
                            );
                            _endDate = DateTime(
                              dateRange.end.year,
                              dateRange.end.month,
                              dateRange.end.day,
                              endTime.hour,
                              endTime.minute,
                            );
                          });
                          _loadSessions();
                        }
                      }
                    }
                  },
                  child: Text('Change'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCards(BuildContext context) {
    // Calculate total milk from all milk entries
    final totalMilk = _sessions.fold<int>(
      0,
      (sum, session) =>
          sum +
          session.milkEntries.fold<int>(
            0,
            (milkSum, entry) => milkSum + entry.amount,
          ),
    );

    var totalSleepDuration = Duration.zero;
    // Calculate total sleep duration by looking at consecutive sessions
    for (int i = 0; i < _sessions.length - 1; i++) {
      final newerSession = _sessions[i];
      final olderSession = _sessions[i + 1];
      if (olderSession.sleepTime != null) {
        totalSleepDuration += newerSession.wakeUpTime.difference(olderSession.sleepTime!);
      }
    }

    // Calculate averages
    final avgSessionsPerDay = _sessions.length / (_endDate.difference(_startDate).inHours / 24);

    return Column(
      children: [
        _buildStatCard(
          context,
          'Total Sessions',
          '${_sessions.length} (${avgSessionsPerDay.toStringAsFixed(1)}/day)',
          Icons.list,
        ),
        SizedBox(height: 8),
        _buildStatCard(
          context,
          'Total Milk Intake',
          '$totalMilk ml (${(totalMilk / _sessions.length).toStringAsFixed(0)} ml/session)',
          Icons.local_drink,
        ),
        SizedBox(height: 8),
        _buildStatCard(
          context,
          'Total Sleep Time',
          '${totalSleepDuration.inHours}h ${totalSleepDuration.inMinutes % 60}m',
          Icons.bedtime,
        ),
        SizedBox(height: 8),
        _buildStatCard(
          context,
          'Total Events',
          _getTotalEventsString(),
          Icons.event,
        ),
      ],
    );
  }

  String _getTotalEventsString() {
    int totalPee = 0;
    int totalPoop = 0;
    int totalMilk = 0;

    for (final session in _sessions) {
      totalPee += session.peeEntries.length;
      totalPoop += session.poopEntries.length;
      totalMilk += session.milkEntries.length;
    }

    return 'Pee: $totalPee, Poop: $totalPoop, Milk: $totalMilk';
  }

  Widget _buildDetailedStats(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detailed Statistics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 16),
            _buildDetailedStatRow('Events per Session', _getAvgEventsPerSession()),
            _buildDetailedStatRow('Average Sleep Between Sessions', _getAvgSleepBetweenSessions()),
            if (_sessions.isNotEmpty) ...[
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
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  String _getAvgEventsPerSession() {
    if (_sessions.isEmpty) return 'N/A';

    final avgPee = _sessions.fold<int>(0, (sum, s) => sum + s.peeEntries.length) / _sessions.length;
    final avgPoop =
        _sessions.fold<int>(0, (sum, s) => sum + s.poopEntries.length) / _sessions.length;
    final avgMilk =
        _sessions.fold<int>(0, (sum, s) => sum + s.milkEntries.length) / _sessions.length;

    return 'Pee: ${avgPee.toStringAsFixed(1)}, '
        'Poop: ${avgPoop.toStringAsFixed(1)}, '
        'Milk: ${avgMilk.toStringAsFixed(1)}';
  }

  String _getAvgSleepBetweenSessions() {
    if (_sessions.length < 2) return 'N/A';

    var totalDuration = Duration.zero;
    var count = 0;

    // Sort sessions by wake up time to ensure correct order
    final sortedSessions = List<Session>.from(_sessions)
      ..sort((a, b) => b.wakeUpTime.compareTo(a.wakeUpTime)); // Newest first

    for (int i = 0; i < sortedSessions.length - 1; i++) {
      final newerSession = sortedSessions[i];
      final olderSession = sortedSessions[i + 1];

      // Only calculate if we have both times
      if (olderSession.sleepTime != null) {
        final duration = newerSession.wakeUpTime.difference(olderSession.sleepTime!);
        // Only count reasonable sleep durations (between 0 and 24 hours)
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

    for (final session in _sessions) {
      totalFeeds += session.milkEntries.length;
      totalMilk += session.milkEntries.fold<int>(0, (sum, entry) => sum + entry.amount);
    }

    if (totalFeeds == 0) return 'N/A';
    return '${(totalMilk / totalFeeds).toStringAsFixed(0)} ml';
  }

  String _getMostActiveTimes() {
    if (_sessions.isEmpty) return 'N/A';

    final hours = List<int>.filled(24, 0);

    for (final session in _sessions) {
      for (final entry in [
        ...session.peeEntries.map((e) => e.time),
        ...session.poopEntries.map((e) => e.time),
        ...session.milkEntries.map((e) => e.time),
      ]) {
        hours[entry.hour]++;
      }
    }

    final maxEvents = hours.reduce(max);
    final activeHours = hours
        .asMap()
        .entries
        .where((e) => e.value > maxEvents * 0.7) // Get hours with >70% of max activity
        .map((e) => '${e.key.toString().padLeft(2, '0')}:00')
        .join(', ');

    return activeHours;
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 32),
            SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRandomPhoto() {
    final sessionsWithPhotos =
        _sessions.where((s) => s.hasSessionPhoto && s.sessionPhotoPath != null).toList();
    if (sessionsWithPhotos.isEmpty) return SizedBox.shrink();

    final random = Random();
    final randomSession = sessionsWithPhotos[random.nextInt(sessionsWithPhotos.length)];

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Random Moment',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            FutureBuilder<String>(
              future: Provider.of<SessionProvider>(context).photoDirectory,
              builder: (context, pathSnapshot) {
                if (!pathSnapshot.hasData) {
                  return CircularProgressIndicator();
                }

                final fullPath = path.join(
                  pathSnapshot.data!,
                  randomSession.sessionPhotoPath!,
                );

                return Column(
                  children: [
                    PhotoView(photoPath: fullPath),
                    SizedBox(height: 8),
                    Text(
                      DateFormat('MMM dd, yyyy HH:mm').format(randomSession.wakeUpTime),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
