import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/session.dart';
import '../providers/session_provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'edit_session_screen.dart';

class SessionHistoryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, sessionProvider, child) {
        final closedSessions = sessionProvider.sessions.where((s) => s.isClosed).toList();
        return ListView.builder(
          itemCount: closedSessions.length,
          itemBuilder: (context, index) {
            final session = closedSessions[index];
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
    final sleepDuration = session.sleepTime?.difference(session.wakeUpTime);

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
                if (session.hasSessionPhoto)
                  _buildPhotoSection(context, session.sessionPhotoPath, ''),
                if (session.poopColor == PoopColor.abnormal && session.hasAbnormalPoopPhoto)
                  _buildPhotoSection(context, session.abnormalPoopPhotoPath, 'Abnormal Poop Photo'),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => EditSessionScreen(originalSession: session),
                      ),
                    );
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

  Widget _buildPhotoSection(
    BuildContext context,
    String? photoPath,
    String title,
  ) {
    if (photoPath == null) return SizedBox.shrink();
    
    return FutureBuilder<bool>(
      future: File(photoPath).exists(),
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          return Column(
            children: [
              SizedBox(height: 8),
              if (title.isNotEmpty)
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              Image.file(
                File(photoPath),
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
            ],
          );
        }
        return SizedBox.shrink();
      },
    );
  }
}
