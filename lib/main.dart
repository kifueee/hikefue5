import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/auth_page.dart';
import 'screens/my_events_page.dart';
import 'screens/event_details_page.dart';
import 'screens/participant_home_page.dart';
import 'screens/notifications_page.dart';
import 'services/auth_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/notification_listener.dart';
// Conditional import for web app
// Web app import removed to fix mobile build

import 'package:flutter_local_notifications/flutter_local_notifications.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // MOBILE ONLY - If running on web, show error message
  if (kIsWeb) {
    print('ERROR: main.dart should not run on web! Use web_app.dart instead.');
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'WRONG APP!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('This is the MOBILE app for PARTICIPANTS'),
              SizedBox(height: 8),
              Text('Use web_app.dart for organizers and admins'),
            ],
          ),
        ),
      ),
    ));
    return;
  }
  
  try {
    if (!Firebase.apps.isNotEmpty) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyC4Id-7sFnJhopu6ZCpXTvSYxkQQVBk59c",
          appId: "1:378043411691:web:b75ca1b2c633ffc7c2e2ae",
          messagingSenderId: "378043411691",
          projectId: "hikefue5-8f6ae",
          storageBucket: "hikefue5-8f6ae.appspot.com",
          measurementId: "G-R8K9S03LZG"
        ),
      );
    }

    // Configure Firebase Auth for development
    if (kDebugMode) {
      await FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: true,
      );
    }
    
    print('Firebase initialized successfully');
  } catch (e) {
    print('Error initializing Firebase: $e');
  }

  // --- BEGIN: Local Notifications Setup ---
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Create a default notification channel for Android (required for Android 8+)
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'default_channel_id',
    'Default',
    description: 'Default channel for notifications',
    importance: Importance.high,
  );
  await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);

  // Listen for FCM messages in the foreground and show a local notification
  // --- END: Local Notifications Setup ---

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HikeFue Mobile - Participants Only',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF556B2F), // Dark olive green
          brightness: Brightness.light,
          primary: const Color(0xFF556B2F),
          secondary: const Color(0xFF6B8E23),
          surface: const Color(0xFFFAFAFA),
          background: const Color(0xFFF8F9FA),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: const Color(0xFF2C3E50),
          onBackground: const Color(0xFF2C3E50),
        ),
        // Enhanced typography
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2C3E50),
            letterSpacing: -0.5,
          ),
          displayMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
            letterSpacing: -0.25,
          ),
          displaySmall: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
          headlineLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
          headlineMedium: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
          headlineSmall: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
          titleLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
          titleMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF2C3E50),
          ),
          titleSmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6C757D),
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF2C3E50),
            height: 1.5,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF2C3E50),
            height: 1.5,
          ),
          bodySmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Color(0xFF6C757D),
            height: 1.4,
          ),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF2C3E50),
          ),
          labelMedium: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6C757D),
          ),
          labelSmall: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6C757D),
          ),
        ),
        // Enhanced card theme
        cardTheme: CardTheme(
          elevation: 2,
          shadowColor: const Color(0xFF2C3E50).withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: Colors.white,
        ),
        // Enhanced app bar theme
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF556B2F),
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF556B2F),
            letterSpacing: -0.25,
          ),
          iconTheme: IconThemeData(
            color: Color(0xFF556B2F),
            size: 24,
          ),
        ),
        // Enhanced button themes
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF556B2F),
            foregroundColor: Colors.white,
            elevation: 2,
            shadowColor: const Color(0xFF556B2F).withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.25,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF556B2F),
            side: const BorderSide(color: Color(0xFF556B2F), width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.25,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF556B2F),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.25,
            ),
          ),
        ),
        // Enhanced input decoration theme
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8F9FA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE9ECEF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE9ECEF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF556B2F), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDC3545)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          hintStyle: const TextStyle(
            color: Color(0xFF6C757D),
            fontSize: 14,
          ),
        ),
        // Enhanced chip theme
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFF8F9FA),
          selectedColor: const Color(0xFF556B2F).withOpacity(0.1),
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF2C3E50),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        // Enhanced divider theme
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE9ECEF),
          thickness: 1,
          space: 1,
        ),
      ),
      home: const AuthWrapper(),
      routes: {
        '/participant_home': (context) => ParticipantHomePage(),
        '/my_events': (context) => const MyEventsPage(),
        '/event_details': (context) => EventDetailsPage(
              eventId: ModalRoute.of(context)!.settings.arguments as String,
            ),
        '/notifications': (context) => NotificationsPage(
              userId: FirebaseAuth.instance.currentUser?.uid ?? '',
            ),
      },
    );
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _hasCheckedInitialAuth = false;
  User? _initialUser;

  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    // Wait a bit for Firebase Auth to initialize
    await Future.delayed(const Duration(milliseconds: 500));
    
    final currentUser = FirebaseAuth.instance.currentUser;
    print('AuthWrapper - Initial auth check: ${currentUser?.uid ?? 'null'}');
    
    if (mounted) {
      setState(() {
        _initialUser = currentUser;
        _hasCheckedInitialAuth = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Add debugging information
        print('AuthWrapper - Connection state: ${snapshot.connectionState}');
        print('AuthWrapper - Has data: ${snapshot.hasData}');
        print('AuthWrapper - User: ${snapshot.data?.uid}');
        print('AuthWrapper - User email: ${snapshot.data?.email}');
        print('AuthWrapper - Has checked initial auth: $_hasCheckedInitialAuth');
        print('AuthWrapper - Initial user: ${_initialUser?.uid}');
        
        // Show loading indicator while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting && !_hasCheckedInitialAuth) {
          print('AuthWrapper - Waiting for auth state...');
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

        // Use the stream data if available, otherwise use initial user
        final user = snapshot.data ?? _initialUser;
        
        // If user is authenticated, check their role and redirect accordingly
        if (user != null) {
          print('AuthWrapper - User authenticated, checking role...');
          return FutureBuilder<DocumentSnapshot?>(
            future: _getUserRole(user.uid),
            builder: (context, roleSnapshot) {
              print('AuthWrapper - Role connection state: ${roleSnapshot.connectionState}');
              print('AuthWrapper - Role has data: ${roleSnapshot.hasData}');
              
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
                final collectionId = roleSnapshot.data!.reference.parent.id;
                print('AuthWrapper - User role collection: $collectionId');
                print('AuthWrapper - User data: $userData');
                
                if (userData != null) {
                  // Only allow participants on mobile
                  if (collectionId == 'participants') {
                    print('AuthWrapper - Redirecting to ParticipantHomePage');
                    return AppNotificationListener(
                      child: ParticipantHomePage(),
                    );
                  }
                }
              }

              // If role not found or invalid, show AuthPage
              print('AuthWrapper - Role not found, showing AuthPage');
              return const AuthPage();
            },
          );
        }

        // If not authenticated, show AuthPage
        print('AuthWrapper - Not authenticated, showing AuthPage');
        return const AuthPage();
      },
    );
  }

  Future<DocumentSnapshot?> _getUserRole(String uid) async {
    try {
      print('AuthWrapper - Getting user role for UID: $uid');
      // Check each collection for the user
      final collections = ['admins', 'organizers', 'participants'];
      for (final collection in collections) {
        final doc = await FirebaseFirestore.instance.collection(collection).doc(uid).get();
        print('AuthWrapper - Checking collection $collection: ${doc.exists}');
        if (doc.exists) {
          print('AuthWrapper - Found user in collection: $collection');
          return doc;
        }
      }
      print('AuthWrapper - User not found in any collection');
      return null;
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }
}

String? getCurrentUserId() {
  // TODO: Replace with your actual user ID retrieval logic (e.g., from Provider, FirebaseAuth, etc.)
  return null;
}
