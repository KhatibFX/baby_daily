import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';

import '../models/session.dart';
import '../providers/session_provider.dart';
import '../shared/widgets/photo_view.dart';
import 'edit_session_screen.dart';

class SessionHistoryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, sessionProvider, child) {
        final closedSessions = sessionProvider.sessions.where((s) => s.isClosed).toList();
        return Scaffold(
          body: closedSessions.isNotEmpty
              ? ListView.builder(
                  itemCount: closedSessions.length * 2 - 1,
                  // Double for separators, minus 1 for last item
                  itemBuilder: (context, index) {
                    // If index is even, it's a session card
                    if (index % 2 == 0) {
                      final sessionIndex = index ~/ 2;
                      final session = closedSessions[sessionIndex];
                      return _buildSessionCard(context, session, sessionProvider);
                    }
                    // If index is odd, it's a separator with sleep duration
                    else {
                      final newerSession = closedSessions[index ~/ 2]; // Index of the session above
                      final olderSession =
                          closedSessions[(index ~/ 2) + 1]; // Index of the session below
                      if (olderSession.sleepTime != null) {
                        final sleepDuration =
                            newerSession.wakeUpTime.difference(olderSession.sleepTime!);
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Row(
                            children: [
                              Container(
                                width: 2,
                                height: 40,
                                color: Theme.of(context).primaryColor.withOpacity(0.5),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.bedtime,
                                size: 16,
                                color: Theme.of(context).primaryColor.withOpacity(0.7),
                              ),
                              SizedBox(width: 4),
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
                      }
                      return SizedBox(height: 4); // Small gap if no sleep data
                    }
                  },
                )
              : Center(
                  child: Text(
                    'No closed sessions found',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
        );
      },
    );
  }

  Widget _buildSessionCard(BuildContext context, Session session, SessionProvider provider) {
    final sleepDuration = session.sleepTime?.difference(session.wakeUpTime);
    final timeFormat = DateFormat('HH:mm');

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
            Text('Wake up: ${timeFormat.format(session.wakeUpTime)}'),
            if (session.sleepTime != null) Text('Sleep: ${timeFormat.format(session.sleepTime!)}'),
            if (sleepDuration != null)
              Text('Duration: ${sleepDuration.inHours}h ${sleepDuration.inMinutes % 60}m'),
          ],
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pee entries section
                Text('Pee Events:', style: Theme.of(context).textTheme.titleSmall),
                ...session.peeEntries.map((entry) => Padding(
                      padding: EdgeInsets.only(left: 16, top: 4),
                      child: Row(
                        children: [
                          Text('${timeFormat.format(entry.time)} - ${entry.amount.name}'),
                          if (entry.remarks?.isNotEmpty == true) ...[
                            SizedBox(width: 8),
                            Text('(${entry.remarks!})',
                                style: TextStyle(fontStyle: FontStyle.italic)),
                          ],
                        ],
                      ),
                    )),
                SizedBox(height: 8),

                // Poop entries section
                Text('Poop Events:', style: Theme.of(context).textTheme.titleSmall),
                ...session.poopEntries.map((entry) => Padding(
                      padding: EdgeInsets.only(left: 16, top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('${timeFormat.format(entry.time)} - ${entry.amount.name}'),
                              SizedBox(width: 8),
                              Text('(${entry.consistency.name}, ${entry.color.name})'),
                            ],
                          ),
                          if (entry.hasPhoto && entry.photoPath != null)
                            Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: _buildPhotoSection(context, entry.photoPath, ''),
                            ),
                        ],
                      ),
                    )),
                SizedBox(height: 8),

                // Milk entries section
                Text('Milk Events:', style: Theme.of(context).textTheme.titleSmall),
                ...session.milkEntries.map((entry) => Padding(
                      padding: EdgeInsets.only(left: 16, top: 4),
                      child: Text('${timeFormat.format(entry.time)} - ${entry.amount}ml'),
                    )),
                SizedBox(height: 16),

                // Other session details
                _buildDetailRow('Vitamin AD', session.vitaminAD ? 'Yes' : 'No'),
                if (session.hasSessionPhoto)
                  _buildPhotoSection(context, session.sessionPhotoPath, ''),
                SizedBox(height: 16),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
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
                    ElevatedButton(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Delete Session'),
                            content: Text(
                                'Are you sure you want to delete this session? This action cannot be undone.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: Text('Delete'),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await provider.deleteSession(session);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Session deleted')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Delete Session'),
                    ),
                  ],
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

    return Consumer<SessionProvider>(
      builder: (context, provider, _) => FutureBuilder<String>(
        future: provider.photoDirectory,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final fullPath = path.join(snapshot.data!, photoPath);
          return PhotoView(
            photoPath: fullPath,
            title: title.isNotEmpty ? title : null,
          );
        },
      ),
    );
  }
}
