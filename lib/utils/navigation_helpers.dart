import 'package:flutter/material.dart';
import '../screens/event_rating_page.dart';
import '../screens/organizer_profile_page.dart';
import '../services/rating_service.dart';

class NavigationHelpers {
  /// Check if user can rate an event and show appropriate UI
  static Future<void> handleEventRating(
    BuildContext context, {
    required String eventId,
    required String eventName,
    required String organizerName,
    bool showDialog = true,
  }) async {
    try {
      final canRateResult = await RatingService.canRateEvent(eventId);
      
      if (canRateResult['canRate'] == true) {
        if (showDialog) {
          final shouldRate = await EventRatingDialog.show(
            context,
            eventId: eventId,
            eventName: eventName,
            organizerName: organizerName,
          );
          
          if (shouldRate == true) {
            // Rating was completed successfully
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Thank you for your feedback!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          // Navigate directly to rating page
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EventRatingPage(
                eventId: eventId,
                eventName: eventName,
                organizerName: organizerName,
              ),
            ),
          );
        }
      } else {
        // Show reason why user can't rate
        final reason = canRateResult['reason'] ?? 'Unable to rate this event';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(reason),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading rating: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Navigate to organizer profile
  static void navigateToOrganizerProfile(
    BuildContext context, {
    required String organizerId,
    String? organizerName,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OrganizerProfilePage(
          organizerId: organizerId,
          organizerName: organizerName,
        ),
      ),
    );
  }

  /// Show organizer info with option to view profile
  static void showOrganizerInfo(
    BuildContext context, {
    required String organizerId,
    required String organizerName,
    String? organizerDescription,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.green[100],
              child: Text(
                organizerName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              organizerName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (organizerDescription != null) ...[
              const SizedBox(height: 8),
              Text(
                organizerDescription,
                style: TextStyle(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  navigateToOrganizerProfile(
                    context,
                    organizerId: organizerId,
                    organizerName: organizerName,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('View Full Profile'),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  /// Show QR code scanner for attendance
  static void showQRScanner(
    BuildContext context, {
    required String eventId,
    required Function(Map<String, dynamic>) onScanComplete,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Scan QR Code',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_scanner,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'QR Scanner functionality would go here',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Simulate successful scan for demo
                        onScanComplete({
                          'success': true,
                          'message': 'Successfully checked in!',
                        });
                      },
                      child: const Text('Simulate Scan'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handle notification actions
  static void handleNotificationAction(
    BuildContext context, {
    required String type,
    required Map<String, dynamic> data,
  }) {
    switch (type) {
      case 'event_completed':
        final eventId = data['eventId'] as String?;
        final eventName = data['eventName'] as String?;
        final organizerName = data['organizerName'] as String?;
        
        if (eventId != null && eventName != null && organizerName != null) {
          handleEventRating(
            context,
            eventId: eventId,
            eventName: eventName,
            organizerName: organizerName,
          );
        }
        break;
        
      case 'organizer_profile':
        final organizerId = data['organizerId'] as String?;
        final organizerName = data['organizerName'] as String?;
        
        if (organizerId != null) {
          navigateToOrganizerProfile(
            context,
            organizerId: organizerId,
            organizerName: organizerName,
          );
        }
        break;
        
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unknown notification type: $type')),
        );
    }
  }
}