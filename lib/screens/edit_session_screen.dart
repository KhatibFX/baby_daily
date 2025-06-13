import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;

import '../models/session.dart';
import '../providers/session_provider.dart';
import '../shared/session_utils.dart';
import '../shared/session_widgets.dart';
import '../shared/shared.dart';
import '../shared/widgets/poop_section_card.dart';

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
              onPressed: _hasChanges ? () async {
                final provider = Provider.of<SessionProvider>(context, listen: false);
                await provider.updateSession(_editingSession);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Changes saved successfully')),
                  );
                  Navigator.of(context).pop();
                }
              } : null,
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
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wake Up Time',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            Consumer<SessionProvider>(
              builder: (context, provider, child) {
                final prevSession = provider.getPreviousSession(_editingSession);
                final firstDate = prevSession?.sleepTime ?? DateTime.now().subtract(Duration(days: 7));
                final lastDate = _editingSession.sleepTime ?? DateTime.now();

                return TimePickerRow(
                  time: _editingSession.wakeUpTime,
                  placeholder: 'Not set',
                  icon: Icons.access_time,
                  firstDate: firstDate,
                  lastDate: lastDate,
                  onValidate: (time) => isValidWakeUpTime(context, time, _editingSession, provider),
                  onTimeSelected: (time) {
                    setState(() {
                      _editingSession = _editingSession.copyWith(wakeUpTime: time);
                      _markAsChanged();
                    });
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeeSection(BuildContext context) {
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
                    selected: _editingSession.pee == amount,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _editingSession = _editingSession.copyWith(pee: amount);
                          _markAsChanged();
                        });
                      }
                    },
                  );
                }).toList(),
              ),
            ),
            if (_editingSession.pee != PeeAmount.na) ...[
              SizedBox(height: 8),
              Consumer<SessionProvider>(
                builder: (context, provider, child) => TimePickerRow(
                  time: _editingSession.peeTime,
                  placeholder: 'Time not set',
                  icon: Icons.access_time,
                  firstDate: _editingSession.wakeUpTime,
                  lastDate: _editingSession.sleepTime ?? DateTime.now(),
                  onValidate: (time) => isValidActivityTime(context, time, _editingSession, provider),
                  onTimeSelected: (time) {
                    setState(() {
                      _editingSession = _editingSession.copyWith(peeTime: time);
                      _markAsChanged();
                    });
                  },
                ),
              ),
              SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Remarks',
                  border: OutlineInputBorder(),
                ),
                controller: _peeRemarksController,
                onChanged: (value) {
                  _editingSession = _editingSession.copyWith(peeRemarks: value);
                  _markAsChanged();
                },
              ),
            ],
          ],
        ),
      ),
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
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Milk Intake (ml)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            Consumer<SessionProvider>(
              builder: (context, provider, child) => TimePickerRow(
                time: _editingSession.milkTime,
                placeholder: 'Time not set',
                icon: Icons.access_time,
                firstDate: _editingSession.wakeUpTime,
                lastDate: _editingSession.sleepTime ?? DateTime.now(),
                onValidate: (time) => isValidActivityTime(context, time, _editingSession, provider),
                onTimeSelected: (time) {
                  setState(() {
                    _editingSession = _editingSession.copyWith(milkTime: time);
                    _markAsChanged();
                  });
                },
              ),
            ),
            SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                labelText: 'Amount in milliliters',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              controller: _milkIntakeController,
              onChanged: (value) {
                final intake = int.tryParse(value) ?? 0;
                _editingSession = _editingSession.copyWith(milkIntake: intake);
                _markAsChanged();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitaminSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Row(
          children: [
            Text(
              'Vitamin AD',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Spacer(),
            Switch(
              value: _editingSession.vitaminAD,
              onChanged: (bool value) {
                setState(() {
                  _editingSession = _editingSession.copyWith(vitaminAD: value);
                  _markAsChanged();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection(BuildContext context, SessionProvider provider) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session Photo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            if (_editingSession.hasSessionPhoto && _editingSession.sessionPhotoPath != null)
              FutureBuilder<String>(
                future: provider.photoDirectory,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final fullPath = path.join(
                    snapshot.data!,
                    _editingSession.sessionPhotoPath!,
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
                        onPressed: () async {
                          if (_editingSession.sessionPhotoPath != null) {
                            await provider.deletePhotoOnly(_editingSession.sessionPhotoPath!);
                          }
                          setState(() {
                            _editingSession = _editingSession.copyWith(
                              sessionPhotoPath: null,
                              hasSessionPhoto: false,
                            );
                            _markAsChanged();
                          });
                        },
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
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final ImagePicker picker = ImagePicker();
                      final XFile? image = await picker.pickImage(
                        source: ImageSource.camera,
                      );
                      if (image != null) {
                        final provider = Provider.of<SessionProvider>(context, listen: false);
                        final String? photoPath = await provider.savePhotoOnly(image, 'session');
                        if (photoPath != null) {
                          setState(() {
                            _editingSession = _editingSession.copyWith(
                              sessionPhotoPath: photoPath,
                              hasSessionPhoto: true,
                            );
                            _markAsChanged();
                          });
                        }
                      }
                    },
                    icon: Icon(Icons.camera_alt),
                    label: Text('Camera'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final ImagePicker picker = ImagePicker();
                      final XFile? image = await picker.pickImage(
                        source: ImageSource.gallery,
                      );
                      if (image != null) {
                        final provider = Provider.of<SessionProvider>(context, listen: false);
                        final String? photoPath = await provider.savePhotoOnly(image, 'session');
                        if (photoPath != null) {
                          setState(() {
                            _editingSession = _editingSession.copyWith(
                              sessionPhotoPath: photoPath,
                              hasSessionPhoto: true,
                            );
                            _markAsChanged();
                          });
                        }
                      }
                    },
                    icon: Icon(Icons.photo_library),
                    label: Text('Gallery'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepTimeSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sleep Time',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            Consumer<SessionProvider>(
              builder: (context, provider, child) {
                final nextSession = provider.getNextSession(_editingSession);
                final lastDate = nextSession?.wakeUpTime ?? DateTime.now();

                return TimePickerRow(
                  time: _editingSession.sleepTime,
                  placeholder: 'Not set',
                  icon: Icons.bedtime,
                  firstDate: _editingSession.wakeUpTime,
                  lastDate: lastDate,
                  onValidate: (time) => isValidSleepTime(context, time, _editingSession, provider),
                  onTimeSelected: (time) {
                    setState(() {
                      _editingSession = _editingSession.copyWith(sleepTime: time);
                      _markAsChanged();
                    });
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
