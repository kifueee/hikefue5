import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math';
import '../../utils/data_utils.dart';

class AdminEventDetailsPage extends StatefulWidget {
  final String eventId;

  const AdminEventDetailsPage({
    super.key,
    required this.eventId,
  });

  @override
  State<AdminEventDetailsPage> createState() => _AdminEventDetailsPageState();
}

class _AdminEventDetailsPageState extends State<AdminEventDetailsPage> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  late TabController _tabController;
  String _selectedFilter = 'all';
  String _searchQuery = '';

  // Map related variables
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  LatLng? _eventLocation;
  LatLng? _meetingPointLocation;
  bool _isMapLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _updateEventStatus(String status) async {
    setState(() => _isLoading = true);
    try {
      await _firestore.collection('events').doc(widget.eventId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Event ${status == 'approved' ? 'approved' : 'rejected'} successfully'),
            backgroundColor: status == 'approved' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating event: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text('Are you sure you want to delete this event? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _firestore.collection('events').doc(widget.eventId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Event deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting event: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _initializeMap(Map<String, dynamic> location, Map<String, dynamic> meetingPoint) async {
    try {
      Set<Marker> markers = {};
      
      // Add event location marker
      final locationCoordinates = location['coordinates'] as Map<String, dynamic>?;
      if (locationCoordinates != null && 
          locationCoordinates['latitude'] != null && 
          locationCoordinates['longitude'] != null) {
        final eventLat = double.tryParse(locationCoordinates['latitude'].toString());
        final eventLng = double.tryParse(locationCoordinates['longitude'].toString());
        
        if (eventLat != null && eventLng != null && eventLat != 0.0 && eventLng != 0.0) {
          _eventLocation = LatLng(eventLat, eventLng);
          markers.add(
            Marker(
              markerId: const MarkerId('event_location'),
              position: _eventLocation!,
              infoWindow: InfoWindow(
                title: 'Event Location',
                snippet: location['address']?.toString() ?? 'No address',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            ),
          );
        }
      }
      
      // Add meeting point marker
      final meetingPointCoordinates = meetingPoint['coordinates'] as Map<String, dynamic>?;
      if (meetingPointCoordinates != null && 
          meetingPointCoordinates['latitude'] != null && 
          meetingPointCoordinates['longitude'] != null) {
        final meetingLat = double.tryParse(meetingPointCoordinates['latitude'].toString());
        final meetingLng = double.tryParse(meetingPointCoordinates['longitude'].toString());
        
        if (meetingLat != null && meetingLng != null && meetingLat != 0.0 && meetingLng != 0.0) {
          _meetingPointLocation = LatLng(meetingLat, meetingLng);
          markers.add(
            Marker(
              markerId: const MarkerId('meeting_point'),
              position: _meetingPointLocation!,
              infoWindow: InfoWindow(
                title: 'Meeting Point',
                snippet: meetingPoint['address']?.toString() ?? 'No address',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            ),
          );
        }
      }
      
      setState(() {
        _markers = markers;
        _isMapLoading = false;
      });
      
      // Fit map to show all markers
      if (markers.isNotEmpty && _mapController != null) {
        _fitMapToMarkers();
      }
    } catch (e) {
      print('Error initializing map: $e');
      setState(() {
        _isMapLoading = false;
      });
    }
  }

  void _fitMapToMarkers() {
    if (_mapController == null || _markers.isEmpty) return;
    
    if (_markers.length == 1) {
      final marker = _markers.first;
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: marker.position,
            zoom: 15,
          ),
        ),
      );
    } else {
      // Fit to show all markers
      final bounds = _getBounds();
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50),
      );
    }
  }

  LatLngBounds _getBounds() {
    double? minLat, maxLat, minLng, maxLng;
    
    for (final marker in _markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;
      
      minLat = minLat == null ? lat : min(minLat, lat);
      maxLat = maxLat == null ? lat : max(maxLat, lat);
      minLng = minLng == null ? lng : min(minLng, lng);
      maxLng = maxLng == null ? lng : max(maxLng, lng);
    }
    
    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('events').doc(widget.eventId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Event Details'),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final event = snapshot.data!.data() as Map<String, dynamic>;
        final media = event['media'] as Map<String, dynamic>? ?? {};
        final posterUrl = media['posterUrl']?.toString();
        final details = event['details'] as Map<String, dynamic>? ?? {};
        final participants = event['participants'] as Map<String, dynamic>? ?? {};
        final date = (event['date'] as Timestamp?)?.toDate() ?? DateTime.now();
        final status = event['status']?.toString() ?? 'pending';
        final organizer = event['organizer'] as Map<String, dynamic>? ?? {};
        final location = event['location'] as Map<String, dynamic>? ?? {};
        final meetingPoint = event['meetingPoint'] as Map<String, dynamic>? ?? {};
        final schedule = event['schedule'] as Map<String, dynamic>? ?? {};
        final pricing = event['pricing'] as Map<String, dynamic>? ?? {};

        // Calculate statistics
        final totalParticipants = participants.length;
        final paidParticipants = participants.values
            .where((p) => (p as Map<String, dynamic>)['paymentStatus'] == 'paid')
            .length;
        final pendingParticipants = totalParticipants - paidParticipants;
        final revenue = paidParticipants * (double.tryParse(pricing['eventFee']?.toString() ?? '0') ?? 0);

        return Scaffold(
          backgroundColor: const Color(0xFFF4F3EF),
          appBar: AppBar(
            title: Text(event['name']?.toString() ?? 'Event Details'),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF2C3E50),
            elevation: 1,
            shadowColor: Colors.black.withOpacity(0.1),
            actions: [
              _buildStatusChip(status),
              const SizedBox(width: 16),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Stat Cards
                Row(
                  children: [
                    Expanded(child: _buildStatCard('Total Participants', totalParticipants.toString(), Icons.people, Colors.blue)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildStatCard('Paid', paidParticipants.toString(), Icons.check_circle, Colors.green)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildStatCard('Pending', pendingParticipants.toString(), Icons.pending, Colors.orange)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildStatCard('Revenue', 'RM ${revenue.toStringAsFixed(2)}', Icons.monetization_on, Colors.purple)),
                  ],
                ),
                const SizedBox(height: 24),

                // Main Content: Two-column layout
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildContentCard(
                            title: 'Event Details',
                            icon: Icons.event_note,
                            iconColor: const Color(0xFFE91E63),
                            child: _buildEventDetailsContent(details, event),
                          ),
                          const SizedBox(height: 24),
                          _buildContentCard(
                            title: 'Participant Management',
                            icon: Icons.people_alt,
                            iconColor: Colors.blue,
                            child: _buildParticipantsTab(participants, organizer),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Right Column
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildContentCard(
                            title: 'Event Actions',
                            icon: Icons.settings,
                            iconColor: Colors.grey,
                            child: _buildSettingsTab(
                              status: status,
                              onUpdateStatus: _updateEventStatus,
                              onDelete: _deleteEvent,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildContentCard(
                            title: 'Location & Map',
                            icon: Icons.map,
                            iconColor: Colors.green,
                            child: _buildLocationTab(location, meetingPoint),
                          ),
                          const SizedBox(height: 24),
                           _buildContentCard(
                            title: 'Description',
                            icon: Icons.description,
                            iconColor: Colors.orange,
                            child: _buildDescriptionContent(event),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContentCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Divider(color: Colors.grey.shade200),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildEventDetailsContent(
    Map<String, dynamic> details,
    Map<String, dynamic> event,
  ) {
    return Column(
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 4.0,
          children: [
            _buildDetailItem('Duration', '${details['duration']?.toString() ?? 'N/A'} hours', Icons.access_time, const Color(0xFF2E8B57)),
            _buildDetailItem('Distance', '${details['distance']?.toString() ?? 'N/A'} km', Icons.straighten, const Color(0xFF228B22)),
            _buildDetailItem('Fitness Level', details['fitnessLevel']?.toString() ?? 'N/A', Icons.fitness_center, const Color(0xFF8FBC8F)),
            _buildDetailItem('Difficulty', details['difficulty']?.toString() ?? 'N/A', Icons.trending_up, const Color(0xFF8B4513)),
            _buildDetailItem('Max Participants', details['maxParticipants']?.toString() ?? 'N/A', Icons.people, const Color(0xFF6B8E23)),
            _buildDetailItem('Current', '${event['participants']?.length ?? 0}', Icons.person_add, const Color(0xFF9ACD32)),
          ],
        ),
        const SizedBox(height: 8),
        // Progress bar
        if (details['maxParticipants'] != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Registration Progress',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                  ),
                  Text(
                    '${event['participants']?.length ?? 0}/${details['maxParticipants']}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF556B2F)),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              LinearProgressIndicator(
                value: (event['participants']?.length ?? 0) / (int.tryParse(details['maxParticipants']?.toString() ?? '1') ?? 1),
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  (event['participants']?.length ?? 0) >= (int.tryParse(details['maxParticipants']?.toString() ?? '1') ?? 1)
                      ? const Color(0xFF8B4513)
                      : const Color(0xFF6B8E23),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[600]),
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullDescription(String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Event Description'),
        content: SingleChildScrollView(
          child: Text(description),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionContent(Map<String, dynamic> event) {
    final description = event['description']?.toString() ?? 'No description available';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          description,
          style: const TextStyle(fontSize: 15, height: 1.4),
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
        ),
        if (description.length > 80)
          TextButton(
            onPressed: () => _showFullDescription(description),
            child: const Text('Read More', style: TextStyle(fontSize: 14)),
          ),
      ],
    );
  }

  Widget _buildParticipantsTab(Map<String, dynamic> participants, Map<String, dynamic> organizer) {
    final filteredParticipants = participants.entries.where((entry) {
      final participantId = entry.key;
      final participantData = entry.value as Map<String, dynamic>;

      if (participantId == organizer['id']) return false;

      if (_searchQuery.isNotEmpty) {
        final name = participantData['name']?.toString().toLowerCase() ?? '';
        final email = participantData['email']?.toString().toLowerCase() ?? '';
        if (name.contains(_searchQuery.toLowerCase()) || email.contains(_searchQuery.toLowerCase())) {
           return true;
        } else {
          return false;
        }
      }

      switch (_selectedFilter) {
        case 'paid':
          return participantData['paymentStatus'] == 'paid';
        case 'pending':
          return participantData['paymentStatus'] == 'pending';
        default:
          return true;
      }
    }).toList();

    return Column(
      children: [
        // Search and Filter Bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[50],
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search participants...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _selectedFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                ],
                onChanged: (value) => setState(() => _selectedFilter = value!),
              ),
            ],
          ),
        ),

        // Participants List
        SizedBox(
          height: 400, // Constrain the height of the ListView
          child: filteredParticipants.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No participants found'),
                    ],
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: filteredParticipants.length,
                  itemBuilder: (context, index) {
                    final entry = filteredParticipants[index];
                    final participantId = entry.key;
                    final participantData = entry.value as Map<String, dynamic>;

                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('participants').doc(participantId).get(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData) {
                          return const SizedBox.shrink();
                        }

                        final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                        final name = userData['name']?.toString() ?? 'Unknown User';
                        final email = userData['email']?.toString() ?? 'No email';
                        final paymentStatus = participantData['paymentStatus']?.toString() ?? 'pending';
                        final paymentDetails = participantData['paymentDetails'] as Map<String, dynamic>? ?? {};
                        final registeredAt = (participantData['registeredAt'] as Timestamp?)?.toDate();

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getPaymentStatusColor(paymentStatus),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(email, style: const TextStyle(fontSize: 14)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getPaymentStatusColor(paymentStatus).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        paymentStatus.toUpperCase(),
                                        style: TextStyle(
                                          color: _getPaymentStatusColor(paymentStatus),
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (registeredAt != null) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        DateFormat('MMM dd, yyyy').format(registeredAt),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            trailing: DataUtils.safeBool(paymentDetails['paid'])
                                ? const Icon(Icons.check_circle, color: Colors.green, size: 28)
                                : const Icon(Icons.pending, color: Colors.orange, size: 28),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLocationTab(Map<String, dynamic> location, Map<String, dynamic> meetingPoint) {
    // Initialize map when this tab is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isMapLoading) {
        _initializeMap(location, meetingPoint);
      }
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event Location - More compact
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red, size: 20),
                      const SizedBox(width: 6),
                      const Text(
                        'Event Location',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDetailGrid([
                    {'Address': location['address']?.toString() ?? 'Not specified'},
                    {'Coordinates': '${location['coordinates']?['latitude']?.toString() ?? 'N/A'}, ${location['coordinates']?['longitude']?.toString() ?? 'N/A'}'},
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Meeting Point - More compact
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.meeting_room, color: Colors.blue, size: 20),
                      const SizedBox(width: 6),
                      const Text(
                        'Meeting Point',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDetailGrid([
                    {'Address': meetingPoint['address']?.toString() ?? 'Not specified'},
                    {'Coordinates': '${meetingPoint['coordinates']?['latitude']?.toString() ?? 'N/A'}, ${meetingPoint['coordinates']?['longitude']?.toString() ?? 'N/A'}'},
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Map View - Interactive
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _isMapLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Loading map...', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                      )
                    : _markers.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.map, size: 48, color: Colors.grey),
                                SizedBox(height: 12),
                                Text('No location data available', style: TextStyle(fontSize: 16)),
                              ],
                            ),
                          )
                        : Stack(
                            children: [
                              GoogleMap(
                                onMapCreated: (controller) {
                                  _mapController = controller;
                                  // Fit map to markers after controller is ready
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    _fitMapToMarkers();
                                  });
                                },
                                initialCameraPosition: CameraPosition(
                                  target: _eventLocation ?? _meetingPointLocation ?? const LatLng(3.1390, 101.6869), // Default to KL
                                  zoom: 12,
                                ),
                                markers: _markers,
                                myLocationEnabled: false,
                                myLocationButtonEnabled: false,
                                zoomControlsEnabled: true,
                                mapToolbarEnabled: false,
                                compassEnabled: true,
                              ),
                              Positioned(
                                top: 8,
                                right: 16,
                                child: Column(
                                  children: [
                                    FloatingActionButton.small(
                                      heroTag: 'adminEventDetailsZoomIn',
                                      onPressed: () {
                                        _mapController?.animateCamera(CameraUpdate.zoomIn());
                                      },
                                      backgroundColor: Colors.white,
                                      child: const Icon(Icons.add),
                                    ),
                                    const SizedBox(height: 8),
                                    FloatingActionButton.small(
                                      heroTag: 'adminEventDetailsZoomOut',
                                      onPressed: () {
                                        _mapController?.animateCamera(CameraUpdate.zoomOut());
                                      },
                                      backgroundColor: Colors.white,
                                      child: const Icon(Icons.remove),
                                    ),
                                    const SizedBox(height: 8),
                                    FloatingActionButton.small(
                                      heroTag: 'adminEventDetailsMyLocation',
                                      onPressed: () {
                                        if (_eventLocation != null) {
                                          // Implement my location functionality
                                        }
                                      },
                                      backgroundColor: Colors.white,
                                      child: const Icon(Icons.location_on),
                                    ),
                                  ],
                                ),
                              ),
                              // Legend
                              Positioned(
                                bottom: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Text('Event Location', style: TextStyle(fontSize: 14)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: const BoxDecoration(
                                              color: Colors.blue,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Text('Meeting Point', style: TextStyle(fontSize: 14)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab({
    required String status,
    required Function(String) onUpdateStatus,
    required VoidCallback onDelete,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event Status Management
          _buildSectionCard(
            title: 'Event Status Management',
            icon: Icons.toggle_on,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Update the event status to control visibility and registration.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (status != 'approved')
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ElevatedButton.icon(
                            onPressed: () => onUpdateStatus('approved'),
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Approve Event'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    if (status != 'rejected')
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: ElevatedButton.icon(
                            onPressed: () => onUpdateStatus('rejected'),
                            icon: const Icon(Icons.cancel),
                            label: const Text('Reject Event'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                )
              ],
            ),
            status: status,
          ),
          const SizedBox(height: 20),

          // Event Actions
          _buildSectionCard(
            title: 'Event Actions',
            icon: Icons.construction,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Perform administrative actions for this event.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                _buildActionButton(
                  'Delete Event',
                  Icons.delete,
                  Colors.red,
                  onDelete,
                ),
              ],
            ),
            status: status,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget content,
    required String status,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: _getStatusColor(status), size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
   Color _getPaymentStatusColor(String status) {
     switch (status) {
       case 'paid':
         return Colors.green;
       case 'pending':
         return Colors.orange;
       default:
         return Colors.grey;
     }
   }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getStatusColor(status)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: _getStatusColor(status),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Stack(
          children: [
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailGrid(List<Map<String, String>> details) {
    return Column(
      children: details.map((detail) {
        final label = detail.keys.first;
        final value = detail.values.first;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}