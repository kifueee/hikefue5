import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> setupAdmin(String email, String password) async {
  try {
    // Create admin user in Firebase Auth
    final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final userId = userCredential.user!.uid;

    // Create admin document
    await FirebaseFirestore.instance.collection('admins').doc(userId).set({
      'email': email,
      'role': 'super_admin',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isActive': true,
    });

    print('Admin account created successfully');
  } catch (e) {
    print('Error creating admin account: $e');
    rethrow;
  }
} 