import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String eventId;
  final String senderId;
  final String senderName;
  final String message;
  final DateTime timestamp;
  final String? senderAvatar;

  ChatMessage({
    required this.id,
    required this.eventId,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.timestamp,
    this.senderAvatar,
  });

  factory ChatMessage.fromFirestore(Map<String, dynamic> data, String id) {
    return ChatMessage(
      id: id,
      eventId: data['eventId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      senderAvatar: data['senderAvatar'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'senderAvatar': senderAvatar,
    };
  }
} 