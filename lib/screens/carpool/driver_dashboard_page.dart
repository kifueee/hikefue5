import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/carpool_matching_service.dart';

import 'driver_carpool_details_page.dart';
import 'create_ride_page.dart';
import '../carpool_chat_page.dart';

class DriverDashboardPage extends StatefulWidget {
  final String eventId;
  final String eventName;
  final String eventLocation;
  final DateTime eventDateTime;

  const DriverDashboardPage({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.eventLocation,
    required this.eventDateTime,
  });

  @override
  State<DriverDashboardPage> createState() => _DriverDashboardPageState();
}

class _DriverDashboardPageState extends State<DriverDashboardPage>
    with TickerProviderStateMixin {
  final CarpoolMatchingService _carpoolService = CarpoolMatchingService();
  late TabController _tabController;
  bool _mounted = true;

  final Color primaryColor = const Color(0xFF004A4D);
  final Color accentColor = const Color(0xFF94BC45);
  final Color darkBackgroundColor = const Color(0xFF231F20);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _mounted = false;
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Driver Dashboard',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.eventName,
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          StreamBuilder<int>(
            stream: _getPendingRequestsCount(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    onPressed: () => _tabController.animateTo(2),
                    icon: const Icon(Icons.notifications, color: Colors.white),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accentColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'My Rides'),
            Tab(text: 'Active Carpools'),
            Tab(text: 'Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyOffersTab(),
          _buildActiveCarpoolsTab(),
          _buildPendingRequestsTab(),
        ],
      ),

    );
  }

  Widget _buildMyOffersTab() {
    if (!_mounted) return const SizedBox.shrink();

    return StreamBuilder<List<DriverOffer>>(
      stream: _carpoolService.getUserDriverOffers(widget.eventId),
      builder: (context, snapshot) {
        if (!_mounted) return const SizedBox.shrink();
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final offers = snapshot.data!;
        if (offers.isEmpty) {
          return _buildEmptyState(
            icon: Icons.drive_eta_outlined,
            title: 'No rides offered',
            subtitle: 'Create your first ride offer!',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: offers.length,
          itemBuilder: (context, index) {
            final offer = offers[index];
            return _buildDriverOfferCard(offer);
          },
        );
      },
    );
  }

  Widget _buildActiveCarpoolsTab() {
    if (!_mounted) return const SizedBox.shrink();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getDriverActiveCarpools(),
      builder: (context, snapshot) {
        if (!_mounted) return const SizedBox.shrink();
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final carpools = snapshot.data!;
        if (carpools.isEmpty) {
          return _buildEmptyState(
            icon: Icons.group_outlined,
            title: 'No active carpools',
            subtitle: 'Passengers will appear here when they join your rides',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: carpools.length,
          itemBuilder: (context, index) {
            final carpool = carpools[index];
            return _buildActiveCarpoolCard(carpool);
          },
        );
      },
    );
  }

  Widget _buildPendingRequestsTab() {
    if (!_mounted) return const SizedBox.shrink();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getPendingPassengerRequests(),
      builder: (context, snapshot) {
        if (!_mounted) return const SizedBox.shrink();
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!;
        if (requests.isEmpty) {
          return _buildEmptyState(
            icon: Icons.person_add_outlined,
            title: 'No pending requests',
            subtitle: 'New passenger requests will appear here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return _buildPendingRequestCard(request);
          },
        );
      },
    );
  }

  Widget _buildDriverOfferCard(DriverOffer offer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
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
                child: Icon(
                  Icons.drive_eta,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ride Offer',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${offer.availableSeats} seats • RM ${offer.price.toStringAsFixed(2)}/person',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              _buildOfferStatusBadge(offer.status),
            ],
          ),
          const SizedBox(height: 16),
          _buildLocationRow(Icons.my_location, Colors.blue, offer.pickupLocation, 'Pickup'),
          const SizedBox(height: 8),
          _buildLocationRow(Icons.location_on, Colors.red, offer.dropoffLocation, 'Dropoff'),
          const SizedBox(height: 8),
          _buildLocationRow(Icons.access_time, Colors.orange, 
            DateFormat('MMM d, h:mm a').format(offer.departureTime), 'Departure'),
          
          const SizedBox(height: 16),
          
          // Passengers count
          FutureBuilder<int>(
            future: _getOfferPassengerCount(offer.id),
            builder: (context, snapshot) {
              final passengerCount = snapshot.data ?? 0;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: passengerCount > 0 ? accentColor.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.group,
                      color: passengerCount > 0 ? accentColor : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      passengerCount > 0 
                        ? '$passengerCount passenger${passengerCount > 1 ? 's' : ''} joined'
                        : 'No passengers yet',
                      style: GoogleFonts.poppins(
                        color: passengerCount > 0 ? accentColor : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _editOffer(offer),
                  icon: const Icon(Icons.edit),
                  label: Text('Edit', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accentColor,
                    side: BorderSide(color: accentColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _viewOfferDetails(offer),
                  icon: const Icon(Icons.visibility),
                  label: Text('View Details', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCarpoolCard(Map<String, dynamic> carpool) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
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
                  Icons.groups,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Carpool',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${carpool['passengerCount'] ?? 0} passenger${(carpool['passengerCount'] ?? 0) != 1 ? 's' : ''}',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Active',
                  style: GoogleFonts.poppins(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLocationRow(Icons.my_location, Colors.blue, carpool['pickupLocation'], 'Pickup'),
          const SizedBox(height: 8),
          _buildLocationRow(Icons.location_on, Colors.red, carpool['dropoffLocation'], 'Dropoff'),
          const SizedBox(height: 8),
          _buildLocationRow(Icons.access_time, Colors.orange, 
            DateFormat('MMM d, h:mm a').format((carpool['departureTime'] as Timestamp).toDate()), 'Departure'),
          
          const SizedBox(height: 16),
          
          // Recent passengers preview
          if (carpool['recentPassengers'] != null && carpool['recentPassengers'].isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Passengers:',
                    style: GoogleFonts.poppins(
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...((carpool['recentPassengers'] as List).take(2).map((passenger) =>
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '• ${passenger['name']} (${passenger['numberOfPassengers']} seat${passenger['numberOfPassengers'] > 1 ? 's' : ''})',
                        style: GoogleFonts.poppins(
                          color: Colors.blue.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )).toList(),
                  if ((carpool['recentPassengers'] as List).length > 2)
                    Text(
                      '... and ${(carpool['recentPassengers'] as List).length - 2} more',
                      style: GoogleFonts.poppins(
                        color: Colors.blue.withOpacity(0.6),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _contactPassengers(carpool),
                  icon: const Icon(Icons.message),
                  label: Text('Message All', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _viewCarpoolDetails(carpool),
                  icon: const Icon(Icons.manage_accounts),
                  label: Text('Manage', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRequestCard(Map<String, dynamic> request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.orange,
                child: Text(
                  (request['passengerName'] as String? ?? 'P')[0].toUpperCase(),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${request['passengerName']} wants to join',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${request['numberOfPassengers']} seat${request['numberOfPassengers'] > 1 ? 's' : ''} requested',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'New',
                  style: GoogleFonts.poppins(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Request details
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (request['notes'] != null && request['notes'].isNotEmpty) ...[
                  Text(
                    'Notes: ${request['notes']}',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  'Requested: ${DateFormat('MMM d, h:mm a').format((request['requestedAt'] as Timestamp).toDate())}',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                if (request['pickupPreference'] != null)
                  Text(
                    'Pickup: ${request['pickupPreference']} location',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _declineRequest(request),
                  icon: const Icon(Icons.close),
                  label: Text('Decline', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _approveRequest(request),
                  icon: const Icon(Icons.check),
                  label: Text('Approve', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.white.withOpacity(0.6),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, Color color, String location, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            location,
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOfferStatusBadge(CarpoolStatus status) {
    Color badgeColor;
    String statusText;
    
    switch (status) {
      case CarpoolStatus.active:
        badgeColor = Colors.green;
        statusText = 'Active';
        break;
      case CarpoolStatus.completed:
        badgeColor = Colors.blue;
        statusText = 'Full';
        break;
      case CarpoolStatus.cancelled:
        badgeColor = Colors.red;
        statusText = 'Cancelled';
        break;
      default:
        badgeColor = Colors.grey;
        statusText = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        statusText,
        style: GoogleFonts.poppins(
          color: badgeColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  // Stream methods for real-time data
  Stream<List<Map<String, dynamic>>> _getDriverActiveCarpools() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('carpools')
        .where('driverId', isEqualTo: user.uid)
        .where('eventId', isEqualTo: widget.eventId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .asyncMap((snapshot) async {
      final List<Map<String, dynamic>> carpools = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        
        // Get passengers for this carpool
        final passengersSnapshot = await doc.reference.collection('passengers').get();
        data['passengerCount'] = passengersSnapshot.docs.length;
        data['recentPassengers'] = passengersSnapshot.docs
            .map((passengerDoc) => passengerDoc.data())
            .toList();
        
        carpools.add(data);
      }
      
      return carpools;
    });
  }

  Stream<List<Map<String, dynamic>>> _getPendingPassengerRequests() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    // Get pending requests from a theoretical pendingRequests collection
    // In practice, you might implement this differently based on your data structure
    return FirebaseFirestore.instance
        .collection('passengerRequests')
        .where('driverId', isEqualTo: user.uid)
        .where('eventId', isEqualTo: widget.eventId)
        .where('status', isEqualTo: 'pending')
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            })
            .toList());
  }

  Stream<int> _getPendingRequestsCount() {
    return _getPendingPassengerRequests().map((requests) => requests.length);
  }

  Future<int> _getOfferPassengerCount(String offerId) async {
    final carpoolsSnapshot = await FirebaseFirestore.instance
        .collection('carpools')
        .where('driverId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
        .where('eventId', isEqualTo: widget.eventId)
        .where('status', isEqualTo: 'active')
        .get();

    int totalPassengers = 0;
    for (var carpoolDoc in carpoolsSnapshot.docs) {
      final passengersSnapshot = await carpoolDoc.reference.collection('passengers').get();
      totalPassengers += passengersSnapshot.docs.length;
    }
    
    return totalPassengers;
  }

  // Action methods

  void _editOffer(DriverOffer offer) {
    // Convert DriverOffer to the format expected by CreateRidePage
    final existingCarpool = {
      'id': offer.id,
      'pickupLocation': offer.pickupLocation,
      'availableSeats': offer.availableSeats,
      'costPerPerson': offer.price,
      'notes': '', // DriverOffer doesn't have notes field
      'departureTime': Timestamp.fromDate(offer.departureTime),
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateRidePage(
          eventId: widget.eventId,
          eventName: widget.eventName,
          eventLocation: widget.eventLocation,
          eventTime: widget.eventDateTime,
          existingCarpool: existingCarpool,
        ),
      ),
    );
  }

  void _viewOfferDetails(DriverOffer offer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverCarpoolDetailsPage(
          offer: offer,
          eventName: widget.eventName,
          eventLocation: widget.eventLocation,
          eventDateTime: widget.eventDateTime,
        ),
      ),
    );
  }

  void _viewCarpoolDetails(Map<String, dynamic> carpool) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverCarpoolDetailsPage.fromCarpool(
          carpool: carpool,
          eventName: widget.eventName,
          eventLocation: widget.eventLocation,
          eventDateTime: widget.eventDateTime,
        ),
      ),
    );
  }

  void _contactPassengers(Map<String, dynamic> carpool) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarpoolChatPage(
          eventId: carpool['eventId'],
          carpoolId: carpool['id'],
          driverEmail: carpool['driverEmail'],
        ),
      ),
    );
  }

  Future<void> _approveRequest(Map<String, dynamic> request) async {
    try {
      await _carpoolService.approvePassengerRequest(request['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Approved ${request['passengerName']}\'s request!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _declineRequest(Map<String, dynamic> request) async {
    String? reason;
    
    // Show dialog to get decline reason
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Decline Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to decline ${request['passengerName']}\'s request?'),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g., Not enough seats, change of plans...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              onChanged: (value) => reason = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'decline'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (result != 'decline') return;

    try {
      await _carpoolService.declinePassengerRequest(request['id'], reason: reason);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Declined ${request['passengerName']}\'s request'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error declining request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}