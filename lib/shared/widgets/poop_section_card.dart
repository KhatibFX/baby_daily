import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;

import '../../models/session.dart';
import '../../providers/session_provider.dart';
import '../session_utils.dart';
import '../session_widgets.dart';

class PoopSectionCard extends StatelessWidget {
  final Session session;
  final Function(Session) onSessionChanged;
  final bool isEditing;

  const PoopSectionCard({
    Key? key,
    required this.session,
    required this.onSessionChanged,
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
                    onSelected: (selected) {
                      if (selected) {
                        // When amount is set to na, reset other poop-related fields
                        final updatedSession = session.copyWith(
                          poopAmount: amount,
                          poopConsistency:
                              amount == PoopAmount.na ? PoopConsistency.normal : null,
                          poopColor: amount == PoopAmount.na ? PoopColor.yellow : null,
                          poopTime: amount == PoopAmount.na ? null : session.poopTime,
                        );
                        onSessionChanged(updatedSession);
                      }
                    },
                  );
                }).toList(),
              ),
            ),
            if (session.poopAmount != PoopAmount.na) ...[
              SizedBox(height: 8),
              Consumer<SessionProvider>(
                builder: (context, provider, child) => TimePickerRow(
                  time: session.poopTime,
                  placeholder: 'Time not set',
                  icon: Icons.access_time,
                  firstDate: session.wakeUpTime,
                  lastDate: session.sleepTime ?? DateTime.now(),
                  onValidate: (time) => isValidActivityTime(context, time, session, provider),
                  onTimeSelected: (time) {
                    final updatedSession = session.copyWith(poopTime: time);
                    onSessionChanged(updatedSession);
                  },
                ),
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
                      onSelected: (selected) {
                        if (selected) {
                          final updatedSession = session.copyWith(poopConsistency: consistency);
                          onSessionChanged(updatedSession);
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
                      onSelected: (selected) {
                        if (selected) {
                          final updatedSession = session.copyWith(poopColor: color);
                          onSessionChanged(updatedSession);
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
              if (session.poopColor == PoopColor.abnormal) ...[
                SizedBox(height: 8),
                if (!session.hasAbnormalPoopPhoto)
                  _buildPhotoButtons(context)
                else
                  _buildPoopPhotoDisplay(context),
              ],
            ],
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
        final String? photoPath = await provider.savePhotoOnly(image, 'poop');
        if (photoPath != null) {
          final updatedSession = session.copyWith(
            abnormalPoopPhotoPath: photoPath,
            hasAbnormalPoopPhoto: true,
          );
          onSessionChanged(updatedSession);
        }
      } else {
        await provider.saveAbnormalPoopPhoto(session, image);
      }
    }
  }

  Widget _buildPoopPhotoDisplay(BuildContext context) {
    if (!session.hasAbnormalPoopPhoto || session.abnormalPoopPhotoPath == null) {
      return const SizedBox.shrink();
    }

    return Consumer<SessionProvider>(
      builder: (context, provider, child) => FutureBuilder<String>(
        future: provider.photoDirectory,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final fullPath = path.join(
            snapshot.data!,
            session.abnormalPoopPhotoPath!,
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
                  if (isEditing) {
                    final provider = Provider.of<SessionProvider>(context, listen: false);                          
                    if (session.abnormalPoopPhotoPath != null) {
                      await provider.deletePhotoOnly(session.abnormalPoopPhotoPath!);
                    }
                    final updatedSession = session.copyWith(
                      abnormalPoopPhotoPath: null,
                      hasAbnormalPoopPhoto: false,
                    );
                    onSessionChanged(updatedSession);
                  } else {
                    final provider = Provider.of<SessionProvider>(context, listen: false);
                    await provider.removeAbnormalPoopPhoto(session);
                  }
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
      ),
    );
  }
}
