import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message.dart';

class CommunityChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Send a message to the community chat
  static Future<void> sendCommunityMessage({
    required String message,
    required String senderName,
    String? senderAvatar,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User must be logged in to send messages');
    }

    final chatMessage = ChatMessage(
      id: '', // Will be set by Firestore
      eventId: 'community', // Special ID for community chat
      senderId: currentUser.uid,
      senderName: senderName,
      message: message.trim(),
      timestamp: DateTime.now(),
      senderAvatar: senderAvatar,
    );

    await _firestore
        .collection('community_chat')
        .add(chatMessage.toMap());
  }

  // Send a message to a specific carpool chat
  static Future<void> sendCarpoolMessage({
    required String carpoolId,
    required String message,
    required String senderName,
    String? senderAvatar,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User must be logged in to send messages');
    }

    final chatMessage = ChatMessage(
      id: '', // Will be set by Firestore
      eventId: carpoolId, // Use carpoolId as eventId for carpool chats
      senderId: currentUser.uid,
      senderName: senderName,
      message: message.trim(),
      timestamp: DateTime.now(),
      senderAvatar: senderAvatar,
    );

    await _firestore
        .collection('carpool_chat')
        .add(chatMessage.toMap());
  }

  // Get real-time stream of community messages
  static Stream<List<ChatMessage>> getCommunityMessages() {
    return _firestore
        .collection('community_chat')
        .orderBy('timestamp', descending: false)
        .limit(100) // Limit to last 100 messages for performance
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get real-time stream of carpool messages
  static Stream<List<ChatMessage>> getCarpoolMessages(String carpoolId) {
    return _firestore
        .collection('carpool_chat')
        .where('eventId', isEqualTo: carpoolId)
        .orderBy('timestamp', descending: false)
        .limit(100) // Limit to last 100 messages for performance
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get all carpool chats for a user (both as driver and passenger)
  static Stream<List<Map<String, dynamic>>> getUserCarpoolChats() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('carpools')
        .where('status', isEqualTo: 'active')
        .orderBy('departureTime')
        .snapshots()
        .asyncMap((snapshot) async {
          final List<Map<String, dynamic>> userCarpools = [];

          for (var doc in snapshot.docs) {
            final data = doc.data();
            data['id'] = doc.id;

            // Check if user is the driver
            if (data['driverId'] == currentUser.uid) {
              data['userRole'] = 'driver';
              userCarpools.add(data);
            } else {
              // Check if user is a passenger in this carpool
              final passengerSnapshot = await doc.reference
                  .collection('passengers')
                  .where('userId', isEqualTo: currentUser.uid)
                  .get();
              
              if (passengerSnapshot.docs.isNotEmpty) {
                data['userRole'] = 'passenger';
                userCarpools.add(data);
              }
            }
          }

          return userCarpools;
        });
  }

  // Check if user is a community member (all authenticated users are members)
  static Future<bool> isCommunityMember() async {
    final currentUser = _auth.currentUser;
    return currentUser != null;
  }

  // Check if user has access to carpool chats
  static Future<bool> hasCarpoolAccess() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    // Check if user is part of any active carpools
    final carpoolsQuery = await _firestore
        .collection('carpools')
        .where('status', isEqualTo: 'active')
        .get();

    for (var carpoolDoc in carpoolsQuery.docs) {
      final data = carpoolDoc.data();
      
      // Check if user is driver
      if (data['driverId'] == currentUser.uid) {
        return true;
      }
      
      // Check if user is passenger
      final passengerSnapshot = await carpoolDoc.reference
          .collection('passengers')
          .where('userId', isEqualTo: currentUser.uid)
          .get();
      
      if (passengerSnapshot.docs.isNotEmpty) {
        return true;
      }
    }

    return false;
  }

  // Get user's display name for chat
  static Future<String> getUserDisplayName() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return 'Anonymous';

    // First try Firebase Auth display name
    if (currentUser.displayName != null && currentUser.displayName!.isNotEmpty) {
      return currentUser.displayName!;
    }

    // Try to get from participants collection
    try {
      final participantDoc = await _firestore
          .collection('participants')
          .doc(currentUser.uid)
          .get();

      if (participantDoc.exists) {
        final data = participantDoc.data() as Map<String, dynamic>;
        if (data['name'] != null && data['name'].toString().isNotEmpty) {
          return data['name'];
        }
      }
    } catch (e) {
      print('Error getting participant data: $e');
    }

    // Try to get from users collection
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        if (data['name'] != null && data['name'].toString().isNotEmpty) {
          return data['name'];
        }
        if (data['displayName'] != null && data['displayName'].toString().isNotEmpty) {
          return data['displayName'];
        }
      }
    } catch (e) {
      print('Error getting user data: $e');
    }

    // Fallback to email username
    if (currentUser.email != null) {
      final emailParts = currentUser.email!.split('@');
      if (emailParts.isNotEmpty && emailParts[0].isNotEmpty) {
        return emailParts[0];
      }
    }

    return 'Anonymous';
  }
} 