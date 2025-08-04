import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hikefue5/services/payment_service.dart';

class EventDeletionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Check if event can be deleted
  static Future<Map<String, dynamic>> canDeleteEvent(String eventId) async {
    try {
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) {
        return {
          'canDelete': false,
          'reason': 'Event not found',
        };
      }

      final eventData = eventDoc.data() as Map<String, dynamic>;
      final eventDate = (eventData['date'] as Timestamp).toDate();
      final now = DateTime.now();
      final participants = eventData['participants'] ?? {};
      final hasPaidParticipants = participants.values.any((p) => 
        p is Map && p['paymentStatus'] == 'paid'
      );

      // Check if event has already passed
      if (eventDate.isBefore(now)) {
        return {
          'canDelete': false,
          'reason': 'Event has already passed',
        };
      }

      // Check if event is too close (within 24 hours)
      final hoursUntilEvent = eventDate.difference(now).inHours;
      if (hoursUntilEvent < 24) {
        return {
          'canDelete': false,
          'reason': 'Event is within 24 hours and cannot be deleted',
        };
      }

      // Check if there are paid participants
      if (hasPaidParticipants) {
        return {
          'canDelete': true,
          'requiresRefund': true,
          'participantCount': participants.length,
          'paidCount': participants.values.where((p) => 
            p is Map && p['paymentStatus'] == 'paid'
          ).length,
        };
      }

      return {
        'canDelete': true,
        'requiresRefund': false,
        'participantCount': participants.length,
      };
    } catch (e) {
      return {
        'canDelete': false,
        'reason': 'Error checking event: $e',
      };
    }
  }

  // Delete event with proper cleanup
  static Future<Map<String, dynamic>> deleteEvent(String eventId) async {
    try {
      print('Starting deletion process for event: $eventId');
      
      // Check if can delete
      final canDeleteResult = await canDeleteEvent(eventId);
      print('Can delete result: $canDeleteResult');
      
      if (!canDeleteResult['canDelete']) {
        return {
          'success': false,
          'message': canDeleteResult['reason'],
        };
      }

      // Get event data
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) {
        return {
          'success': false,
          'message': 'Event not found',
        };
      }
      
      final eventData = eventDoc.data() as Map<String, dynamic>;
      final eventName = eventData['name'] ?? 'Event';
      final participants = eventData['participants'] ?? {};
      final requiresRefund = canDeleteResult['requiresRefund'] ?? false;

      print('Event data retrieved. Participants: ${participants.length}, Requires refund: $requiresRefund');

      // Start batch operations
      final batch = _firestore.batch();

      // 1. Handle refunds if needed
      if (requiresRefund) {
        print('Processing refunds...');
        final refundResults = await _processRefunds(eventId, participants);
        print('Refund results: $refundResults');
        if (!refundResults['success']) {
          return {
            'success': false,
            'message': 'Failed to process refunds: ${refundResults['message']}',
          };
        }
      }

      // 2. Send notifications to all participants
      print('Sending notifications...');
      await _notifyParticipants(eventId, eventName, participants.keys.toList());

      // 3. Delete carpool arrangements
      print('Deleting carpools...');
      await _deleteCarpools(eventId);

      // 4. Update participant records
      print('Updating participant records...');
      await _updateParticipantRecords(eventId, participants.keys.toList());

      // 5. Delete the event
      print('Deleting event document...');
      batch.delete(eventDoc.reference);

      // 6. Delete related documents (notifications, etc.)
      print('Deleting related documents...');
      await _deleteRelatedDocuments(eventId);

      // Commit all changes
      print('Committing batch...');
      await batch.commit();

      print('Event deletion completed successfully');

      return {
        'success': true,
        'message': 'Event deleted successfully',
        'participantsNotified': participants.length,
        'refundsProcessed': requiresRefund,
      };

    } catch (e) {
      print('Error in deleteEvent: $e');
      return {
        'success': false,
        'message': 'Error deleting event: $e',
      };
    }
  }

  // Process refunds for paid participants
  static Future<Map<String, dynamic>> _processRefunds(
    String eventId, 
    Map<String, dynamic> participants
  ) async {
    try {
      print('Processing refunds for event: $eventId');
      
      final paidParticipants = participants.entries.where((entry) {
        final participant = entry.value as Map<String, dynamic>;
        return participant['paymentStatus'] == 'paid';
      }).toList();

      print('Found ${paidParticipants.length} paid participants');

      if (paidParticipants.isEmpty) {
        return {'success': true, 'message': 'No refunds needed'};
      }

      // Process refunds through your payment service
      for (final entry in paidParticipants) {
        final participantId = entry.key;
        final participant = entry.value as Map<String, dynamic>;
        final paymentId = participant['paymentId'];
        final amount = participant['amount'] ?? 0.0;

        print('Processing refund for participant $participantId, paymentId: $paymentId, amount: $amount');

        if (paymentId != null && amount > 0) {
          try {
            // Call your payment service to process refund
            final refundResult = await PaymentService.processRefund(
              paymentId: paymentId,
              amount: amount,
              reason: 'Event cancelled by organizer',
            );

            print('Refund result for $participantId: $refundResult');

            if (!refundResult['success']) {
              // Log the error but continue with other refunds
              print('Failed to refund $participantId: ${refundResult['message']}');
            }
          } catch (refundError) {
            print('Exception during refund for $participantId: $refundError');
            // Continue with other refunds
          }
        } else {
          print('Skipping refund for $participantId - missing paymentId or amount');
        }
      }

      return {'success': true, 'message': 'Refunds processed'};
    } catch (e) {
      print('Error in _processRefunds: $e');
      return {'success': false, 'message': 'Error processing refunds: $e'};
    }
  }

  // Notify all participants about event deletion
  static Future<void> _notifyParticipants(
    String eventId, 
    String eventName, 
    List<String> participantIds
  ) async {
    try {
      print('Sending notifications to ${participantIds.length} participants');
      
      final batch = _firestore.batch();

      for (final participantId in participantIds) {
        // First notification: Event deleted
        final eventDeletedNotifRef = _firestore
            .collection('participants')
            .doc(participantId)
            .collection('notifications')
            .doc();

        batch.set(eventDeletedNotifRef, {
          'title': 'Event Deleted',
          'body': 'The event "$eventName" has been deleted by the organizer.',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'eventId': eventId,
          'type': 'event_deleted',
        });

        // Second notification: Refund information
        final refundNotifRef = _firestore
            .collection('participants')
            .doc(participantId)
            .collection('notifications')
            .doc();

        batch.set(refundNotifRef, {
          'title': 'Payment Refund',
          'body': 'If you made a payment for "$eventName", your refund will be processed within 3 business days.',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'eventId': eventId,
          'type': 'refund_notice',
        });
      }

      await batch.commit();
      print('Successfully sent notifications to all participants');
    } catch (e) {
      print('Error sending notifications: $e');
      // Don't throw error to prevent deletion from failing due to notification issues
    }
  }

  // Delete carpool arrangements for the event
  static Future<void> _deleteCarpools(String eventId) async {
    try {
      // Delete carpools from the event
      final carpoolsSnapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('carpools')
          .get();

      final batch = _firestore.batch();
      for (final doc in carpoolsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Also delete from global carpools collection if you have one
      final globalCarpoolsSnapshot = await _firestore
          .collection('carpools')
          .where('eventId', isEqualTo: eventId)
          .get();

      final globalBatch = _firestore.batch();
      for (final doc in globalCarpoolsSnapshot.docs) {
        globalBatch.delete(doc.reference);
      }
      await globalBatch.commit();
    } catch (e) {
      print('Error deleting carpools: $e');
    }
  }

  // Update participant records to remove the event
  static Future<void> _updateParticipantRecords(
    String eventId, 
    List<String> participantIds
  ) async {
    try {
      final batch = _firestore.batch();

      for (final participantId in participantIds) {
        // Remove event from participant's events list
        final participantRef = _firestore.collection('participants').doc(participantId);
        batch.update(participantRef, {
          'events.$eventId': FieldValue.delete(),
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error updating participant records: $e');
    }
  }

  // Delete related documents
  static Future<void> _deleteRelatedDocuments(String eventId) async {
    try {
      // Delete event-specific notifications
      final notificationsSnapshot = await _firestore
          .collection('notifications')
          .where('eventId', isEqualTo: eventId)
          .get();

      final batch = _firestore.batch();
      for (final doc in notificationsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Error deleting related documents: $e');
    }
  }

  // Alternative: Cancel event instead of deleting (safer option)
  static Future<Map<String, dynamic>> cancelEvent(String eventId) async {
    try {
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) {
        return {
          'success': false,
          'message': 'Event not found',
        };
      }

      final eventData = eventDoc.data() as Map<String, dynamic>;
      final eventName = eventData['name'] ?? 'Event';
      final participants = eventData['participants'] ?? {};

      // Update event status to cancelled
      await _firestore.collection('events').doc(eventId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': _auth.currentUser?.uid,
      });

      // Send notifications (Firebase Function will handle this)
      // The notifyOnEventCancellation function will automatically trigger

      return {
        'success': true,
        'message': 'Event cancelled successfully',
        'participantsNotified': participants.length,
      };

    } catch (e) {
      return {
        'success': false,
        'message': 'Error cancelling event: $e',
      };
    }
  }
} 