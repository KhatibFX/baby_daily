import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';

import '../../models/session.dart';
import '../../providers/session_provider.dart';

class SessionPhotoCard extends StatelessWidget {
  final Session session;
  final Function(Session) onSessionChanged;
  final bool isEditing;
  final String title;
  final String photoPrefix;
  final String? photoPath;
  final bool hasPhoto;
  final Function(Session, String?, bool) updatePhotoInSession;

  const SessionPhotoCard({
    Key? key,
    required this.session,
    required this.onSessionChanged,
    required this.title,
    required this.photoPrefix,
    required this.photoPath,
    required this.hasPhoto,
    required this.updatePhotoInSession,
    this.isEditing = false,
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
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            if (hasPhoto && photoPath != null)
              _buildPhotoDisplay(context)
            else
              _buildPhotoButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: () => _handlePhotoCapture(context, ImageSource.camera),
          icon: Icon(Icons.camera_alt),
          label: Text('Camera'),
        ),
        ElevatedButton.icon(
          onPressed: () => _handlePhotoCapture(context, ImageSource.gallery),
          icon: Icon(Icons.photo_library),
          label: Text('Gallery'),
        ),
      ],
    );
  }

  Future<void> _handlePhotoCapture(BuildContext context, ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    if (image != null) {
      final provider = Provider.of<SessionProvider>(context, listen: false);
      if (isEditing) {
        // In edit mode, just save the new photo without persisting to DB
        final String? newPhotoPath = await provider.savePhotoOnly(image, photoPrefix);
        if (newPhotoPath != null) {
          // Update through EditSessionProvider to maintain edit mode state
          final updatedSession = updatePhotoInSession(session, newPhotoPath, true);
          onSessionChanged(updatedSession);
        }
      } else {
        if (photoPrefix == 'session') {
          await provider.saveSessionPhoto(session, image);
        } else if (photoPrefix == 'poop') {
          // First save the photo and get its path
          final String? newPhotoPath = await provider.savePhotoOnly(image, photoPrefix);
          if (newPhotoPath != null) {
            // Then update the session with the new photo path
            final updatedSession = updatePhotoInSession(session, newPhotoPath, true);
            // For open sessions, persist through provider
            if (!session.isClosed) {
              await provider.updateSessionWithPoopEntries(updatedSession);
            } else {
              onSessionChanged(updatedSession);
            }
          }
        }
      }
    }
  }

  Widget _buildPhotoDisplay(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, provider, child) => FutureBuilder<String>(
        future: provider.photoDirectory,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final fullPath = path.join(
            snapshot.data!,
            photoPath!,
          );

          return Column(
            children: [
              Image.file(
                File(fullPath),
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
              ElevatedButton.icon(
                onPressed: () => _handlePhotoRemoval(context),
                icon: Icon(Icons.delete),
                label: Text('Remove Photo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handlePhotoRemoval(BuildContext context) async {
    if (photoPath == null) return;

    final provider = Provider.of<SessionProvider>(context, listen: false);
    if (isEditing) {
      // In edit mode, just update the session state
      final updatedSession = updatePhotoInSession(session, null, false);
      onSessionChanged(updatedSession);
    } else {
      if (photoPrefix == 'session') {
        await provider.removeSessionPhoto(session);
      } else if (photoPrefix == 'poop') {
        await provider.deletePhotoOnly(photoPath!);
        final updatedSession = updatePhotoInSession(session, null, false);
        if (!session.isClosed) {
          await provider.updateSessionWithPoopEntries(updatedSession);
        } else {
          onSessionChanged(updatedSession);
        }
      }
    }
  }
}
