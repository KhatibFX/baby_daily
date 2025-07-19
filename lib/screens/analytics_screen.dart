import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';

import '../models/session.dart';
import '../providers/session_provider.dart';
import '../shared/widgets/photo_view.dart';

// Date range validation constants
final DateTime kAnalyticsFirstAllowedDate = DateTime(2020);
final DateTime kAnalyticsLastAllowedDate = DateTime(2030, 12, 31, 23, 59, 59);

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
    final now = DateTime.now();
    final today720AM = DateTime(now.year, now.month, now.day, 7, 20);

    _startDate =
        now.isAfter(today720AM) ? today720AM : today720AM.subtract(const Duration(days: 1));

    // End time is always 24 hours after start time
    _endDate = _startDate.add(const Duration(days: 1));
  }

  Future<void> _loadSessions() async {
    final provider = Provider.of<SessionProvider>(context, listen: false);
    final sessions = await provider.getClosedSessionsInRange(_startDate, _endDate);
    setState(() {
      _sessions = sessions;
    });
  }

  void _decrementDateRange() {
    setState(() {
      _startDate = _startDate.subtract(const Duration(days: 1));
      _endDate = _endDate.subtract(const Duration(days: 1));
    });
    _loadSessions();
  }

  void _incrementDateRange() {
    // Restrict increment so that _endDate does not go beyond the allowed lastDate
    final newStartDate = _startDate.add(const Duration(days: 1));
    final newEndDate = _endDate.add(const Duration(days: 1));
    if (newEndDate.isAfter(kAnalyticsLastAllowedDate)) {
      // Do not increment if it would exceed the allowed range
      return;
    }
    setState(() {
      _startDate = newStartDate;
      _endDate = newEndDate;
    });
    _loadSessions();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateRangePicker(context),
          const SizedBox(height: 16),
          _buildStatisticsCards(context),
          if (_sessions.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildDetailedStats(context),
            const SizedBox(height: 16),
            _buildRandomPhoto(),
          ],
        ],
      ),
    );
  }

  Widget _buildDateRangePicker(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date Range',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_left),
                  onPressed: _decrementDateRange,
                ),
                Expanded(
                  child: Text(
                    '${DateFormat('MMM dd, yyyy HH:mm').format(_startDate)} - '
                    '${DateFormat('MMM dd, yyyy HH:mm').format(_endDate)}',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_right),
                  onPressed: _incrementDateRange,
                ),
                TextButton(
                  onPressed: () async {
                    final DateTimeRange? dateRange = await showDateRangePicker(
                      context: context,
                      firstDate: kAnalyticsFirstAllowedDate, // Use constant
                      lastDate: kAnalyticsLastAllowedDate, // Use constant
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
                  child: const Text('Change'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  void _showMilkDetails(BuildContext context) {
    // Sort sessions from oldest to newest
    final sortedSessions = List<Session>.from(_sessions)
      ..sort((a, b) => a.wakeUpTime.compareTo(b.wakeUpTime));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Milk Intake Details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
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
                              Text(
                                DateFormat('MMM dd, yyyy').format(session.wakeUpTime),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              ...session.milkEntries.map((entry) {
                                return Padding(
                                  padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                                  child: Row(
                                    children: [
                                      Text(
                                        DateFormat('HH:mm').format(entry.time),
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        '${entry.amount} ml',
                                        style: Theme.of(context).textTheme.bodyLarge,
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ));
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSleepDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        List<Map<String, dynamic>> sleepPeriods = [];

        // Start from the oldest session
        if (_sessions.isNotEmpty) {
          // First, add all sessions except the newest one
          for (int i = _sessions.length - 1; i > 0; i--) {
            final currentSession = _sessions[i];
            final nextSession = _sessions[i - 1];

            if (currentSession.sleepTime != null) {
              final sessionDuration =
                  currentSession.sleepTime!.difference(currentSession.wakeUpTime);
              final sleepDuration = nextSession.wakeUpTime.difference(currentSession.sleepTime!);

              sleepPeriods.add({
                'sleepTime': currentSession.sleepTime!,
                'currentWakeUpTime': currentSession.wakeUpTime,
                'sessionDuration': sessionDuration,
                'sleepDuration': sleepDuration,
              });
            }
          }

          // Then add the newest session if it has a sleep time
          final newestSession = _sessions.first;
          if (newestSession.sleepTime != null) {
            final sessionDuration = newestSession.sleepTime!.difference(newestSession.wakeUpTime);

            sleepPeriods.add({
              'sleepTime': newestSession.sleepTime!,
              'currentWakeUpTime': newestSession.wakeUpTime,
              'sessionDuration': sessionDuration,
            });
          }
        }

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sleep Details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: sleepPeriods.length,
                      separatorBuilder: (context, index) {
                        // Don't show separator after the last item
                        if (index == sleepPeriods.length - 1) {
                          return const SizedBox(height: 4);
                        }

                        final period = sleepPeriods[index];
                        final sleepDuration = period['sleepDuration'] as Duration;

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
                              Icon(
                                Icons.bedtime,
                                size: 16,
                                color: Theme.of(context).primaryColor.withOpacity(0.7),
                              ),
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
                                Text(
                                  DateFormat('MMM dd, yyyy').format(wakeUpTime),
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text('Wake: '),
                                          Text(
                                            DateFormat('HH:mm').format(wakeUpTime),
                                            style: Theme.of(context).textTheme.bodyLarge,
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          const Text('Sleep: '),
                                          Text(
                                            DateFormat('HH:mm').format(sleepTime),
                                            style: Theme.of(context).textTheme.bodyLarge,
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          const Text('Session: '),
                                          Text(
                                            '${sessionDuration.inHours}h ${sessionDuration.inMinutes % 60}m',
                                            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                                  color: Theme.of(context).colorScheme.primary,
                                                ),
                                          ),
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
          },
        );
      },
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
        const SizedBox(height: 8),
        _buildStatCard(
          context,
          'Total Milk Intake',
          '$totalMilk ml (${(totalMilk / _sessions.length).toStringAsFixed(0)} ml/session)',
          Icons.local_drink,
          onTap: () => _showMilkDetails(context),
        ),
        const SizedBox(height: 8),
        _buildStatCard(
          context,
          'Total Sleep Time',
          '${totalSleepDuration.inHours}h ${totalSleepDuration.inMinutes % 60}m',
          Icons.bedtime,
          onTap: () => _showSleepDetails(context),
        ),
        const SizedBox(height: 8),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
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

    // Group events by hour
    final hourCounts = <int, int>{};

    // Collect all event times
    for (final session in _sessions) {
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

    // Sort hours by number of events
    final sortedHours = hourCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // For short date ranges (1 day or less), show only top 3 hours
    if (_endDate.difference(_startDate).inHours <= 24) {
      // Only include hours that have at least 2 events
      final topHours = sortedHours
          .where((e) => e.value >= 2)
          .take(3)
          .map((e) => '${e.key.toString().padLeft(2, '0')}:00')
          .join(', ');

      return topHours.isEmpty ? 'N/A' : topHours;
    }

    // For longer ranges, use the 70% threshold but limit to top 5 hours
    final maxEvents = sortedHours.first.value;
    final activeHours = sortedHours
        .where((e) => e.value > maxEvents * 0.7)
        .take(5)
        .map((e) => '${e.key.toString().padLeft(2, '0')}:00')
        .join(', ');

    return activeHours.isEmpty ? 'N/A' : activeHours;
  }

  Widget _buildRandomPhoto() {
    final sessionsWithPhotos =
        _sessions.where((s) => s.hasSessionPhoto && s.sessionPhotoPath != null).toList();
    if (sessionsWithPhotos.isEmpty) return const SizedBox.shrink();

    final random = Random();
    final randomSession = sessionsWithPhotos[random.nextInt(sessionsWithPhotos.length)];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Random Moment',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            FutureBuilder<String>(
              future: Provider.of<SessionProvider>(context).photoDirectory,
              builder: (context, pathSnapshot) {
                if (!pathSnapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final fullPath = path.join(
                  pathSnapshot.data!,
                  randomSession.sessionPhotoPath!,
                );

                return Column(
                  children: [
                    PhotoView(photoPath: fullPath),
                    const SizedBox(height: 8),
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
