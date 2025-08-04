/// Utility functions for handling mixed data types from Firestore
class DataUtils {
  /// Safely converts mixed boolean/string values to boolean
  /// Handles cases where Firestore data might be stored as string 'true'/'false' or boolean true/false
  static bool safeBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    
    if (value is bool) return value;
    
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'true':
        case '1':
        case 'yes':
          return true;
        case 'false':
        case '0':
        case 'no':
          return false;
        default:
          return defaultValue;
      }
    }
    
    if (value is int) {
      return value != 0;
    }
    
    return defaultValue;
  }
  
  /// Safely converts mixed string/number values to string
  static String safeString(dynamic value, {String defaultValue = ''}) {
    if (value == null) return defaultValue;
    return value.toString();
  }
  
  /// Safely converts mixed number values to int
  static int safeInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    
    return defaultValue;
  }
  
  /// Safely converts mixed number values to double
  static double safeDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    
    return defaultValue;
  }
}