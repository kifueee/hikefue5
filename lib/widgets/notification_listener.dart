import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hikefue5/services/notification_service.dart';

class AppNotificationListener extends StatefulWidget {
  final Widget child;

  const AppNotificationListener({
    super.key,
    required this.child,
  });

  @override
  State<AppNotificationListener> createState() => _AppNotificationListenerState();
}

class _AppNotificationListenerState extends State<AppNotificationListener> {
  StreamSubscription<AppNotification>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _initializeNotificationListener();
  }

  void _initializeNotificationListener() {
    // Initialize the notification listener
    NotificationService.initializeNotificationListener();
    
    // Listen to new notifications
    _notificationSubscription = NotificationService.notificationStream.listen(
      (notification) {
        NotificationService.showNotificationSnackbarWithSound(context, notification);
      },
    );
  }

  void _showNotificationSnackbar(AppNotification notification) {
    if (!mounted) return;
    
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
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
} 