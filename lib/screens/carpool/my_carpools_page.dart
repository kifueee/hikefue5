import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/carpool_matching_service.dart';
import 'create_ride_page.dart';
import 'ride_details_page.dart';
import 'carpool_details_page.dart';
import 'join_carpool_flow_page.dart';
import 'driver_dashboard_page.dart';
import '../driver_application_form.dart';

// Theme colors
const Color primaryColor = Color(0xFF004A4D);
const Color accentColor = Color(0xFF94BC45);
const Color darkBackgroundColor = Color(0xFF231F20);

class MyCarpoolsPage extends StatefulWidget {
  final String eventId;
  final String eventName;
  final String eventLocation;
  final DateTime eventDateTime;

  const MyCarpoolsPage({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.eventLocation,
    required this.eventDateTime,
  });

  @override
  State<MyCarpoolsPage> createState() => _MyCarpoolsPageState();
}

class _MyCarpoolsPageState extends State<MyCarpoolsPage> {
  final _carpoolService = CarpoolMatchingService();
  final _auth = FirebaseAuth.instance;
  bool _mounted = true;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_mounted) return const SizedBox.shrink();
    
    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Carpool Management',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _navigateToDriverDashboard(),
            icon: const Icon(Icons.dashboard, color: Colors.white),
            tooltip: 'Driver Dashboard',
          ),
        ],
      ),
      body: Column(
        children: [
                  _buildEventInfo(),
          _buildTabBar(),
                  Expanded(
            child: _buildCurrentTab(),
                  ),
                ],
              ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildEventInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
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
                  child: const Icon(Icons.event, color: accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.eventName,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        widget.eventLocation,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, color: accentColor, size: 16),
                const SizedBox(width: 4),
                Text(
                  DateFormat('EEE, MMM d, y • h:mm a').format(widget.eventDateTime),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTabButton(0, Icons.directions_car, 'Available'),
          _buildTabButton(1, Icons.drive_eta, 'Offered'),
          _buildTabButton(2, Icons.event_seat, 'Joined'),
          _buildTabButton(3, Icons.people, 'My Carpools'),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, IconData icon, String label) {
    final isSelected = _currentTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_mounted) {
            setState(() {
              _currentTabIndex = index;
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? darkBackgroundColor : Colors.white.withOpacity(0.7),
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? darkBackgroundColor : Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentTabIndex) {
      case 0:
        return _buildAvailableRidesTab();
      case 1:
        return _buildMyOfferedRidesTab();
      case 2:
        return _buildMyJoinedRidesTab();
      case 3:
        return _buildMyCarpoolsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAvailableRidesTab() {
    if (!_mounted) return const SizedBox.shrink();
    
    return StreamBuilder<List<DriverOffer>>(
      stream: _carpoolService.getAvailableDriverOffersForEvent(widget.eventId),
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.directions_car_outlined,
                  size: 64,
                  color: Colors.white.withOpacity(0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  'No available rides',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Be the first to offer a ride!',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: offers.length,
          itemBuilder: (context, index) {
            final offer = offers[index];
            return _buildRideCard(offer);
          },
        );
      },
    );
  }

  Widget _buildMyOfferedRidesTab() {
    if (!_mounted) return const SizedBox.shrink();
    
    return FutureBuilder<List<DriverOffer>>(
      future: _carpoolService.getUserDriverOffers(widget.eventId).first,
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.drive_eta_outlined,
                  size: 64,
                  color: Colors.white.withOpacity(0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  'No offered rides',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Offer a ride to help others!',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: offers.length,
          itemBuilder: (context, index) {
            final offer = offers[index];
            return _buildOfferedRideCard(offer);
          },
        );
      },
    );
  }

  Widget _buildMyJoinedRidesTab() {
    if (!_mounted) return const SizedBox.shrink();
    
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _carpoolService.getActiveCarpoolsForUser().first,
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

        final carpools = snapshot.data!
            .where((carpool) => 
                carpool['eventId'] == widget.eventId &&
                carpool['userRole'] == 'passenger')
            .toList();

        if (carpools.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_seat_outlined,
                  size: 64,
                  color: Colors.white.withOpacity(0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  'No joined rides',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Join a ride to get to the event!',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: carpools.length,
          itemBuilder: (context, index) {
            final carpool = carpools[index];
            return _buildJoinedRideCard(carpool);
          },
        );
      },
    );
  }

  Widget _buildMyCarpoolsTab() {
    if (!_mounted) return const SizedBox.shrink();
    
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _carpoolService.getActiveCarpoolsForUser().first,
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

        final carpools = snapshot.data!
            .where((carpool) => 
                carpool['eventId'] == widget.eventId &&
                carpool['userRole'] == 'driver')
            .toList();

        if (carpools.isEmpty) {
          return Center(
                  child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Colors.white.withOpacity(0.6),
                ),
                const SizedBox(height: 16),
                      Text(
                  'No active carpools',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            const SizedBox(height: 8),
                Text(
                  'Create a ride offer to start a carpool!',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: carpools.length,
          itemBuilder: (context, index) {
            final carpool = carpools[index];
            return _buildDriverCarpoolCard(carpool);
          },
        );
      },
    );
  }

  Widget _buildFloatingActionButton() {
    if (!_mounted) return const SizedBox.shrink();
    
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('driver_applications')
          .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
          .where('eventId', isEqualTo: widget.eventId)
          .get(),
      builder: (context, snapshot) {
        if (!_mounted) return const SizedBox.shrink();
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final docs = snapshot.data!.docs;
        final exists = docs.isNotEmpty;
        final status = exists ? docs.first.get('status') : null;
        
        if (!exists) {
          return FloatingActionButton.extended(
            heroTag: 'myCarpoolsApplyToBeDriver',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DriverApplicationForm(eventId: widget.eventId)),
              );
            },
            icon: const Icon(Icons.drive_eta),
            label: Text('Become a Driver', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        backgroundColor: accentColor,
                        foregroundColor: darkBackgroundColor,
          );
        } else if (status == 'pending') {
          return FloatingActionButton.extended(
            onPressed: null,
            icon: const Icon(Icons.hourglass_empty),
            label: Text('Pending Approval', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            backgroundColor: Colors.grey,
            foregroundColor: Colors.white,
          );
        } else if (status == 'approved') {
          return FutureBuilder<List<DriverOffer>>(
            future: _carpoolService.getUserDriverOffers(widget.eventId).first,
            builder: (context, snapshot) {
              if (!_mounted) return const SizedBox.shrink();
              if (!snapshot.hasData) return const SizedBox.shrink();
              
              final hasActiveDriverOffer = snapshot.data!.isNotEmpty;
              if (hasActiveDriverOffer) return const SizedBox.shrink();
              
              return FloatingActionButton.extended(
                heroTag: 'myCarpoolsCreateRide',
                onPressed: () => _showCreateRideDialog(),
                icon: const Icon(Icons.add),
                label: Text('Offer a Ride', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    backgroundColor: accentColor,
                    foregroundColor: darkBackgroundColor,
              );
            },
          );
        } else if (status == 'rejected') {
          return FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DriverApplicationForm(eventId: widget.eventId)),
              );
            },
            icon: const Icon(Icons.drive_eta),
            label: Text('Become a Driver', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
          );
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }

  // Placeholder methods for the card builders
  Widget _buildRideCard(DriverOffer offer) {
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
              CircleAvatar(
                backgroundColor: accentColor,
                child: Text(
                  offer.driverName[0].toUpperCase(),
                  style: GoogleFonts.poppins(
                    color: darkBackgroundColor,
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
                      offer.driverName,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Verified Driver',
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
                  color: accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'RM ${offer.price.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLocationRow(Icons.location_on, Colors.red.shade400, offer.pickupLocation, 'Pickup'),
          const SizedBox(height: 8),
          _buildLocationRow(Icons.location_on, Colors.green.shade400, offer.dropoffLocation, 'Dropoff'),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, size: 20, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                DateFormat('MMM d, h:mm a').format(offer.departureTime),
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const Spacer(),
              Text(
                '${offer.availableSeats} seats available',
                style: GoogleFonts.poppins(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.directions_car, size: 20, color: Colors.white70),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  offer.vehicleDetails,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RideDetailsPage(
                        offer: offer,
                        eventName: widget.eventName,
                        eventLocation: widget.eventLocation,
                        eventDateTime: widget.eventDateTime,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.visibility),
                  label: Text('View Details', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accentColor,
                    side: const BorderSide(color: accentColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showJoinCarpoolDialog(offer),
                  icon: const Icon(Icons.person_add),
                  label: Text('Join Ride', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: darkBackgroundColor,
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

  Widget _buildOfferedRideCard(DriverOffer offer) {
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
              CircleAvatar(
                backgroundColor: accentColor,
                child: const Icon(Icons.directions_car, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Ride Offer',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${offer.availableSeats} seats available',
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
                  color: accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'RM ${offer.price.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLocationRow(Icons.location_on, Colors.red.shade400, offer.pickupLocation, 'Pickup'),
          const SizedBox(height: 8),
          _buildLocationRow(Icons.location_on, Colors.green.shade400, offer.dropoffLocation, 'Dropoff'),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, size: 20, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                DateFormat('MMM d, h:mm a').format(offer.departureTime),
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.directions_car, size: 20, color: Colors.white70),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  offer.vehicleDetails,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _cancelOffer(offer.id),
                  icon: const Icon(Icons.cancel),
                  label: Text('Cancel Offer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                    side: BorderSide(color: Colors.red.shade400),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _editOffer(offer),
                  icon: const Icon(Icons.edit),
                  label: Text('Edit Offer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: darkBackgroundColor,
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

  Widget _buildJoinedRideCard(Map<String, dynamic> carpool) {
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
                CircleAvatar(
                  backgroundColor: accentColor,
                  child: Text(
                  (carpool['driverName'] as String? ?? 'D')[0].toUpperCase(),
                    style: GoogleFonts.poppins(
                      color: darkBackgroundColor,
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
                      'Driver: ${carpool['driverName'] ?? 'Unknown'}',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'You are a passenger',
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
                    color: accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                  'RM ${(carpool['costPerPerson'] as num?)?.toStringAsFixed(2) ?? '0.00'}/person',
                    style: GoogleFonts.poppins(
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          _buildLocationRow(Icons.location_on, Colors.red.shade400, carpool['pickupLocation'] ?? 'No pickup location', 'Pickup'),
            const SizedBox(height: 8),
          _buildLocationRow(Icons.location_on, Colors.green.shade400, carpool['dropoffLocation'] ?? 'No dropoff location', 'Dropoff'),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 20, color: accentColor),
                const SizedBox(width: 8),
                Text(
                DateFormat('MMM d, h:mm a').format((carpool['departureTime'] as Timestamp?)?.toDate() ?? DateTime.now()),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            if (carpool['distanceInKm'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.route, size: 20, color: accentColor),
                  const SizedBox(width: 8),
                  Text(
                    '${(carpool['distanceInKm'] as num).toStringAsFixed(1)} km',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  if (carpool['durationInMinutes'] != null) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.timer, size: 20, color: accentColor),
                    const SizedBox(width: 8),
                    Text(
                      '${carpool['durationInMinutes']} mins',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewCarpoolDetails(carpool['id']),
                    icon: const Icon(Icons.visibility),
                    label: Text('View Details', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentColor,
                    side: const BorderSide(color: accentColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _cancelJoinedRide(carpool['id']),
                    icon: const Icon(Icons.cancel),
                    label: Text('Cancel Ride', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade400,
                      side: BorderSide(color: Colors.red.shade400),
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

  Widget _buildLocationRow(IconData icon, Color color, String location, String label) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              Text(
                location,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _viewCarpoolDetails(String carpoolId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarpoolDetailsPage(
          carpoolId: carpoolId,
          eventName: widget.eventName,
          eventLocation: widget.eventLocation,
          eventDateTime: widget.eventDateTime,
        ),
      ),
    );
  }

  Future<void> _cancelJoinedRide(String carpoolId) async {
    try {
      await _carpoolService.cancelCarpool(carpoolId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride cancelled')),
        );
        // Refresh the tab
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildDriverCarpoolCard(Map<String, dynamic> carpool) {
    final passengers = List<Map<String, dynamic>>.from(carpool['passengers'] ?? []);
    final totalPassengers = passengers.fold<int>(0, (sum, passenger) => sum + (passenger['numberOfPassengers'] as int));
    
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
                CircleAvatar(
                  backgroundColor: accentColor,
                  child: const Icon(Icons.directions_car, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Carpool',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '$totalPassengers passengers • ${carpool['availableSeats']} seats left',
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
                    color: accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                  'RM ${(carpool['costPerPerson'] as num?)?.toStringAsFixed(2) ?? '0.00'}/person',
                    style: GoogleFonts.poppins(
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          _buildLocationRow(Icons.location_on, Colors.red.shade400, carpool['pickupLocation'] ?? 'No pickup location', 'Pickup'),
            const SizedBox(height: 8),
          _buildLocationRow(Icons.location_on, Colors.green.shade400, carpool['dropoffLocation'] ?? 'No dropoff location', 'Dropoff'),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 20, color: accentColor),
                const SizedBox(width: 8),
                Text(
                DateFormat('MMM d, h:mm a').format((carpool['departureTime'] as Timestamp?)?.toDate() ?? DateTime.now()),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            if (passengers.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Passengers:',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              ...passengers.take(3).map((passenger) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.white70),
                    const SizedBox(width: 8),
                    Text(
                      '${passenger['name']} (${passenger['numberOfPassengers']} ${passenger['numberOfPassengers'] == 1 ? 'person' : 'people'})',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              )).toList(),
              if (passengers.length > 3) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '... and ${passengers.length - 3} more',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _viewCarpoolDetails(carpool['id']),
                icon: const Icon(Icons.visibility),
                label: Text('View Details', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: darkBackgroundColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
      ),
    );
  }

  void _showCreateRideDialog() {
    // Placeholder implementation
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateRidePage(
        eventId: widget.eventId,
        eventName: widget.eventName,
        eventLocation: widget.eventLocation,
        eventTime: widget.eventDateTime,
      )),
    );
  }

  void _showJoinCarpoolDialog(DriverOffer offer) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JoinCarpoolFlowPage(
          offer: offer,
          eventName: widget.eventName,
          eventLocation: widget.eventLocation,
          eventDateTime: widget.eventDateTime,
        ),
      ),
    );
    
    // If successful, refresh the UI by calling setState
    if (result == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _cancelOffer(String offerId) async {
    try {
      await _carpoolService.cancelDriverOffer(offerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride offer cancelled')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

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

  void _navigateToDriverDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverDashboardPage(
          eventId: widget.eventId,
          eventName: widget.eventName,
          eventLocation: widget.eventLocation,
          eventDateTime: widget.eventDateTime,
        ),
      ),
    );
  }
} 