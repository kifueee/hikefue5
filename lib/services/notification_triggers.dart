import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationTriggers {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Trigger notification when user successfully registers for an event
  static Future<void> onEventRegistration(String eventId, String eventName) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _firestore
        .collection('participants')
        .doc(currentUser.uid)
        .collection('notifications')
        .add({
      'title': 'Registration Successful!',
      'body': 'You have successfully registered for "$eventName". We\'ll see you there!',
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'eventId': eventId,
    });
  }

  // Trigger notification when user cancels event registration
  static Future<void> onEventCancellation(String eventId, String eventName) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _firestore
        .collection('participants')
        .doc(currentUser.uid)
        .collection('notifications')
        .add({
      'title': 'Registration Cancelled',
      'body': 'Your registration for "$eventName" has been cancelled.',
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'eventId': eventId,
    });
  }

  // Trigger notification when carpool is created
  static Future<void> onCarpoolCreated(String eventId, String eventName) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _firestore
        .collection('participants')
        .doc(currentUser.uid)
        .collection('notifications')
        .add({
      'title': 'Carpool Available',
      'body': 'A carpool has been created for "$eventName". Check it out!',
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'eventId': eventId,
    });
  }

  // Trigger notification when carpool request is accepted
  static Future<void> onCarpoolRequestAccepted(String eventId, String eventName) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _firestore
        .collection('participants')
        .doc(currentUser.uid)
        .collection('notifications')
        .add({
      'title': 'Carpool Request Accepted',
      'body': 'Your carpool request for "$eventName" has been accepted!',
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'eventId': eventId,
    });
  }

  // Trigger notification when carpool request is rejected
  static Future<void> onCarpoolRequestRejected(String eventId, String eventName) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _firestore
        .collection('participants')
        .doc(currentUser.uid)
        .collection('notifications')
        .add({
      'title': 'Carpool Request Rejected',
      'body': 'Your carpool request for "$eventName" was not accepted. Try another carpool!',
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'eventId': eventId,
    });
  }

  // Trigger notification when someone joins your carpool
  static Future<void> onPassengerJoinedCarpool(String eventId, String eventName, String passengerName, int numberOfPassengers, String driverId) async {
    await _firestore
        .collection('participants')
        .doc(driverId)
        .collection('notifications')
        .add({
      'title': 'New Passenger Joined',
      'body': '$passengerName joined your carpool for "$eventName" with $numberOfPassengers ${numberOfPassengers == 1 ? 'person' : 'people'}.',
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'eventId': eventId,
    });
  }

  // Trigger notification when carpool is cancelled
  static Future<void> onCarpoolCancelled(String eventId, String eventName, String cancelledBy, List<String> userIdsToNotify) async {
    final batch = _firestore.batch();
    
    for (final userId in userIdsToNotify) {
      final notifRef = _firestore
          .collection('participants')
          .doc(userId)
          .collection('notifications')
          .doc();
      
      batch.set(notifRef, {
        'title': 'Carpool Cancelled',
        'body': 'Your carpool for "$eventName" has been cancelled by $cancelledBy.',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'eventId': eventId,
      });
    }
    
    await batch.commit();
  }

  // Trigger notification when a passenger cancels their carpool participation
  static Future<void> onPassengerCancelledCarpool(String eventId, String eventName, String passengerName, int numberOfPassengers, String driverId) async {
    await _firestore
        .collection('participants')
        .doc(driverId)
        .collection('notifications')
        .add({
      'title': 'Passenger Cancelled',
      'body': '$passengerName cancelled their carpool participation for "$eventName" (${numberOfPassengers} ${numberOfPassengers == 1 ? 'person' : 'people'}).',
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'eventId': eventId,
    });
  }

  // Trigger notification when payment is due soon
  static Future<void> onPaymentDueSoon(String eventId, String eventName, int daysLeft) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    String title, body;
    if (daysLeft <= 0) {
      title = 'Payment Overdue';
      body = 'Your payment for "$eventName" is overdue. Please contact support.';
    } else if (daysLeft == 1) {
      title = 'Payment Due Tomorrow';
      body = 'Your payment for "$eventName" is due tomorrow. Please complete payment to secure your spot.';
    } else {
      title = 'Payment Due Soon';
      body = 'Your payment for "$eventName" is due in $daysLeft days. Please complete payment to secure your spot.';
    }

    await _firestore
        .collection('participants')
        .doc(currentUser.uid)
        .collection('notifications')
        .add({
      'title': title,
      'body': body,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'eventId': eventId,
    });
  }

  // Trigger notification when payment is successful
  static Future<void> onPaymentSuccess(String eventId, String eventName, double amount) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _firestore
        .collection('participants')
        .doc(currentUser.uid)
        .collection('notifications')
        .add({
      'title': 'Payment Successful',
      'body': 'Your payment of RM${amount.toStringAsFixed(2)} for "$eventName" has been completed successfully!',
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'eventId': eventId,
    });
  }

  // Trigger notification when payment fails
  static Future<void> onPaymentFailure(String eventId, String eventName, String reason) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _firestore
        .collection('participants')
        .doc(currentUser.uid)
        .collection('notifications')
        .add({
      'title': 'Payment Failed',
      'body': 'Your payment for "$eventName" failed: $reason. Please try again.',
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'eventId': eventId,
    });
  }

  // Trigger notification when event is about to start (1 hour before)
  static Future<void> onEventStartingSoon(String eventId, String eventName) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _firestore
        .collection('participants')
        .doc(currentUser.uid)
        .collection('notifications')
        .add({
      'title': 'Event Starting Soon!',
      'body': '"$eventName" starts in 1 hour. Make sure you\'re ready!',
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'eventId': eventId,
    });
  }

  // Trigger notification when user profile is updated
  static Future<void> onProfileUpdated() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _firestore
        .collection('participants')
        .doc(currentUser.uid)
        .collection('notifications')
        .add({
      'title': 'Profile Updated',
      'body': 'Your profile has been updated successfully.',
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  // Trigger notification for app updates or maintenance
  static Future<void> onAppUpdate(String message) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _firestore
        .collection('participants')
        .doc(currentUser.uid)
        .collection('notifications')
        .add({
      'title': 'App Update',
      'body': message,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  // Trigger notification for weather alerts
  static Future<void> onWeatherAlert(String eventId, String eventName, String weatherInfo) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _firestore
        .collection('participants')
        .doc(currentUser.uid)
        .collection('notifications')
        .add({
      'title': 'Weather Alert',
      'body': 'Weather update for "$eventName": $weatherInfo',
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'eventId': eventId,
    });
  }

  // Trigger notification for safety alerts
  static Future<void> onSafetyAlert(String eventId, String eventName, String safetyInfo) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _firestore
        .collection('participants')
        .doc(currentUser.uid)
        .collection('notifications')
        .add({
      'title': 'Safety Alert',
      'body': 'Important safety information for "$eventName": $safetyInfo',
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'eventId': eventId,
    });
  }

  // Trigger notification when passenger requests to join driver's ride
  static Future<void> onPassengerRequestedJoin(String eventId, String eventName, String passengerName, int numberOfPassengers, String driverId) async {
    await _firestore
        .collection('participants')
        .doc(driverId)
        .collection('notifications')
        .add({
      'title': 'New Ride Request',
      'body': '$passengerName wants to join your ride for "$eventName" (${numberOfPassengers} seat${numberOfPassengers > 1 ? 's' : ''})',
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'eventId': eventId,
      'type': 'passenger_request',
      'requiresAction': true,
    });

    // Also try organizers collection in case the driver is an organizer
    try {
      await _firestore
          .collection('organizers')
          .doc(driverId)
          .collection('notifications')
          .add({
        'title': 'New Ride Request',
        'body': '$passengerName wants to join your ride for "$eventName" (${numberOfPassengers} seat${numberOfPassengers > 1 ? 's' : ''})',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'eventId': eventId,
        'type': 'passenger_request',
        'requiresAction': true,
      });
    } catch (e) {
      // Ignore if organizer document doesn't exist
    }
  }

  // Trigger notification when driver approves passenger request
  static Future<void> onRequestApproved(String eventId, String eventName, String passengerName, String passengerId) async {
    await _firestore
        .collection('participants')
        .doc(passengerId)
        .collection('notifications')
        .add({
      'title': 'Request Approved!',
      'body': 'Great news! Your request to join the carpool for "$eventName" has been approved!',
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'eventId': eventId,
      'type': 'request_approved',
    });

    // Also try organizers collection
    try {
      await _firestore
          .collection('organizers')
          .doc(passengerId)
          .collection('notifications')
          .add({
        'title': 'Request Approved!',
        'body': 'Great news! Your request to join the carpool for "$eventName" has been approved!',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'eventId': eventId,
        'type': 'request_approved',
      });
    } catch (e) {
      // Ignore if organizer document doesn't exist
    }
  }

  // Trigger notification when driver declines passenger request
  static Future<void> onRequestDeclined(String eventId, String eventName, String passengerName, String passengerId, String? reason) async {
    String body = 'Your request to join the carpool for "$eventName" was declined.';
    if (reason != null && reason.isNotEmpty) {
      body += ' Reason: $reason';
    }

    await _firestore
        .collection('participants')
        .doc(passengerId)
        .collection('notifications')
        .add({
      'title': 'Request Declined',
      'body': body,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'eventId': eventId,
      'type': 'request_declined',
    });

    // Also try organizers collection
    try {
      await _firestore
          .collection('organizers')
          .doc(passengerId)
          .collection('notifications')
          .add({
        'title': 'Request Declined',
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'eventId': eventId,
        'type': 'request_declined',
      });
    } catch (e) {
      // Ignore if organizer document doesn't exist
    }
  }

  // Trigger notification when event is completed for rating/review
  static Future<void> onEventCompleted(String eventId, String eventName, String participantId) async {
    await _firestore
        .collection('participants')
        .doc(participantId)
        .collection('notifications')
        .add({
      'title': 'Event Complete! Rate Your Experience',
      'body': '"$eventName" has concluded. Share your thoughts and rate the organizer to help others!',
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'eventId': eventId,
      'type': 'event_completed',
      'requiresAction': true,
    });

    // Also try organizers collection
    try {
      await _firestore
          .collection('organizers')
          .doc(participantId)
          .collection('notifications')
          .add({
        'title': 'Event Complete! Rate Your Experience',
        'body': '"$eventName" has concluded. Share your thoughts and rate the organizer to help others!',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'eventId': eventId,
        'type': 'event_completed',
        'requiresAction': true,
      });
    } catch (e) {
      // Ignore if organizer document doesn't exist
    }
  }

  // Trigger notification to all participants when a new event is published
  static Future<void> onNewEventPublished(String eventId, String eventName, String organizerName, String location) async {
    try {
      // Get all participants (users who have registered for any event)
      final participantsQuery = await _firestore.collection('participants').get();
      
      final batch = _firestore.batch();
      
      for (final participantDoc in participantsQuery.docs) {
        final notifRef = _firestore
            .collection('participants')
            .doc(participantDoc.id)
            .collection('notifications')
            .doc();
        
        batch.set(notifRef, {
          'title': 'New Event Available!',
          'body': 'Check out "$eventName" by $organizerName in $location. Register now!',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'eventId': eventId,
          'type': 'new_event_available',
        });
      }
      
      if (participantsQuery.docs.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {
      print('Error sending new event notifications: $e');
    }
  }

  // Trigger notification to participants when event starts
  static Future<void> onEventStarted(String eventId, String eventName, Map<String, dynamic> participants) async {
    try {
      final batch = _firestore.batch();
      
      for (final participantId in participants.keys) {
        final participant = participants[participantId] as Map<String, dynamic>?;
        if (participant == null) continue;
        
        final participantStatus = participant['status'] as String? ?? '';
        // Only notify active participants
        if (participantStatus == 'registered' || participantStatus == 'confirmed' || participantStatus == 'active' || participantStatus.isEmpty) {
          final notifRef = _firestore
              .collection('participants')
              .doc(participantId)
              .collection('notifications')
              .doc();
          
          batch.set(notifRef, {
            'title': 'Event Started! 🚀',
            'body': '"$eventName" has started! You can now check in using the QR code.',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'eventId': eventId,
            'type': 'event_started',
          });
        }
      }
      
      if (participants.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {
      print('Error sending event started notifications: $e');
    }
  }
} 