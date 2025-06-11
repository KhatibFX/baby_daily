import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;

import '../models/session.dart';
import '../providers/session_provider.dart';

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

  @override
  void dispose() {
    _peeRemarksController.dispose();
    _milkIntakeController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Discard Changes?'),
        content: Text('You have unsaved changes. Do you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Discard'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  void _markAsChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
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
                await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Discard Changes?'),
                    content: Text('Do you want to discard all changes?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        },
                        child: Text('Discard'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                      ),
                    ],
                  ),
                );
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
          builder: (context, provider, child) => SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
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
            Row(
              children: [
                Icon(Icons.access_time),
                SizedBox(width: 8),
                Text(
                  DateFormat('MMM dd, yyyy HH:mm').format(_editingSession.wakeUpTime),
                ),
                Spacer(),
                TextButton(
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _editingSession.wakeUpTime,
                      firstDate: DateTime.now().subtract(Duration(days: 7)),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      final TimeOfDay? time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_editingSession.wakeUpTime),
                      );
                      if (time != null) {
                        final newDateTime = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          time.hour,
                          time.minute,
                        );
                        setState(() {
                          _editingSession = _editingSession.copyWith(wakeUpTime: newDateTime);
                          _markAsChanged();
                        });
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
            Wrap(
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
        ),
      ),
    );
  }

  Widget _buildPoopSection(BuildContext context) {
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
            Wrap(
              spacing: 8.0,
              children: PoopAmount.values.map((amount) {
                return ChoiceChip(
                  label: Text(amount.name),
                  selected: _editingSession.poopAmount == amount,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _editingSession = _editingSession.copyWith(poopAmount: amount);
                        _markAsChanged();
                      });
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
                  selected: _editingSession.poopConsistency == consistency,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _editingSession = _editingSession.copyWith(poopConsistency: consistency);
                        _markAsChanged();
                      });
                    }
                  },
                );
              }).toList(),
            ),
            Text('Color'),
            SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              children: PoopColor.values.map((color) {
                return ChoiceChip(
                  label: Text(color.name),
                  selected: _editingSession.poopColor == color,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _editingSession = _editingSession.copyWith(poopColor: color);
                        _markAsChanged();
                      });
                    }
                  },
                );
              }).toList(),
            ),
            if (_editingSession.poopColor == PoopColor.abnormal) ...[
              SizedBox(height: 8),
              if (!_editingSession.hasAbnormalPoopPhoto)
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
                          final String? photoPath = await provider.savePhotoOnly(image, 'poop');
                          if (photoPath != null) {
                            setState(() {
                              _editingSession = _editingSession.copyWith(
                                abnormalPoopPhotoPath: photoPath,
                                hasAbnormalPoopPhoto: true,
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
                          final String? photoPath = await provider.savePhotoOnly(image, 'poop');
                          if (photoPath != null) {
                            setState(() {
                              _editingSession = _editingSession.copyWith(
                                abnormalPoopPhotoPath: photoPath,
                                hasAbnormalPoopPhoto: true,
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
                )
              else
                _buildAbnormalPoopPhotoSection(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAbnormalPoopPhotoSection(BuildContext context) {
    if (!_editingSession.hasAbnormalPoopPhoto || 
        _editingSession.abnormalPoopPhotoPath == null) {
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
            _editingSession.abnormalPoopPhotoPath!,
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
                  final provider = Provider.of<SessionProvider>(context, listen: false);                          if (_editingSession.abnormalPoopPhotoPath != null) {
                            await provider.deletePhotoOnly(_editingSession.abnormalPoopPhotoPath!);
                          }
                          setState(() {
                            _editingSession = _editingSession.copyWith(
                              abnormalPoopPhotoPath: null,
                              hasAbnormalPoopPhoto: false,
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
      ),
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
            Row(
              children: [
                Icon(Icons.bedtime),
                SizedBox(width: 8),
                Text(
                  _editingSession.sleepTime != null
                      ? DateFormat('MMM dd, yyyy HH:mm').format(_editingSession.sleepTime!)
                      : 'Not set',
                ),
                Spacer(),
                TextButton(
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _editingSession.sleepTime ?? DateTime.now(),
                      firstDate: _editingSession.wakeUpTime,
                      lastDate: DateTime.now().add(Duration(days: 1)),
                    );
                    if (picked != null) {
                      final TimeOfDay? time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(
                          _editingSession.sleepTime ?? DateTime.now(),
                        ),
                      );
                      if (time != null) {
                        final newDateTime = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          time.hour,
                          time.minute,
                        );
                        setState(() {
                          _editingSession = _editingSession.copyWith(sleepTime: newDateTime);
                          _markAsChanged();
                        });
                      }
                    }
                  },
                  child: Text(_editingSession.sleepTime == null ? 'Set' : 'Change'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
