import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/session.dart';
import '../providers/session_provider.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:io';

class AnalyticsScreen extends StatefulWidget {
  @override
  _AnalyticsScreenState createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  DateTime _startDate = DateTime.now().subtract(Duration(hours: 24));
  DateTime _endDate = DateTime.now();
  List<Session> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
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
                      firstDate: DateTime.now().subtract(Duration(days: 365)),
                      lastDate: DateTime.now(),
                      initialDateRange: DateTimeRange(
                        start: _startDate,
                        end: _endDate,
                      ),
                    );
                    
                    if (dateRange != null) {
                      // Get start time
                      final TimeOfDay? startTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_startDate),
                      );
                      
                      if (startTime != null) {
                        // Get end time
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
    final totalMilk = _sessions.fold<int>(
      0,
      (sum, session) => sum + session.milkIntake,
    );

    final totalSleepDuration = _sessions.fold<Duration>(
      Duration.zero,
      (sum, session) {
        if (session.sleepTime != null) {
          return sum + session.sleepTime!.difference(session.wakeUpTime);
        }
        return sum;
      },
    );

    return Column(
      children: [
        _buildStatCard(
          context,
          'Total Sessions',
          _sessions.length.toString(),
          Icons.list,
        ),
        SizedBox(height: 8),
        _buildStatCard(
          context,
          'Total Milk Intake',
          '$totalMilk ml',
          Icons.local_drink,
        ),
        SizedBox(height: 8),
        _buildStatCard(
          context,
          'Total Sleep Time',
          '${totalSleepDuration.inHours}h ${totalSleepDuration.inMinutes % 60}m',
          Icons.bedtime,
        ),
      ],
    );
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
            FutureBuilder<bool>(
              future: File(randomSession.sessionPhotoPath!).exists(),
              builder: (context, snapshot) {
                if (snapshot.data == true) {
                  return Column(
                    children: [
                      Image.file(
                        File(randomSession.sessionPhotoPath!),
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            width: double.infinity,
                            color: Colors.grey[300],
                            child: Center(child: Text('Failed to load image')),
                          );
                        },
                      ),
                      SizedBox(height: 8),
                      Text(
                        DateFormat('MMM dd, yyyy HH:mm').format(randomSession.wakeUpTime),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }
}
