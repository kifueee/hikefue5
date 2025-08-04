import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FixOrganizerAuth {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> fixApprovedOrganizers() async {
    try {
      print('Starting to fix approved organizers authentication...');
      
      // Get all approved organizers
      final snapshot = await _firestore
          .collection('organizers')
          .where('status', isEqualTo: 'approved')
          .get();
      
      print('Found ${snapshot.docs.length} approved organizers');
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final email = data['email'] as String?;
        final uid = data['uid'] as String?;
        
        print('Processing organizer: $email (UID: $uid)');
        
        if (email == null) continue;
        
        // Check if Firebase Auth user exists by fetching user by email
        try {
          final methods = await _auth.fetchSignInMethodsForEmail(email);
          if (methods.isNotEmpty) {
            print('Firebase Auth user exists for: $email');
            continue;
          }
        } catch (e) {
          print('Error checking sign-in methods for $email: $e');
        }
        
        // If user does not exist, create them
        await _createFirebaseAuthUser(email, data);
      }
      
      print('Finished fixing organizer authentication');
    } catch (e) {
      print('Error fixing organizer authentication: $e');
    }
  }

  static Future<void> _createFirebaseAuthUser(String email, Map<String, dynamic> data) async {
    try {
      // Generate a temporary password
      final tempPassword = 'TempPass${DateTime.now().millisecondsSinceEpoch}';
      
      // Create Firebase Auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: tempPassword,
      );
      
      final uid = userCredential.user!.uid;
      print('Created Firebase Auth user with UID: $uid for email: $email');
      
      // Update the organizer document with the UID
      await _firestore.collection('organizers').doc(data['tempId'] ?? data['uid'] ?? uid).update({
        'uid': uid,
        'tempPassword': tempPassword, // Store temporarily so admin can share with organizer
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('Updated organizer document with UID: $uid');
      
      // Send password reset email so organizer can set their own password
      await _auth.sendPasswordResetEmail(email: email);
      print('Sent password reset email to: $email');
      
    } catch (e) {
      print('Error creating Firebase Auth user for $email: $e');
    }
  }
}

// Usage in admin dashboard
class AdminDashboardHelper {
  static Future<void> fixOrganizerAuth() async {
    await FixOrganizerAuth.fixApprovedOrganizers();
  }
} 