import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hikefue5/models/payment_status.dart';
import 'package:hikefue5/services/notification_service.dart';
import 'package:hikefue5/services/toyyibpay_service.dart';
import 'package:flutter/material.dart';

class PaymentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a payment record when user registers for an event
  static Future<PaymentInfo> createPayment({
    required String eventId,
    required double amount,
    required int deadlineDays,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User must be logged in to create payment');
    }

    final deadline = DateTime.now().add(Duration(days: deadlineDays));
    
    final paymentData = {
      'eventId': eventId,
      'userId': currentUser.uid,
      'amount': amount,
      'status': PaymentStatus.pending.toString().split('.').last,
      'createdAt': FieldValue.serverTimestamp(),
      'deadline': Timestamp.fromDate(deadline),
    };

    final docRef = await _firestore.collection('payments').add(paymentData);
    final doc = await docRef.get();
    
    // Update participant payment details to reflect the total amount
    final eventRef = _firestore.collection('events').doc(eventId);
    final eventDoc = await eventRef.get();
    
    if (eventDoc.exists) {
      final eventData = eventDoc.data() as Map<String, dynamic>;
      final participants = eventData['participants'] as Map<String, dynamic>? ?? {};
      
      // Find all participants added by the paying user
      final participantsToUpdate = <String>[];
      participants.forEach((participantId, participantData) {
        final participant = participantData as Map<String, dynamic>;
        if (participant['addedBy'] == currentUser.uid) {
          participantsToUpdate.add(participantId);
        }
      });
      
      // Update payment details for all participants added by this user
      final updates = <String, dynamic>{};
      for (final participantId in participantsToUpdate) {
        final participantField = 'participants.$participantId';
        updates['$participantField.paymentDetails.amount'] = amount;
        updates['$participantField.paymentId'] = docRef.id;
      }
      
      if (updates.isNotEmpty) {
        await eventRef.update(updates);
      }
    }
    
    return PaymentInfo.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
  }

  // Get payment info for a specific event and user
  static Future<PaymentInfo?> getPayment(String eventId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    final querySnapshot = await _firestore
        .collection('payments')
        .where('eventId', isEqualTo: eventId)
        .where('userId', isEqualTo: currentUser.uid)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) return null;

    final doc = querySnapshot.docs.first;
    return PaymentInfo.fromFirestore(doc.data(), doc.id);
  }

  // Get all payments for current user
  static Stream<List<PaymentInfo>> getUserPayments() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('payments')
        .where('userId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentInfo.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get pending payments that are about to expire
  static Stream<List<PaymentInfo>> getExpiringPayments() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    final now = DateTime.now();
    final warningThreshold = now.add(const Duration(days: 1)); // 1 day warning

    return _firestore
        .collection('payments')
        .where('userId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: PaymentStatus.pending.toString().split('.').last)
        .where('deadline', isLessThan: Timestamp.fromDate(warningThreshold))
        .where('deadline', isGreaterThan: Timestamp.fromDate(now))
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentInfo.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Mark payment as completed
  static Future<void> completePayment(String paymentId, String transactionId) async {
    await _firestore.collection('payments').doc(paymentId).update({
      'status': PaymentStatus.completed.toString().split('.').last,
      'completedAt': FieldValue.serverTimestamp(),
      'transactionId': transactionId,
    });

    // Create success notification
    final payment = await _firestore.collection('payments').doc(paymentId).get();
    if (payment.exists) {
      final paymentData = PaymentInfo.fromFirestore(payment.data()!, paymentId);
      await NotificationService.createPaymentSuccessNotification(paymentData);

      // Get event details to find all participants added by this user
      final eventRef = _firestore.collection('events').doc(paymentData.eventId);
      final eventDoc = await eventRef.get();
      
      if (eventDoc.exists) {
        final eventData = eventDoc.data() as Map<String, dynamic>;
        final participants = eventData['participants'] as Map<String, dynamic>? ?? {};
        
        // Find all participants added by the paying user
        final participantsToUpdate = <String>[];
        participants.forEach((participantId, participantData) {
          final participant = participantData as Map<String, dynamic>;
          if (participant['addedBy'] == paymentData.userId) {
            participantsToUpdate.add(participantId);
          }
        });
        
        // Update payment status for all participants added by this user
        final updates = <String, dynamic>{};
        for (final participantId in participantsToUpdate) {
          final participantField = 'participants.$participantId';
          updates['$participantField.paymentStatus'] = 'paid';
          updates['$participantField.paymentDetails'] = {
            'paid': true,
            'transactionId': transactionId,
            'completedAt': FieldValue.serverTimestamp(),
          };
        }
        
        if (updates.isNotEmpty) {
          await eventRef.update(updates);
        }
      }
    }
  }

  // Mark payment as failed
  static Future<void> failPayment(String paymentId, String reason) async {
    await _firestore.collection('payments').doc(paymentId).update({
      'status': PaymentStatus.failed.toString().split('.').last,
      'failureReason': reason,
    });

    // Create failure notification
    final payment = await _firestore.collection('payments').doc(paymentId).get();
    if (payment.exists) {
      final paymentData = PaymentInfo.fromFirestore(payment.data()!, paymentId);
      await NotificationService.createPaymentFailureNotification(paymentData, reason);
    }
  }

  // Cancel payment
  static Future<void> cancelPayment(String paymentId) async {
    await _firestore.collection('payments').doc(paymentId).update({
      'status': PaymentStatus.cancelled.toString().split('.').last,
    });
  }

  // Update expired payments (should be called periodically)
  static Future<void> updateExpiredPayments() async {
    final now = DateTime.now();
    
    final expiredPayments = await _firestore
        .collection('payments')
        .where('status', isEqualTo: PaymentStatus.pending.toString().split('.').last)
        .where('deadline', isLessThan: Timestamp.fromDate(now))
        .get();

    final batch = _firestore.batch();
    for (final doc in expiredPayments.docs) {
      batch.update(doc.reference, {
        'status': PaymentStatus.expired.toString().split('.').last,
      });
    }
    
    if (expiredPayments.docs.isNotEmpty) {
      await batch.commit();
    }
  }

  // Get payment statistics for user
  static Future<Map<String, int>> getPaymentStats() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return {};

    final payments = await _firestore
        .collection('payments')
        .where('userId', isEqualTo: currentUser.uid)
        .get();

    final stats = <String, int>{};
    for (final doc in payments.docs) {
      final payment = PaymentInfo.fromFirestore(doc.data(), doc.id);
      final status = payment.status.toString().split('.').last;
      stats[status] = (stats[status] ?? 0) + 1;
    }

    return stats;
  }

  // Check if user has pending payments for an event
  static Future<bool> hasPendingPayment(String eventId) async {
    final payment = await getPayment(eventId);
    return payment?.isPending ?? false;
  }

  // Process refund for a payment
  static Future<Map<String, dynamic>> processRefund({
    required String paymentId,
    required double amount,
    required String reason,
  }) async {
    try {
      // Update payment status to refunded
      await _firestore.collection('payments').doc(paymentId).update({
        'status': PaymentStatus.refunded.toString().split('.').last,
        'refundedAt': FieldValue.serverTimestamp(),
        'refundReason': reason,
        'refundAmount': amount,
      });

      // Update payment status for all participants added by this user
      final paymentDoc = await _firestore.collection('payments').doc(paymentId).get();
      if (paymentDoc.exists) {
        final paymentData = paymentDoc.data() as Map<String, dynamic>;
        final eventId = paymentData['eventId'];
        final userId = paymentData['userId'];

        if (eventId != null && userId != null) {
          final eventRef = _firestore.collection('events').doc(eventId);
          final eventDoc = await eventRef.get();
          
          if (eventDoc.exists) {
            final eventData = eventDoc.data() as Map<String, dynamic>;
            final participants = eventData['participants'] as Map<String, dynamic>? ?? {};
            
            // Find all participants added by the user getting refunded
            final participantsToUpdate = <String>[];
            participants.forEach((participantId, participantData) {
              final participant = participantData as Map<String, dynamic>;
              if (participant['addedBy'] == userId) {
                participantsToUpdate.add(participantId);
              }
            });
            
            // Update refund status for all participants added by this user
            final updates = <String, dynamic>{};
            for (final participantId in participantsToUpdate) {
              final participantField = 'participants.$participantId';
              updates['$participantField.paymentStatus'] = 'refunded';
              updates['$participantField.refundDetails'] = {
                'refunded': true,
                'amount': amount,
                'reason': reason,
                'refundedAt': FieldValue.serverTimestamp(),
              };
            }
            
            if (updates.isNotEmpty) {
              await eventRef.update(updates);
            }
          }
        }
      }

      return {
        'success': true,
        'message': 'Refund processed successfully',
        'amount': amount,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error processing refund: $e',
      };
    }
  }

  // Get event details for payment
  static Future<Map<String, dynamic>?> getEventDetails(String eventId) async {
    final doc = await _firestore.collection('events').doc(eventId).get();
    if (!doc.exists) return null;
    
    final data = doc.data() as Map<String, dynamic>;
    return {
      'id': doc.id,
      'name': data['name'] ?? 'Unknown Event',
      'date': data['date'],
      'location': data['location'],
      'pricing': data['pricing'],
      'media': data['media'],
    };
  }

  // Create ToyyibPay payment
  static Future<Map<String, dynamic>> createToyyibPayPayment({
    required String eventId,
    required double amount,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required BuildContext context,
  }) async {
    try {
      // Get event details
      final eventDetails = await getEventDetails(eventId);
      if (eventDetails == null) {
        return {
          'success': false,
          'message': 'Event not found',
        };
      }

      // Create ToyyibPay bill directly
      final billResult = await ToyyibPayService.createBill(
        billName: 'Event: ${eventDetails['name']}',
        billDescription: 'Payment for event registration: ${eventDetails['name']}',
        amount: amount,
        customerName: customerName,
        customerEmail: customerEmail,
        customerPhone: customerPhone,
        returnUrl: 'https://dev.toyyibpay.com/payment-success',
        callbackUrl: 'https://dev.toyyibpay.com/payment-callback',
      );

      if (billResult['success']) {
        // Create payment record with ToyyibPay details
        final currentUser = _auth.currentUser;
        if (currentUser == null) {
          return {
            'success': false,
            'message': 'User must be logged in to create payment',
          };
        }

        final paymentData = {
          'eventId': eventId,
          'userId': currentUser.uid,
          'amount': amount,
          'status': PaymentStatus.pending.toString().split('.').last,
          'createdAt': FieldValue.serverTimestamp(),
          'deadline': Timestamp.fromDate(DateTime.now().add(const Duration(days: 3))),
          'toyyibpayBillCode': billResult['billCode'],
          'toyyibpayOrderId': billResult['orderId'],
          'paymentGateway': 'toyyibpay',
        };

        final docRef = await _firestore.collection('payments').add(paymentData);

        // Launch payment and wait for result
        final paymentResult = await ToyyibPayService.launchPayment(
          context,
          billResult['paymentUrl'],
        );

        // Handle payment result
        if (paymentResult == 'success') {
          // Payment was successful, complete it
          await completeToyyibPayPayment(docRef.id, billResult['orderId']);
          
          return {
            'success': true,
            'paymentId': docRef.id,
            'billCode': billResult['billCode'],
            'orderId': billResult['orderId'],
            'paymentCompleted': true,
            'message': 'Payment completed successfully',
          };
        } else if (paymentResult == 'cancelled') {
          // Payment was cancelled, fail it
          await failPayment(docRef.id, 'Payment cancelled by user');
          
          return {
            'success': false,
            'paymentId': docRef.id,
            'billCode': billResult['billCode'],
            'orderId': billResult['orderId'],
            'message': 'Payment was cancelled',
          };
        } else {
          // Payment status unknown, return as initiated but not completed
          return {
            'success': true,
            'paymentId': docRef.id,
            'billCode': billResult['billCode'],
            'orderId': billResult['orderId'],
            'paymentCompleted': false,
            'message': 'Payment window closed, status unknown',
          };
        }
      } else {
        return billResult;
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error creating payment: $e',
      };
    }
  }

  // Check ToyyibPay payment status
  static Future<Map<String, dynamic>> checkToyyibPayStatus(String paymentId) async {
    try {
      final paymentDoc = await _firestore.collection('payments').doc(paymentId).get();
      if (!paymentDoc.exists) {
        return {
          'success': false,
          'message': 'Payment not found',
        };
      }

      final paymentData = paymentDoc.data() as Map<String, dynamic>;
      final billCode = paymentData['toyyibpayBillCode'];

      if (billCode == null) {
        return {
          'success': false,
          'message': 'No ToyyibPay bill code found',
        };
      }

      final statusResult = await ToyyibPayService.getBillStatus(billCode);
      
      if (statusResult['success']) {
        final status = statusResult['status'];
        
        // Update payment status based on ToyyibPay response
        if (status == '1') { // Payment successful
          await completePayment(paymentId, statusResult['orderId'] ?? '');
        } else if (status == '2') { // Payment failed
          await failPayment(paymentId, 'Payment failed');
        }
        
        return statusResult;
      } else {
        return statusResult;
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error checking payment status: $e',
      };
    }
  }

  // Complete ToyyibPay payment after successful payment
  static Future<void> completeToyyibPayPayment(String paymentId, String transactionId) async {
    try {
      print('DEBUG: Starting completeToyyibPayPayment for paymentId: $paymentId');
      
      // Complete the payment
      await completePayment(paymentId, transactionId);
      print('DEBUG: Payment completed in payments collection');
      
      // Get payment details to update participant status
      final paymentDoc = await _firestore.collection('payments').doc(paymentId).get();
      if (paymentDoc.exists) {
        final paymentData = paymentDoc.data() as Map<String, dynamic>;
        final eventId = paymentData['eventId'];
        final userId = paymentData['userId'];
        
        print('DEBUG: Found payment data - eventId: $eventId, userId: $userId');
        
        // Update participant status to completed
        final eventRef = _firestore.collection('events').doc(eventId);
        final eventDoc = await eventRef.get();
        
        if (eventDoc.exists) {
          final eventData = eventDoc.data() as Map<String, dynamic>;
          final participants = eventData['participants'] as Map<String, dynamic>? ?? {};
          
          print('DEBUG: Found ${participants.length} participants in event');
          
          // Find all participants added by the paying user
          final participantsToUpdate = <String>[];
          participants.forEach((participantId, participantData) {
            final participant = participantData as Map<String, dynamic>;
            print('DEBUG: Checking participant $participantId - addedBy: ${participant['addedBy']}, current status: ${participant['status']}');
            if (participant['addedBy'] == userId) {
              participantsToUpdate.add(participantId);
              print('DEBUG: Added participant $participantId to update list');
            }
          });
          
          print('DEBUG: Found ${participantsToUpdate.length} participants to update');
          
          // Update participant status to completed
          final updates = <String, dynamic>{};
          for (final participantId in participantsToUpdate) {
            final participantField = 'participants.$participantId';
            updates['$participantField.status'] = 'completed';
            updates['$participantField.paymentStatus'] = 'completed';
            updates['$participantField.paymentDetails'] = {
              'paid': true,
              'paymentStatus': 'completed',
              'transactionId': transactionId,
              'completedAt': FieldValue.serverTimestamp(),
            };
          }
          
          if (updates.isNotEmpty) {
            print('DEBUG: Updating event with changes: $updates');
            await eventRef.update(updates);
            print('DEBUG: Event updated successfully');
          } else {
            print('DEBUG: No participants to update');
          }
        } else {
          print('DEBUG: Event document does not exist');
        }
      } else {
        print('DEBUG: Payment document does not exist');
      }
    } catch (e) {
      print('Error completing ToyyibPay payment: $e');
    }
  }

  // Process ToyyibPay callback
  static Future<void> processToyyibPayCallback(Map<String, dynamic> callbackData) async {
    try {
      final paymentId = callbackData['paymentId'];
      final orderId = callbackData['order_id'];
      final status = callbackData['status_id'];
      final signature = callbackData['signature'];

      // Verify signature
      if (!ToyyibPayService.verifyPaymentSignature(callbackData, signature)) {
        print('Invalid payment signature');
        return;
      }

      // Update payment status
      if (status == '1') { // Payment successful
        await completeToyyibPayPayment(paymentId, orderId);
      } else if (status == '2') { // Payment failed
        await failPayment(paymentId, 'Payment failed');
      }
    } catch (e) {
      print('Error processing ToyyibPay callback: $e');
    }
  }
} 