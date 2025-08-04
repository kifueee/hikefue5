import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EventRating {
  final String id;
  final String eventId;
  final String participantId;
  final String participantName;
  final String organizerId;
  final int rating; // 1-5 stars
  final String comment;
  final DateTime timestamp;
  final bool isAnonymous;
  final Map<String, int> aspectRatings; // organization, communication, venue, etc.

  EventRating({
    required this.id,
    required this.eventId,
    required this.participantId,
    required this.participantName,
    required this.organizerId,
    required this.rating,
    required this.comment,
    required this.timestamp,
    required this.isAnonymous,
    required this.aspectRatings,
  });

  factory EventRating.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EventRating(
      id: doc.id,
      eventId: data['eventId'] ?? '',
      participantId: data['participantId'] ?? '',
      participantName: data['participantName'] ?? 'Anonymous',
      organizerId: data['organizerId'] ?? '',
      rating: data['rating'] ?? 5,
      comment: data['comment'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isAnonymous: data['isAnonymous'] ?? false,
      aspectRatings: Map<String, int>.from(data['aspectRatings'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'participantId': participantId,
      'participantName': isAnonymous ? 'Anonymous' : participantName,
      'organizerId': organizerId,
      'rating': rating,
      'comment': comment,
      'timestamp': FieldValue.serverTimestamp(),
      'isAnonymous': isAnonymous,
      'aspectRatings': aspectRatings,
    };
  }
}

class OrganizerRatingStats {
  final String organizerId;
  final double averageRating;
  final int totalRatings;
  final Map<int, int> ratingDistribution; // star count -> number of ratings
  final Map<String, double> aspectAverages;
  final List<EventRating> recentReviews;

  OrganizerRatingStats({
    required this.organizerId,
    required this.averageRating,
    required this.totalRatings,
    required this.ratingDistribution,
    required this.aspectAverages,
    required this.recentReviews,
  });
}

class RatingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Submit a rating for an event
  static Future<Map<String, dynamic>> submitRating({
    required String eventId,
    required int rating,
    required String comment,
    required bool isAnonymous,
    Map<String, int>? aspectRatings,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'User not authenticated',
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

      final eventData = eventDoc.data()!;
      final organizerId = eventData['organizerId'];
      final participants = eventData['participants'] as Map<String, dynamic>? ?? {};
      
      // Verify user participated in the event
      if (!participants.containsKey(currentUser.uid)) {
        return {
          'success': false,
          'message': 'You must have participated in this event to rate it',
        };
      }

      // Check if event has ended
      final eventStatus = eventData['eventStatus'] as String? ?? 'draft';
      if (eventStatus != 'ended') {
        return {
          'success': false,
          'message': 'You can only rate events after they have ended',
        };
      }

      // Check if user already rated this event
      final existingRating = await _firestore
          .collection('ratings')
          .where('eventId', isEqualTo: eventId)
          .where('participantId', isEqualTo: currentUser.uid)
          .get();

      if (existingRating.docs.isNotEmpty) {
        return {
          'success': false,
          'message': 'You have already rated this event',
        };
      }

      // Get participant name
      final participant = participants[currentUser.uid] as Map<String, dynamic>;
      final participantName = participant['name'] ?? 'Anonymous';

      // Create rating document
      final ratingData = EventRating(
        id: '',
        eventId: eventId,
        participantId: currentUser.uid,
        participantName: participantName,
        organizerId: organizerId,
        rating: rating,
        comment: comment,
        timestamp: DateTime.now(),
        isAnonymous: isAnonymous,
        aspectRatings: aspectRatings ?? {},
      );

      await _firestore.collection('ratings').add(ratingData.toMap());

      // Update organizer rating stats
      await _updateOrganizerStats(organizerId);

      return {
        'success': true,
        'message': 'Rating submitted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error submitting rating: $e',
      };
    }
  }

  /// Get ratings for a specific event
  static Future<List<EventRating>> getEventRatings(String eventId) async {
    try {
      final ratingsQuery = await _firestore
          .collection('ratings')
          .where('eventId', isEqualTo: eventId)
          .orderBy('timestamp', descending: true)
          .get();

      return ratingsQuery.docs.map((doc) => EventRating.fromDoc(doc)).toList();
    } catch (e) {
      print('Error getting event ratings: $e');
      return [];
    }
  }

  /// Get ratings for an organizer
  static Future<List<EventRating>> getOrganizerRatings(String organizerId, {int limit = 50}) async {
    try {
      final ratingsQuery = await _firestore
          .collection('ratings')
          .where('organizerId', isEqualTo: organizerId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return ratingsQuery.docs.map((doc) => EventRating.fromDoc(doc)).toList();
    } catch (e) {
      print('Error getting organizer ratings: $e');
      return [];
    }
  }

  /// Get comprehensive organizer rating statistics
  static Future<OrganizerRatingStats?> getOrganizerStats(String organizerId) async {
    try {
      final ratings = await getOrganizerRatings(organizerId, limit: 1000);
      
      if (ratings.isEmpty) {
        return OrganizerRatingStats(
          organizerId: organizerId,
          averageRating: 0.0,
          totalRatings: 0,
          ratingDistribution: {},
          aspectAverages: {},
          recentReviews: [],
        );
      }

      // Calculate average rating
      final totalRating = ratings.fold<int>(0, (sum, rating) => sum + rating.rating);
      final averageRating = totalRating / ratings.length;

      // Calculate rating distribution
      final ratingDistribution = <int, int>{};
      for (int i = 1; i <= 5; i++) {
        ratingDistribution[i] = ratings.where((r) => r.rating == i).length;
      }

      // Calculate aspect averages
      final aspectAverages = <String, double>{};
      final aspectTotals = <String, int>{};
      final aspectCounts = <String, int>{};

      for (final rating in ratings) {
        for (final entry in rating.aspectRatings.entries) {
          aspectTotals[entry.key] = (aspectTotals[entry.key] ?? 0) + entry.value;
          aspectCounts[entry.key] = (aspectCounts[entry.key] ?? 0) + 1;
        }
      }

      for (final aspect in aspectTotals.keys) {
        aspectAverages[aspect] = aspectTotals[aspect]! / aspectCounts[aspect]!;
      }

      // Get recent reviews (last 10 with comments)
      final recentReviews = ratings
          .where((r) => r.comment.isNotEmpty)
          .take(10)
          .toList();

      return OrganizerRatingStats(
        organizerId: organizerId,
        averageRating: averageRating,
        totalRatings: ratings.length,
        ratingDistribution: ratingDistribution,
        aspectAverages: aspectAverages,
        recentReviews: recentReviews,
      );
    } catch (e) {
      print('Error getting organizer stats: $e');
      return null;
    }
  }

  /// Update organizer cached statistics
  static Future<void> _updateOrganizerStats(String organizerId) async {
    try {
      final stats = await getOrganizerStats(organizerId);
      if (stats == null) return;

      await _firestore.collection('organizerStats').doc(organizerId).set({
        'averageRating': stats.averageRating,
        'totalRatings': stats.totalRatings,
        'ratingDistribution': stats.ratingDistribution,
        'aspectAverages': stats.aspectAverages,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating organizer stats: $e');
    }
  }

  /// Check if user can rate an event
  static Future<Map<String, dynamic>> canRateEvent(String eventId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {
          'canRate': false,
          'reason': 'User not authenticated',
        };
      }

      // Get event data
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) {
        return {
          'canRate': false,
          'reason': 'Event not found',
        };
      }

      final eventData = eventDoc.data()!;
      final participants = eventData['participants'] as Map<String, dynamic>? ?? {};
      
      // Check if user participated
      if (!participants.containsKey(currentUser.uid)) {
        return {
          'canRate': false,
          'reason': 'You must have participated in this event to rate it',
        };
      }

      // Check if event has ended
      final eventStatus = eventData['eventStatus'] as String? ?? 'draft';
      if (eventStatus != 'ended') {
        return {
          'canRate': false,
          'reason': 'You can only rate events after they have ended',
        };
      }

      // Check if already rated
      final existingRating = await _firestore
          .collection('ratings')
          .where('eventId', isEqualTo: eventId)
          .where('participantId', isEqualTo: currentUser.uid)
          .get();

      if (existingRating.docs.isNotEmpty) {
        return {
          'canRate': false,
          'reason': 'You have already rated this event',
          'existingRating': EventRating.fromDoc(existingRating.docs.first),
        };
      }

      return {
        'canRate': true,
        'eventName': eventData['name'] ?? 'Event',
        'organizerName': eventData['organizerName'] ?? 'Organizer',
      };
    } catch (e) {
      return {
        'canRate': false,
        'reason': 'Error checking rating eligibility: $e',
      };
    }
  }

  /// Get default aspect rating categories
  static Map<String, String> getAspectCategories() {
    return {
      'organization': 'Event Organization',
      'communication': 'Communication',
      'venue': 'Venue & Location',
      'safety': 'Safety Measures',
      'value': 'Value for Money',
      'experience': 'Overall Experience',
    };
  }
}