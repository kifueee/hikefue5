import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/carpool_matching_service.dart';
import 'create_ride_page.dart';

class DriverCarpoolDetailsPage extends StatefulWidget {
  final DriverOffer? offer;
  final Map<String, dynamic>? carpool;
  final String eventName;
  final String eventLocation;
  final DateTime eventDateTime;

  const DriverCarpoolDetailsPage({
    super.key,
    this.offer,
    this.carpool,
    required this.eventName,
    required this.eventLocation,
    required this.eventDateTime,
  });

  const DriverCarpoolDetailsPage.fromCarpool({
    super.key,
    required Map<String, dynamic> carpool,
    required this.eventName,
    required this.eventLocation,
    required this.eventDateTime,
  }) : carpool = carpool, offer = null;

  @override
  State<DriverCarpoolDetailsPage> createState() => _DriverCarpoolDetailsPageState();
}

class _DriverCarpoolDetailsPageState extends State<DriverCarpoolDetailsPage> {
  final Color primaryColor = const Color(0xFF004A4D);
  final Color accentColor = const Color(0xFF94BC45);
  bool _mounted = true;

  @override
  void dispose() {
    _mounted = false;
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
        title: Text(
          'Carpool Management',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => _showCarpoolMenu(),
            icon: const Icon(Icons.more_vert, color: Colors.white),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ride details card
            _buildRideDetailsCard(),
            const SizedBox(height: 16),
            
            // Statistics card
            _buildStatisticsCard(),
            const SizedBox(height: 16),
            
            // Passengers section
            _buildPassengersSection(),
            const SizedBox(height: 16),
            
            // Actions section
            _buildActionsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildRideDetailsCard() {
    // Use either offer data or carpool data
    final pickupLocation = widget.offer?.pickupLocation ?? widget.carpool?['pickupLocation'] ?? '';
    final dropoffLocation = widget.offer?.dropoffLocation ?? widget.carpool?['dropoffLocation'] ?? '';
    final departureTime = widget.offer?.departureTime ?? 
        (widget.carpool?['departureTime'] as Timestamp?)?.toDate() ?? DateTime.now();
    final costPerPerson = widget.offer?.price ?? widget.carpool?['costPerPerson']?.toDouble() ?? 0.0;
    final vehicleDetails = widget.offer?.vehicleDetails ?? widget.carpool?['vehicleDetails'] ?? '';
    final availableSeats = widget.offer?.availableSeats ?? widget.carpool?['availableSeats'] ?? 0;

    return Container(
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
                child: Text(
                  'Your Ride Details',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildDetailRow('Event', widget.eventName, Icons.event),
          _buildDetailRow('From', pickupLocation, Icons.my_location),
          _buildDetailRow('To', dropoffLocation, Icons.location_on),
          _buildDetailRow('Departure', DateFormat('MMM d, yyyy h:mm a').format(departureTime), Icons.access_time),
          _buildDetailRow('Vehicle', vehicleDetails, Icons.directions_car),
          _buildDetailRow('Cost per person', 'RM ${costPerPerson.toStringAsFixed(2)}', Icons.payment),
          _buildDetailRow('Available seats', '$availableSeats', Icons.event_seat),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getPassengersStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final passengers = snapshot.data!.docs;
        final totalPassengers = passengers.fold<int>(0, (sum, doc) {
          final data = doc.data() as Map<String, dynamic>;
          return sum + (data['numberOfPassengers'] as int? ?? 1);
        });
        
        final totalRevenue = totalPassengers * (widget.offer?.price ?? widget.carpool?['costPerPerson']?.toDouble() ?? 0.0);
        final availableSeats = widget.offer?.availableSeats ?? widget.carpool?['availableSeats'] ?? 0;
        final occupancyRate = availableSeats > 0 ? (totalPassengers / (totalPassengers + availableSeats)) * 100 : 0.0;

        return Container(
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
                  Icon(Icons.analytics, color: accentColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Ride Statistics',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Passengers',
                      '$totalPassengers',
                      Icons.group,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Revenue',
                      'RM ${totalRevenue.toStringAsFixed(0)}',
                      Icons.monetization_on,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Occupancy',
                      '${occupancyRate.toStringAsFixed(0)}%',
                      Icons.event_seat,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Available',
                      '$availableSeats seats',
                      Icons.event_available,
                      Colors.purple,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPassengersSection() {
    return Container(
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
              Icon(Icons.people, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Passengers',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          StreamBuilder<QuerySnapshot>(
            stream: _getPassengersStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final passengers = snapshot.data!.docs;
              
              if (passengers.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.person_add_outlined,
                        size: 48,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No passengers yet',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Share your ride to get passengers!',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: passengers.map((doc) {
                  final passenger = doc.data() as Map<String, dynamic>;
                  passenger['id'] = doc.id;
                  return _buildPassengerCard(passenger);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerCard(Map<String, dynamic> passenger) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: accentColor,
                radius: 20,
                child: Text(
                  (passenger['name'] as String? ?? 'P')[0].toUpperCase(),
                  style: GoogleFonts.poppins(
                    color: primaryColor,
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
                      passenger['name'] ?? 'Unknown Passenger',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${passenger['numberOfPassengers'] ?? 1} seat${(passenger['numberOfPassengers'] ?? 1) > 1 ? 's' : ''}',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Joined',
                  style: GoogleFonts.poppins(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          if (passenger['notes'] != null && passenger['notes'].isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.note, size: 16, color: Colors.blue),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      passenger['notes'],
                      style: GoogleFonts.poppins(
                        color: Colors.blue,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Joined: ${DateFormat('MMM d, h:mm a').format((passenger['joinedAt'] as Timestamp).toDate())}',
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              if (passenger['email'] != null)
                TextButton.icon(
                  onPressed: () => _contactPassenger(passenger),
                  icon: const Icon(Icons.message, size: 16),
                  label: const Text('Contact'),
                  style: TextButton.styleFrom(
                    foregroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection() {
    return Container(
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
              Icon(Icons.settings, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Actions',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildActionButton(
            icon: Icons.edit,
            label: 'Edit Ride Details',
            color: Colors.orange,
            onPressed: _editRideDetails,
          ),
          const SizedBox(height: 12),
          
          _buildActionButton(
            icon: Icons.cancel,
            label: 'Cancel Ride',
            color: Colors.red,
            onPressed: _cancelRide,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accentColor),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: color.withOpacity(0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(
          label,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Stream<QuerySnapshot> _getPassengersStream() {
    if (widget.carpool != null) {
      // If we have carpool data, get passengers from that carpool
      return FirebaseFirestore.instance
          .collection('carpools')
          .doc(widget.carpool!['id'])
          .collection('passengers')
          .orderBy('joinedAt')
          .snapshots();
    } else if (widget.offer != null) {
      // If we have offer data, get all passengers from carpools created from this offer
      return FirebaseFirestore.instance
          .collection('carpools')
          .where('driverId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
          .where('eventId', isEqualTo: widget.offer!.eventId)
          .where('status', isEqualTo: 'active')
          .snapshots()
          .asyncMap((carpoolsSnapshot) async {
        final List<QueryDocumentSnapshot> allPassengers = [];
        
        for (var carpoolDoc in carpoolsSnapshot.docs) {
          final passengersSnapshot = await carpoolDoc.reference
              .collection('passengers')
              .orderBy('joinedAt')
              .get();
          allPassengers.addAll(passengersSnapshot.docs);
        }
        
        // Return a mock QuerySnapshot - in practice, you might structure this differently
        return MockQuerySnapshot(allPassengers);
      });
    } else {
      return Stream.value(MockQuerySnapshot([]));
    }
  }

  void _showCarpoolMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: primaryColor,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.white),
              title: Text(
                'Refresh Data',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() {});
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics, color: Colors.white),
              title: Text(
                'View Analytics',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _showAnalytics();
              },
            ),
            ListTile(
              leading: const Icon(Icons.report, color: Colors.white),
              title: Text(
                'Report Issue',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _reportIssue();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _contactPassenger(Map<String, dynamic> passenger) async {
    final email = passenger['email'] as String?;
    if (email != null) {
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: email,
        queryParameters: {
          'subject': 'Carpool for ${widget.eventName}',
          'body': 'Hi ${passenger['name']},\n\nRegarding our carpool for ${widget.eventName}...',
        },
      );
      
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open email app'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }





  void _editRideDetails() {
    if (widget.offer != null) {
      // Edit driver offer
      _editDriverOffer(widget.offer!);
    } else if (widget.carpool != null) {
      // Edit carpool
      _editCarpool(widget.carpool!);
    } else {
      _showErrorMessage('Cannot edit: No ride data available');
    }
  }

  void _editDriverOffer(DriverOffer offer) {
    // Convert DriverOffer to the format expected by CreateRidePage
    final existingCarpool = {
      'id': offer.id,
      'pickupLocation': offer.pickupLocation,
      'availableSeats': offer.availableSeats,
      'costPerPerson': offer.price,
      'notes': '', // DriverOffer doesn't have notes field directly
      'departureTime': Timestamp.fromDate(offer.departureTime),
      'pickupCoordinates': offer.pickupCoordinates,
      'dropoffCoordinates': offer.dropoffCoordinates,
    };

    _navigateToEditPage(existingCarpool);
  }

  void _editCarpool(Map<String, dynamic> carpool) async {
    try {
      // Find the associated driver offer ID for this carpool
      // The updateDriverOffer method expects a driver offer ID, not carpool ID
      final driverOfferQuery = await FirebaseFirestore.instance
          .collection('driverOffers')
          .where('eventId', isEqualTo: carpool['eventId'])
          .where('driverId', isEqualTo: carpool['driverId'])
          .where('status', isEqualTo: 'active')
          .get();
      
      if (driverOfferQuery.docs.isEmpty) {
        _showErrorMessage('Cannot edit: Associated driver offer not found');
        return;
      }
      
      final driverOfferId = driverOfferQuery.docs.first.id;
      
      // Convert carpool to the format expected by CreateRidePage
      // Use the driver offer ID instead of carpool ID for editing
      final existingCarpool = {
        'id': driverOfferId, // Use driver offer ID, not carpool ID
        'pickupLocation': carpool['pickupLocation'],
        'availableSeats': carpool['availableSeats'] ?? carpool['totalSeats'],
        'costPerPerson': carpool['costPerPerson'],
        'notes': carpool['notes'] ?? '',
        'departureTime': carpool['departureTime'],
        'pickupCoordinates': carpool['pickupCoordinates'],
        'dropoffCoordinates': carpool['dropoffCoordinates'],
      };

      _navigateToEditPage(existingCarpool);
    } catch (e) {
      _showErrorMessage('Error finding associated driver offer: $e');
    }
  }

  void _navigateToEditPage(Map<String, dynamic> existingCarpool) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateRidePage(
          eventId: widget.offer?.eventId ?? widget.carpool?['eventId'] ?? '',
          eventName: widget.eventName,
          eventLocation: widget.eventLocation,
          eventTime: widget.eventDateTime,
          existingCarpool: existingCarpool,
        ),
      ),
    ).then((result) {
      // Refresh the page if changes were made
      if (result == true && mounted) {
        Navigator.pop(context, true); // Go back with result to refresh parent
      }
    });
  }

  void _cancelRide() {
    // Get passenger count for better messaging
    final int passengerCount = _getPassengerCount();
    
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent accidental dismissal
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            const Text(
              'Cancel Ride',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to cancel this ride?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'This action will:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildCancellationPoint('Cancel your ride offer'),
                  if (passengerCount > 0) ...[
                    _buildCancellationPoint('Notify $passengerCount ${passengerCount == 1 ? 'passenger' : 'passengers'}'),
                    _buildCancellationPoint('Remove all passengers from this ride'),
                  ],
                  _buildCancellationPoint('Remove ride from available listings'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Keep Ride',
              style: TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performCancelRide();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'Yes, Cancel Ride',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancellationPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  int _getPassengerCount() {
    if (widget.carpool != null && widget.carpool!.containsKey('passengers')) {
      final passengers = widget.carpool!['passengers'] as List?;
      return passengers?.length ?? 0;
    }
    return 0;
  }

  void _performCancelRide() async {
    try {
      // Get passenger count for better messaging
      final int passengerCount = _getPassengerCount();
      
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cancelling ride...',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (passengerCount > 0)
                        Text(
                          'Notifying $passengerCount ${passengerCount == 1 ? 'passenger' : 'passengers'}',
                          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 30), // Long duration for process
          ),
        );
      }

      final carpoolService = CarpoolMatchingService();
      
      if (widget.offer != null) {
        // Cancel driver offer
        await carpoolService.cancelDriverOffer(widget.offer!.id);
      } else if (widget.carpool != null) {
        // For carpool cancellation, we need to find and cancel the associated driver offer
        await _cancelCarpoolByDriverOffer(carpoolService);
      } else {
        throw Exception('No ride data available to cancel');
      }

      // Hide loading snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        
        // Show success message with passenger count
        final int passengerCount = _getPassengerCount();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ride Cancelled Successfully',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (passengerCount > 0)
                        Text(
                          '✓ $passengerCount ${passengerCount == 1 ? 'passenger' : 'passengers'} notified',
                          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                        )
                      else
                        Text(
                          '✓ Ride removed from listings',
                          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        
        // Navigate back to previous screen after brief delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pop(true); // Return true to indicate cancellation
          }
        });
      }
    } catch (e) {
      if (mounted) {
        // Hide loading snackbar
        ScaffoldMessenger.of(context).clearSnackBars();
        
        // Check if this was a notification error vs cancellation error
        String errorMessage;
        if (e.toString().contains('Error sending notifications')) {
          errorMessage = 'Ride cancelled, but some passengers may not have been notified. Please contact them manually.';
        } else {
          errorMessage = 'Failed to cancel ride: ${e.toString()}';
        }
        
        _showErrorMessage(errorMessage);
      }
    }
  }

  Future<void> _cancelCarpoolByDriverOffer(CarpoolMatchingService carpoolService) async {
    if (widget.carpool == null) return;
    
    final carpool = widget.carpool!;
    
    // Find the associated driver offer to cancel
    final query = await FirebaseFirestore.instance
        .collection('driverOffers')
        .where('eventId', isEqualTo: carpool['eventId'])
        .where('driverId', isEqualTo: carpool['driverId'])
        .where('status', isEqualTo: 'active')
        .get();
    
    if (query.docs.isNotEmpty) {
      final offerId = query.docs.first.id;
      await carpoolService.cancelDriverOffer(offerId);
    } else {
      throw Exception('Associated driver offer not found');
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  void _showAnalytics() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Analytics feature coming soon!'),
        backgroundColor: Colors.purple,
      ),
    );
  }

  void _reportIssue() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report issue feature coming soon!'),
        backgroundColor: Colors.grey,
      ),
    );
  }
}

// Mock class for QuerySnapshot when we need to return passenger data
class MockQuerySnapshot implements QuerySnapshot {
  final List<QueryDocumentSnapshot> _docs;

  MockQuerySnapshot(this._docs);

  @override
  List<QueryDocumentSnapshot> get docs => _docs;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}