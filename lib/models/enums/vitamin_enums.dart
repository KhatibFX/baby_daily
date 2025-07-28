import '../../constants/enum_labels.dart';
import '../../utils/enum_utils.dart';

enum VitaminType {
  ad,
  other,
  // Future types can be added here
}

extension VitaminTypeExtension on VitaminType {
  String get label {
    switch (this) {
      case VitaminType.ad:
        return VitaminTypeLabels.ad;
      case VitaminType.other:
        return VitaminTypeLabels.other;
    }
  }

  static VitaminType? fromString(String? value) {
    return EnumUtils.fromString(VitaminType.values, value);
  }
} 