import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/session.dart';
import '../../providers/session_provider.dart';
import '../session_utils.dart';
import '../session_widgets.dart';

class MilkSectionCard extends StatelessWidget {
  final Session session;
  final Function(Session) onSessionChanged;
  final TextEditingController? intakeController;

  const MilkSectionCard({
    Key? key,
    required this.session,
    required this.onSessionChanged,
    this.intakeController,
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
              'Milk Intake (ml)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            Consumer<SessionProvider>(
              builder: (context, provider, child) => TimePickerRow(
                time: session.milkTime,
                placeholder: 'Time not set',
                icon: Icons.access_time,
                firstDate: session.wakeUpTime,
                lastDate: session.sleepTime ?? DateTime.now(),
                onValidate: (time) => isValidActivityTime(context, time, session, provider),
                onTimeSelected: (time) {
                  final updatedSession = session.copyWith(milkTime: time);
                  onSessionChanged(updatedSession);
                },
              ),
            ),
            SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                labelText: 'Amount in milliliters',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              controller: intakeController,
              onChanged: (value) {
                final intake = int.tryParse(value) ?? 0;
                final updatedSession = session.copyWith(milkIntake: intake);
                onSessionChanged(updatedSession);
              },
            ),
          ],
        ),
      ),
    );
  }
}
