import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/session.dart';
import '../providers/edit_session_provider.dart';
import '../providers/session_provider.dart';
import '../shared/shared.dart';
import '../shared/widgets/milk_section_card.dart';
import '../shared/widgets/pee_section_card.dart';
import '../shared/widgets/poop_section_card.dart';
import '../shared/widgets/session_photo_card.dart';
import '../shared/widgets/time_section_cards.dart';
import '../shared/widgets/vitamin_section_card.dart';

class EditSessionScreen extends StatelessWidget {
  final Session originalSession;

  const EditSessionScreen({super.key, required this.originalSession});

  @override
  Widget build(BuildContext context) {
    // Initialize editing session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EditSessionProvider>().startEditing(originalSession);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Session'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          TextButton(
            onPressed: () async {
              final discard = await showDiscardChangesDialog(
                context: context,
                message: 'Do you want to discard all changes?',
              );
              if (discard && context.mounted) {
                context.read<EditSessionProvider>().resetSession();
                Navigator.of(context).pop();
              }
            },
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white),
            ),
          ),
          Consumer<EditSessionProvider>(
            builder: (context, editProvider, _) {
              final editingSession = editProvider.editingSession;
              final hasChanges = editingSession != null && editingSession != originalSession;

              return TextButton(
                onPressed: hasChanges
                    ? () async {
                        final sessionProvider = context.read<SessionProvider>();
                        
                        // Update session and all entry types
                        await Future.wait([
                          sessionProvider.updateSession(editingSession!),
                          sessionProvider.updateSessionWithPeeEntries(editingSession!),
                          sessionProvider.updateSessionWithPoopEntries(editingSession!),
                          sessionProvider.updateSessionWithMilkEntries(editingSession!),
                        ]);

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Changes saved successfully')),
                          );
                          editProvider.resetSession();
                          Navigator.of(context).pop();
                        }
                      }
                    : null,
                child: Text(
                  'Save',
                  style: TextStyle(
                    color: hasChanges ? Colors.white : Colors.white.withOpacity(0.5),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<EditSessionProvider>(
        builder: (context, editProvider, child) {
          final editingSession = editProvider.editingSession;
          if (editingSession == null) return Container();

          return GestureDetector(
            onTap: () {
              // Hide keyboard when tapping outside text fields
              FocusScope.of(context).unfocus();
            },
            child: KeyboardAwareScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWakeUpTimeSection(context, editProvider, editingSession),
                  _buildPeeSection(context, editProvider, editingSession),
                  _buildPoopSection(context, editProvider, editingSession),
                  _buildMilkSection(context, editProvider, editingSession),
                  _buildVitaminSection(context, editProvider, editingSession),
                  _buildPhotoSection(context, editProvider, editingSession),
                  SizedBox(height: 20),
                  _buildSleepTimeSection(context, editProvider, editingSession),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWakeUpTimeSection(
      BuildContext context, EditSessionProvider provider, Session session) {
    return WakeUpTimeCard(
      session: session,
      onSessionChanged: (updatedSession) {
        provider.updateSession(updatedSession);
      },
    );
  }

  Widget _buildPeeSection(BuildContext context, EditSessionProvider provider, Session session) {
    return PeeSectionCard(
      session: session,
      onSessionChanged: (updatedSession) {
        provider.updateSession(updatedSession);
      },
    );
  }

  Widget _buildPoopSection(BuildContext context, EditSessionProvider provider, Session session) {
    return PoopSectionCard(
      session: session,
      onSessionChanged: (updatedSession) {
        provider.updateSession(updatedSession);
      },
    );
  }

  Widget _buildMilkSection(BuildContext context, EditSessionProvider provider, Session session) {
    return MilkSectionCard(
      session: session,
      onSessionChanged: (updatedSession) {
        provider.updateSession(updatedSession);
      },
    );
  }

  Widget _buildVitaminSection(BuildContext context, EditSessionProvider provider, Session session) {
    return VitaminSectionCard(
      session: session,
      onSessionChanged: (updatedSession) {
        provider.updateSession(updatedSession);
      },
    );
  }

  Widget _buildPhotoSection(BuildContext context, EditSessionProvider provider, Session session) {
    return SessionPhotoCard(
      session: session,
      onSessionChanged: (updatedSession) {
        provider.updateSession(updatedSession);
      },
      title: 'Session Photo',
      photoPrefix: 'session',
      photoPath: session.sessionPhotoPath,
      hasPhoto: session.hasSessionPhoto,
      updatePhotoInSession: (session, path, hasPhoto) => session.copyWith(
        sessionPhotoPath: path,
        hasSessionPhoto: hasPhoto,
      ),
    );
  }

  Widget _buildSleepTimeSection(
      BuildContext context, EditSessionProvider provider, Session session) {
    return SleepTimeCard(
      session: session,
      onSessionChanged: (updatedSession) {
        provider.updateSession(updatedSession);
      },
    );
  }
}
