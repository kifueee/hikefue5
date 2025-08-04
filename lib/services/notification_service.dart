import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hikefue5/models/payment_status.dart';
import 'package:hikefue5/services/payment_service.dart';
import 'package:audioplayers/audioplayers.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool read;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.read,
  });

  factory AppNotification.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: data['read'] ?? false,
    );
  }
}

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Global notification listener
  static StreamController<AppNotification>? _notificationController;
  static Stream<AppNotification>? _notificationStream;
  
  // Initialize the notification stream
  static Stream<AppNotification> get notificationStream {
    _notificationController ??= StreamController<AppNotification>.broadcast();
    _notificationStream ??= _notificationController!.stream;
    return _notificationStream!;
  }

  // Initialize real-time notification listener
  static void initializeNotificationListener() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    _firestore
        .collection('participants')
        .doc(currentUser.uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final latestDoc = snapshot.docs.first;
        final notification = AppNotification.fromDoc(latestDoc);
        
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
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
    } catch (e) {
      // Fallback to system sound if custom sound fails
      try {
        await _audioPlayer.play(AssetSource('sounds/notification.wav'));
      } catch (e) {
        // If both fail, just log the error
        print('Could not play notification sound: $e');
      }
    }
  }
  
  // Show notification snackbar and play sound
  static void showNotificationSnackbarWithSound(BuildContext context, AppNotification notification) {
    showNotificationSnackbar(context, notification);
    playNotificationSound();
  }

  // Show notification snackbar
  static void showNotificationSnackbar(BuildContext context, AppNotification notification) {
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
            Navigator.pushNamed(context, '/notifications');
          },
        ),
      ),
    );
    playNotificationSound(); // Always play sound when showing snackbar
  }

  // Create a notification
  static Future<void> createNotification({
    required String title,
    required String message,
    required String type,
    String? eventId,
    String? paymentId,
    Map<String, dynamic>? additionalData,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final notificationData = {
      'userId': currentUser.uid,
      'title': title,
      'message': message,
      'type': type,
      'eventId': eventId,
      'paymentId': paymentId,
      'additionalData': additionalData,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('notifications').add(notificationData);
  }

  // Get user notifications
  static Stream<List<Map<String, dynamic>>> getUserNotifications() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList());
  }

  // Mark notification as read
  static Future<void> markAsRead(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  // Mark all notifications as read
  static Future<void> markAllAsRead() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final notifications = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: currentUser.uid)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in notifications.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    
    if (notifications.docs.isNotEmpty) {
      await batch.commit();
    }
  }

  // Get unread notification count for the new notification system
  static Stream<int> getUnreadCount() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('participants')
        .doc(currentUser.uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Mark notification as read in the new system
  static Future<void> markNotificationAsRead(String notificationId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _firestore
        .collection('participants')
        .doc(currentUser.uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  // Mark all notifications as read in the new system
  static Future<void> markAllNotificationsAsRead() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final notifications = await _firestore
        .collection('participants')
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

  // Create payment reminder notification
  static Future<void> createPaymentReminder(PaymentInfo payment) async {
    final eventDetails = await PaymentService.getEventDetails(payment.eventId);
    if (eventDetails == null) return;

    final eventName = eventDetails['name'] ?? 'Unknown Event';
    final deadline = payment.deadline;
    final now = DateTime.now();
    final daysLeft = deadline.difference(now).inDays;

    String title, message;

    if (daysLeft <= 0) {
      title = 'Payment Expired';
      message = 'Your payment for "$eventName" has expired. Please contact support.';
    } else if (daysLeft <= 1) {
      title = 'Payment Due Tomorrow';
      message = 'Your payment for "$eventName" is due tomorrow. Please complete payment to secure your spot.';
    } else if (daysLeft <= 3) {
      title = 'Payment Due Soon';
      message = 'Your payment for "$eventName" is due in $daysLeft days. Please complete payment to secure your spot.';
    } else {
      title = 'Payment Reminder';
      message = 'Please complete your payment for "$eventName" within $daysLeft days.';
    }

    await createNotification(
      title: title,
      message: message,
      type: 'payment_reminder',
      eventId: payment.eventId,
      paymentId: payment.id,
      additionalData: {
        'amount': payment.amount,
        'deadline': payment.deadline.toIso8601String(),
        'daysLeft': daysLeft,
      },
    );
  }

  // Create payment success notification
  static Future<void> createPaymentSuccessNotification(PaymentInfo payment) async {
    final eventDetails = await PaymentService.getEventDetails(payment.eventId);
    if (eventDetails == null) return;

    final eventName = eventDetails['name'] ?? 'Unknown Event';

    await createNotification(
      title: 'Payment Successful',
      message: 'Your payment for "$eventName" has been completed successfully. You\'re all set!',
      type: 'payment_success',
      eventId: payment.eventId,
      paymentId: payment.id,
      additionalData: {
        'amount': payment.amount,
        'transactionId': payment.transactionId,
      },
    );
  }

  // Create payment failure notification
  static Future<void> createPaymentFailureNotification(
    PaymentInfo payment,
    String reason,
  ) async {
    final eventDetails = await PaymentService.getEventDetails(payment.eventId);
    if (eventDetails == null) return;

    final eventName = eventDetails['name'] ?? 'Unknown Event';

    await createNotification(
      title: 'Payment Failed',
      message: 'Your payment for "$eventName" failed: $reason. Please try again.',
      type: 'payment_failure',
      eventId: payment.eventId,
      paymentId: payment.id,
      additionalData: {
        'amount': payment.amount,
        'failureReason': reason,
      },
    );
  }

  // Create event reminder notification
  static Future<void> createEventReminder(
    String eventId,
    String eventName,
    DateTime eventDate,
  ) async {
    final now = DateTime.now();
    final daysUntilEvent = eventDate.difference(now).inDays;

    if (daysUntilEvent <= 0) return; // Event has passed

    String title, message;

    if (daysUntilEvent == 1) {
      title = 'Event Tomorrow';
      message = 'Your event "$eventName" is tomorrow! Don\'t forget to attend.';
    } else if (daysUntilEvent <= 3) {
      title = 'Event Soon';
      message = 'Your event "$eventName" is in $daysUntilEvent days. Get ready!';
    } else if (daysUntilEvent <= 7) {
      title = 'Event Reminder';
      message = 'Your event "$eventName" is in $daysUntilEvent days.';
    } else {
      return; // Don't send reminder for events more than a week away
    }

    await createNotification(
      title: title,
      message: message,
      type: 'event_reminder',
      eventId: eventId,
      additionalData: {
        'eventDate': eventDate.toIso8601String(),
        'daysUntilEvent': daysUntilEvent,
      },
    );
  }

  // Check and create payment reminders for expiring payments
  static Future<void> checkAndCreatePaymentReminders() async {
    final expiringPayments = await PaymentService.getExpiringPayments().first;
    
    for (final payment in expiringPayments) {
      await createPaymentReminder(payment);
    }
  }

  // Delete old notifications (older than 30 days)
  static Future<void> cleanupOldNotifications() async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    
    final oldNotifications = await _firestore
        .collection('notifications')
        .where('createdAt', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
        .get();

    final batch = _firestore.batch();
    for (final doc in oldNotifications.docs) {
      batch.delete(doc.reference);
    }
    
    if (oldNotifications.docs.isNotEmpty) {
      await batch.commit();
    }
  }

  static Stream<List<AppNotification>> notificationsStream(String userId) {
    return FirebaseFirestore.instance
      .collection('participants')
      .doc(userId)
      .collection('notifications')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => AppNotification.fromDoc(doc)).toList());
  }

  // Dispose resources
  static void dispose() {
    _notificationController?.close();
    _audioPlayer.dispose();
  }
} 