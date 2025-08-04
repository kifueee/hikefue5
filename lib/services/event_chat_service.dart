import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EventChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if user is a participant of the event
  static Future<bool> isEventParticipant(String eventId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) return false;

      final eventData = eventDoc.data()!;
      final participants = eventData['participants'] as Map<String, dynamic>? ?? {};
      
      return participants.containsKey(currentUser.uid);
    } catch (e) {
      print('Error checking event participant status: $e');
      return false;
    }
  }

  /// Get event chat messages stream
  static Stream<QuerySnapshot> getEventMessages(String eventId) {
    return _firestore
        .collection('event_chats')
        .doc(eventId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  /// Send a message to event chat
  static Future<void> sendEventMessage({
    required String eventId,
    required String message,
    required String senderName,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Verify user is a participant
      final isParticipant = await isEventParticipant(eventId);
      if (!isParticipant) throw Exception('Only event participants can send messages');

      // Get the actual display name if not provided
      String actualSenderName = senderName;
      if (senderName == 'Anonymous' || senderName.isEmpty) {
        actualSenderName = await getUserDisplayName();
      }

      final messageData = {
        'text': message,
        'senderId': currentUser.uid,
        'senderName': actualSenderName,
        'timestamp': FieldValue.serverTimestamp(),
        'eventId': eventId,
        'type': 'event_chat',
      };

      await _firestore
          .collection('event_chats')
          .doc(eventId)
          .collection('messages')
          .add(messageData);
    } catch (e) {
      print('Error sending event message: $e');
      rethrow;
    }
  }

  /// Get event information for chat
  static Future<Map<String, dynamic>?> getEventInfo(String eventId) async {
    try {
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) return null;

      return eventDoc.data();
    } catch (e) {
      print('Error getting event info: $e');
      return null;
    }
  }

  /// Get participant count for the event
  static Future<int> getParticipantCount(String eventId) async {
    try {
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) return 0;

      final eventData = eventDoc.data()!;
      final participants = eventData['participants'] as Map<String, dynamic>? ?? {};
      
      return participants.length;
    } catch (e) {
      print('Error getting participant count: $e');
      return 0;
    }
  }

  /// Get user's display name for chat
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