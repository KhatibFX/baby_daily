/// Utility class for enum operations
abstract class EnumUtils {
  /// Generic method to find enum value by name
  static T? fromString<T extends Enum>(List<T> values, String? value) {
    if (value == null) return null;
    for (T enumValue in values) {
      if (enumValue.name == value) {
        return enumValue;
      }
    }
    return null;
  }
} 