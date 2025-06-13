import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/session.dart';
import '../../providers/session_provider.dart';
import '../session_utils.dart';
import '../session_widgets.dart';

class WakeUpTimeCard extends StatelessWidget {
  final Session session;
  final Function(Session) onSessionChanged;

  const WakeUpTimeCard({
    Key? key,
    required this.session,
    required this.onSessionChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wake Up Time',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            Consumer<SessionProvider>(
              builder: (context, provider, child) {
                final prevSession = provider.getPreviousSession(session);
                final firstDate = prevSession?.sleepTime ?? DateTime.now().subtract(Duration(days: 7));
                final lastDate = session.sleepTime ?? DateTime.now();

                return TimePickerRow(
                  time: session.wakeUpTime,
                  placeholder: 'Not set',
                  icon: Icons.access_time,
                  firstDate: firstDate,
                  lastDate: lastDate,
                  onValidate: (time) => isValidWakeUpTime(context, time, session, provider),
                  onTimeSelected: (time) {
                    final updatedSession = session.copyWith(wakeUpTime: time);
                    onSessionChanged(updatedSession);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class SleepTimeCard extends StatelessWidget {
  final Session session;
  final Function(Session) onSessionChanged;

  const SleepTimeCard({
    Key? key,
    required this.session,
    required this.onSessionChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sleep Time',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            Consumer<SessionProvider>(
              builder: (context, provider, child) {
                final nextSession = provider.getNextSession(session);
                final lastDate = nextSession?.wakeUpTime ?? DateTime.now();

                return TimePickerRow(
                  time: session.sleepTime,
                  placeholder: 'Not set',
                  icon: Icons.bedtime,
                  firstDate: session.wakeUpTime,
                  lastDate: lastDate,
                  onValidate: (time) => isValidSleepTime(context, time, session, provider),
                  onTimeSelected: (time) {
                    final updatedSession = session.copyWith(sleepTime: time);
                    onSessionChanged(updatedSession);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
