import 'dart:math';

import 'package:baby_daily/models/session.dart';
import 'package:baby_daily/providers/session_provider.dart';
import 'package:baby_daily/shared/widgets/photo_view.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';

class AnalyticsRandomPhoto extends StatelessWidget {
  final List<Session> sessions;

  const AnalyticsRandomPhoto({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    final sessionsWithPhotos =
        sessions.where((s) => s.hasSessionPhoto && s.sessionPhotoPath != null).toList();
    if (sessionsWithPhotos.isEmpty) return const SizedBox.shrink();
    final random = Random();
    final randomSession = sessionsWithPhotos[random.nextInt(sessionsWithPhotos.length)];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Random Moment', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            FutureBuilder<String>(
              future: Provider.of<SessionProvider>(context).photoDirectory,
              builder: (context, pathSnapshot) {
                if (!pathSnapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                final fullPath = path.join(pathSnapshot.data!, randomSession.sessionPhotoPath!);
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
