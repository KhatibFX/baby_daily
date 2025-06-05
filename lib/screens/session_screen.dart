import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/session.dart';
import '../providers/session_provider.dart';

class SessionScreen extends StatelessWidget {
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

        return SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
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
              if (!session.isClosed)
                Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      await sessionProvider.closeCurrentSession();
                    },
                    child: Text('Close Session'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
            ],
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
            Row(
              children: [
                Icon(Icons.access_time),
                SizedBox(width: 8),
                Text(
                  DateFormat('MMM dd, yyyy HH:mm').format(session.wakeUpTime),
                ),
                Spacer(),
                TextButton(
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: session.wakeUpTime,
                      firstDate: DateTime.now().subtract(Duration(days: 7)),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      final TimeOfDay? time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(session.wakeUpTime),
                      );
                      if (time != null) {
                        final newDateTime = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          time.hour,
                          time.minute,
                        );
                        await provider.updateCurrentSession(
                          session.copyWith(wakeUpTime: newDateTime),
                        );
                      }
                    }
                  },
                  child: Text('Change'),
                ),
              ],
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
            Wrap(
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
              controller: TextEditingController(text: session.peeRemarks),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPoopSection(BuildContext context, Session session, SessionProvider provider) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'Poop',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 8),
          Text('Amount'),
          Wrap(
            spacing: 8.0,
            children: PoopAmount.values.map((amount) {
              return ChoiceChip(
                label: Text(amount.name),
                selected: session.poopAmount == amount,
                onSelected: (selected) {
                  if (selected) {
                    provider.updateCurrentSession(
                      session.copyWith(poopAmount: amount),
                    );
                  }
                },
              );
            }).toList(),
          ),
          SizedBox(height: 8),
          Text('Consistency'),
          Wrap(
            spacing: 8.0,
            children: PoopConsistency.values.map((consistency) {
              return ChoiceChip(
                label: Text(consistency.name),
                selected: session.poopConsistency == consistency,
                onSelected: (selected) {
                  if (selected) {
                    provider.updateCurrentSession(
                      session.copyWith(poopConsistency: consistency),
                    );
                  }
                },
              );
            }).toList(),
          ),
          SizedBox(height: 8),
          Text('Color'),
          Wrap(
            spacing: 8.0,
            children: PoopColor.values.map((color) {
              return ChoiceChip(
                label: Text(color.name),
                selected: session.poopColor == color,
                onSelected: (selected) {
                  if (selected) {
                    provider.updateCurrentSession(
                      session.copyWith(poopColor: color),
                    );
                  }
                },
              );
            }).toList(),
          ),
          if (session.poopColor == PoopColor.abnormal) ...[
            SizedBox(height: 8),
            if (session.poopColor == PoopColor.abnormal) ...[
              SizedBox(height: 8),
              if (session.abnormalPoopPhotoPath != null)
                Column(
                  children: [
                    Image.file(
                      File(session.abnormalPoopPhotoPath!),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        provider.updateCurrentSession(
                          session.copyWith(abnormalPoopPhotoPath: null),
                        );
                      },
                      icon: Icon(Icons.delete),
                      label: Text('Remove Photo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
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
                          provider.updateCurrentSession(
                            session.copyWith(abnormalPoopPhotoPath: image.path),
                          );
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
                          provider.updateCurrentSession(
                            session.copyWith(abnormalPoopPhotoPath: image.path),
                          );
                        }
                      },
                      icon: Icon(Icons.photo_library),
                      label: Text('Gallery'),
                    ),
                  ],
                ),
            ],
          ],
        ]),
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
              controller: TextEditingController(
                text: session.milkIntake.toString(),
              ),
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
            if (session.sessionPhotoPath != null)
              Column(
                children: [
                  Image.file(
                    File(session.sessionPhotoPath!),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  if (!session.isClosed) ...[
                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        provider.updateCurrentSession(
                          session.copyWith(sessionPhotoPath: null),
                        );
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
                        provider.updateCurrentSession(
                          session.copyWith(sessionPhotoPath: image.path),
                        );
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
                        provider.updateCurrentSession(
                          session.copyWith(sessionPhotoPath: image.path),
                        );
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
}
