import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';

import '../models/session.dart';
import '../providers/session_provider.dart';
import '../shared/session_utils.dart';
import '../shared/session_widgets.dart';
import '../shared/shared.dart';

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
            TimePickerRow(
              time: session.wakeUpTime,
              placeholder: 'Not set',
              firstDate: DateTime.now().subtract(Duration(days: 7)),
              lastDate: DateTime.now(),
              onValidate: (time) => isValidWakeUpTime(context, time, session, provider),
              onTimeSelected: (time) async {
                await provider.updateCurrentSession(
                  session.copyWith(wakeUpTime: time),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepTimeSection(
    BuildContext context,
    Session session,
    SessionProvider provider,
  ) {
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
            TimePickerRow(
              time: session.sleepTime,
              placeholder: 'Not set',
              icon: Icons.bedtime,
              firstDate: session.wakeUpTime,
              lastDate: DateTime.now(),
              onValidate: (time) => isValidSleepTime(context, time, session, provider),
              onTimeSelected: (time) async {
                await provider.updateCurrentSession(
                  session.copyWith(sleepTime: time),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeeSection(
    BuildContext context,
    Session session,
    SessionProvider provider,
  ) {
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
                    selected: session.pee == amount,
                    onSelected: (selected) {
                      if (selected) {
                        provider.updateCurrentSession(
                          session.copyWith(pee: amount),
                        );
                      }
                    },
                  );
                }).toList(),
              ),
            ),
            if (session.pee != PeeAmount.na) ...[
              SizedBox(height: 8),
              TimePickerRow(
                time: session.peeTime,
                placeholder: 'Time not set',
                icon: Icons.access_time,
                firstDate: session.wakeUpTime,
                lastDate: session.sleepTime ?? DateTime.now(),
                onValidate: (time) => isValidActivityTime(context, time, session, provider),
                onTimeSelected: (time) async {
                  await provider.updateCurrentSession(
                    session.copyWith(peeTime: time),
                  );
                },
              ),
              SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Remarks',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  provider.updateCurrentSession(
                    session.copyWith(peeRemarks: value),
                  );
                },
                controller: _peeRemarksController,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPoopSection(
    BuildContext context,
    Session session,
    SessionProvider provider,
  ) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Poop',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            Text('Amount'),
            Container(
              width: double.infinity,
              child: Wrap(
                spacing: 8.0,
                children: PoopAmount.values.map((amount) {
                  return ChoiceChip(
                    label: Text(amount.name),
                    selected: session.poopAmount == amount,
                    onSelected: (bool selected) {
                      if (selected) {
                        // When amount is set to na, reset other poop-related fields
                        provider.updateCurrentSession(
                          session.copyWith(
                            poopAmount: amount,
                            poopConsistency:
                                amount == PoopAmount.na ? PoopConsistency.normal : null,
                            poopColor: amount == PoopAmount.na ? PoopColor.yellow : null,
                            poopTime: amount == PoopAmount.na ? null : session.poopTime,
                          ),
                        );
                      }
                    },
                  );
                }).toList(),
              ),
            ),
            if (session.poopAmount != PoopAmount.na) ...[
              SizedBox(height: 8),
              TimePickerRow(
                time: session.poopTime,
                placeholder: 'Time not set',
                icon: Icons.access_time,
                firstDate: session.wakeUpTime,
                lastDate: session.sleepTime ?? DateTime.now(),
                onValidate: (time) => isValidActivityTime(context, time, session, provider),
                onTimeSelected: (time) async {
                  await provider.updateCurrentSession(
                    session.copyWith(poopTime: time),
                  );
                },
              ),
              Text('Consistency'),
              SizedBox(height: 8),
              Container(
                width: double.infinity,
                child: Wrap(
                  spacing: 8.0,
                  children: PoopConsistency.values.map((consistency) {
                    return ChoiceChip(
                      label: Text(consistency.name),
                      selected: session.poopConsistency == consistency,
                      onSelected: (bool selected) {
                        if (selected) {
                          provider.updateCurrentSession(
                            session.copyWith(poopConsistency: consistency),
                          );
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
              Text('Color'),
              SizedBox(height: 8),
              Container(
                width: double.infinity,
                child: Wrap(
                  spacing: 8.0,
                  children: PoopColor.values.map((color) {
                    return ChoiceChip(
                      label: Text(color.name),
                      selected: session.poopColor == color,
                      onSelected: (bool selected) {
                        if (selected) {
                          provider.updateCurrentSession(
                            session.copyWith(poopColor: color),
                          );
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
              if (session.poopColor == PoopColor.abnormal) ...[
                SizedBox(height: 8),
                if (!session.hasAbnormalPoopPhoto)
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
                            await provider.saveAbnormalPoopPhoto(session, image);
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
                            await provider.saveAbnormalPoopPhoto(session, image);
                          }
                        },
                        icon: Icon(Icons.photo_library),
                        label: Text('Gallery'),
                      ),
                    ],
                  )
                else
                  _buildPoopPhotoSection(context, session, provider),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMilkSection(
    BuildContext context,
    Session session,
    SessionProvider provider,
  ) {
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
            TimePickerRow(
              time: session.milkTime,
              placeholder: 'Time not set',
              icon: Icons.access_time,
              firstDate: session.wakeUpTime,
              lastDate: session.sleepTime ?? DateTime.now(),
              onValidate: (time) => isValidActivityTime(context, time, session, provider),
              onTimeSelected: (time) async {
                await provider.updateCurrentSession(
                  session.copyWith(milkTime: time),
                );
              },
            ),
            SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                labelText: 'Amount in milliliters',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final intake = int.tryParse(value) ?? 0;
                provider.updateCurrentSession(
                  session.copyWith(milkIntake: intake),
                );
              },
              controller: _milkIntakeController,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitaminSection(
    BuildContext context,
    Session session,
    SessionProvider provider,
  ) {
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
              value: session.vitaminAD,
              onChanged: (bool value) {
                provider.updateCurrentSession(
                  session.copyWith(vitaminAD: value),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<Widget> _buildPhotoDisplay(
    BuildContext context,
    String relativePath,
    SessionProvider provider,
  ) async {
    print('Building photo display for relative path: $relativePath');
    final photoDir = await provider.photoDirectory;
    final fullPath = path.join(photoDir, relativePath);
    print('Full photo path constructed: $fullPath');

    final file = File(fullPath);
    if (await file.exists()) {
      final size = await file.length();
      print('Photo file exists at $fullPath with size: $size bytes');
      return Image.file(
        file,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('Error loading image: $error'); // Debug log
          return Container(
            height: 200,
            width: double.infinity,
            color: Colors.grey[300],
            child: Center(child: Text('Failed to load image')),
          );
        },
      );
    } else {
      print('Photo file not found at: $fullPath');
      return const Center(child: CircularProgressIndicator());
    }
  }

  Widget _buildPhotoSection(
    BuildContext context,
    Session session,
    SessionProvider provider,
  ) {
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
            if (session.hasSessionPhoto && session.sessionPhotoPath != null)
              FutureBuilder<Widget>(
                future: _buildPhotoDisplay(context, session.sessionPhotoPath!, provider),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasData) {
                    return Column(
                      children: [
                        snapshot.data!,
                        if (!session.isClosed) ...[
                          SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await provider.removeSessionPhoto(session);
                            },
                            icon: Icon(Icons.delete),
                            label: Text('Remove Photo'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    );
                  }
                  // If the image doesn't exist, remove it from the session
                  provider.removeSessionPhoto(session);
                  return const SizedBox.shrink();
                },
              )
            else if (!session.isClosed)
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
                        await provider.saveSessionPhoto(session, image);
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
                        await provider.saveSessionPhoto(session, image);
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

  Widget _buildPoopPhotoSection(
    BuildContext context,
    Session session,
    SessionProvider provider,
  ) {
    if (!session.hasAbnormalPoopPhoto || session.abnormalPoopPhotoPath == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<Widget>(
      future: _buildPhotoDisplay(context, session.abnormalPoopPhotoPath!, provider),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          return Column(
            children: [
              snapshot.data!,
              SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () async {
                  await provider.removeAbnormalPoopPhoto(session);
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
        }
        // If the image doesn't exist, remove it from the session
        provider.removeAbnormalPoopPhoto(session);
        return const SizedBox.shrink();
      },
    );
  }
}
