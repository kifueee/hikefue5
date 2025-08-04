import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/tag.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Helper method to get the correct collection based on user type
  CollectionReference _getUserCollection(String userType) {
    switch (userType.toLowerCase()) {
      case 'organizer':
        return _firestore.collection('organizers');
      case 'participant':
        return _firestore.collection('participants');
      case 'admin':
        return _firestore.collection('admins');
      default:
        throw Exception('Invalid user type: $userType');
    }
  }

  // Get user data
  Future<Map<String, dynamic>?> getUserData(String uid, String userType) async {
    final doc = await _getUserCollection(userType).doc(uid).get();
    return doc.data() as Map<String, dynamic>?;
  }

  // Update user data
  Future<void> updateUserData(String uid, String userType, Map<String, dynamic> data) async {
    await _getUserCollection(userType).doc(uid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Create user data
  Future<void> createUserData(String uid, String userType, Map<String, dynamic> data) async {
    await _getUserCollection(userType).doc(uid).set({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get user stream
  Stream<DocumentSnapshot> getUserStream(String uid, String userType) {
    return _getUserCollection(userType).doc(uid).snapshots();
  }

  // Check if user exists in any collection
  Future<Map<String, dynamic>?> getUserFromAnyCollection(String uid) async {
    // Try each collection
    final collections = ['organizers', 'participants', 'admins'];
    for (final collection in collections) {
      final doc = await _firestore.collection(collection).doc(uid).get();
      if (doc.exists) {
        return {
          'data': doc.data(),
          'type': collection,
        };
      }
    }
    return null;
  }

  // Delete user data
  Future<void> deleteUserData(String uid, String userType) async {
    await _getUserCollection(userType).doc(uid).delete();
  }

  // Hikes Operations
  Future<void> addHike(String userId, String userType, Map<String, dynamic> hikeData) async {
    await _getUserCollection(userType)
        .doc(userId)
        .collection('hikes')
        .add({
          ...hikeData,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> updateHike(String userId, String userType, String hikeId, Map<String, dynamic> hikeData) async {
    await _getUserCollection(userType)
        .doc(userId)
        .collection('hikes')
        .doc(hikeId)
        .update(hikeData);
  }

  // Trails Operations
  Future<void> addTrail(Map<String, dynamic> trailData) async {
    await _firestore.collection('trails').add({
      ...trailData,
      'createdAt': FieldValue.serverTimestamp(),
      'rating': 0,
      'reviews': [],
    });
  }

  Future<void> updateTrail(String trailId, Map<String, dynamic> trailData) async {
    await _firestore.collection('trails').doc(trailId).update(trailData);
  }

  // Reviews Operations
  Future<void> addReview(Map<String, dynamic> reviewData) async {
    final reviewRef = await _firestore.collection('reviews').add({
      ...reviewData,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update trail's reviews array
    await _firestore.collection('trails').doc(reviewData['trailId']).update({
      'reviews': FieldValue.arrayUnion([reviewRef.id]),
    });
  }

  // Queries
  Stream<QuerySnapshot> getUserHikes(String userId, String userType) {
    return _getUserCollection(userType)
        .doc(userId)
        .collection('hikes')
        .orderBy('date', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getTrails() {
    return _firestore
        .collection('trails')
        .orderBy('rating', descending: true)
        .snapshots();
  }

  Future<List<DocumentSnapshot>> getTrailReviews(String trailId) async {
    final reviewsQuery = await _firestore
        .collection('reviews')
        .where('trailId', isEqualTo: trailId)
        .orderBy('createdAt', descending: true)
        .get();
    
    return reviewsQuery.docs;
  }

  // Tag Operations
  Future<List<Tag>> getAllTags() async {
    final snapshot = await _firestore.collection('tags').get();
    return snapshot.docs
        .map((doc) => Tag.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<void> addTag(Tag tag) async {
    await _firestore.collection('tags').add(tag.toMap());
  }

  // Get user data by automatically detecting user type
  static Future<Map<String, dynamic>?> getUserDataAuto(String uid) async {
    final firestore = FirebaseFirestore.instance;
    
    // Check each collection
    final collections = ['organizers', 'participants', 'admins'];
    for (final collection in collections) {
      final doc = await firestore.collection(collection).doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data['userType'] = collection.substring(0, collection.length - 1); // Remove 's' from end
        return data;
      }
    }
    return null;
  }

  // Store passenger join details
  static Future<void> storePassengerJoinDetails({
    required String userId,
    required String offerId,
    required String eventId,
    required Map<String, dynamic> contactDetails,
  }) async {
    final firestore = FirebaseFirestore.instance;
    
    await firestore.collection('passengerDetails').add({
      'userId': userId,
      'offerId': offerId,
      'eventId': eventId,
      'contactDetails': contactDetails,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
} 