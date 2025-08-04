import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  String? _userType; // 'organizer', 'participant', or 'admin'

  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      if (user != null) {
        _determineUserType();
      } else {
        _userType = null;
      }
      notifyListeners();
    });
  }

  User? get user => _user;
  String? get userType => _userType;
  bool get isAuthenticated => _user != null;

  Future<void> _determineUserType() async {
    if (_user == null) return;

    // Check each collection
    final collections = ['organizers', 'participants', 'admins'];
    for (final collection in collections) {
      final doc = await _firestore.collection(collection).doc(_user!.uid).get();
      if (doc.exists) {
        _userType = collection;
        notifyListeners();
        return;
      }
    }
    _userType = null;
    notifyListeners();
  }

  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _determineUserType();
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential> registerWithEmailAndPassword(
    String email,
    String password,
    String userType,
    Map<String, dynamic> userData,
  ) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in the appropriate collection
      await _firestore.collection(userType).doc(userCredential.user!.uid).set({
        ...userData,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      _userType = userType;
      notifyListeners();
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _userType = null;
    notifyListeners();
  }

  Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    if (_user == null || _userType == null) return;

    try {
      await _firestore.collection(_userType!).doc(_user!.uid).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      // Custom action code settings for forgot password email template
      final actionCodeSettings = ActionCodeSettings(
        url: 'https://hikefue5-8f6ae.firebaseapp.com/auth/password-reset-complete', // Your app's URL for password reset completion
        handleCodeInApp: false,
        androidPackageName: 'com.example.hikefue5',
        iOSBundleId: 'com.example.hikefue5',
        dynamicLinkDomain: null, // Add if you have Firebase Dynamic Links
      );
      
      await _auth.sendPasswordResetEmail(
        email: email,
        actionCodeSettings: actionCodeSettings,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteAccount() async {
    if (_user == null || _userType == null) return;

    try {
      // Delete user data from Firestore
      await _firestore.collection(_userType!).doc(_user!.uid).delete();
      
      // Delete user from Firebase Auth
      await _user!.delete();
      
      _userType = null;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
} 