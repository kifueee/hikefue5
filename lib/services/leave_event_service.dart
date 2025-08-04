import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'payment_service.dart';
import 'notification_triggers.dart';

class LeaveEventService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Comprehensive method to handle leaving an event with all business logic
  static Future<Map<String, dynamic>> leaveEvent({
    required String eventId,
    String reason = 'Personal reasons',
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'User not logged in',
        };
      }

      // Get event and participant data
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) {
        return {
          'success': false,
          'message': 'Event not found',
        };
      }

      final eventData = eventDoc.data() as Map<String, dynamic>;
      final participants = eventData['participants'] as Map<String, dynamic>? ?? {};
      
      if (!participants.containsKey(currentUser.uid)) {
        return {
          'success': false,
          'message': 'You are not registered for this event',
        };
      }

      final participantData = participants[currentUser.uid] as Map<String, dynamic>;
      final participantName = participantData['name'] ?? 'Unknown';
      final eventName = eventData['name'] ?? 'Event';
      final organizerId = eventData['organizerId'];
      final eventDate = eventData['date'];

      // Check if event has already started
      if (eventDate != null) {
        final eventDateTime = (eventDate as Timestamp).toDate();
        final now = DateTime.now();
        
        if (eventDateTime.isBefore(now)) {
          return {
            'success': false,
            'message': 'Cannot leave an event that has already started',
          };
        }
        
        // Check if leaving too close to event date (within 24 hours)
        final hoursDifference = eventDateTime.difference(now).inHours;
        if (hoursDifference < 24) {
          // Allow leaving but with penalties/restrictions
          return {
            'success': false,
            'message': 'Cannot leave event within 24 hours of start time. Please contact the organizer.',
          };
        }
      }

      // Start the leaving process
      final results = <String, dynamic>{
        'success': true,
        'actions_taken': [],
        'warnings': [],
      };

      // Get all participants to be removed (main + additional)
      final participantsToRemove = await _getParticipantsToRemove(eventId, currentUser.uid, eventData);

      // 1. Handle payment refunds
      final refundResult = await _handlePaymentRefund(
        eventId: eventId,
        participantId: currentUser.uid,
        participantData: participantData,
        eventName: eventName,
        totalParticipants: participantsToRemove.length,
      );
      
      if (refundResult['processed']) {
        results['actions_taken'].add('Payment refund initiated: ${refundResult['message']}');
      }

      // 2. Handle carpool cleanup
      final carpoolResult = await _handleCarpoolCleanup(
        eventId: eventId,
        participantId: currentUser.uid,
        participantName: participantName,
        eventName: eventName,
      );
      
      if (carpoolResult['carpools_affected'] > 0) {
        results['actions_taken'].add('${carpoolResult['carpools_affected']} carpool(s) updated');
        if (carpoolResult['warnings'].isNotEmpty) {
          results['warnings'].addAll(carpoolResult['warnings']);
        }
      }

      // 3. Remove participant and any additional participants they registered from event
      final updateData = <String, dynamic>{};
      for (final participantId in participantsToRemove) {
        updateData['participants.$participantId'] = FieldValue.delete();
      }
      
      await _firestore.collection('events').doc(eventId).update(updateData);

      final totalRemoved = participantsToRemove.length;
      if (totalRemoved > 1) {
        results['actions_taken'].add('Removed $totalRemoved participants from event registration (including ${totalRemoved - 1} additional participant${totalRemoved - 1 > 1 ? 's' : ''})');
      } else {
        results['actions_taken'].add('Removed from event registration');
      }

      // 4. Send enhanced notification to organizer
      if (organizerId != null) {
        await _sendOrganizerNotification(
          organizerId: organizerId,
          eventId: eventId,
          eventName: eventName,
          participantName: participantName,
          reason: reason,
          refundAmount: refundResult['amount'],
          carpoolsAffected: carpoolResult['carpools_affected'],
          totalParticipantsRemoved: participantsToRemove.length,
        );
        
        results['actions_taken'].add('Organizer notified of departure');
      }

      // 5. Update participant's event history
      await _updateParticipantHistory(
        participantId: currentUser.uid,
        eventId: eventId,
        eventName: eventName,
        reason: reason,
      );

      // 6. Send confirmation notification to participant
      await _sendParticipantConfirmation(
        participantId: currentUser.uid,
        eventName: eventName,
        refundAmount: refundResult['amount'],
      );

      results['message'] = 'Successfully left the event';
      return results;

    } catch (e) {
      return {
        'success': false,
        'message': 'Error leaving event: $e',
      };
    }
  }

  /// Handle payment refunds when leaving an event
  static Future<Map<String, dynamic>> _handlePaymentRefund({
    required String eventId,
    required String participantId,
    required Map<String, dynamic> participantData,
    required String eventName,
    int totalParticipants = 1,
  }) async {
    try {
      final paymentStatus = participantData['paymentStatus'];
      final paymentId = participantData['paymentId'];
      final amount = participantData['amount'] ?? 0.0;

      // Only process refund if payment was made
      if (paymentStatus == 'paid' && paymentId != null && amount > 0) {
        // Calculate refund amount for all participants (could apply cancellation fees here)
        final totalPaidAmount = amount * totalParticipants;
        final refundAmount = _calculateRefundAmount(totalPaidAmount);
        
        final refundResult = await PaymentService.processRefund(
          paymentId: paymentId,
          amount: refundAmount,
          reason: 'Participant left event: $eventName (${totalParticipants} participant${totalParticipants > 1 ? 's' : ''})',
        );

        if (refundResult['success']) {
          return {
            'processed': true,
            'amount': refundAmount,
            'message': 'Refund of RM${refundAmount.toStringAsFixed(2)} initiated',
          };
        } else {
          return {
            'processed': false,
            'amount': 0.0,
            'message': 'Refund failed: ${refundResult['message']}',
          };
        }
      }

      return {
        'processed': false,
        'amount': 0.0,
        'message': 'No payment to refund',
      };
    } catch (e) {
      return {
        'processed': false,
        'amount': 0.0,
        'message': 'Error processing refund: $e',
      };
    }
  }

  /// Calculate refund amount (can apply cancellation fees)
  static double _calculateRefundAmount(double originalAmount) {
    // For now, return full amount
    // You could implement cancellation fee logic here
    // e.g., 10% cancellation fee: return originalAmount * 0.9;
    return originalAmount;
  }

  /// Handle carpool cleanup when participant leaves
  static Future<Map<String, dynamic>> _handleCarpoolCleanup({
    required String eventId,
    required String participantId,
    required String participantName,
    required String eventName,
  }) async {
    try {
      int carpoolsAffected = 0;
      final warnings = <String>[];

      // Check if participant is a driver in any carpools
      final driverCarpools = await _firestore
          .collection('carpools')
          .where('eventId', isEqualTo: eventId)
          .where('driverId', isEqualTo: participantId)
          .where('status', isEqualTo: 'active')
          .get();

      // Cancel driver's carpools
      for (final carpoolDoc in driverCarpools.docs) {
        // Get passengers to notify them
        final passengersSnapshot = await carpoolDoc.reference
            .collection('passengers')
            .get();
        
        if (passengersSnapshot.docs.isNotEmpty) {
          final passengerIds = passengersSnapshot.docs
              .map((doc) => doc.data()['userId'] as String)
              .toList();

          // Notify passengers about carpool cancellation
          await NotificationTriggers.onCarpoolCancelled(
            eventId,
            eventName,
            participantName,
            passengerIds,
          );

          warnings.add('${passengersSnapshot.docs.length} passengers notified of carpool cancellation');
        }

        // Cancel the carpool
        await carpoolDoc.reference.update({
          'status': 'cancelled',
          'cancelledBy': participantId,
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancellationReason': 'Driver left the event',
        });

        carpoolsAffected++;
      }

      // Check if participant is a passenger in any carpools
      final allCarpools = await _firestore
          .collection('carpools')
          .where('eventId', isEqualTo: eventId)
          .where('status', isEqualTo: 'active')
          .get();

      for (final carpoolDoc in allCarpools.docs) {
        final passengersSnapshot = await carpoolDoc.reference
            .collection('passengers')
            .where('userId', isEqualTo: participantId)
            .get();

        if (passengersSnapshot.docs.isNotEmpty) {
          final passengerData = passengersSnapshot.docs.first.data();
          final numberOfPassengers = passengerData['numberOfPassengers'] as int;
          final carpoolData = carpoolDoc.data();

          // Remove passenger from carpool
          await passengersSnapshot.docs.first.reference.delete();

          // Update available seats
          await carpoolDoc.reference.update({
            'availableSeats': carpoolData['availableSeats'] + numberOfPassengers,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Notify driver
          await NotificationTriggers.onPassengerCancelledCarpool(
            eventId,
            eventName,
            participantName,
            numberOfPassengers,
            carpoolData['driverId'],
          );

          carpoolsAffected++;
        }
      }

      return {
        'carpools_affected': carpoolsAffected,
        'warnings': warnings,
      };
    } catch (e) {
      return {
        'carpools_affected': 0,
        'warnings': ['Error handling carpool cleanup: $e'],
      };
    }
  }

  /// Get all participants that should be removed (main + additional participants)
  static Future<List<String>> _getParticipantsToRemove(
    String eventId,
    String userId,
    Map<String, dynamic> eventData,
  ) async {
    final participants = eventData['participants'] as Map<String, dynamic>? ?? {};
    final participantsToRemove = <String>[];
    
    // Add the main participant
    if (participants.containsKey(userId)) {
      participantsToRemove.add(userId);
    }
    
    // Find all additional participants added by this user
    participants.forEach((participantId, participantData) {
      final data = participantData as Map<String, dynamic>;
      if (data['addedBy'] == userId && participantId != userId) {
        participantsToRemove.add(participantId);
      }
    });
    
    return participantsToRemove;
  }

  /// Send enhanced notification to organizer
  static Future<void> _sendOrganizerNotification({
    required String organizerId,
    required String eventId,
    required String eventName,
    required String participantName,
    required String reason,
    double? refundAmount,
    int? carpoolsAffected,
    int? totalParticipantsRemoved,
  }) async {
    try {
      String body = '$participantName has left your event "$eventName".';
      
      if (totalParticipantsRemoved != null && totalParticipantsRemoved > 1) {
        body += '\nTotal participants removed: $totalParticipantsRemoved (including ${totalParticipantsRemoved - 1} additional participant${totalParticipantsRemoved - 1 > 1 ? 's' : ''})';
      }
      
      if (reason.isNotEmpty && reason != 'Personal reasons') {
        body += '\nReason: $reason';
      }
      
      if (refundAmount != null && refundAmount > 0) {
        body += '\nRefund processed: RM${refundAmount.toStringAsFixed(2)}';
      }
      
      if (carpoolsAffected != null && carpoolsAffected > 0) {
        body += '\n$carpoolsAffected carpool(s) affected';
      }

      // Use organizer notification service
      await _firestore
          .collection('organizers')
          .doc(organizerId)
          .collection('notifications')
          .add({
        'title': 'Participant Left Event',
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'participant_left',
        'eventId': eventId,
        'additionalData': {
          'participantName': participantName,
          'reason': reason,
          'refundAmount': refundAmount ?? 0.0,
          'carpoolsAffected': carpoolsAffected ?? 0,
          'totalParticipantsRemoved': totalParticipantsRemoved ?? 1,
        },
      });
    } catch (e) {
      print('Error sending organizer notification: $e');
    }
  }

  /// Update participant's event history
  static Future<void> _updateParticipantHistory({
    required String participantId,
    required String eventId,
    required String eventName,
    required String reason,
  }) async {
    try {
      await _firestore
          .collection('participants')
          .doc(participantId)
          .collection('event_history')
          .doc(eventId)
          .set({
        'eventId': eventId,
        'eventName': eventName,
        'action': 'left',
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating participant history: $e');
    }
  }

  /// Send confirmation notification to participant
  static Future<void> _sendParticipantConfirmation({
    required String participantId,
    required String eventName,
    double? refundAmount,
  }) async {
    try {
      String body = 'You have successfully left "$eventName".';
      
      if (refundAmount != null && refundAmount > 0) {
        body += ' A refund of RM${refundAmount.toStringAsFixed(2)} has been initiated and will be processed within 3-5 business days.';
      }

      await _firestore
          .collection('participants')
          .doc(participantId)
          .collection('notifications')
          .add({
        'title': 'Left Event Successfully',
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'eventId': null, // No longer associated with the event
      });
    } catch (e) {
      print('Error sending participant confirmation: $e');
    }
  }

  /// Check if participant can leave event (validation)
  static Future<Map<String, dynamic>> canLeaveEvent(String eventId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {
          'canLeave': false,
          'reason': 'User not logged in',
        };
      }

      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) {
        return {
          'canLeave': false,
          'reason': 'Event not found',
        };
      }

      final eventData = eventDoc.data() as Map<String, dynamic>;
      final participants = eventData['participants'] as Map<String, dynamic>? ?? {};
      
      if (!participants.containsKey(currentUser.uid)) {
        return {
          'canLeave': false,
          'reason': 'You are not registered for this event',
        };
      }

      final eventDate = eventData['date'];
      if (eventDate != null) {
        final eventDateTime = (eventDate as Timestamp).toDate();
        final now = DateTime.now();
        
        if (eventDateTime.isBefore(now)) {
          return {
            'canLeave': false,
            'reason': 'Cannot leave an event that has already started',
          };
        }
        
        final hoursDifference = eventDateTime.difference(now).inHours;
        if (hoursDifference < 24) {
          return {
            'canLeave': false,
            'reason': 'Cannot leave event within 24 hours of start time',
            'contactOrganizer': true,
          };
        }
      }

      return {
        'canLeave': true,
        'message': 'You can leave this event',
      };
    } catch (e) {
      return {
        'canLeave': false,
        'reason': 'Error checking leave eligibility: $e',
      };
    }
  }
}