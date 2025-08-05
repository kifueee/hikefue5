import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/event_status_service.dart';

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

class EventDetailsPage extends StatelessWidget {
  final String eventId;
  final Map<String, dynamic> eventData;

  const EventDetailsPage({super.key, required this.eventId, required this.eventData});

  @override
  Widget build(BuildContext context) {
    final name = eventData['name'] as String? ?? 'Unnamed Event';
    final imageUrl = eventData['media']?['posterUrl'] as String?;
    final date = (eventData['date'] as dynamic)?.toDate();
    final location = eventData['location']?['address'] as String? ?? 'Location TBD';
    final meetingPoint = eventData['meetingPoint']?['address'] as String? ?? 'TBD';
    final currentParticipants = eventData['details']?['currentParticipants'] as int? ?? 0;
    final maxParticipants = eventData['details']?['maxParticipants'] as int? ?? 0;
    final status = eventData['status'] as String? ?? 'pending';
    final description = eventData['description'] as String? ?? '';
    final organizerName = eventData['organizer']?['name'] as String? ?? '';
    final organizerLogo = eventData['organizer']?['logoUrl'] as String?;
    final difficulty = eventData['details']?['difficulty'] as String? ?? '';
    final distance = eventData['details']?['distance'] as num? ?? 0;
    final duration = eventData['details']?['duration'] as num? ?? 0;
    final eventFee = eventData['pricing']?['eventFee'] as num? ?? 0;

    return Scaffold(
      backgroundColor: darkBackgroundColor.withOpacity(0.85),
      body: Stack(
        children: [
          // Background wallpaper
          SizedBox.expand(
            child: Image.asset(
              'assets/images/trees_background.jpg',
              fit: BoxFit.cover,
            ),
          ),
          // Lighter overlay
          Container(
            color: Colors.black.withOpacity(0.4),
          ),
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 0),
                child: Container(
                  width: 900,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LEFT COLUMN: Main info
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(40, 40, 32, 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: GoogleFonts.poppins(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: primaryColor,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.calendar_today, color: accentColor, size: 18),
                                            const SizedBox(width: 8),
                                            Text(
                                              date != null ? _formatDate(date) : 'Date TBD',
                                              style: GoogleFonts.poppins(
                                                color: Colors.grey.shade800,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(width: 24),
                                            Icon(Icons.people, color: accentColor, size: 18),
                                            const SizedBox(width: 6),
                                            Text(
                                              '$currentParticipants/$maxParticipants',
                                              style: GoogleFonts.poppins(
                                                color: Colors.grey.shade800,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Price and button
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        eventFee > 0 ? 'RM${eventFee.toStringAsFixed(2)}' : 'Free',
                                        style: GoogleFonts.poppins(
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 22,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              Text(
                                'Event Overview',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                description.isNotEmpty ? description : 'No description provided.',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey.shade900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 32),
                              _buildEventStatusIndicator(),
                              const SizedBox(height: 32),
                              Text(
                                'Event Details',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.directions_walk, color: accentColor, size: 20),
                                      const SizedBox(width: 8),
                                      Text('Difficulty: ', style: GoogleFonts.poppins(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                                      Text(eventData['details']?['difficulty'] ?? '-', style: GoogleFonts.poppins(color: Colors.grey.shade900)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.timeline, color: accentColor, size: 20),
                                      const SizedBox(width: 8),
                                      Text('Distance: ', style: GoogleFonts.poppins(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                                      Text('${eventData['details']?['distance'] ?? '-'} km', style: GoogleFonts.poppins(color: Colors.grey.shade900)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.timer, color: accentColor, size: 20),
                                      const SizedBox(width: 8),
                                      Text('Duration: ', style: GoogleFonts.poppins(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                                      Text('${eventData['details']?['duration'] ?? '-'} hours', style: GoogleFonts.poppins(color: Colors.grey.shade900)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.monetization_on, color: accentColor, size: 20),
                                      const SizedBox(width: 8),
                                      Text('Fee: ', style: GoogleFonts.poppins(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                                      Text(eventFee > 0 ? 'RM${eventFee.toStringAsFixed(2)}' : 'Free', style: GoogleFonts.poppins(color: Colors.grey.shade900)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.people, color: accentColor, size: 20),
                                      const SizedBox(width: 8),
                                      Text('Participants: ', style: GoogleFonts.poppins(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                                      Text('$currentParticipants/$maxParticipants', style: GoogleFonts.poppins(color: Colors.grey.shade900)),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // RIGHT COLUMN: Sidebar
                      Container(
                        width: 280,
                        padding: const EdgeInsets.fromLTRB(0, 40, 40, 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Event image or logo
                            if (imageUrl != null && imageUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  width: 240,
                                  height: 140,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    width: 240,
                                    height: 140,
                                    color: Colors.grey.shade200,
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    width: 240,
                                    height: 140,
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                                  ),
                                ),
                              )
                            else
                              Container(
                                width: 240,
                                height: 140,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.image, size: 48, color: Colors.grey),
                              ),
                            const SizedBox(height: 24),
                            Text(
                              'Location',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              location,
                              style: GoogleFonts.poppins(
                                color: Colors.grey.shade900,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (eventData['meetingPoint']?['address'] != null && eventData['meetingPoint']['address'].toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Meeting Point:',
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey.shade800,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        eventData['meetingPoint']['address'],
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey.shade900,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 12),
                            if (date != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.calendar_today, color: accentColor, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Date & Time:',
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey.shade800,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _formatExactDateTime(date, eventData['schedule']),
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey.shade900,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 12),
                            if (eventData['location']?['coordinates'] != null &&
                                eventData['meetingPoint']?['coordinates'] != null)
                              SizedBox(
                                width: 240,
                                height: 180,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: GoogleMap(
                                    initialCameraPosition: CameraPosition(
                                      target: LatLng(
                                        eventData['location']['coordinates']['latitude'] ?? 0.0,
                                        eventData['location']['coordinates']['longitude'] ?? 0.0,
                                      ),
                                      zoom: 13,
                                    ),
                                    markers: {
                                      Marker(
                                        markerId: const MarkerId('event_location'),
                                        position: LatLng(
                                          eventData['location']['coordinates']['latitude'] ?? 0.0,
                                          eventData['location']['coordinates']['longitude'] ?? 0.0,
                                        ),
                                        infoWindow: const InfoWindow(title: 'Event Location'),
                                      ),
                                      Marker(
                                        markerId: const MarkerId('meeting_point'),
                                        position: LatLng(
                                          eventData['meetingPoint']['coordinates']['latitude'] ?? 0.0,
                                          eventData['meetingPoint']['coordinates']['longitude'] ?? 0.0,
                                        ),
                                        infoWindow: const InfoWindow(title: 'Meeting Point'),
                                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                                      ),
                                    },
                                    zoomControlsEnabled: false,
                                    myLocationButtonEnabled: false,
                                    liteModeEnabled: true,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 24),
                            Text(
                              'Organizer Information',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (organizerLogo != null && organizerLogo.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: CircleAvatar(
                                  backgroundImage: NetworkImage(organizerLogo),
                                  radius: 22,
                                ),
                              ),
                            if (organizerName.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  organizerName,
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey.shade800,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            if (eventData['organizer']?['email'] != null && eventData['organizer']['email'].toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.email, color: accentColor, size: 18),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        eventData['organizer']['email'],
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey.shade800,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (eventData['organizer']?['phone'] != null && eventData['organizer']['phone'].toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.phone, color: accentColor, size: 18),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        eventData['organizer']['phone'],
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey.shade800,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 24),
                            Text(
                              'Share With Friends',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.facebook, color: Color(0xFF4267B2)),
                                  onPressed: () {},
                                  tooltip: 'Share on Facebook',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.share, color: Colors.black87),
                                  onPressed: () {},
                                  tooltip: 'Copy Link',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Back button (floating)
          Positioned(
            top: 32,
            left: 32,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventStatusIndicator() {
    return FutureBuilder<EventStatus>(
      future: EventStatusService.getEventStatus(eventId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Loading event status...',
                style: GoogleFonts.poppins(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          return const SizedBox.shrink(); // Hide on error
        }

        final status = snapshot.data ?? EventStatus.draft;
        final statusInfo = EventStatusService.getStatusDisplayInfo(status);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusInfo['color'].withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: statusInfo['color'].withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Text(
                statusInfo['icon'],
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Event Status',
                      style: GoogleFonts.poppins(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      statusInfo['title'],
                      style: GoogleFonts.poppins(
                        color: statusInfo['color'],
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;
    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else if (difference < 7 && difference > 0) {
      return 'In $difference days';
    } else if (difference < 0 && difference > -7) {
      return '${difference.abs()} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatExactDateTime(DateTime date, Map<String, dynamic>? schedule) {
    final dateStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    String? start = schedule != null ? schedule['startTime'] as String? : null;
    String? end = schedule != null ? schedule['endTime'] as String? : null;
    if (start != null && start.isNotEmpty && end != null && end.isNotEmpty) {
      return '$dateStr, $start - $end';
    } else if (start != null && start.isNotEmpty) {
      return '$dateStr, $start';
    } else {
      return dateStr;
    }
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
          fontSize: 13,
        ),
      ),
    );
  }
} 