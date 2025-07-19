import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/session.dart';
import '../providers/session_provider.dart';
import '../shared/shared.dart';
import '../shared/widgets/milk_section_card.dart';
import '../shared/widgets/pee_section_card.dart';
import '../shared/widgets/poop_section_card.dart';
import '../shared/widgets/session_photo_card.dart';
import '../shared/widgets/time_section_cards.dart';
import '../shared/widgets/vitamin_section_card.dart';

class SessionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, sessionProvider, child) {
        final session = sessionProvider.currentSession;

        if (session == null) {
          return Center(
            child: Container(
              width: MediaQuery.of(context).size.shortestSide * 0.5,
              height: MediaQuery.of(context).size.shortestSide * 0.5,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4FC3F7), Color(0xFF7C4DFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C4DFF).withOpacity(0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => sessionProvider.createNewSession(),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_circle_outline, size: 40, color: Colors.white),
                        const SizedBox(height: 8),
                        const Text(
                          'Start New Session',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return GestureDetector(
          onTap: () {
            // Hide keyboard when tapping outside text fields
            FocusScope.of(context).unfocus();
          },
          child: KeyboardAwareScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWakeUpTimeSection(context, session, sessionProvider),
                _buildPeeSection(context, session, sessionProvider),
                _buildPoopSection(context, session, sessionProvider),
                _buildMilkSection(context, session, sessionProvider),
                _buildVitaminSection(context, session, sessionProvider),
                _buildPhotoSection(context, session, sessionProvider),
                SizedBox(height: 20),
                _buildSleepTimeSection(context, session, sessionProvider),
                SizedBox(height: 20),
                SessionActionsBar(
                  showCloseButton: !session.isClosed,
                  onClose: () => sessionProvider.closeCurrentSession(),
                  errorMessage: session.sleepTime == null
                      ? 'Please set a sleep time before closing the session'
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWakeUpTimeSection(
    BuildContext context,
    Session session,
    SessionProvider provider,
  ) {
    return WakeUpTimeCard(
      session: session,
      onSessionChanged: (updatedSession) async {
        await provider.updateCurrentSession(updatedSession);
      },
    );
  }

  Widget _buildSleepTimeSection(
    BuildContext context,
    Session session,
    SessionProvider provider,
  ) {
    return SleepTimeCard(
      session: session,
      onSessionChanged: (updatedSession) async {
        await provider.updateCurrentSession(updatedSession);
      },
    );
  }

  Widget _buildPeeSection(
    BuildContext context,
    Session session,
    SessionProvider provider,
  ) {
    return PeeSectionCard(
      session: session,
      onSessionChanged: (updatedSession) async {
        await provider.updateCurrentSession(updatedSession);
      },
    );
  }

  Widget _buildPoopSection(
    BuildContext context,
    Session session,
    SessionProvider provider,
  ) {
    return PoopSectionCard(
      session: session,
      onSessionChanged: (updatedSession) async {
        await provider.updateCurrentSession(updatedSession);
      },
    );
  }

  Widget _buildMilkSection(
    BuildContext context,
    Session session,
    SessionProvider provider,
  ) {
    return MilkSectionCard(
      session: session,
      onSessionChanged: (updatedSession) async {
        await provider.updateCurrentSession(updatedSession);
      },
    );
  }

  Widget _buildVitaminSection(
    BuildContext context,
    Session session,
    SessionProvider provider,
  ) {
    return VitaminSectionCard(
      session: session,
      onSessionChanged: (updatedSession) async {
        await provider.updateCurrentSession(updatedSession);
      },
    );
  }

  Widget _buildPhotoSection(
    BuildContext context,
    Session session,
    SessionProvider provider,
  ) {
    return SessionPhotoCard(
      session: session,
      onSessionChanged: (updatedSession) async {
        await provider.updateCurrentSession(updatedSession);
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
}
