import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/session.dart';
import '../../providers/session_provider.dart';
import '../session_utils.dart';
import '../session_widgets.dart';

class PeeSectionCard extends StatelessWidget {
  final Session session;
  final Function(Session) onSessionChanged;
  final TextEditingController? remarksController;

  const PeeSectionCard({
    Key? key,
    required this.session,
    required this.onSessionChanged,
    this.remarksController,
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
              'Pee',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            Container(
              width: double.infinity,
              child: Wrap(
                spacing: 8.0,
                children: PeeAmount.values.map((amount) {
                  return ChoiceChip(
                    label: Text(amount.name),
                    selected: session.pee == amount,
                    onSelected: (selected) {
                      if (selected) {
                        final updatedSession = session.copyWith(pee: amount);
                        onSessionChanged(updatedSession);
                      }
                    },
                  );
                }).toList(),
              ),
            ),
            if (session.pee != PeeAmount.na) ...[
              SizedBox(height: 8),
              Consumer<SessionProvider>(
                builder: (context, provider, child) => TimePickerRow(
                  time: session.peeTime,
                  placeholder: 'Time not set',
                  icon: Icons.access_time,
                  firstDate: session.wakeUpTime,
                  lastDate: session.sleepTime ?? DateTime.now(),
                  onValidate: (time) => isValidActivityTime(context, time, session, provider),
                  onTimeSelected: (time) {
                    final updatedSession = session.copyWith(peeTime: time);
                    onSessionChanged(updatedSession);
                  },
                ),
              ),
              SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Remarks',
                  border: OutlineInputBorder(),
                ),
                controller: remarksController,
                onChanged: (value) {
                  final updatedSession = session.copyWith(peeRemarks: value);
                  onSessionChanged(updatedSession);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
