import 'package:flutter/material.dart';
import 'package:hikefue5/services/organizer_notification_service.dart';

class OrganizerNotificationBadge extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onTap;
  final Color? badgeColor;
  final Color? textColor;

  const OrganizerNotificationBadge({
    super.key,
    required this.icon,
    this.onTap,
    this.badgeColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: OrganizerNotificationService.getUnreadCount(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;
        
        return GestureDetector(
          onTap: onTap,
          child: Stack(
            children: [
              icon,
              if (unreadCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: badgeColor ?? Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: TextStyle(
                        color: textColor ?? Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
} 