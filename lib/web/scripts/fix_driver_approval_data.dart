import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Script to fix inconsistent isApprovedDriver data types in Firestore
/// This converts all string 'true' values to boolean true values
Future<void> main() async {
  // Initialize Firebase
  await Firebase.initializeApp();
  
  final firestore = FirebaseFirestore.instance;
  
  print('Starting to normalize isApprovedDriver data...');
  
  try {
    // Get all users with isApprovedDriver field
    final usersQuery = await firestore
        .collection('users')
        .where('isApprovedDriver', whereIn: [true, 'true'])
        .get();
    
    print('Found ${usersQuery.docs.length} users with isApprovedDriver field');
    
    int updatedCount = 0;
    
    for (final doc in usersQuery.docs) {
      final data = doc.data();
      final currentValue = data['isApprovedDriver'];
      
      // Only update if the value is a string
      if (currentValue is String && currentValue == 'true') {
        await doc.reference.update({
          'isApprovedDriver': true,
        });
        
        updatedCount++;
        print('Updated user ${doc.id}: string "true" -> boolean true');
      } else if (currentValue == true) {
        print('User ${doc.id} already has boolean true value');
      } else {
        print('User ${doc.id} has unexpected value: $currentValue (${currentValue.runtimeType})');
      }
    }
    
    print('\nNormalization complete!');
    print('Total users checked: ${usersQuery.docs.length}');
    print('Users updated: $updatedCount');
    
  } catch (e) {
    print('Error during normalization: $e');
  }
}