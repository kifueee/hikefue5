import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyC4Id-7sFnJhopu6ZCpXTvSYxkQQVBk59c",
        projectId: "hikefue5-8f6ae",
        messagingSenderId: "378043411691",
        appId: "1:378043411691:android:2082af74922c9ceac2e2ae",
        storageBucket: "hikefue5-8f6ae.appspot.com",
      ),
    );

    // Get admin email and password
    stdout.write('Enter admin email: ');
    final email = stdin.readLineSync()?.trim();
    if (email == null || email.isEmpty) {
      throw Exception('Email is required');
    }

    stdout.write('Enter admin password (min 6 characters): ');
    final password = stdin.readLineSync()?.trim();
    if (password == null || password.isEmpty || password.length < 6) {
      throw Exception('Password must be at least 6 characters');
    }

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

    print('\nAdmin account created successfully!');
    print('Email: $email');
    print('User ID: $userId');
  } catch (e) {
    print('\nError creating admin account: $e');
    exit(1);
  } finally {
    exit(0);
  }
} 