import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/session.dart';
import '../providers/session_provider.dart';
import 'analytics/widgets/analytics_detailed_stats.dart';
import 'analytics/widgets/analytics_milk_details.dart';
import 'analytics/widgets/analytics_random_photo.dart';
import 'analytics/widgets/analytics_sleep_details.dart';
import 'analytics/widgets/analytics_stat_cards.dart';
import 'analytics/widgets/analytics_vitamin_details.dart';

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
          AnalyticsStatCards(
            sessions: _sessions,
            startDate: _startDate,
            endDate: _endDate,
            onMilkTap: () => _showMilkDetails(context),
            onVitaminTap: () => _showVitaminDetails(context),
            onSleepTap: () => _showSleepDetails(context),
          ),
          if (_sessions.isNotEmpty) ...[
            const SizedBox(height: 16),
            AnalyticsDetailedStats(
              sessions: _sessions,
              startDate: _startDate,
              endDate: _endDate,
            ),
            const SizedBox(height: 16),
            AnalyticsRandomPhoto(sessions: _sessions),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Date Range',
                  style: Theme.of(context).textTheme.titleLarge,
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
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: ShapeDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20), // squircle effect
                    ),
                  ),
                  child: IconButton(
                    iconSize: 24, // default size
                    icon: const Icon(Icons.arrow_left),
                    onPressed: _decrementDateRange,
                    splashRadius: 28,
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        DateFormat('MMM dd, yyyy HH:mm').format(_startDate),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _isToday(_startDate) ? Colors.blue : null,
                          fontWeight: _isToday(_startDate) ? FontWeight.bold : null,
                          fontSize: 16,
                        ),
                      ),
                      const Text('-', textAlign: TextAlign.center),
                      Text(
                        DateFormat('MMM dd, yyyy HH:mm').format(_endDate),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _isToday(_endDate) ? Colors.blue : null,
                          fontWeight: _isToday(_endDate) ? FontWeight.bold : null,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: ShapeDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20), // squircle effect
                    ),
                  ),
                  child: IconButton(
                    iconSize: 24, // default size
                    icon: const Icon(Icons.arrow_right),
                    onPressed: _incrementDateRange,
                    splashRadius: 28,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showMilkDetails(BuildContext context) {
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
            return AnalyticsMilkDetails(sessions: _sessions);
          },
        );
      },
    );
  }

  void _showVitaminDetails(BuildContext context) {
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
            return AnalyticsVitaminDetails(sessions: _sessions);
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
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return AnalyticsSleepDetails(sessions: _sessions);
          },
        );
      },
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
}
