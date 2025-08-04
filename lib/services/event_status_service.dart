import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'notification_triggers.dart';
import 'organizer_notification_service.dart';

enum EventStatus {
  draft,       // Event created but not published
  published,   // Event published and visible to participants
  started,     // Event has begun, participants can check in
  ongoing,     // Event is actively happening
  ended,       // Event concluded, ready for ratings/reviews
}

class EventStatusService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Update event status
  static Future<void> updateEventStatus(String eventId, EventStatus status) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      await _firestore.collection('events').doc(eventId).update({
        'eventStatus': status.toString().split('.').last,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'statusUpdatedBy': currentUser.uid,
      });

      // Handle special status transitions
      if (status == EventStatus.ended) {
        await _handleEventCompletion(eventId);
      } else if (status == EventStatus.published) {
        await _handleEventPublished(eventId);
      } else if (status == EventStatus.started) {
        await _handleEventStarted(eventId);
      }
    } catch (e) {
      print('Error updating event status: $e');
      rethrow;
    }
  }

  /// Handle event completion - notify participants to rate/review
  static Future<void> _handleEventCompletion(String eventId) async {
    try {
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) return;

      final eventData = eventDoc.data()!;
      final eventName = eventData['name'] ?? 'Event';
      final participants = eventData['participants'] as Map<String, dynamic>? ?? {};

      // Notify all participants to rate the event
      // Notify only confirmed/active participants
      for (final entry in participants.entries) {
        final participantId = entry.key;
        final participantData = entry.value as Map<String, dynamic>;
        final participantStatus = participantData['status'] as String? ?? '';
        
        if (participantStatus == 'completed' || participantStatus == 'registered' || participantStatus == 'active' || participantStatus == 'confirmed' || participantStatus.isEmpty) {
          await NotificationTriggers.onEventCompleted(eventId, eventName, participantId);
        }
      }
    } catch (e) {
      print('Error handling event completion: $e');
    }
  }

  /// Get current event status
  static Future<EventStatus> getEventStatus(String eventId) async {
    try {
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) throw Exception('Event not found');

      final eventData = eventDoc.data()!;
      final statusString = eventData['eventStatus'] as String? ?? 'draft';
      
      return EventStatus.values.firstWhere(
        (e) => e.toString().split('.').last == statusString,
        orElse: () => EventStatus.draft,
      );
    } catch (e) {
      print('Error getting event status: $e');
      return EventStatus.draft;
    }
  }

  /// Mark participant as checked in/out
  static Future<void> toggleAttendance(String eventId, String participantId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Get current participant status
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) throw Exception('Event not found');

      final eventData = eventDoc.data()!;
      final participants = eventData['participants'] as Map<String, dynamic>? ?? {};
      final participant = participants[participantId] as Map<String, dynamic>?;
      
      if (participant == null) throw Exception('Participant not found');

      final currentStatus = participant['attendanceStatus'] as String? ?? 'not_checked_in';
      final newStatus = currentStatus == 'checked_in' ? 'not_checked_in' : 'checked_in';

      await _firestore.collection('events').doc(eventId).update({
        'participants.$participantId.attendanceStatus': newStatus,
        'participants.$participantId.attendanceUpdatedAt': FieldValue.serverTimestamp(),
        'participants.$participantId.attendanceUpdatedBy': currentUser.uid,
      });
    } catch (e) {
      print('Error toggling attendance: $e');
      rethrow;
    }
  }

  /// Get attendance statistics
  static Future<Map<String, dynamic>> getAttendanceStats(String eventId) async {
    try {
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) throw Exception('Event not found');

      final eventData = eventDoc.data()!;
      final participants = eventData['participants'] as Map<String, dynamic>? ?? {};
      
      int totalParticipants = 0;
      int checkedInCount = 0;
      int notCheckedInCount = 0;

      participants.forEach((participantId, participantData) {
        final participant = participantData as Map<String, dynamic>;
        final participantStatus = participant['status'] as String? ?? '';
        
        // Only count active/confirmed participants (not pending, cancelled, etc.)
        // Also count participants without status (legacy data)
        if (participantStatus == 'completed' || participantStatus == 'registered' || participantStatus == 'active' || participantStatus == 'confirmed' || participantStatus.isEmpty) {
          totalParticipants++;
          
          final attendanceStatus = participant['attendanceStatus'] as String? ?? 'not_checked_in';
          if (attendanceStatus == 'checked_in') {
            checkedInCount++;
          } else {
            notCheckedInCount++;
          }
        }
      });

      return {
        'total': totalParticipants,
        'checkedIn': checkedInCount,
        'notCheckedIn': notCheckedInCount,
        'attendanceRate': totalParticipants > 0 ? (checkedInCount / totalParticipants * 100).round() : 0,
      };
    } catch (e) {
      print('Error getting attendance stats: $e');
      return {
        'total': 0,
        'checkedIn': 0,
        'notCheckedIn': 0,
        'attendanceRate': 0,
      };
    }
  }

  /// Get status display info
  static Map<String, dynamic> getStatusDisplayInfo(EventStatus status) {
    switch (status) {
      case EventStatus.draft:
        return {
          'title': 'Draft',
          'color': const Color(0xFF9E9E9E), // Grey
          'icon': '📝',
          'description': 'Event is being prepared',
        };
      case EventStatus.published:
        return {
          'title': 'Published',
          'color': const Color(0xFF2196F3), // Blue
          'icon': '📅',
          'description': 'Event is open for registration',
        };
      case EventStatus.started:
        return {
          'title': 'Started',
          'color': const Color(0xFFFF9800), // Orange
          'icon': '🚀',
          'description': 'Event has begun, check-in available',
        };
      case EventStatus.ongoing:
        return {
          'title': 'Ongoing',
          'color': const Color(0xFF4CAF50), // Green
          'icon': '🎯',
          'description': 'Event is actively happening',
        };
      case EventStatus.ended:
        return {
          'title': 'Ended',
          'color': const Color(0xFF6A1B9A), // Purple
          'icon': '⭐',
          'description': 'Event concluded - Rate your experience',
        };
    }
  }

  /// Check if event can be started (must be published and have participants)
  static Future<bool> canStartEvent(String eventId) async {
    try {
      final status = await getEventStatus(eventId);
      if (status != EventStatus.published) return false;

      final stats = await getAttendanceStats(eventId);
      return stats['total'] > 0;
    } catch (e) {
      return false;
    }
  }

  /// Check if event can be ended (must be ongoing)
  static Future<bool> canEndEvent(String eventId) async {
    try {
      final status = await getEventStatus(eventId);
      return status == EventStatus.ongoing;
    } catch (e) {
      return false;
    }
  }

  /// Check if event can be published (must be draft)
  static Future<bool> canPublishEvent(String eventId) async {
    try {
      final status = await getEventStatus(eventId);
      return status == EventStatus.draft;
    } catch (e) {
      return false;
    }
  }

  /// Check if event can transition to ongoing (must be started)
  static Future<bool> canSetOngoing(String eventId) async {
    try {
      final status = await getEventStatus(eventId);
      return status == EventStatus.started;
    } catch (e) {
      return false;
    }
  }

  /// Handle event publishing - notify organizer
  static Future<void> _handleEventPublished(String eventId) async {
    try {
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) return;

      final eventData = eventDoc.data()!;
      final eventName = eventData['name'] ?? 'Event';
      final organizerName = eventData['organizerName'] ?? 'Organizer';
      final location = eventData['location']?['address'] ?? 'Location TBA';

      // Notify organizer that event is now published and live
      await OrganizerNotificationService.onEventPublished(eventId, eventName);
      
      // Notify all participants about the new event
      await NotificationTriggers.onNewEventPublished(eventId, eventName, organizerName, location);
    } catch (e) {
      print('Error handling event publishing: $e');
    }
  }

  /// Handle event started - notify participants
  static Future<void> _handleEventStarted(String eventId) async {
    try {
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) return;

      final eventData = eventDoc.data()!;
      final eventName = eventData['name'] ?? 'Event';
      final participants = eventData['participants'] as Map<String, dynamic>? ?? {};

      // Notify all registered participants that event has started
      await NotificationTriggers.onEventStarted(eventId, eventName, participants);
    } catch (e) {
      print('Error handling event started: $e');
    }
  }

  /// Generate QR code data for event attendance
  static String generateAttendanceQRData(String eventId) {
    return 'hikefue_attendance:$eventId:${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Verify QR code and check in participant
  static Future<Map<String, dynamic>> checkInWithQR(String qrData, String participantId) async {
    try {
      if (!qrData.startsWith('hikefue_attendance:')) {
        return {
          'success': false,
          'message': 'Invalid QR code format',
        };
      }

      final parts = qrData.split(':');
      if (parts.length != 3) {
        return {
          'success': false,
          'message': 'Invalid QR code format',
        };
      }

      final eventId = parts[1];
      final timestamp = int.tryParse(parts[2]);
      
      if (timestamp == null) {
        return {
          'success': false,
          'message': 'Invalid QR code timestamp',
        };
      }

      // Check if QR code is not too old (within 5 minutes)
      final qrAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (qrAge > 300000) { // 5 minutes
        return {
          'success': false,
          'message': 'QR code expired. Please get a fresh code.',
        };
      }

      // Verify event exists and participant is registered
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) {
        return {
          'success': false,
          'message': 'Event not found',
        };
      }

      final eventData = eventDoc.data()!;
      final participants = eventData['participants'] as Map<String, dynamic>? ?? {};
      
      if (!participants.containsKey(participantId)) {
        return {
          'success': false,
          'message': 'You are not registered for this event',
        };
      }

      // Check if event is in correct status for check-in
      final eventStatus = eventData['eventStatus'] as String? ?? 'draft';
      if (eventStatus != 'started' && eventStatus != 'ongoing') {
        return {
          'success': false,
          'message': 'Event is not currently accepting check-ins',
        };
      }

      // Perform check-in
      await toggleAttendance(eventId, participantId);
      
      final participant = participants[participantId] as Map<String, dynamic>;
      final participantName = participant['name'] ?? 'Participant';
      final eventName = eventData['name'] ?? 'Event';

      return {
        'success': true,
        'message': 'Successfully checked in to $eventName',
        'participantName': participantName,
        'eventName': eventName,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error during check-in: $e',
      };
    }
  }
} 