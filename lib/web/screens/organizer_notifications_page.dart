import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hikefue5/services/organizer_notification_service.dart';

class OrganizerNotificationsPage extends StatefulWidget {
  const OrganizerNotificationsPage({super.key});

  @override
  State<OrganizerNotificationsPage> createState() => _OrganizerNotificationsPageState();
}

class _OrganizerNotificationsPageState extends State<OrganizerNotificationsPage> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          TextButton.icon(
            onPressed: _markAllAsRead,
            icon: const Icon(Icons.done_all, color: Colors.blue),
            label: Text(
              'Mark All Read',
              style: GoogleFonts.poppins(color: Colors.blue),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<OrganizerNotification>>(
        stream: OrganizerNotificationService.getOrganizerNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading notifications',
                    style: GoogleFonts.poppins(fontSize: 18, color: Colors.red[300]),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ll see notifications here when they arrive',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _buildNotificationCard(notification);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(OrganizerNotification notification) {
    final isRead = notification.read;
    final timestamp = notification.timestamp;
    final timeAgo = _getTimeAgo(timestamp);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isRead ? 1 : 3,
      color: isRead ? Colors.white : Colors.blue[50],
      child: InkWell(
        onTap: () => _markAsRead(notification.id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notification icon based on type
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getNotificationColor(notification.type).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getNotificationIcon(notification.type),
                  color: _getNotificationColor(notification.type),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Notification content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: GoogleFonts.poppins(
                              fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                              fontSize: 16,
                              color: isRead ? Colors.grey[700] : Colors.black87,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeAgo,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        if (notification.eventId != null) ...[
                          const SizedBox(width: 16),
                          Icon(
                            Icons.event,
                            size: 12,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Event Related',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'event_created':
      case 'event_approved':
      case 'event_updated':
        return Colors.green;
      case 'event_rejected':
      case 'account_suspended':
        return Colors.red;
      case 'new_participant':
      case 'payment_received':
        return Colors.blue;
      case 'event_full':
      case 'event_almost_full':
        return Colors.orange;
      case 'carpool_request':
      case 'carpool_created':
        return Colors.purple;
      case 'event_starting_soon':
      case 'event_today':
        return Colors.amber;
      case 'account_approved':
        return Colors.green;
      case 'maintenance':
        return Colors.red;
      case 'new_feature':
        return Colors.indigo;
      case 'event_milestone':
      case 'revenue_milestone':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'event_created':
      case 'event_approved':
      case 'event_updated':
        return Icons.event;
      case 'event_rejected':
        return Icons.cancel;
      case 'new_participant':
        return Icons.person_add;
      case 'participant_cancelled':
        return Icons.person_remove;
      case 'event_full':
        return Icons.people;
      case 'event_almost_full':
        return Icons.warning;
      case 'payment_received':
        return Icons.payment;
      case 'payment_refunded':
        return Icons.money_off;
      case 'carpool_request':
        return Icons.directions_car;
      case 'carpool_created':
        return Icons.car_rental;
      case 'event_starting_soon':
      case 'event_today':
        return Icons.schedule;
      case 'account_approved':
        return Icons.check_circle;
      case 'account_suspended':
        return Icons.block;
      case 'maintenance':
        return Icons.build;
      case 'new_feature':
        return Icons.new_releases;
      case 'event_milestone':
        return Icons.emoji_events;
      case 'revenue_milestone':
        return Icons.trending_up;
      default:
        return Icons.notifications;
    }
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    setState(() => _isLoading = true);
    try {
      await OrganizerNotificationService.markNotificationAsRead(notificationId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error marking notification as read: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllAsRead() async {
    setState(() => _isLoading = true);
    try {
      await OrganizerNotificationService.markAllNotificationsAsRead();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error marking notifications as read: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
} 