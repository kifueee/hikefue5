import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hikefue5/screens/participant_events_page.dart';
import 'package:hikefue5/screens/profile_page.dart';
import 'package:hikefue5/screens/my_events_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:hikefue5/screens/carpool/my_carpools_page.dart';
import 'package:hikefue5/screens/event_details_page.dart';
import 'package:hikefue5/screens/chat_selection_page.dart';
import 'package:hikefue5/models/tag.dart';
import 'notifications_page.dart';
import '../widgets/notification_badge.dart';
import '../widgets/error_boundary.dart';

// New Color Palette
const Color primaryColor = Color(0xFF004A4D);
const Color accentColor = Color(0xFF94BC45);
const Color darkBackgroundColor = Color(0xFF231F20);

class ParticipantHomePage extends StatelessWidget {
  // Replace with your user ID retrieval logic
  final String userId = getCurrentUserId();

  ParticipantHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: darkBackgroundColor,
      body: Stack(
        children: [
          // Blurred Background Image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/trees_background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(color: primaryColor.withOpacity(0.6)),
          ),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  pinned: true,
                  expandedHeight: 120.0,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    title: Text(
                      'Welcome, ${user?.displayName ?? 'Hiker'}!',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  actions: [
                    NotificationBadge(
                      child: IconButton(
                        icon: const Icon(Icons.notifications),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NotificationsPage(userId: userId),
                            ),
                          );
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.person_outline, size: 28),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ProfilePage()),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: accentColor.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.event_available, 
                                       color: accentColor, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    "MY EVENTS",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: accentColor,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Upcoming Events",
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Events you've joined and registered for",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white70,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildProfessionalMyEventsList(user?.uid),
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 16.0),
                    child: Text(
                      "Trending Events",
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                _buildTrendingEventsList(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 16.0),
                    child: Text(
                      "Explore",
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                _buildActionGrid(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalMyEventsList(String? userId) {
    if (userId == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .where('status', isEqualTo: 'approved')
          .where('eventStatus', whereIn: ['published', 'started', 'ongoing'])
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(color: accentColor)),
            ),
          );
        }
        
        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(color: accentColor)),
            ),
          );
        }

        // Filter events where user is registered
        final allEvents = snapshot.data!.docs;
        print('🔍 TOTAL EVENTS: ${allEvents.length}');
        print('🔍 USER ID: $userId');
        
        // First, filter for future events manually
        final futureEvents = allEvents.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final eventDate = (data['date'] as Timestamp?)?.toDate();
          if (eventDate == null) {
            print('⚠️  Event ${data['name']} has no date');
            return false;
          }
          final isFuture = eventDate.isAfter(DateTime.now());
          print('📅 Event: ${data['name']} - Date: $eventDate - Future: $isFuture');
          return isFuture;
        }).toList();
        
        print('🔍 FUTURE EVENTS: ${futureEvents.length}');
        
        final userEvents = futureEvents.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final participants = data['participants'] as Map<String, dynamic>? ?? {};
          final userParticipant = participants[userId] as Map<String, dynamic>?;
          
          print('🔎 Checking Event: ${data['name']}');
          print('   👥 Participants count: ${participants.length}');
          print('   🔑 Participant keys: ${participants.keys.take(3).toList()}${participants.length > 3 ? '...' : ''}');
          print('   🧑 User found: ${userParticipant != null}');
          
          if (userParticipant != null) {
            print('   ✅ User status: ${userParticipant['status']}');
            final isValidStatus = ['registered', 'confirmed', 'pending_payment', 'completed'].contains(userParticipant['status']);
            print('   ✅ Valid status: $isValidStatus');
            return isValidStatus;
          } else {
            print('   ❌ User NOT in participants');
            // Check if user ID is close to any existing IDs (for debugging)
            final similarIds = participants.keys.where((id) => 
              id.toString().contains(userId.substring(0, 5)) || 
              userId.contains(id.toString().substring(0, 5))
            ).toList();
            if (similarIds.isNotEmpty) {
              print('   🔍 Similar IDs found: $similarIds');
            }
            return false;
          }
        }).toList();
        
        print('🎯 FINAL USER EVENTS: ${userEvents.length}');
        
        if (userEvents.isEmpty) {
          return SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    darkBackgroundColor.withOpacity(0.3),
                    darkBackgroundColor.withOpacity(0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.event_busy_rounded,
                      size: 48,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No Events Yet",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Join some amazing hiking events to see them here!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final event = userEvents[index];
              final data = event.data() as Map<String, dynamic>;
              final eventDate = (data['date'] as Timestamp).toDate();
              return _buildProfessionalEventCard(
                context,
                event.id,
                data,
                eventDate,
              );
            },
            childCount: userEvents.length,
          ),
        );
      },
    );
  }

  Widget _buildProfessionalEventCard(
      BuildContext context, String eventId, Map<String, dynamic> data, DateTime eventDate) {
    final name = data['name'] ?? 'Unnamed Event';
    final location = data['location']?['address'] ?? 'Location TBA';
    final imageUrl = data['media']?['posterUrl'];
    final startTime = data['schedule']?['startTime'] ?? '';
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            darkBackgroundColor.withOpacity(0.4),
            darkBackgroundColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventDetailsPage(eventId: eventId),
            ),
          ),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Event Image
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(imageUrl),
                            fit: BoxFit.cover,
                            onError: (exception, stackTrace) {},
                          )
                        : null,
                    color: imageUrl == null ? accentColor.withOpacity(0.2) : null,
                  ),
                  child: imageUrl == null
                      ? Icon(
                          Icons.hiking,
                          color: accentColor,
                          size: 32,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                // Event Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Event Name
                      Text(
                        name,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Location
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 14,
                            color: Colors.white60,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white60,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Date and Time
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${DateFormat('MMM d').format(eventDate)} • $startTime',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Countdown Timer
                _buildCountdownTimer(eventDate),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownTimer(DateTime eventDate) {
    final now = DateTime.now();
    final difference = eventDate.difference(now);
    
    if (difference.isNegative) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.event_busy, color: Colors.grey, size: 20),
            const SizedBox(height: 2),
            Text(
              'Past',
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    
    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;
    
    String timeText;
    String unitText;
    
    if (days > 0) {
      timeText = days.toString();
      unitText = days == 1 ? 'day' : 'days';
    } else if (hours > 0) {
      timeText = hours.toString();
      unitText = hours == 1 ? 'hr' : 'hrs';
    } else {
      timeText = minutes.toString();
      unitText = 'min';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withOpacity(0.8),
            accentColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            timeText,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            unitText,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingEventsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .where('status', isEqualTo: 'approved')
          .where('eventStatus', whereIn: ['published', 'started', 'ongoing'])
          .where('date', isGreaterThanOrEqualTo: Timestamp.now())
          .orderBy('date')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(heightFactor: 3, child: CircularProgressIndicator()),
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        // Get all events and sort by participant count for trending
        final allEvents = snapshot.data!.docs;
        final trendingEvents = List<DocumentSnapshot>.from(allEvents);
        trendingEvents.sort((a, b) {
          final aCount = (a.data() as Map<String, dynamic>)['participantsCount'] ?? 0;
          final bCount = (b.data() as Map<String, dynamic>)['participantsCount'] ?? 0;
          return bCount.compareTo(aCount);
        });

        // Take top 5 trending events
        final limitedTrendingEvents = trendingEvents.take(5).toList();
        
        if (limitedTrendingEvents.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('tags').snapshots(),
          builder: (context, tagsSnapshot) {
            if (tagsSnapshot.connectionState == ConnectionState.waiting) {
              return const SliverToBoxAdapter(
                child: Center(heightFactor: 3, child: CircularProgressIndicator()),
              );
            }
            
            final allTags = tagsSnapshot.data?.docs.map((doc) => 
              Tag.fromMap(doc.id, doc.data() as Map<String, dynamic>)
            ).toList() ?? [];
            
            return SliverToBoxAdapter(
              child: SizedBox(
                height: 220,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: limitedTrendingEvents.length,
                  itemBuilder: (context, index) {
                    return _buildTrendingEventCard(context, limitedTrendingEvents[index], allTags);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTrendingEventCard(BuildContext context, DocumentSnapshot event, List<Tag> allTags) {
    final data = event.data() as Map<String, dynamic>;
    final imageUrl = data['media']?['posterUrl'] ?? 'https://via.placeholder.com/200';
    final date = (data['date'] as Timestamp).toDate();
    final List<dynamic> tagIds = data['tags'] ?? [];
    final eventTags = allTags.where((tag) => tagIds.contains(tag.id)).toList();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => EventDetailsPage(eventId: event.id)),
        );
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
            onError: (err, stack) {},
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, darkBackgroundColor.withOpacity(0.9)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data['name'],
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('d MMM yyyy').format(date),
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 8),
                if (eventTags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: eventTags.map((tag) => Chip(
                        label: Text(tag.name, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                        backgroundColor: Color(int.parse('0xff${tag.color.substring(1)}')),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      )).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverGrid.count(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
        children: [
          _buildActionCard(
            'Discover',
            Icons.explore_outlined,
            'Find new hiking events',
            accentColor,
            () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ParticipantEventsPage())),
          ),
          _buildActionCard(
            'My Events',
            Icons.calendar_today_outlined,
            'View all your events',
            accentColor,
            () => Navigator.push(context,
                MaterialPageRoute(builder: (context) => const MyEventsPage())),
          ),
          _buildActionCard(
            'Carpools',
            Icons.directions_car_outlined,
            'Manage your ride shares',
            accentColor,
            () => _showCarpoolsPage(context),
          ),
          _buildActionCard(
            'Community',
            Icons.chat_bubble_outline,
            'Connect with hikers',
            accentColor,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ChatSelectionPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, String subtitle,
      Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              darkBackgroundColor,
              darkBackgroundColor.withOpacity(0.7)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 36),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.white70)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCarpoolsPage(BuildContext context) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please log in to access carpools'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Simplified query - get events where user is a participant
      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('participants.$userId', isEqualTo: true)
          .get();

      if (!context.mounted) return;

      // Filter events to only show active ones
      final activeEvents = eventsSnapshot.docs.where((doc) {
        final data = doc.data();
        final status = data['status'] as String?;
        final eventStatus = data['eventStatus'] as String?;
        
        return status == 'approved' && 
               (eventStatus == 'published' || eventStatus == 'started' || eventStatus == 'ongoing');
      }).toList();

      if (activeEvents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('You are not participating in any active events'),
            backgroundColor: accentColor,
          ),
        );
        return;
      }

      // Show dialog to select event
      final selectedEventDoc = await showDialog<QueryDocumentSnapshot<Map<String, dynamic>>>(
        context: context,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          backgroundColor: darkBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Select Event for Carpool',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: activeEvents.length,
              itemBuilder: (context, index) {
                final eventDoc = activeEvents[index];
                final event = eventDoc.data();
                final eventDate = (event['date'] as Timestamp?)?.toDate();
                return Card(
                  color: Colors.white.withOpacity(0.1),
                  child: ListTile(
                    title: Text(event['name'] ?? 'Unnamed Event',
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                    subtitle: eventDate != null 
                        ? Text(DateFormat('MMM dd, yyyy').format(eventDate),
                            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12))
                        : null,
                    leading: const Icon(Icons.event, color: accentColor),
                    onTap: () {
                      Navigator.of(context).pop(eventDoc);
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white70)),
            ),
          ],
        ),
      );

      if (!context.mounted) return;

      if (selectedEventDoc != null) {
        final selectedEvent = selectedEventDoc.data();
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MyCarpoolsPage(
              eventId: selectedEventDoc.id,
              eventName: selectedEvent['name'] ?? 'Unnamed Event',
              eventLocation: selectedEvent['location']?['address'] ?? 'No location',
              eventDateTime: (selectedEvent['date'] as Timestamp).toDate(),
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading carpools: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 

String getCurrentUserId() {
  final user = FirebaseAuth.instance.currentUser;
  return user?.uid ?? '';
} 