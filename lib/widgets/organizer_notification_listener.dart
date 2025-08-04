import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hikefue5/services/organizer_notification_service.dart';

class OrganizerNotificationListener extends StatefulWidget {
  final Widget child;

  const OrganizerNotificationListener({
    super.key,
    required this.child,
  });

  @override
  State<OrganizerNotificationListener> createState() => _OrganizerNotificationListenerState();
}

class _OrganizerNotificationListenerState extends State<OrganizerNotificationListener> {
  StreamSubscription<OrganizerNotification>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _initializeNotificationListener();
  }

  void _initializeNotificationListener() {
    // Initialize the notification listener
    OrganizerNotificationService.initializeNotificationListener();
    
    // Listen to new notifications
    _notificationSubscription = OrganizerNotificationService.notificationStream.listen(
      (notification) {
        OrganizerNotificationService.showNotificationSnackbarWithSound(context, notification);
      },
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