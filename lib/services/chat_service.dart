import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message.dart';

class ChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Send a message to an event chat
  static Future<void> sendMessage({
    required String eventId,
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
      eventId: eventId,
      senderId: currentUser.uid,
      senderName: senderName,
      message: message.trim(),
      timestamp: DateTime.now(),
      senderAvatar: senderAvatar,
    );

    await _firestore
        .collection('event_chats')
        .doc(eventId)
        .collection('messages')
        .add(chatMessage.toMap());
  }

  // Get real-time stream of messages for an event
  static Stream<List<ChatMessage>> getEventMessages(String eventId) {
    return _firestore
        .collection('event_chats')
        .doc(eventId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Check if user is a participant of the event (for security)
  static Future<bool> isEventParticipant(String eventId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    final eventDoc = await _firestore.collection('events').doc(eventId).get();
    if (!eventDoc.exists) return false;

    final eventData = eventDoc.data() as Map<String, dynamic>;
    final participants = eventData['participants'] as Map<String, dynamic>? ?? {};

    return participants.containsKey(currentUser.uid);
  }

  // Get user's display name for chat
  static Future<String> getUserDisplayName() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return 'Anonymous';

    // Try to get from participants collection first
    final participantDoc = await _firestore
        .collection('participants')
        .doc(currentUser.uid)
        .get();

    if (participantDoc.exists) {
      final data = participantDoc.data() as Map<String, dynamic>;
      return data['name'] ?? currentUser.email?.split('@')[0] ?? 'Anonymous';
    }

    // Fallback to email
    return currentUser.email?.split('@')[0] ?? 'Anonymous';
  }
} 