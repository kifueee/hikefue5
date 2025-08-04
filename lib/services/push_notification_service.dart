
class PushNotificationService {
  /// Call this after user login (pass participant userId)
  static Future<void> initializeFCM(String userId) async {
    // Request permissions (iOS)
    // REMOVE: await _messaging.requestPermission();

    // Get the FCM token
    // REMOVE: String? token = await _messaging.getToken();
    // REMOVE: if (token != null) {
    // REMOVE:   // Save the token to Firestore under the participant's document
    // REMOVE:   await FirebaseFirestore.instance
    // REMOVE:       .collection('participants')
    // REMOVE:       .doc(userId)
    // REMOVE:       .update({'fcmToken': token});
    // REMOVE: }
  }

  /// Force refresh FCM token and update in Firestore
  static Future<void> refreshAndUpdateToken(String userId) async {
    try {
      print('Refreshing FCM token for user: $userId');
      
      // Delete the old token
      // REMOVE: await _messaging.deleteToken();
      print('Old FCM token deleted');
      
      // Get a new token
      // REMOVE: String? newToken = await _messaging.getToken();
      // REMOVE: if (newToken != null) {
      // REMOVE:   print('New FCM Token generated: ${newToken.substring(0, 20)}...');
      // REMOVE:   
      // REMOVE:   // Save the new token to Firestore
      // REMOVE:   await FirebaseFirestore.instance
      // REMOVE:       .collection('participants')
      // REMOVE:       .doc(userId)
      // REMOVE:       .update({'fcmToken': newToken});
      // REMOVE:   print('New FCM Token saved to Firestore for user: $userId');
      // REMOVE:   
      // REMOVE:   // Test the token by printing it (you can copy this to Firebase Console for testing)
      // REMOVE:   print('=== COPY THIS TOKEN FOR TESTING ===');
      // REMOVE:   print(newToken);
      // REMOVE:   print('=== END TOKEN ===');
      // REMOVE: } else {
      // REMOVE:   print('Failed to get new FCM token');
      // REMOVE: }
    } catch (e) {
      print('Error refreshing FCM token: $e');
    }
  }

  /// Listen for FCM token refresh and update Firestore
  static void listenForTokenRefresh(String userId) {
    // REMOVE: _messaging.onTokenRefresh.listen((newToken) async {
    // REMOVE:   print('FCM token refreshed: ' + newToken);
    // REMOVE:   await FirebaseFirestore.instance
    // REMOVE:       .collection('participants')
    // REMOVE:       .doc(userId)
    // REMOVE:       .update({'fcmToken': newToken});
    // REMOVE:   print('FCM token updated in Firestore for user: ' + userId);
    // REMOVE: });
  }

  /// Get current FCM token (for debugging)
  static Future<String?> getCurrentToken() async {
    // REMOVE: return await _messaging.getToken();
    return null; // Placeholder as FCM is removed
  }
} 