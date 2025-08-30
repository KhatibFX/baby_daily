import 'milk_entry.dart';
import 'pee_entry.dart';
import 'poop_entry.dart';
import 'vitamin_entry.dart';

class Session {
  final int? id;
  DateTime wakeUpTime;
  List<PeeEntry> peeEntries;
  List<PoopEntry> poopEntries;
  List<MilkEntry> milkEntries;
  List<VitaminEntry> vitaminEntries;
  DateTime? sleepTime;
  String? sessionPhotoPath;
  bool hasSessionPhoto;
  bool isClosed;

  int get totalMilkIntake => milkEntries
      .where((entry) => entry.amount != null)
      .fold(0, (sum, entry) => sum + entry.amount!);

  /// Returns true if all entries in this session have mandatory fields filled
  bool get hasCompleteEntries {
    return peeEntries.every((entry) => entry.isComplete) &&
        poopEntries.every((entry) => entry.isComplete) &&
        milkEntries.every((entry) => entry.isComplete) &&
        vitaminEntries.every((entry) => entry.isComplete);
  }

  /// Returns a list of incomplete entries for user feedback
  List<String> get incompleteEntryTypes {
    final incomplete = <String>[];

    if (peeEntries.any((entry) => !entry.isComplete)) {
      incomplete.add('Pee entries');
    }
    if (poopEntries.any((entry) => !entry.isComplete)) {
      incomplete.add('Poop entries');
    }
    if (milkEntries.any((entry) => !entry.isComplete)) {
      incomplete.add('Milk entries');
    }
    if (vitaminEntries.any((entry) => !entry.isComplete)) {
      incomplete.add('Vitamin entries');
    }

    return incomplete;
  }

  Session({
    this.id,
    required this.wakeUpTime,
    List<PeeEntry>? peeEntries,
    List<PoopEntry>? poopEntries,
    List<MilkEntry>? milkEntries,
    List<VitaminEntry>? vitaminEntries,
    this.sleepTime,
    this.sessionPhotoPath,
    this.hasSessionPhoto = false,
    this.isClosed = false,
  })  : peeEntries = peeEntries ?? [],
        poopEntries = poopEntries ?? [],
        milkEntries = milkEntries ?? [],
        vitaminEntries = vitaminEntries ?? [];

  // Helper methods to manage entries
  void addPeeEntry(PeeEntry entry) {
    peeEntries.add(entry); // Add to the end to maintain time order (ascending)
  }

  void addPoopEntry(PoopEntry entry) {
    poopEntries.add(entry); // Add to the end to maintain time order (ascending)
  }

  void addMilkEntry(MilkEntry entry) {
    milkEntries.add(entry); // Add to the end to maintain time order (ascending)
  }

  void addVitaminEntry(VitaminEntry entry) {
    vitaminEntries.add(entry);
  }

  void removePeeEntry(int entryId) {
    peeEntries.removeWhere((entry) => entry.id == entryId);
  }

  void removePoopEntry(int entryId) {
    poopEntries.removeWhere((entry) => entry.id == entryId);
  }

  void removeMilkEntry(int entryId) {
    milkEntries.removeWhere((entry) => entry.id == entryId);
  }

  void removeVitaminEntry(int entryId) {
    vitaminEntries.removeWhere((entry) => entry.id == entryId);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'wakeUpTime': wakeUpTime.toIso8601String(),
      'peeEntries': peeEntries.map((e) => e.toMap()).toList(),
      'poopEntries': poopEntries.map((e) => e.toMap()).toList(),
      'milkEntries': milkEntries.map((e) => e.toMap()).toList(),
      'vitaminEntries': vitaminEntries.map((e) => e.toMap()).toList(),
      'sleepTime': sleepTime?.toIso8601String(),
      'sessionPhotoPath': sessionPhotoPath,
      'hasSessionPhoto': hasSessionPhoto ? 1 : 0,
      'isClosed': isClosed ? 1 : 0,
    };
  }

  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'] as int?,
      wakeUpTime: DateTime.parse(map['wakeUpTime']),
      peeEntries: (map['peeEntries'] as List? ?? [])
          .map((e) => PeeEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
      poopEntries: (map['poopEntries'] as List? ?? [])
          .map((e) => PoopEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
      milkEntries: (map['milkEntries'] as List? ?? [])
          .map((e) => MilkEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
      vitaminEntries: (map['vitaminEntries'] as List? ?? [])
          .map((e) => VitaminEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
      sleepTime: map['sleepTime'] != null ? DateTime.parse(map['sleepTime']) : null,
      sessionPhotoPath: map['sessionPhotoPath'] as String?,
      hasSessionPhoto: map['hasSessionPhoto'] == 1,
      isClosed: map['isClosed'] == 1,
    );
  }

  Session copyWith({
    int? id,
    DateTime? wakeUpTime,
    List<PeeEntry>? peeEntries,
    List<PoopEntry>? poopEntries,
    List<MilkEntry>? milkEntries,
    List<VitaminEntry>? vitaminEntries,
    DateTime? sleepTime,
    String? sessionPhotoPath,
    bool? hasSessionPhoto,
    bool? isClosed,
  }) {
    return Session(
      id: id ?? this.id,
      wakeUpTime: wakeUpTime ?? this.wakeUpTime,
      peeEntries: peeEntries ?? List.from(this.peeEntries),
      poopEntries: poopEntries ?? List.from(this.poopEntries),
      milkEntries: milkEntries ?? List.from(this.milkEntries),
      vitaminEntries: vitaminEntries ?? List.from(this.vitaminEntries),
      sleepTime: sleepTime ?? this.sleepTime,
      sessionPhotoPath: sessionPhotoPath ?? this.sessionPhotoPath,
      hasSessionPhoto: hasSessionPhoto ?? this.hasSessionPhoto,
      isClosed: isClosed ?? this.isClosed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'wakeUpTime': wakeUpTime.toIso8601String(),
      'peeEntries': peeEntries.map((e) => e.toJson()).toList(),
      'poopEntries': poopEntries.map((e) => e.toJson()).toList(),
      'milkEntries': milkEntries.map((e) => e.toJson()).toList(),
      'vitaminEntries': vitaminEntries.map((e) => e.toJson()).toList(),
      'sleepTime': sleepTime?.toIso8601String(),
      'sessionPhotoPath': sessionPhotoPath,
      'hasSessionPhoto': hasSessionPhoto,
      'isClosed': isClosed,
    };
  }

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as int?,
      wakeUpTime: DateTime.parse(json['wakeUpTime'] as String),
      peeEntries: (json['peeEntries'] as List)
          .map((e) => PeeEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      poopEntries: (json['poopEntries'] as List)
          .map((e) => PoopEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      milkEntries: (json['milkEntries'] as List)
          .map((e) => MilkEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      vitaminEntries: (json['vitaminEntries'] as List? ?? [])
          .map((e) => VitaminEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      sleepTime: json['sleepTime'] != null ? DateTime.parse(json['sleepTime'] as String) : null,
      sessionPhotoPath: json['sessionPhotoPath'] as String?,
      hasSessionPhoto: json['hasSessionPhoto'] as bool,
      isClosed: json['isClosed'] as bool,
    );
  }
}
