import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';

class OrganizerNotification {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool read;
  final String? eventId;
  final String? type;

  OrganizerNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.read,
    this.eventId,
    this.type,
  });

  factory OrganizerNotification.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrganizerNotification(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: data['read'] ?? false,
      eventId: data['eventId'],
      type: data['type'],
    );
  }
}

class OrganizerNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Global notification listener
  static StreamController<OrganizerNotification>? _notificationController;
  static Stream<OrganizerNotification>? _notificationStream;
  
  // Initialize the notification stream
  static Stream<OrganizerNotification> get notificationStream {
    _notificationController ??= StreamController<OrganizerNotification>.broadcast();
    _notificationStream ??= _notificationController!.stream;
    return _notificationStream!;
  }

  // Initialize real-time notification listener for organizers
  static void initializeNotificationListener() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    _firestore
        .collection('organizers')
        .doc(currentUser.uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final latestDoc = snapshot.docs.first;
        final notification = OrganizerNotification.fromDoc(latestDoc);
        
        // Only show notification if it's new (within last 5 seconds)
        final now = DateTime.now();
        if (now.difference(notification.timestamp).inSeconds <= 5) {
          _notificationController?.add(notification);
        }
      }
    });
  }

  // Play notification sound
  static Future<void> playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/notification.wav'));
    } catch (e) {
      print('Could not play notification sound: $e');
    }
  }

  // Show notification snackbar and play sound
  static void showNotificationSnackbarWithSound(BuildContext context, OrganizerNotification notification) {
    showNotificationSnackbar(context, notification);
    playNotificationSound();
  }

  // Show notification snackbar
  static void showNotificationSnackbar(BuildContext context, OrganizerNotification notification) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    notification.body,
                    style: const TextStyle(color: Colors.white70),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue[600],
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            // Navigate to notifications page
            Navigator.pushNamed(context, '/organizer_notifications');
          },
        ),
      ),
    );
    playNotificationSound();
  }

  // Create a notification for organizers
  static Future<void> createNotification({
    required String title,
    required String body,
    required String type,
    String? eventId,
    Map<String, dynamic>? additionalData,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final notificationData = {
      'title': title,
      'body': body,
      'type': type,
      'eventId': eventId,
      'additionalData': additionalData,
      'read': false,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection('organizers')
        .doc(currentUser.uid)
        .collection('notifications')
        .add(notificationData);
  }

  // Get organizer notifications
  static Stream<List<OrganizerNotification>> getOrganizerNotifications() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('organizers')
        .doc(currentUser.uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrganizerNotification.fromDoc(doc))
            .toList());
  }

  // Get unread notification count
  static Stream<int> getUnreadCount() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('organizers')
        .doc(currentUser.uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Mark notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _firestore
        .collection('organizers')
        .doc(currentUser.uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  // Mark all notifications as read
  static Future<void> markAllNotificationsAsRead() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final notifications = await _firestore
        .collection('organizers')
        .doc(currentUser.uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in notifications.docs) {
      batch.update(doc.reference, {'read': true});
    }
    
    if (notifications.docs.isNotEmpty) {
      await batch.commit();
    }
  }

  // ===== ORGANIZER-SPECIFIC NOTIFICATION TRIGGERS =====

  // Event Management Notifications
  static Future<void> onEventCreated(String eventId, String eventName) async {
    await createNotification(
      title: 'Event Created Successfully',
      body: 'Your event "$eventName" has been created in draft status. Publish it when ready for participants to see!',
      type: 'event_created',
      eventId: eventId,
    );
  }

  static Future<void> onEventPublished(String eventId, String eventName) async {
    await createNotification(
      title: 'Event Published!',
      body: 'Your event "$eventName" is now live and visible to participants. Registrations are open!',
      type: 'event_published',
      eventId: eventId,
    );
  }

  static Future<void> onEventApproved(String eventId, String eventName) async {
    await createNotification(
      title: 'Event Approved!',
      body: 'Your event "$eventName" has been approved and is now live.',
      type: 'event_approved',
      eventId: eventId,
    );
  }

  static Future<void> onEventRejected(String eventId, String eventName, String reason) async {
    await createNotification(
      title: 'Event Not Approved',
      body: 'Your event "$eventName" was not approved: $reason',
      type: 'event_rejected',
      eventId: eventId,
      additionalData: {'reason': reason},
    );
  }

  static Future<void> onEventUpdated(String eventId, String eventName) async {
    await createNotification(
      title: 'Event Updated',
      body: 'Your event "$eventName" has been updated successfully.',
      type: 'event_updated',
      eventId: eventId,
    );
  }

  // Participant Activity Notifications
  static Future<void> onNewParticipant(String eventId, String eventName, String participantName) async {
    await createNotification(
      title: 'New Participant',
      body: '$participantName has registered for "$eventName".',
      type: 'new_participant',
      eventId: eventId,
      additionalData: {'participantName': participantName},
    );
  }

  static Future<void> onParticipantCancelled(String eventId, String eventName, String participantName) async {
    await createNotification(
      title: 'Participant Cancelled',
      body: '$participantName has cancelled their registration for "$eventName".',
      type: 'participant_cancelled',
      eventId: eventId,
      additionalData: {'participantName': participantName},
    );
  }

  static Future<void> onEventFull(String eventId, String eventName) async {
    await createNotification(
      title: 'Event Full!',
      body: 'Your event "$eventName" has reached maximum capacity.',
      type: 'event_full',
      eventId: eventId,
    );
  }

  static Future<void> onEventAlmostFull(String eventId, String eventName, int spotsLeft) async {
    await createNotification(
      title: 'Event Almost Full',
      body: 'Your event "$eventName" has only $spotsLeft spots remaining.',
      type: 'event_almost_full',
      eventId: eventId,
      additionalData: {'spotsLeft': spotsLeft},
    );
  }

  // Payment Notifications
  static Future<void> onPaymentReceived(String eventId, String eventName, String participantName, double amount) async {
    await createNotification(
      title: 'Payment Received',
      body: '$participantName has paid RM${amount.toStringAsFixed(2)} for "$eventName".',
      type: 'payment_received',
      eventId: eventId,
      additionalData: {
        'participantName': participantName,
        'amount': amount,
      },
    );
  }

  static Future<void> onPaymentRefunded(String eventId, String eventName, String participantName, double amount) async {
    await createNotification(
      title: 'Payment Refunded',
      body: 'RM${amount.toStringAsFixed(2)} has been refunded to $participantName for "$eventName".',
      type: 'payment_refunded',
      eventId: eventId,
      additionalData: {
        'participantName': participantName,
        'amount': amount,
      },
    );
  }

  // Carpool Notifications
  static Future<void> onCarpoolRequest(String eventId, String eventName, String driverName) async {
    await createNotification(
      title: 'Carpool Request',
      body: '$driverName has applied to be a driver for "$eventName".',
      type: 'carpool_request',
      eventId: eventId,
      additionalData: {'driverName': driverName},
    );
  }

  static Future<void> onCarpoolCreated(String eventId, String eventName) async {
    await createNotification(
      title: 'Carpool Created',
      body: 'A carpool has been created for "$eventName".',
      type: 'carpool_created',
      eventId: eventId,
    );
  }

  // Event Reminders
  static Future<void> onEventStartingSoon(String eventId, String eventName) async {
    await createNotification(
      title: 'Event Starting Soon',
      body: 'Your event "$eventName" starts in 1 hour. Make sure everything is ready!',
      type: 'event_starting_soon',
      eventId: eventId,
    );
  }

  static Future<void> onEventDayReminder(String eventId, String eventName) async {
    await createNotification(
      title: 'Event Today',
      body: 'Your event "$eventName" is today! Good luck!',
      type: 'event_today',
      eventId: eventId,
    );
  }

  // System Notifications
  static Future<void> onAccountApproved() async {
    await createNotification(
      title: 'Account Approved',
      body: 'Your organizer account has been approved. You can now create events!',
      type: 'account_approved',
    );
  }

  static Future<void> onAccountSuspended(String reason) async {
    await createNotification(
      title: 'Account Suspended',
      body: 'Your organizer account has been suspended: $reason',
      type: 'account_suspended',
      additionalData: {'reason': reason},
    );
  }

  static Future<void> onMaintenanceNotice(String message) async {
    await createNotification(
      title: 'System Maintenance',
      body: message,
      type: 'maintenance',
      additionalData: {'message': message},
    );
  }

  static Future<void> onNewFeature(String featureName, String description) async {
    await createNotification(
      title: 'New Feature: $featureName',
      body: description,
      type: 'new_feature',
      additionalData: {
        'featureName': featureName,
        'description': description,
      },
    );
  }

  // Analytics Notifications
  static Future<void> onEventMilestone(String eventId, String eventName, String milestone) async {
    await createNotification(
      title: 'Event Milestone Reached',
      body: 'Your event "$eventName" has reached: $milestone',
      type: 'event_milestone',
      eventId: eventId,
      additionalData: {'milestone': milestone},
    );
  }

  static Future<void> onRevenueMilestone(String eventId, String eventName, double revenue) async {
    await createNotification(
      title: 'Revenue Milestone',
      body: 'Your event "$eventName" has generated RM${revenue.toStringAsFixed(2)} in revenue!',
      type: 'revenue_milestone',
      eventId: eventId,
      additionalData: {'revenue': revenue},
    );
  }
} 