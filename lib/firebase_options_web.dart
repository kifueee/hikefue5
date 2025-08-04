import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are not supported for this platform.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAE4jbrjU5QiNVa2EvocVgFdsR__c-kCRE',
    appId: '1:378043411691:web:2082af74922c9ceac2e2ae',
    messagingSenderId: '378043411691',
    projectId: 'hikefue5-8f6ae',
    authDomain: 'hikefue5-8f6ae.firebaseapp.com',
    storageBucket: 'hikefue5-8f6ae.appspot.com',
  );
} 