import 'pee_entry.dart';
import 'poop_entry.dart';
import 'milk_entry.dart';

enum PeeAmount { na, small, medium, large, xlarge }
enum PoopAmount { na, small, medium, large, blowout }
enum PoopConsistency { normal, dry, liquid, diarrhea }
enum PoopColor { green, yellow, yellowGreen, abnormal }

class Session {
  final int? id;
  DateTime wakeUpTime;
  List<PeeEntry> peeEntries;
  List<PoopEntry> poopEntries;
  List<MilkEntry> milkEntries;
  bool vitaminAD;
  DateTime? sleepTime;
  String? sessionPhotoPath;
  bool hasSessionPhoto;
  bool isClosed;

  int get totalMilkIntake => milkEntries.fold(0, (sum, entry) => sum + entry.amount);

  Session({
    this.id,
    required this.wakeUpTime,
    List<PeeEntry>? peeEntries,
    List<PoopEntry>? poopEntries,
    List<MilkEntry>? milkEntries,
    this.vitaminAD = false,
    this.sleepTime,
    this.sessionPhotoPath,
    this.hasSessionPhoto = false,
    this.isClosed = false,
  })  : peeEntries = peeEntries ?? [],
        poopEntries = poopEntries ?? [],
        milkEntries = milkEntries ?? [];

  // Helper methods to manage entries
  void addPeeEntry(PeeEntry entry) {
    peeEntries.insert(0, entry); // Add to the beginning to maintain time order
  }

  void addPoopEntry(PoopEntry entry) {
    poopEntries.insert(0, entry);
  }

  void addMilkEntry(MilkEntry entry) {
    milkEntries.add(entry);  // Add to the end to maintain time order (ascending)
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'wakeUpTime': wakeUpTime.toIso8601String(),
      'vitaminAD': vitaminAD ? 1 : 0,
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
      vitaminAD: map['vitaminAD'] == 1,
      sleepTime: map['sleepTime'] != null 
          ? DateTime.parse(map['sleepTime'])
          : null,
      sessionPhotoPath: map['sessionPhotoPath'],
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
    bool? vitaminAD,
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
      vitaminAD: vitaminAD ?? this.vitaminAD,
      sleepTime: sleepTime ?? this.sleepTime,
      sessionPhotoPath: sessionPhotoPath ?? this.sessionPhotoPath,
      hasSessionPhoto: hasSessionPhoto ?? this.hasSessionPhoto,
      isClosed: isClosed ?? this.isClosed,
    );
  }
}
