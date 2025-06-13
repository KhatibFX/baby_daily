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

class EditSessionScreen extends StatefulWidget {
  final Session originalSession;

  const EditSessionScreen({super.key, required this.originalSession});

  @override
  State<EditSessionScreen> createState() => _EditSessionScreenState();
}

class _EditSessionScreenState extends State<EditSessionScreen> {
  late Session _editingSession;
  late TextEditingController _peeRemarksController;
  late TextEditingController _milkIntakeController;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    // Create a copy of the original session for editing
    _editingSession = widget.originalSession.copyWith();
    _peeRemarksController = TextEditingController(text: _editingSession.peeRemarks);
    _milkIntakeController = TextEditingController(text: _editingSession.milkIntake.toString());
  }

  void _markAsChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  @override
  void dispose() {
    _peeRemarksController.dispose();
    _milkIntakeController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    return showDiscardChangesDialog(context: context);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
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
                if (discard && mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: _hasChanges
                  ? () async {
                      final provider = Provider.of<SessionProvider>(context, listen: false);
                      await provider.updateSession(_editingSession);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Changes saved successfully')),
                        );
                        Navigator.of(context).pop();
                      }
                    }
                  : null,
              child: Text(
                'Save',
                style: TextStyle(
                  color: _hasChanges ? Colors.white : Colors.white.withOpacity(0.5),
                ),
              ),
            ),
          ],
        ),
        body: Consumer<SessionProvider>(
          builder: (context, provider, child) => KeyboardAwareScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWakeUpTimeSection(context),
                _buildPeeSection(context),
                _buildPoopSection(context),
                _buildMilkSection(context),
                _buildVitaminSection(context),
                _buildPhotoSection(context, provider),
                SizedBox(height: 20),
                _buildSleepTimeSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWakeUpTimeSection(BuildContext context) {
    return WakeUpTimeCard(
      session: _editingSession,
      onSessionChanged: (updatedSession) {
        setState(() {
          _editingSession = updatedSession;
          _markAsChanged();
        });
      },
    );
  }

  Widget _buildPeeSection(BuildContext context) {
    return PeeSectionCard(
      session: _editingSession,
      onSessionChanged: (updatedSession) {
        setState(() {
          _editingSession = updatedSession;
          _markAsChanged();
        });
      },
      remarksController: _peeRemarksController,
    );
  }

  Widget _buildPoopSection(BuildContext context) {
    return PoopSectionCard(
      session: _editingSession,
      onSessionChanged: (updatedSession) {
        setState(() {
          _editingSession = updatedSession;
          _markAsChanged();
        });
      },
      isEditing: true,
    );
  }

  Widget _buildMilkSection(BuildContext context) {
    return MilkSectionCard(
      session: _editingSession,
      onSessionChanged: (updatedSession) {
        setState(() {
          _editingSession = updatedSession;
          _markAsChanged();
        });
      },
      intakeController: _milkIntakeController,
    );
  }

  Widget _buildVitaminSection(BuildContext context) {
    return VitaminSectionCard(
      session: _editingSession,
      onSessionChanged: (updatedSession) {
        setState(() {
          _editingSession = updatedSession;
          _markAsChanged();
        });
      },
    );
  }

  Widget _buildPhotoSection(BuildContext context, SessionProvider provider) {
    return SessionPhotoCard(
      session: _editingSession,
      onSessionChanged: (updatedSession) {
        setState(() {
          _editingSession = updatedSession;
          _markAsChanged();
        });
      },
      title: 'Session Photo',
      photoPrefix: 'session',
      photoPath: _editingSession.sessionPhotoPath,
      hasPhoto: _editingSession.hasSessionPhoto,
      updatePhotoInSession: (session, path, hasPhoto) => session.copyWith(
        sessionPhotoPath: path,
        hasSessionPhoto: hasPhoto,
      ),
      isEditing: true,
    );
  }

  Widget _buildSleepTimeSection(BuildContext context) {
    return SleepTimeCard(
      session: _editingSession,
      onSessionChanged: (updatedSession) {
        setState(() {
          _editingSession = updatedSession;
          _markAsChanged();
        });
      },
    );
  }
}
