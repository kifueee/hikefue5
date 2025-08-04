import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class DebugPage extends StatelessWidget {
  const DebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug - Current User'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current User Info:',
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (user != null) ...[
              Text('UID: ${user.uid}'),
              Text('Email: ${user.email}'),
              Text('Display Name: ${user.displayName}'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Force Logout'),
              ),
              const SizedBox(height: 24),
              FutureBuilder<DocumentSnapshot?> (
                future: _checkUserInCollections(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  
                  if (snapshot.hasData && snapshot.data != null) {
                    final collectionName = snapshot.data!.reference.parent.id;
                    return Text('User found in collection: $collectionName');
                  }
                  
                  return const Text('User not found in any collection');
                },
              ),
            ] else ...[
              const Text('No user logged in'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/');
                },
                child: const Text('Go to Landing Page'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<DocumentSnapshot?> _checkUserInCollections(String uid) async {
    final collections = ['admins', 'organizers', 'participants'];
    for (final collection in collections) {
      final doc = await FirebaseFirestore.instance.collection(collection).doc(uid).get();
      if (doc.exists) {
        return doc;
      }
    }
    return null;
  }
} 