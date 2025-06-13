import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/session.dart';
import '../providers/session_provider.dart';
import '../shared/shared.dart';
import '../shared/widgets/poop_section_card.dart';
import '../shared/widgets/pee_section_card.dart';
import '../shared/widgets/milk_section_card.dart';
import '../shared/widgets/vitamin_section_card.dart';
import '../shared/widgets/session_photo_card.dart';
import '../shared/widgets/time_section_cards.dart';

class SessionScreen extends StatefulWidget {
  @override
  _SessionScreenState createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  late TextEditingController _peeRemarksController;
  late TextEditingController _milkIntakeController;

  @override
  void initState() {
    super.initState();
    _peeRemarksController = TextEditingController();
    _milkIntakeController = TextEditingController();
  }

  @override
  void dispose() {
    _peeRemarksController.dispose();
    _milkIntakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, sessionProvider, child) {
        final session = sessionProvider.currentSession;

        if (session == null) {
          return Center(
            child: ElevatedButton(
              onPressed: () => sessionProvider.createNewSession(),
              child: Text('Start New Session'),
            ),
          );
        }

        // Update controllers when session changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_peeRemarksController.text != session.peeRemarks) {
            _peeRemarksController.text = session.peeRemarks ?? '';
          }
          if (_milkIntakeController.text != session.milkIntake.toString()) {
            _milkIntakeController.text = session.milkIntake.toString();
          }
        });

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
      remarksController: _peeRemarksController,
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
      intakeController: _milkIntakeController,
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
