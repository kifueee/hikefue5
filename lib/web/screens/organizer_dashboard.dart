import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'organizer_event_management.dart';
import 'organizer_create_event.dart';
import 'profile_dialog.dart';
import 'event_details_page.dart';
import 'organizer_analytics_page.dart';
import 'organizer_notifications_page.dart';
import '../../models/tag.dart';
import '../../services/firestore_service.dart';
import '../../widgets/organizer_notification_badge.dart';

// New Color Palette (same as mobile participant)
const Color primaryColor = Color(0xFF004A4D);
const Color accentColor = Color(0xFF94BC45);
const Color darkBackgroundColor = Color(0xFF231F20);

class HikeFueBanner extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  const HikeFueBanner({required this.title, this.actions, super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: 160,
          width: double.infinity,
          child: Image.asset(
            'assets/images/trees_background.jpg',
            fit: BoxFit.cover,
          ),
        ),
        Container(
          height: 160,
          width: double.infinity,
          color: Colors.black.withOpacity(0.6),
        ),
        Container(
          height: 160,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "HIKEFUE",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              if (actions != null) ...actions!,
            ],
          ),
        ),
      ],
    );
  }
}

class OrganizerDashboard extends StatefulWidget {
  const OrganizerDashboard({super.key});

  @override
  State<OrganizerDashboard> createState() => _OrganizerDashboardState();
}

class _OrganizerDashboardState extends State<OrganizerDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Tag> _allTags = [];
  bool _loadingTags = false;

  @override
  void initState() {
    super.initState();
    _fetchAllTags();
  }

  Future<void> _fetchAllTags() async {
    setState(() => _loadingTags = true);
    final tags = await FirestoreService().getAllTags();
    setState(() {
      _allTags = tags;
      _loadingTags = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Full background wallpaper
          SizedBox.expand(
            child: Image.asset(
              'assets/images/trees_background.jpg',
              fit: BoxFit.cover,
            ),
          ),
          // Dark overlay for readability
          Container(
            color: Colors.black.withOpacity(0.5),
          ),
          // Main content
          SingleChildScrollView(
            child: Column(
              children: [
                HikeFueBanner(
                  title: "Organizer Dashboard",
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OrganizerCreateEvent(),
                        ),
                      ),
                      child: Row(children: [Icon(Icons.add_circle_outline, color: accentColor), SizedBox(width: 4), Text("Create Event", style: TextStyle(color: Colors.white))]),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OrganizerEventManagement(),
                        ),
                      ),
                      child: Row(children: [Icon(Icons.event_note, color: accentColor), SizedBox(width: 4), Text("Manage Events", style: TextStyle(color: Colors.white))]),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OrganizerAnalyticsPage(),
                        ),
                      ),
                      child: Row(children: [Icon(Icons.analytics, color: accentColor), SizedBox(width: 4), Text("Analytics", style: TextStyle(color: Colors.white))]),
                    ),
                    TextButton(
                      onPressed: () => _showProfileDialog(),
                      child: Row(children: [Icon(Icons.person, color: accentColor), SizedBox(width: 4), Text("Profile", style: TextStyle(color: Colors.white))]),
                    ),
                    OrganizerNotificationBadge(
                      icon: const Icon(Icons.notifications, color: accentColor),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OrganizerNotificationsPage(),
                        ),
                      ),
                      badgeColor: Colors.red,
                      textColor: Colors.white,
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: accentColor),
                      onPressed: () async {
                        await _auth.signOut();
                        if (mounted) {
                          Navigator.of(context).pushReplacementNamed('/organizer_login');
                        }
                      },
                      tooltip: 'Logout',
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Upcoming Events',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                _buildAllEventsList(),
                const SizedBox(height: 32),
                _buildActionButtons(),
                const SizedBox(height: 32),
                // Removed filter tabs
                // Removed _buildEventsList() placeholder
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllEventsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('events')
          .where('date', isGreaterThanOrEqualTo: Timestamp.now())
          .where('status', isEqualTo: 'approved')
          .where('eventStatus', whereIn: ['published', 'started', 'ongoing'])
          .orderBy('date')
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: accentColor),
            ),
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: darkBackgroundColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Text(
              'No upcoming events found',
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }

        final events = snapshot.data!.docs;
        // Display events in a grid with 4 cards per row, no scrolling, just like a normal website
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
              childAspectRatio: 0.95,
            ),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final eventDoc = events[index];
              final eventData = eventDoc.data() as Map<String, dynamic>;
              final eventName = eventData['name'] as String? ?? 'Unnamed Event';
              final eventDate = (eventData['date'] as Timestamp).toDate();
              final organizerId = eventData['organizerId'] as String?;
              final legacyOrganizerId = eventData['organizer']?['id'] as String?;
              final currentUserId = _auth.currentUser?.uid;
              final isMyEvent = (organizerId != null && organizerId == currentUserId) ||
                                (legacyOrganizerId != null && legacyOrganizerId == currentUserId);
              return _buildEventCarouselCard(
                eventDoc.id,
                eventName,
                eventDate,
                eventData['media']?['posterUrl'],
                isMyEvent,
                eventData,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEventCarouselCard(String eventId, String name, DateTime date, String? imageUrl, bool isMyEvent, Map<String, dynamic> eventData) {
    final location = eventData['location']?['address'] as String? ?? 'Location TBD';
    final currentParticipants = eventData['details']?['currentParticipants'] as int? ?? 0;
    final maxParticipants = eventData['details']?['maxParticipants'] as int? ?? 0;
    final status = eventData['status'] as String? ?? 'pending';
    final description = eventData['description'] as String? ?? '';
    final eventFee = eventData['pricing']?['eventFee'] as num? ?? 0;
    final List<dynamic> tagIds = eventData['tags'] ?? [];
    final eventTags = _allTags.where((tag) => tagIds.contains(tag.id)).toList();
    return Container(
      width: 340,
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Poster image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: double.infinity,
                      height: 140,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 140,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 140,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                      ),
                    )
                  : Container(
                      height: 140,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.image, size: 48, color: Colors.grey),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDateTime(date),
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    location,
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        eventFee > 0 ? 'RM${eventFee.toStringAsFixed(2)}' : 'Free',
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '$currentParticipants people going',
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (eventTags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: eventTags.map((tag) => Chip(
                    label: Text(tag.name, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                    backgroundColor: Color(int.parse('0xff${tag.color.substring(1)}')),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  )).toList(),
                ),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EventDetailsPage(eventId: eventId, eventData: eventData),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue.shade700,
                        side: BorderSide(color: Colors.blue.shade200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                      ),
                      child: const Text('VIEW'),
                    ),
                  ),
                  if (isMyEvent) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const OrganizerEventManagement(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue.shade700,
                          side: BorderSide(color: Colors.blue.shade200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                        ),
                        child: const Text('MANAGE'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    // Example: Aug 10, 2017 5:30 PM – Aug 11, 2017 9:00 PM
    // For now, just show one date/time
    return '${_monthName(date.month)} ${date.day}, ${date.year} ${_formatTime(date)}';
  }
  String _monthName(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month];
  }
  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final min = date.minute.toString().padLeft(2, '0');
    return '$hour:$min $ampm';
  }

  Widget _buildActionCard(String title, IconData icon, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              darkBackgroundColor.withOpacity(0.8),
              darkBackgroundColor.withOpacity(0.6)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: accentColor, size: 32),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBarButton(String title, IconData icon, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 20),
      label: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => const CompanyProfileDialog(),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'approved':
        color = Colors.green;
        label = 'Approved';
        break;
      case 'pending':
        color = Colors.orange;
        label = 'Pending';
        break;
      case 'rejected':
        color = Colors.red;
        label = 'Rejected';
        break;
      default:
        color = Colors.grey;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  'Create Event',
                  Icons.add_circle_outline,
                  'Start a new event',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OrganizerCreateEvent(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionCard(
                  'Manage Events',
                  Icons.event_note,
                  'View and edit events',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OrganizerEventManagement(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionCard(
                  'Analytics',
                  Icons.analytics,
                  'View event statistics',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OrganizerAnalyticsPage(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 