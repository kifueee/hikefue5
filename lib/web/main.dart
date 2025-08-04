import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/admin_login_page.dart';
import 'screens/organizer_login_page.dart';
import 'screens/admin_dashboard.dart';
import 'screens/organizer_dashboard.dart';
import 'screens/organizer_pending_page.dart';
import 'screens/debug_page.dart';
import '../screens/web_landing_page.dart';
import '../widgets/notification_listener.dart';
import 'screens/organizer_notifications_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyC4Id-7sFnJhopu6ZCpXTvSYxkQQVBk59c",
      authDomain: "hikefue5-8f6ae.firebaseapp.com",
      projectId: "hikefue5-8f6ae",
      storageBucket: "hikefue5-8f6ae.appspot.com",
      messagingSenderId: "378043411691",
      appId: "1:378043411691:web:b75ca1b2c633ffc7c2e2ae",
      measurementId: "G-R8K9S03LZG"
    ),
  );

  // Configure Firebase Auth persistence for web
  await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);

  // Disable App Check for development
  // await FirebaseAppCheck.instance.activate(
  //   webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
  //   androidProvider: AndroidProvider.debug,
  //   appleProvider: AppleProvider.appAttest,
  // );

  runApp(const HikeFueWebApp());
}

class HikeFueWebApp extends StatelessWidget {
  const HikeFueWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppNotificationListener(
      child: MaterialApp(
        title: 'HikeFue Web',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF556B2F),
            brightness: Brightness.light,
          ),
          textTheme: GoogleFonts.poppinsTextTheme(),
        ),
        home: const AuthWrapper(),
        routes: {
          '/': (context) => const WebLandingPage(),
          '/admin_login': (context) => const AdminLoginPage(),
          '/organizer_login': (context) => const OrganizerLoginPage(),
          '/organizer_notifications': (context) => const OrganizerNotificationsPage(),
          '/debug': (context) => const DebugPage(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading indicator while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6B8E23),
                    Color(0xFF556B2F),
                    Color(0xFF2F4F2F),
                  ],
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
          );
        }

        // If user is authenticated, check their role and redirect accordingly
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<DocumentSnapshot?>(
            future: _getUserRole(snapshot.data!.uid),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return Scaffold(
                  body: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF6B8E23),
                          Color(0xFF556B2F),
                          Color(0xFF2F4F2F),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              }

              // Redirect based on user role
              if (roleSnapshot.hasData && roleSnapshot.data != null) {
                final userData = roleSnapshot.data!.data() as Map<String, dynamic>?;
                final collectionName = roleSnapshot.data!.reference.parent.id;
                print('User found in collection: $collectionName');
                print('User data: $userData');
                
                if (userData != null) {
                  // Check if it's an admin
                  if (collectionName == 'admins') {
                    print('Redirecting to Admin Dashboard');
                    return const AdminDashboard();
                  }
                  
                  // Check if it's an organizer
                  if (collectionName == 'organizers') {
                    final status = userData['status'] as String?;
                    print('Organizer status: $status');
                    if (status == 'approved') {
                      print('Redirecting to Organizer Dashboard');
                      return const OrganizerDashboard();
                    } else if (status == 'pending') {
                      print('Redirecting to Organizer Pending Page');
                      return const OrganizerPendingPage();
                    }
                  }
                  
                  // If user is not admin or organizer, show landing page
                  print('User is not admin or organizer, showing landing page');
                  return const WebLandingPage();
                }
              }
              
              // If role not found or invalid, show landing page
              print('No valid role found, showing landing page');
              return const WebLandingPage();

              // If role not found or invalid, show landing page
              return const WebLandingPage();
            },
          );
        }

        // If not authenticated, show landing page
        return const WebLandingPage();
      },
    );
  }

  Future<DocumentSnapshot?> _getUserRole(String uid) async {
    try {
      print('Getting user role for UID: $uid');
      // Check only admin and organizer collections - web is ONLY for organizers and admins
      final collections = ['admins', 'organizers'];
      for (final collection in collections) {
        final doc = await FirebaseFirestore.instance.collection(collection).doc(uid).get();
        print('Checking collection $collection: ${doc.exists}');
        if (doc.exists) {
          print('Found user in collection: $collection');
          return doc;
        }
      }
      print('User not found in admin or organizer collections');
      return null;
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }
} 