import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:io';
import 'event_registration_page.dart';
import '../../services/payment_service.dart';
import '../../widgets/leave_event_dialog.dart';
import '../../widgets/qr_attendance_widget.dart';
import '../../services/event_status_service.dart';
import '../../services/rating_service.dart';
import 'event_chat_page.dart';

// Theme Colors
const Color primaryColor = Color(0xFF004A4D);
const Color accentColor = Color(0xFF94BC45);
const Color darkBackgroundColor = Color(0xFF231F20);

class EventDetailsPage extends StatefulWidget {
  final String eventId;

  const EventDetailsPage({
    super.key,
    required this.eventId,
  });

  static Route<dynamic> route(String eventId) {
    return MaterialPageRoute(
      builder: (context) => EventDetailsPage(eventId: eventId),
    );
  }

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  bool _isJoining = false;
  bool _isLeaving = false;
  Map<String, dynamic>? _eventData;
  bool _isOrganizer = false;
  bool _isParticipant = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    print('EventDetailsPage initState called');
    print('Event ID: ${widget.eventId}');
    _loadEventData();
    print('initState: _isOrganizer = $_isOrganizer, _isParticipant = $_isParticipant');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEventData() async {
    print('Loading event data for ID: ${widget.eventId}');
    try {
      final eventDoc = await _firestore.collection('events').doc(widget.eventId).get();
      print('Event document exists: ${eventDoc.exists}');
      if (eventDoc.exists) {
        final data = eventDoc.data() as Map<String, dynamic>;
        print('Event data loaded: $data');
        print('Media data: ${data['media']}');
        print('Poster URL: ${data['media']?['posterUrl']}');
        
        final currentUser = _auth.currentUser;
        
        // Ensure participants map exists and is properly initialized
        if (data['participants'] == null || data['participants'] is! Map) {
          data['participants'] = <String, dynamic>{};
        }
        
        // Debug prints
        print('Current user ID: ${currentUser?.uid}');
        print('Organizer ID: ${data['organizer']?['id']}');
        print('Participants map: ${data['participants']}');
        
        final isOrganizer = data['organizer']?['id'] == currentUser?.uid;
        final participants = Map<String, dynamic>.from(data['participants'] as Map);
        final isParticipant = currentUser != null && participants.containsKey(currentUser.uid);
        
        print('Is organizer check: $isOrganizer');
        print('Is participant check: $isParticipant');
        print('Participants contains user: ${participants.containsKey(currentUser?.uid)}');
        
        setState(() {
          _eventData = data;
          _isOrganizer = isOrganizer;
          _isParticipant = isParticipant;
          _isLoading = false;
        });
        print('_loadEventData: After setState - _isOrganizer = $_isOrganizer, _isParticipant = $_isParticipant');
      }
    } catch (e) {
      print('Error loading event data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading event: $e')),
        );
      }
    }
  }

  Future<void> _joinEvent(Map<String, dynamic> participantDetails) async {
    if (_eventData == null) return;

    setState(() => _isJoining = true);

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      final participants = _eventData!['participants'] as Map<String, dynamic>? ?? {};
      if (participants.containsKey(currentUser.uid)) {
        throw Exception('Already joined this event');
      }

      final maxParticipants = (_eventData!['details'] as Map<String, dynamic>)['maxParticipants'] as int;
      if (participants.length >= maxParticipants) {
        throw Exception('Event is full');
      }

      final now = DateTime.now();
      final eventFee = (_eventData!['pricing'] as Map<String, dynamic>)['eventFee'] as double;
      final participantData = {
        'status': 'Registered',
        'role': 'participant',
        'registeredAt': Timestamp.fromDate(now),
        'paymentStatus': 'pending',
        'paymentDetails': {
          'paid': false,
          'paidAt': null,
          'amount': eventFee,
        },
        'addedBy': currentUser.uid,
        ...participantDetails,
      };

      // Update Firestore
      await _firestore.collection('events').doc(widget.eventId).update({
        'participants.${currentUser.uid}': participantData,
      });

      // Create payment record if event has a fee
      if (eventFee > 0) {
        await PaymentService.createPayment(
          eventId: widget.eventId,
          amount: eventFee,
          deadlineDays: 7,
        );
      }

      // Update local state
      setState(() {
        _isParticipant = true;
        final updatedParticipants = Map<String, dynamic>.from(participants);
        updatedParticipants[currentUser.uid] = participantData;
        _eventData = {
          ..._eventData!,
          'participants': updatedParticipants,
        };
      });

      if (mounted) {
        final message = eventFee > 0 
            ? 'Successfully joined the event! Please complete payment within 7 days.'
            : 'Successfully joined the event!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining event: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
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

  void _navigateToRegistrationPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventRegistrationPage(
          event: _eventData!,
          eventId: widget.eventId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/trees_background.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF94BC45)),
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading event details...',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_eventData == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/trees_background.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: Color(0xFF94BC45),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Event Not Found',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'The requested event could not be found.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final status = _eventData!['status']?.toString() ?? 'pending';
    final isPending = status == 'pending';
    final isRejected = status == 'rejected';

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
            child: Column(
              children: [
                // Custom App Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          _eventData!['name']?.toString() ?? 'Event Details',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Event Status Banner
                if (isPending || isRejected)
                  _buildGlassCard(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            isPending ? Icons.pending_rounded : Icons.cancel_rounded,
                            color: isPending 
                                ? const Color(0xFFFFA726)
                                : const Color(0xFFEF5350),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isPending ? 'Event Pending Approval' : 'Event Rejected',
                              style: GoogleFonts.poppins(
                                color: isPending 
                                    ? const Color(0xFFFFA726)
                                    : const Color(0xFFEF5350),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Tab Bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: darkBackgroundColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentColor.withOpacity(0.2)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: primaryColor,
                    unselectedLabelColor: Colors.white70,
                    labelStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    unselectedLabelStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                    tabs: const [
                      Tab(icon: Icon(Icons.info_outline), text: 'Overview'),
                      Tab(icon: Icon(Icons.tune), text: 'Details'),
                      Tab(icon: Icon(Icons.location_on), text: 'Location'),
                      Tab(icon: Icon(Icons.schedule), text: 'Schedule'),
                      Tab(icon: Icon(Icons.payment), text: 'Pricing'),
                    ],
                  ),
                ),

                // Join/Leave Button
                if (!_isOrganizer && status == 'approved')
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isJoining || _isLeaving ? null : () {
                                if (_isParticipant) {
                                  _leaveEvent();
                                } else {
                                  _navigateToRegistrationPage();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isParticipant ? Colors.red : accentColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: _isJoining || _isLeaving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _isParticipant ? 'Leave Event' : 'Join Event',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          if (_isParticipant) ...[
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EventChatPage(
                                      eventId: widget.eventId,
                                      eventName: _eventData?['name'] ?? 'Event Chat',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: Text('Chat', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: darkBackgroundColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                // Tab Bar View
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildDetailsTab(),
                      _buildLocationTab(),
                      _buildScheduleTab(),
                      _buildPricingTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(String title, String address, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: accentColor,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  address,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleRow(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: accentColor,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingRow(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: accentColor,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankDetailRow(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white.withOpacity(0.6),
            size: 20,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewSection(String title, String content, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: accentColor,
                size: 24,
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
              height: 1.6,
            ),
          ),
        ],
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
    
    return hasLocationCoords || hasMeetingCoords;
  }

  LatLng _getInitialMapPosition() {
    final location = _eventData?['location'] as Map<String, dynamic>?;
    final meetingPoint = _eventData?['meetingPoint'] as Map<String, dynamic>?;
    
    // Try to get coordinates from location first
    if (location != null) {
      double? lat, lng;
      
      // Check direct coordinates
      if (location['latitude'] != null && location['longitude'] != null) {
        lat = (location['latitude'] as num).toDouble();
        lng = (location['longitude'] as num).toDouble();
      }
      // Check nested coordinates object
      else if (location['coordinates'] != null) {
        final coords = location['coordinates'] as Map<String, dynamic>?;
        if (coords?['latitude'] != null && coords?['longitude'] != null) {
          lat = (coords!['latitude'] as num).toDouble();
          lng = (coords['longitude'] as num).toDouble();
        }
      }
      // Check alternative field names
      else if (location['lat'] != null && location['lng'] != null) {
        lat = (location['lat'] as num).toDouble();
        lng = (location['lng'] as num).toDouble();
      } else if (location['lat'] != null && location['lon'] != null) {
        lat = (location['lat'] as num).toDouble();
        lng = (location['lon'] as num).toDouble();
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
      }
      // Check nested coordinates object
      else if (meetingPoint['coordinates'] != null) {
        final coords = meetingPoint['coordinates'] as Map<String, dynamic>?;
        if (coords?['latitude'] != null && coords?['longitude'] != null) {
          lat = (coords!['latitude'] as num).toDouble();
          lng = (coords['longitude'] as num).toDouble();
        }
      }
      // Check alternative field names
      else if (meetingPoint['lat'] != null && meetingPoint['lng'] != null) {
        lat = (meetingPoint['lat'] as num).toDouble();
        lng = (meetingPoint['lng'] as num).toDouble();
      } else if (meetingPoint['lat'] != null && meetingPoint['lon'] != null) {
        lat = (meetingPoint['lat'] as num).toDouble();
        lng = (meetingPoint['lon'] as num).toDouble();
      }
      
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    }
    
    return const LatLng(3.1390, 101.6869); // Default to Kuala Lumpur
  }

  Set<Marker> _getMapMarkers() {
    final markers = <Marker>{};
    final location = _eventData?['location'] as Map<String, dynamic>?;
    final meetingPoint = _eventData?['meetingPoint'] as Map<String, dynamic>?;
    
    // Add event location marker
    if (location != null) {
      double? lat, lng;
      
      // Check direct coordinates
      if (location['latitude'] != null && location['longitude'] != null) {
        lat = (location['latitude'] as num).toDouble();
        lng = (location['longitude'] as num).toDouble();
      }
      // Check nested coordinates object
      else if (location['coordinates'] != null) {
        final coords = location['coordinates'] as Map<String, dynamic>?;
        if (coords?['latitude'] != null && coords?['longitude'] != null) {
          lat = (coords!['latitude'] as num).toDouble();
          lng = (coords['longitude'] as num).toDouble();
        }
      }
      // Check alternative field names
      else if (location['lat'] != null && location['lng'] != null) {
        lat = (location['lat'] as num).toDouble();
        lng = (location['lng'] as num).toDouble();
      } else if (location['lat'] != null && location['lon'] != null) {
        lat = (location['lat'] as num).toDouble();
        lng = (location['lon'] as num).toDouble();
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
      }
    }

    // Add meeting point marker
    if (meetingPoint != null) {
      double? lat, lng;
      
      // Check direct coordinates
      if (meetingPoint['latitude'] != null && meetingPoint['longitude'] != null) {
        lat = (meetingPoint['latitude'] as num).toDouble();
        lng = (meetingPoint['longitude'] as num).toDouble();
      }
      // Check nested coordinates object
      else if (meetingPoint['coordinates'] != null) {
        final coords = meetingPoint['coordinates'] as Map<String, dynamic>?;
        if (coords?['latitude'] != null && coords?['longitude'] != null) {
          lat = (coords!['latitude'] as num).toDouble();
          lng = (coords['longitude'] as num).toDouble();
        }
      }
      // Check alternative field names
      else if (meetingPoint['lat'] != null && meetingPoint['lng'] != null) {
        lat = (meetingPoint['lat'] as num).toDouble();
        lng = (meetingPoint['lng'] as num).toDouble();
      } else if (meetingPoint['lat'] != null && meetingPoint['lon'] != null) {
        lat = (meetingPoint['lat'] as num).toDouble();
        lng = (meetingPoint['lon'] as num).toDouble();
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
      }
    }

    return markers;
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

  // Tab Building Methods
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event Name
          Text(
            _eventData!['name'] as String,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Event Poster
          if (_eventData!['media'] != null && _eventData!['media']['posterUrl'] != null)
            _buildGlassCard(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullScreenPoster(
                        posterUrl: _eventData!['media']['posterUrl'],
                      ),
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
                          imageUrl: _eventData!['media']['posterUrl'],
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.transparent,
                            child: const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF94BC45)),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.transparent,
                            child: const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFF94BC45),
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
          const SizedBox(height: 16),

          // Description
          _buildOverviewSection(
            'About This Event',
            _eventData!['description'] as String,
            Icons.description,
          ),
          const SizedBox(height: 16),

          // Organizer Details
          if (_eventData!['organizer'] != null)
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
            ),
          const SizedBox(height: 16),



          // QR Scanner for Active Events (when started or ongoing)
          FutureBuilder<EventStatus>(
            future: EventStatusService.getEventStatus(widget.eventId),
            builder: (context, statusSnapshot) {
              if (statusSnapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox.shrink();
              }
              
              final eventStatus = statusSnapshot.data ?? EventStatus.draft;
              
              // Only show QR scanner when event is started or ongoing
              if (eventStatus == EventStatus.started || eventStatus == EventStatus.ongoing) {
                return Column(
                  children: [
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
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.qr_code_scanner,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Check-In Available',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    eventStatus.toString().split('.').last.toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            QRAttendanceWidget(
                              eventId: widget.eventId,
                              isOrganizer: _isOrganizer,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }
              
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Event Details',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Difficulty
          _buildDetailRow(
            'Difficulty Level',
            _eventData!['details']['difficulty']?.toString() ?? 'Easy',
            Icons.trending_up,
            _getDifficultyColor(_eventData!['details']['difficulty']?.toString() ?? 'Easy'),
          ),
          const SizedBox(height: 20),

          // Fitness Level
          _buildDetailRow(
            'Fitness Level',
            _eventData!['details']['fitnessLevel']?.toString() ?? 'Beginner',
            Icons.person_outline,
            accentColor,
          ),
          const SizedBox(height: 20),

          // Duration
          _buildDetailRow(
            'Duration',
            '${_eventData!['details']['duration']?.toDouble() ?? 0.0} hours',
            Icons.access_time,
            accentColor,
          ),
          const SizedBox(height: 20),

          // Distance
          _buildDetailRow(
            'Distance',
            '${_eventData!['details']['distance']?.toDouble() ?? 0.0} km',
            Icons.straighten,
            accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Location Information',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Event Location
          _buildLocationRow(
            'Event Location',
            _eventData!['location']['address']?.toString() ?? 'No location specified',
            Icons.location_on,
          ),
          const SizedBox(height: 20),

          // Meeting Point
          _buildLocationRow(
            'Meeting Point',
            _eventData!['meetingPoint']['address']?.toString() ?? 'No meeting point specified',
            Icons.place,
          ),
          const SizedBox(height: 24),

          // Map Preview
          if (_hasValidCoordinates(_eventData!['location'], _eventData!['meetingPoint']))
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Map Legend
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Event Location',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 24),
                      Row(
                        children: [
                          Icon(
                            Icons.place,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Meeting Point',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _getInitialMapPosition(),
                        zoom: 12,
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openFullScreenMap(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.fullscreen),
                        label: Text(
                          'Full Map',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _getDirections(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.directions),
                        label: Text(
                          'Directions',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                color: Colors.grey.withOpacity(0.1),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.map_outlined,
                      color: Colors.white.withOpacity(0.5),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Map not available',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Coordinates not provided for this event',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schedule',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Date
          _buildScheduleRow(
            'Date',
            DateFormat('EEEE, MMMM dd, yyyy').format(DateTime.fromMillisecondsSinceEpoch(_eventData!['date'].seconds * 1000)),
            Icons.calendar_today,
          ),
          const SizedBox(height: 20),

          // Time
          _buildScheduleRow(
            'Time',
            '${_eventData!['schedule']['startTime']} - ${_eventData!['schedule']['endTime']}',
            Icons.access_time,
          ),
        ],
      ),
    );
  }

  Widget _buildPricingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pricing & Payment',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Event Fee
          _buildPricingRow(
            'Event Fee',
            '\$${_eventData!['pricing']['eventFee']?.toDouble()?.toStringAsFixed(2) ?? '0.00'}',
            Icons.payment,
          ),
          const SizedBox(height: 20),

          // Payment Deadline
          _buildPricingRow(
            'Payment Deadline',
            DateFormat('EEEE, MMMM dd, yyyy').format(_eventData!['pricing']['paymentDeadline']?.toDate() ?? DateTime.now()),
            Icons.schedule,
          ),
          const SizedBox(height: 24),

          // Bank Details Section
          Text(
            'Bank Transfer Details',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          // Bank Name
          _buildBankDetailRow(
            'Bank Name',
            (_eventData!['pricing']['bankDetails'] as Map<String, dynamic>?)?['bankName']?.toString() ?? 'Not specified',
            Icons.account_balance,
          ),
          const SizedBox(height: 12),

          // Account Number
          _buildBankDetailRow(
            'Account Number',
            (_eventData!['pricing']['bankDetails'] as Map<String, dynamic>?)?['accountNumber']?.toString() ?? 'Not specified',
            Icons.account_circle,
          ),
          const SizedBox(height: 12),

          // Account Holder
          _buildBankDetailRow(
            'Account Holder',
            (_eventData!['pricing']['bankDetails'] as Map<String, dynamic>?)?['accountHolder']?.toString() ?? 'Not specified',
            Icons.person,
          ),
        ],
      ),
    );
  }

  void _openFullScreenMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenMapPage(
          eventData: _eventData!,
        ),
      ),
    );
  }

  void _getDirections() {
    final location = _eventData?['location'] as Map<String, dynamic>?;
    final meetingPoint = _eventData?['meetingPoint'] as Map<String, dynamic>?;
    
    // Show dialog to choose destination
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: darkBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Get Directions',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (location?['address'] != null)
              ListTile(
                leading: Icon(Icons.location_on, color: Colors.green),
                title: Text(
                  'Event Location',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                subtitle: Text(
                  location!['address'],
                  style: GoogleFonts.poppins(color: Colors.white70),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _launchDirections(location['address']);
                },
              ),
            if (meetingPoint?['address'] != null)
              ListTile(
                leading: Icon(Icons.place, color: Colors.blue),
                title: Text(
                  'Meeting Point',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                subtitle: Text(
                  meetingPoint!['address'],
                  style: GoogleFonts.poppins(color: Colors.white70),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _launchDirections(meetingPoint['address']);
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  void _launchDirections(String address) async {
    // Try multiple URL formats for better compatibility
    final urls = [
      'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(address)}',
      'https://maps.google.com/maps?daddr=${Uri.encodeComponent(address)}',
      'geo:0,0?q=${Uri.encodeComponent(address)}',
    ];

    bool launched = false;
    
    for (final url in urls) {
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          launched = true;
          break;
        }
      } catch (e) {
        print('Failed to launch URL $url: $e');
        continue;
      }
    }

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not launch directions. Please manually search for: $address'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Copy Address',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: address));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Address copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ),
      );
    }
  }

  void _showJoinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF282828),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Join Event',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to join this event?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleJoinEvent();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleJoinEvent() async {
    setState(() => _isJoining = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .update({
        'participants.${user.uid}': {
          'joinedAt': FieldValue.serverTimestamp(),
          'status': 'registered',
        },
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully joined the event!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining event: $e')),
      );
    } finally {
      setState(() => _isJoining = false);
    }
  }

  Future<void> _launchMaps(String address) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch maps')),
        );
      }
    }
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
      backgroundColor: Colors.black,
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
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(
                          Icons.error_outline,
                          color: Colors.white,
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
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
            ),
          ),
          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              icon: const Icon(
                Icons.close,
                color: Colors.white,
                size: 30,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

class LocationMapPage extends StatefulWidget {
  final String title;
  final String address;

  const LocationMapPage({
    super.key,
    required this.title,
    required this.address,
  });

  @override
  State<LocationMapPage> createState() => _LocationMapPageState();
}

class _LocationMapPageState extends State<LocationMapPage> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _isLoading = true;
  LatLng? _location;

  @override
  void initState() {
    super.initState();
    _getLocationCoordinates();
  }

  Future<void> _getLocationCoordinates() async {
    try {
      // Convert address to coordinates using geocoding
      List<Location> locations = await locationFromAddress(widget.address);
      
      if (locations.isNotEmpty) {
        final location = locations.first;
        final latLng = LatLng(location.latitude, location.longitude);
        
        setState(() {
          _location = latLng;
          _markers = {
            Marker(
              markerId: MarkerId(widget.address),
              position: latLng,
              infoWindow: InfoWindow(
                title: widget.title,
                snippet: widget.address,
              ),
            ),
          };
          _isLoading = false;
        });

        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: latLng,
                zoom: 15,
              ),
            ),
          );
        }
      } else {
        throw Exception('Could not find location for address');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading location: $e')),
        );
        // Fallback to default location if geocoding fails
        const defaultLocation = LatLng(3.1390, 101.6869); // Default to KL
        setState(() {
          _location = defaultLocation;
          _markers = {
            Marker(
              markerId: MarkerId(widget.address),
              position: defaultLocation,
              infoWindow: InfoWindow(
                title: widget.title,
                snippet: '${widget.address}\n(Approximate location)',
              ),
            ),
          };
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black87,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _location == null
              ? const Center(child: Text('Could not load location'))
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _location!,
                    zoom: 15,
                  ),
                  markers: _markers,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  mapToolbarEnabled: false,
                ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

class FullScreenMapPage extends StatefulWidget {
  final Map<String, dynamic> eventData;

  const FullScreenMapPage({
    super.key,
    required this.eventData,
  });

  @override
  State<FullScreenMapPage> createState() => _FullScreenMapPageState();
}

class _FullScreenMapPageState extends State<FullScreenMapPage> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _initializeMarkers();
  }

  void _initializeMarkers() {
    final location = widget.eventData['location'] as Map<String, dynamic>?;
    final meetingPoint = widget.eventData['meetingPoint'] as Map<String, dynamic>?;
    
    // Add event location marker
    if (location != null) {
      double? lat, lng;
      
      // Check direct coordinates
      if (location['latitude'] != null && location['longitude'] != null) {
        lat = (location['latitude'] as num).toDouble();
        lng = (location['longitude'] as num).toDouble();
      }
      // Check nested coordinates object
      else if (location['coordinates'] != null) {
        final coords = location['coordinates'] as Map<String, dynamic>?;
        if (coords?['latitude'] != null && coords?['longitude'] != null) {
          lat = (coords!['latitude'] as num).toDouble();
          lng = (coords['longitude'] as num).toDouble();
        }
      }
      // Check alternative field names
      else if (location['lat'] != null && location['lng'] != null) {
        lat = (location['lat'] as num).toDouble();
        lng = (location['lng'] as num).toDouble();
      } else if (location['lat'] != null && location['lon'] != null) {
        lat = (location['lat'] as num).toDouble();
        lng = (location['lon'] as num).toDouble();
      }
      
      if (lat != null && lng != null) {
        _markers.add(
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
      }
    }

    // Add meeting point marker
    if (meetingPoint != null) {
      double? lat, lng;
      
      // Check direct coordinates
      if (meetingPoint['latitude'] != null && meetingPoint['longitude'] != null) {
        lat = (meetingPoint['latitude'] as num).toDouble();
        lng = (meetingPoint['longitude'] as num).toDouble();
      }
      // Check nested coordinates object
      else if (meetingPoint['coordinates'] != null) {
        final coords = meetingPoint['coordinates'] as Map<String, dynamic>?;
        if (coords?['latitude'] != null && coords?['longitude'] != null) {
          lat = (coords!['latitude'] as num).toDouble();
          lng = (coords['longitude'] as num).toDouble();
        }
      }
      // Check alternative field names
      else if (meetingPoint['lat'] != null && meetingPoint['lng'] != null) {
        lat = (meetingPoint['lat'] as num).toDouble();
        lng = (meetingPoint['lng'] as num).toDouble();
      } else if (meetingPoint['lat'] != null && meetingPoint['lon'] != null) {
        lat = (meetingPoint['lat'] as num).toDouble();
        lng = (meetingPoint['lon'] as num).toDouble();
      }
      
      if (lat != null && lng != null) {
        _markers.add(
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
      }
    }
  }

  LatLng _getInitialPosition() {
    final location = widget.eventData['location'] as Map<String, dynamic>?;
    final meetingPoint = widget.eventData['meetingPoint'] as Map<String, dynamic>?;
    
    // Try to get coordinates from location first
    if (location != null) {
      double? lat, lng;
      
      // Check direct coordinates
      if (location['latitude'] != null && location['longitude'] != null) {
        lat = (location['latitude'] as num).toDouble();
        lng = (location['longitude'] as num).toDouble();
      }
      // Check nested coordinates object
      else if (location['coordinates'] != null) {
        final coords = location['coordinates'] as Map<String, dynamic>?;
        if (coords?['latitude'] != null && coords?['longitude'] != null) {
          lat = (coords!['latitude'] as num).toDouble();
          lng = (coords['longitude'] as num).toDouble();
        }
      }
      // Check alternative field names
      else if (location['lat'] != null && location['lng'] != null) {
        lat = (location['lat'] as num).toDouble();
        lng = (location['lng'] as num).toDouble();
      } else if (location['lat'] != null && location['lon'] != null) {
        lat = (location['lat'] as num).toDouble();
        lng = (location['lon'] as num).toDouble();
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
      }
      // Check nested coordinates object
      else if (meetingPoint['coordinates'] != null) {
        final coords = meetingPoint['coordinates'] as Map<String, dynamic>?;
        if (coords?['latitude'] != null && coords?['longitude'] != null) {
          lat = (coords!['latitude'] as num).toDouble();
          lng = (coords['longitude'] as num).toDouble();
        }
      }
      // Check alternative field names
      else if (meetingPoint['lat'] != null && meetingPoint['lng'] != null) {
        lat = (meetingPoint['lat'] as num).toDouble();
        lng = (meetingPoint['lng'] as num).toDouble();
      } else if (meetingPoint['lat'] != null && meetingPoint['lon'] != null) {
        lat = (meetingPoint['lat'] as num).toDouble();
        lng = (meetingPoint['lon'] as num).toDouble();
      }
      
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    }
    
    return const LatLng(3.1390, 101.6869); // Default to Kuala Lumpur
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Event Map',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.white),
            onPressed: () {
              _mapController?.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: _getInitialPosition(),
                    zoom: 15,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _getInitialPosition(),
          zoom: 12,
        ),
        markers: _markers,
        onMapCreated: (controller) {
          _mapController = controller;
        },
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
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
} 