import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum PaymentStatus {
  pending,
  completed,
  failed,
  expired,
  cancelled,
  refunded
}

class PaymentInfo {
  final String id;
  final String eventId;
  final String userId;
  final double amount;
  final PaymentStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime deadline;
  final String? transactionId;
  final String? failureReason;

  PaymentInfo({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.completedAt,
    required this.deadline,
    this.transactionId,
    this.failureReason,
  });

  factory PaymentInfo.fromFirestore(Map<String, dynamic> data, String id) {
    return PaymentInfo(
      id: id,
      eventId: data['eventId'] ?? '',
      userId: data['userId'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      status: PaymentStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => PaymentStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: data['completedAt'] != null 
          ? (data['completedAt'] as Timestamp?)?.toDate() 
          : null,
      deadline: (data['deadline'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(days: 7)),
      transactionId: data['transactionId'],
      failureReason: data['failureReason'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'eventId': eventId,
      'userId': userId,
      'amount': amount,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'deadline': Timestamp.fromDate(deadline),
      'transactionId': transactionId,
      'failureReason': failureReason,
    };
  }

  bool get isExpired => DateTime.now().isAfter(deadline);
  bool get isPending => status == PaymentStatus.pending && !isExpired;
  bool get isCompleted => status == PaymentStatus.completed;
  bool get isFailed => status == PaymentStatus.failed;
  bool get isCancelled => status == PaymentStatus.cancelled;

  String get statusText {
    if (isExpired) return 'Expired';
    switch (status) {
      case PaymentStatus.pending:
        return 'Pending Payment';
      case PaymentStatus.completed:
        return 'Paid';
      case PaymentStatus.failed:
        return 'Payment Failed';
      case PaymentStatus.expired:
        return 'Expired';
      case PaymentStatus.cancelled:
        return 'Cancelled';
      case PaymentStatus.refunded:
        return 'Refunded';
    }
  }

  Color get statusColor {
    if (isExpired) return Colors.red;
    switch (status) {
      case PaymentStatus.pending:
        return Colors.orange;
      case PaymentStatus.completed:
        return Colors.green;
      case PaymentStatus.failed:
        return Colors.red;
      case PaymentStatus.expired:
        return Colors.red;
      case PaymentStatus.cancelled:
        return Colors.grey;
      case PaymentStatus.refunded:
        return Colors.blue;
    }
  }
} 