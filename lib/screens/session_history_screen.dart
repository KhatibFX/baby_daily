import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/session.dart';
import '../providers/session_provider.dart';
import 'package:intl/intl.dart';

class SessionHistoryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, sessionProvider, child) {
        return ListView.builder(
          itemCount: sessionProvider.sessions.length,
          itemBuilder: (context, index) {
            final session = sessionProvider.sessions[index];
            return _buildSessionCard(context, session, sessionProvider);
          },
        );
      },
    );
  }

  Widget _buildSessionCard(
    BuildContext context,
    Session session,
    SessionProvider provider,
  ) {
    final sleepDuration = session.sleepTime != null && session.wakeUpTime != null
        ? session.sleepTime!.difference(session.wakeUpTime)
        : null;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text(
          DateFormat('MMM dd, yyyy').format(session.wakeUpTime),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wake up: ${DateFormat('HH:mm').format(session.wakeUpTime)}',
            ),
            if (session.sleepTime != null)
              Text(
                'Sleep: ${DateFormat('HH:mm').format(session.sleepTime!)}',
              ),
            if (sleepDuration != null)
              Text(
                'Duration: ${sleepDuration.inHours}h ${sleepDuration.inMinutes % 60}m',
              ),
          ],
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Pee', session.pee.name),
                if (session.peeRemarks?.isNotEmpty == true)
                  _buildDetailRow('Pee Remarks', session.peeRemarks!),
                _buildDetailRow('Poop Amount', session.poopAmount.name),
                _buildDetailRow('Poop Consistency', session.poopConsistency.name),
                _buildDetailRow('Poop Color', session.poopColor.name),
                _buildDetailRow('Milk Intake', '${session.milkIntake} ml'),
                _buildDetailRow('Vitamin AD', session.vitaminAD ? 'Yes' : 'No'),
                if (session.sessionPhotoPath != null)
                  Image.asset(session.sessionPhotoPath!),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Implement session editing
                  },
                  child: Text('Edit Session'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }
}
