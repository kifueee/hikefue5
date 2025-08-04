import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:io';
import 'event_registration_page.dart';
import '../../models/tag.dart';
import '../../services/firestore_service.dart';
import '../../services/event_status_service.dart';
import '../../services/rating_service.dart';
import '../../widgets/leave_event_dialog.dart';
import '../../widgets/qr_attendance_widget.dart';
import 'event_rating_page.dart';

// Theme Colors
const Color primaryColor = Color(0xFF004A4D);
const Color accentColor = Color(0xFF94BC45);
const Color darkBackgroundColor = Color(0xFF231F20);

class ParticipantEventDetailsPage extends StatefulWidget {
  final String eventId;

  const ParticipantEventDetailsPage({
    super.key,
    required this.eventId,
  });

  @override
  State<ParticipantEventDetailsPage> createState() => _ParticipantEventDetailsPageState();
}

class _ParticipantEventDetailsPageState extends State<ParticipantEventDetailsPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  final bool _isJoining = false;
  bool _isLeaving = false;
  Map<String, dynamic>? _eventData;
  bool _isParticipant = false;
  List<Tag> _allTags = [];
  bool _loadingTags = false;

  @override
  void initState() {
    super.initState();
    _loadEventData();
    _fetchAllTags();
  }

  Future<void> _loadEventData() async {
    try {
      final eventDoc = await _firestore.collection('events').doc(widget.eventId).get();
      if (eventDoc.exists) {
        final data = eventDoc.data() as Map<String, dynamic>;
        final currentUser = _auth.currentUser;
        
        // Initialize participants map if it doesn't exist
        if (data['participants'] == null) {
          data['participants'] = {};
        }
        
        setState(() {
          _eventData = data;
          // Check if user is a participant by looking at the participants map
          _isParticipant = currentUser != null && 
              (data['participants'] as Map<String, dynamic>).containsKey(currentUser.uid);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading event: $e')),
        );
      }
    }
  }

  Future<void> _fetchAllTags() async {
    setState(() => _loadingTags = true);
    final tags = await FirestoreService().getAllTags();
    setState(() {
      _allTags = tags;
      _loadingTags = false;
    });
  }

  Future<void> _joinEvent() async {
    if (_eventData == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventRegistrationPage(
          event: _eventData!,
          eventId: widget.eventId,
        ),
      ),
    );

    if (result == true) {
      await _loadEventData();
      setState(() {});
    }
  }

  Future<void> _leaveEvent() async {
    if (_eventData == null) return;

    // Show the comprehensive leave event dialog
    showDialog(
      context: context,
      builder: (context) => LeaveEventDialog(
        eventId: widget.eventId,
        eventName: _eventData!['name'] ?? 'Event',
        onEventLeft: () {
          // Reload event data after leaving
          _loadEventData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: darkBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
          ),
        ),
      );
    }

    if (_eventData == null) {
      return Scaffold(
        backgroundColor: darkBackgroundColor,
        body: const Center(
          child: Text(
            'Event not found',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    // Safely extract all values with proper null checks
    final date = (_eventData!['date'] as Timestamp?)?.toDate() ?? DateTime.now();
    final participants = _eventData!['participants'] as Map<String, dynamic>? ?? {};
    final details = _eventData!['details'] as Map<String, dynamic>? ?? {};
    final maxParticipants = (details['maxParticipants'] as num?)?.toInt() ?? 0;
    final difficulty = details['difficulty']?.toString() ?? 'Easy';
    final fitnessLevel = details['fitnessLevel']?.toString() ?? 'Beginner';
    final duration = (details['duration'] as num?)?.toDouble() ?? 0.0;
    final distance = (details['distance'] as num?)?.toDouble() ?? 0.0;
    
    final media = _eventData!['media'] as Map<String, dynamic>? ?? {};
    final posterUrl = media['posterUrl']?.toString();
    
    final location = _eventData!['location'] as Map<String, dynamic>? ?? {};
    final locationAddress = location['address']?.toString() ?? 'No location specified';
    
    final meetingPoint = _eventData!['meetingPoint'] as Map<String, dynamic>? ?? {};
    final meetingPointAddress = meetingPoint['address']?.toString() ?? 'No meeting point specified';
    
    // Debug print to see the actual data structure
    print('Event Data Location: ${_eventData!['location']}');
    print('Event Data Meeting Point: ${_eventData!['meetingPoint']}');
    print('Organizer data: ${_eventData!['organizer']}');
    
    final schedule = _eventData!['schedule'] as Map<String, dynamic>? ?? {};
    final startTime = schedule['startTime']?.toString() ?? 'No start time specified';
    final endTime = schedule['endTime']?.toString() ?? 'No end time specified';
    
    final pricing = _eventData!['pricing'] as Map<String, dynamic>? ?? {};
    final eventFee = (pricing['eventFee'] as num?)?.toDouble() ?? 0.0;
    final paymentDeadlineTimestamp = pricing['paymentDeadline'] as Timestamp?;
    final paymentDeadline = paymentDeadlineTimestamp?.toDate();
    
    final bankDetails = pricing['bankDetails'] as Map<String, dynamic>? ?? {};
    final bankName = bankDetails['bankName']?.toString() ?? 'No bank specified';
    final accountNumber = bankDetails['accountNumber']?.toString() ?? 'No account number specified';
    final accountHolder = bankDetails['accountHolder']?.toString() ?? 'No account holder specified';

    return Scaffold(
      backgroundColor: darkBackgroundColor,
      body: Stack(
        children: [
          // Background Image with Blur Effect
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
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Custom App Bar
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  pinned: true,
                  expandedHeight: 80.0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: Text(
                    _eventData!['name']?.toString() ?? 'Event Details',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Event Name
                        Text(
                          _eventData!['name']?.toString() ?? 'Untitled Event',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Event Poster
                        if (posterUrl != null)
                          _buildGlassCard(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FullScreenPoster(posterUrl: posterUrl),
                                  ),
                                );
                              },
                              child: Container(
                                width: double.infinity,
                                height: 200,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Stack(
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl: posterUrl,
                                        width: double.infinity,
                                        height: 200,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          color: Colors.transparent,
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                                            ),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          color: Colors.transparent,
                                          child: const Icon(
                                            Icons.error_outline_rounded,
                                            color: accentColor,
                                            size: 50,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: 12,
                                        top: 12,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.6),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.fullscreen_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),

                        // Organizer Details
                        if (_eventData!['organizer'] != null && (_eventData!['organizer'] as Map<String, dynamic>).isNotEmpty)
                          _buildGlassCard(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: accentColor.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.verified_user_rounded,
                                          color: accentColor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Organizer',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  if (_eventData!['organizer']['logoUrl'] != null && (_eventData!['organizer']['logoUrl'] as String).isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: CircleAvatar(
                                        backgroundImage: NetworkImage(_eventData!['organizer']['logoUrl']),
                                        radius: 28,
                                      ),
                                    ),
                                  if (_eventData!['organizer']['name'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        _eventData!['organizer']['name'],
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  if (_eventData!['organizer']['email'] != null && (_eventData!['organizer']['email'] as String).isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.email, color: accentColor, size: 18),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              _eventData!['organizer']['email'],
                                              style: GoogleFonts.poppins(
                                                color: Colors.white70,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (_eventData!['organizer']['phone'] != null && (_eventData!['organizer']['phone'] as String).isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.phone, color: accentColor, size: 18),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              _eventData!['organizer']['phone'],
                                              style: GoogleFonts.poppins(
                                                color: Colors.white70,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // Organizer Rating Section
                                  if (_eventData!['organizerId'] != null)
                                    FutureBuilder<OrganizerRatingStats?>(
                                      future: RatingService.getOrganizerStats(_eventData!['organizerId']),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState == ConnectionState.waiting) {
                                          return const SizedBox.shrink();
                                        }
                                        
                                        final stats = snapshot.data;
                                        if (stats == null || stats.totalRatings == 0) {
                                          return const SizedBox.shrink();
                                        }
                                        
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 16),
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.amber.withOpacity(0.3)),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.star, color: Colors.amber, size: 16),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        'Organizer Rating',
                                                        style: GoogleFonts.poppins(
                                                          color: Colors.amber[700],
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    children: [
                                                      // Star Rating Display
                                                      Row(
                                                        children: List.generate(5, (index) {
                                                          return Icon(
                                                            index < stats.averageRating.round()
                                                                ? Icons.star
                                                                : Icons.star_outline,
                                                            color: Colors.amber,
                                                            size: 16,
                                                          );
                                                        }),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        '${stats.averageRating.toStringAsFixed(1)}/5.0',
                                                        style: GoogleFonts.poppins(
                                                          color: Colors.amber[700],
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      const Spacer(),
                                                      Text(
                                                        '${stats.totalRatings} reviews',
                                                        style: GoogleFonts.poppins(
                                                          color: Colors.white70,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (stats.recentReviews.isNotEmpty) ...[
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      '"${stats.recentReviews.first.comment}"',
                                                      style: GoogleFonts.poppins(
                                                        color: Colors.white70,
                                                        fontSize: 12,
                                                        fontStyle: FontStyle.italic,
                                                      ),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          )
                        else
                          _buildGlassCard(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                'No organizer details available for this event.',
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),

                        // Event Status Indicator
                        _buildEventStatusIndicator(),
                        const SizedBox(height: 20),

                        // QR Scanner for Active Events
                        _buildQRSection(),
                        const SizedBox(height: 20),



                        // Rating Prompt for Ended Events
                        if (_isParticipant) _buildRatingPrompt(),
                        if (_isParticipant) const SizedBox(height: 20),

                        // Description
                        _buildGlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: accentColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.description_rounded,
                                        color: accentColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'About This Event',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _eventData!['description'] as String,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 16,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Event Tags
                                if (_eventData!['tags'] != null && (_eventData!['tags'] as List).isNotEmpty)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Tags',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: (_eventData!['tags'] as List).map((tagId) {
                                          final tag = _allTags.firstWhere(
                                            (tag) => tag.id == tagId,
                                            orElse: () => Tag(id: '', name: 'Unknown', color: '#000000'),
                                          );
                                          return Chip(
                                            label: Text(tag.name, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                                            backgroundColor: Color(int.parse('0xff${tag.color.substring(1)}')),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Event Details Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Event Details',
                              style: GoogleFonts.poppins(
                                color: accentColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    final participantList = participants.entries.toList();
                                    return AlertDialog(
                                      backgroundColor: darkBackgroundColor,
                                      title: Text(
                                        'Participants (${participantList.length}/$maxParticipants)',
                                        style: GoogleFonts.poppins(color: accentColor, fontWeight: FontWeight.bold),
                                      ),
                                      content: SizedBox(
                                        width: double.maxFinite,
                                        child: participantList.isEmpty
                                            ? Text('No participants yet.', style: GoogleFonts.poppins(color: Colors.white70))
                                            : ListView.builder(
                                                shrinkWrap: true,
                                                itemCount: participantList.length,
                                                itemBuilder: (context, idx) {
                                                  final p = participantList[idx].value;
                                                  return ListTile(
                                                    leading: const Icon(Icons.person, color: accentColor),
                                                    title: Text(p['name'] ?? 'Unknown', style: GoogleFonts.poppins(color: Colors.white)),
                                                    subtitle: Text(p['email'] ?? '', style: GoogleFonts.poppins(color: Colors.white70)),
                                                  );
                                                },
                                              ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: Text('Close', style: GoogleFonts.poppins(color: accentColor)),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              icon: const Icon(Icons.people, color: accentColor),
                              label: Text(
                                '${participants.length}/$maxParticipants',
                                style: GoogleFonts.poppins(color: accentColor, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Difficulty and Fitness Level
                        Row(
                          children: [
                            Expanded(
                              child: _buildDetailCard(
                                'Difficulty',
                                difficulty,
                                Icons.fitness_center_rounded,
                                _getDifficultyColor(difficulty),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildDetailCard(
                                'Fitness Level',
                                fitnessLevel,
                                Icons.person_rounded,
                                accentColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Duration and Distance
                        Row(
                          children: [
                            Expanded(
                              child: _buildDetailCard(
                                'Duration',
                                '${duration.toStringAsFixed(1)} hours',
                                Icons.timer_rounded,
                                accentColor,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildDetailCard(
                                'Distance',
                                '${distance.toStringAsFixed(1)} km',
                                Icons.route_rounded,
                                accentColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Location Section
                        Text(
                          'Location Information',
                          style: GoogleFonts.poppins(
                            color: accentColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Event Location
                        _buildGlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: accentColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.location_on_rounded, color: accentColor),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Event Location',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  locationAddress,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Meeting Point
                        _buildGlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: accentColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.place_rounded, color: accentColor),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Meeting Point',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  meetingPointAddress,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Map Section
                        Text(
                          'Map Preview',
                          style: GoogleFonts.poppins(
                            color: accentColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Map Preview
                        _buildGlassCard(
                          child: Container(
                            height: 250,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: _getInitialMapPosition(),
                                  zoom: 13,
                                ),
                                markers: _getMapMarkers(),
                                myLocationEnabled: true,
                                myLocationButtonEnabled: true,
                                zoomControlsEnabled: true,
                                mapToolbarEnabled: false,
                                compassEnabled: true,
                                rotateGesturesEnabled: true,
                                scrollGesturesEnabled: true,
                                tiltGesturesEnabled: true,
                                zoomGesturesEnabled: true,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Schedule Section
                        Text(
                          'Schedule',
                          style: GoogleFonts.poppins(
                            color: accentColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Date and Time
                        _buildGlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: accentColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.calendar_today_rounded, color: accentColor),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        DateFormat('MMMM dd, yyyy').format(date),
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: accentColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.access_time_rounded, color: accentColor),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '$startTime - $endTime',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Pricing Section
                        Text(
                          'Pricing',
                          style: GoogleFonts.poppins(
                            color: accentColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Event Fee and Payment Details
                        _buildGlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: accentColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.attach_money_rounded, color: accentColor),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Event Fee: \$${eventFee.toStringAsFixed(2)}',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: accentColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.event_available_rounded, color: accentColor),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        paymentDeadline != null 
                                            ? 'Payment Deadline: ${DateFormat('MMMM dd, yyyy').format(paymentDeadline)}'
                                            : 'Payment Deadline: Not specified',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: accentColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.account_balance_rounded, color: accentColor),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Bank Details:',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: darkBackgroundColor.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: accentColor.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Bank: $bankName',
                                        style: GoogleFonts.poppins(color: Colors.white),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Account Number: $accountNumber',
                                        style: GoogleFonts.poppins(color: Colors.white),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Account Holder: $accountHolder',
                                        style: GoogleFonts.poppins(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Participants Section
                        Text(
                          'Participants',
                          style: GoogleFonts.poppins(
                            color: accentColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Participants Count
                        _buildGlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: accentColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.people_rounded, color: accentColor),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${participants.length}/$maxParticipants participants',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Join/Leave Button
                        if (!_isParticipant)
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _joinEvent,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'Join Event',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ),

                        if (_isParticipant)
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLeaving ? null : _leaveEvent,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.withOpacity(0.1),
                                foregroundColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: _isLeaving
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'Leave Event',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: darkBackgroundColor.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: accentColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildDetailCard(String title, String value, IconData icon, Color color) {
    return _buildGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.poppins(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasValidCoordinates(Map<String, dynamic> location, Map<String, dynamic> meetingPoint) {
    // Check for coordinates in different possible formats
    bool hasLocationCoords = false;
    bool hasMeetingCoords = false;
    
    // Check direct coordinates
    hasLocationCoords = location['latitude'] != null && location['longitude'] != null;
    hasMeetingCoords = meetingPoint['latitude'] != null && meetingPoint['longitude'] != null;
    
    // Check nested coordinates object
    if (!hasLocationCoords && location['coordinates'] != null) {
      final coords = location['coordinates'] as Map<String, dynamic>?;
      hasLocationCoords = coords?['latitude'] != null && coords?['longitude'] != null;
    }
    
    if (!hasMeetingCoords && meetingPoint['coordinates'] != null) {
      final coords = meetingPoint['coordinates'] as Map<String, dynamic>?;
      hasMeetingCoords = coords?['latitude'] != null && coords?['longitude'] != null;
    }
    
    // Also check for alternative field names
    if (!hasLocationCoords) {
      hasLocationCoords = (location['lat'] != null && location['lng'] != null) ||
          (location['lat'] != null && location['lon'] != null);
    }
    
    if (!hasMeetingCoords) {
      hasMeetingCoords = (meetingPoint['lat'] != null && meetingPoint['lng'] != null) ||
          (meetingPoint['lat'] != null && meetingPoint['lon'] != null);
    }
    
    print('Location has coords: $hasLocationCoords');
    print('Meeting point has coords: $hasMeetingCoords');
    
    return hasLocationCoords || hasMeetingCoords;
  }

  LatLng _getInitialMapPosition() {
    final location = _eventData?['location'] as Map<String, dynamic>?;
    final meetingPoint = _eventData?['meetingPoint'] as Map<String, dynamic>?;
    
    print('DEBUG: Location data: $location');
    print('DEBUG: Meeting point data: $meetingPoint');
    
    // Try to get coordinates from location first
    if (location != null) {
      double? lat, lng;
      
      // Check direct coordinates
      if (location['latitude'] != null && location['longitude'] != null) {
        lat = (location['latitude'] as num).toDouble();
        lng = (location['longitude'] as num).toDouble();
        print('DEBUG: Found direct coordinates: $lat, $lng');
      }
      // Check nested coordinates object
      else if (location['coordinates'] != null) {
        final coords = location['coordinates'] as Map<String, dynamic>?;
        if (coords?['latitude'] != null && coords?['longitude'] != null) {
          lat = (coords!['latitude'] as num).toDouble();
          lng = (coords['longitude'] as num).toDouble();
          print('DEBUG: Found nested coordinates: $lat, $lng');
        }
      }
      // Check alternative field names
      else if (location['lat'] != null && location['lng'] != null) {
        lat = (location['lat'] as num).toDouble();
        lng = (location['lng'] as num).toDouble();
        print('DEBUG: Found lat/lng coordinates: $lat, $lng');
      } else if (location['lat'] != null && location['lon'] != null) {
        lat = (location['lat'] as num).toDouble();
        lng = (location['lon'] as num).toDouble();
        print('DEBUG: Found lat/lon coordinates: $lat, $lng');
      }
      
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    }
    
    // Try meeting point if location doesn't have coordinates
    if (meetingPoint != null) {
      double? lat, lng;
      
      // Check direct coordinates
      if (meetingPoint['latitude'] != null && meetingPoint['longitude'] != null) {
        lat = (meetingPoint['latitude'] as num).toDouble();
        lng = (meetingPoint['longitude'] as num).toDouble();
        print('DEBUG: Found meeting point direct coordinates: $lat, $lng');
      }
      // Check nested coordinates object
      else if (meetingPoint['coordinates'] != null) {
        final coords = meetingPoint['coordinates'] as Map<String, dynamic>?;
        if (coords?['latitude'] != null && coords?['longitude'] != null) {
          lat = (coords!['latitude'] as num).toDouble();
          lng = (coords['longitude'] as num).toDouble();
          print('DEBUG: Found meeting point nested coordinates: $lat, $lng');
        }
      }
      // Check alternative field names
      else if (meetingPoint['lat'] != null && meetingPoint['lng'] != null) {
        lat = (meetingPoint['lat'] as num).toDouble();
        lng = (meetingPoint['lng'] as num).toDouble();
        print('DEBUG: Found meeting point lat/lng coordinates: $lat, $lng');
      } else if (meetingPoint['lat'] != null && meetingPoint['lon'] != null) {
        lat = (meetingPoint['lat'] as num).toDouble();
        lng = (meetingPoint['lon'] as num).toDouble();
        print('DEBUG: Found meeting point lat/lon coordinates: $lat, $lng');
      }
      
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    }
    
    print('DEBUG: No coordinates found, using default Kuala Lumpur location');
    return const LatLng(3.1390, 101.6869); // Default to Kuala Lumpur
  }

  Set<Marker> _getMapMarkers() {
    final markers = <Marker>{};
    final location = _eventData?['location'] as Map<String, dynamic>?;
    final meetingPoint = _eventData?['meetingPoint'] as Map<String, dynamic>?;
    
    print('DEBUG: Creating markers for location: $location');
    print('DEBUG: Creating markers for meeting point: $meetingPoint');
    
    // Add event location marker
    if (location != null) {
      double? lat, lng;
      
      // Check direct coordinates
      if (location['latitude'] != null && location['longitude'] != null) {
        lat = (location['latitude'] as num).toDouble();
        lng = (location['longitude'] as num).toDouble();
        print('DEBUG: Event location direct coordinates: $lat, $lng');
      }
      // Check nested coordinates object
      else if (location['coordinates'] != null) {
        final coords = location['coordinates'] as Map<String, dynamic>?;
        if (coords?['latitude'] != null && coords?['longitude'] != null) {
          lat = (coords!['latitude'] as num).toDouble();
          lng = (coords['longitude'] as num).toDouble();
          print('DEBUG: Event location nested coordinates: $lat, $lng');
        }
      }
      // Check alternative field names
      else if (location['lat'] != null && location['lng'] != null) {
        lat = (location['lat'] as num).toDouble();
        lng = (location['lng'] as num).toDouble();
        print('DEBUG: Event location lat/lng coordinates: $lat, $lng');
      } else if (location['lat'] != null && location['lon'] != null) {
        lat = (location['lat'] as num).toDouble();
        lng = (location['lon'] as num).toDouble();
        print('DEBUG: Event location lat/lon coordinates: $lat, $lng');
      }
      
      if (lat != null && lng != null) {
        markers.add(
          Marker(
            markerId: const MarkerId('event_location'),
            position: LatLng(lat, lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(
              title: 'Event Location',
              snippet: location['address']?.toString() ?? 'Event Location',
            ),
          ),
        );
        print('DEBUG: Added event location marker at $lat, $lng');
      } else {
        print('DEBUG: No valid coordinates found for event location');
      }
    }

    // Add meeting point marker
    if (meetingPoint != null) {
      double? lat, lng;
      
      // Check direct coordinates
      if (meetingPoint['latitude'] != null && meetingPoint['longitude'] != null) {
        lat = (meetingPoint['latitude'] as num).toDouble();
        lng = (meetingPoint['longitude'] as num).toDouble();
        print('DEBUG: Meeting point direct coordinates: $lat, $lng');
      }
      // Check nested coordinates object
      else if (meetingPoint['coordinates'] != null) {
        final coords = meetingPoint['coordinates'] as Map<String, dynamic>?;
        if (coords?['latitude'] != null && coords?['longitude'] != null) {
          lat = (coords!['latitude'] as num).toDouble();
          lng = (coords['longitude'] as num).toDouble();
          print('DEBUG: Meeting point nested coordinates: $lat, $lng');
        }
      }
      // Check alternative field names
      else if (meetingPoint['lat'] != null && meetingPoint['lng'] != null) {
        lat = (meetingPoint['lat'] as num).toDouble();
        lng = (meetingPoint['lng'] as num).toDouble();
        print('DEBUG: Meeting point lat/lng coordinates: $lat, $lng');
      } else if (meetingPoint['lat'] != null && meetingPoint['lon'] != null) {
        lat = (meetingPoint['lat'] as num).toDouble();
        lng = (meetingPoint['lon'] as num).toDouble();
        print('DEBUG: Meeting point lat/lon coordinates: $lat, $lng');
      }
      
      if (lat != null && lng != null) {
        markers.add(
          Marker(
            markerId: const MarkerId('meeting_point'),
            position: LatLng(lat, lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: InfoWindow(
              title: 'Meeting Point',
              snippet: meetingPoint['address']?.toString() ?? 'Meeting Point',
            ),
          ),
        );
        print('DEBUG: Added meeting point marker at $lat, $lng');
      } else {
        print('DEBUG: No valid coordinates found for meeting point');
      }
    }

    print('DEBUG: Total markers created: ${markers.length}');
    return markers;
  }

  Widget _buildEventStatusIndicator() {
    return FutureBuilder<EventStatus>(
      future: EventStatusService.getEventStatus(widget.eventId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    strokeWidth: 2,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Loading event status...',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return const SizedBox.shrink(); // Hide on error
        }

        final status = snapshot.data ?? EventStatus.draft;
        final statusInfo = EventStatusService.getStatusDisplayInfo(status);

        return _buildGlassCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusInfo['color'].withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusInfo['icon'],
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Event Status',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusInfo['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: statusInfo['color'].withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(status),
                        color: statusInfo['color'],
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        statusInfo['title'],
                        style: GoogleFonts.poppins(
                          color: statusInfo['color'],
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  statusInfo['description'],
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getStatusIcon(EventStatus status) {
    switch (status) {
      case EventStatus.draft:
        return Icons.schedule;
      case EventStatus.published:
        return Icons.event;
      case EventStatus.started:
        return Icons.play_arrow;
      case EventStatus.ongoing:
        return Icons.play_circle_filled;
      case EventStatus.ended:
        return Icons.check_circle;
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      case 'extreme':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildQRSection() {
    return FutureBuilder<EventStatus>(
      future: EventStatusService.getEventStatus(widget.eventId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Loading Event Status...',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
          );
        }

        final status = snapshot.data ?? EventStatus.draft;
        
        // Show QR scanner for started or ongoing events
        if (status == EventStatus.started || status == EventStatus.ongoing) {
          return Column(
            children: [
              // Status indicator
              Card(
                color: Colors.green.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Event is ${status.toString().split('.').last.toUpperCase()} - QR Scanner Available',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // QR Scanner Widget
              QRAttendanceWidget(
                eventId: widget.eventId,
                isOrganizer: false, // This is for participants
              ),
            ],
          );
        }
        
        // Show status info for non-active events
        return Card(
          color: Colors.orange.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Text(
                      'QR Scanner Not Available',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.orange[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Current Event Status: ${status.toString().split('.').last.toUpperCase()}'),
                const SizedBox(height: 8),
                Text(
                  'The QR scanner will be available when the organizer starts the event.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Event status: ${status.toString().split('.').last}'),
                        action: SnackBarAction(
                          label: 'Refresh',
                          onPressed: () => setState(() {}),
                        ),
                      ),
                    );
                  },
                  icon: Icon(Icons.refresh),
                  label: Text('Check Status'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRatingPrompt() {
    return FutureBuilder<EventStatus>(
      future: EventStatusService.getEventStatus(widget.eventId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final status = snapshot.data ?? EventStatus.draft;
        
        // Only show rating prompt for ended events
        if (status == EventStatus.ended) {
          return _buildGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.star_rate,
                          color: Colors.amber,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Rate Your Experience',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'How was your experience at this event? Your feedback helps improve future events.',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToRating(),
                      icon: const Icon(Icons.rate_review),
                      label: const Text('Rate Event'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: darkBackgroundColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        return const SizedBox.shrink();
      },
    );
  }

  void _navigateToRating() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventRatingPage(
          eventId: widget.eventId,
          eventName: _eventData?['name'] ?? 'Unknown Event',
          organizerName: _eventData?['organizerName'] ?? 'Organizer',
        ),
      ),
    );
  }
}

class FullScreenPoster extends StatelessWidget {
  final String posterUrl;

  const FullScreenPoster({
    super.key,
    required this.posterUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          // Full screen image
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: posterUrl.startsWith('http')
                  ? CachedNetworkImage(
                      imageUrl: posterUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1DB954),
                        ),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(
                          Icons.error_outline,
                          color: Color(0xFF1DB954),
                          size: 50,
                        ),
                      ),
                    )
                  : Image.file(
                      File(posterUrl),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(
                          Icons.error_outline,
                          color: Color(0xFF1DB954),
                          size: 50,
                        ),
                      ),
                    ),
            ),
          ),
          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 