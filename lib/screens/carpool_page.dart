// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/carpool_matching_service.dart';
import 'carpool/create_ride_page.dart';
import 'carpool/ride_details_page.dart';
import 'carpool_chat_page.dart';

class CarpoolPage extends StatefulWidget {
  final String eventId;
  final String eventName;
  final String eventLocation;
  final DateTime eventDateTime;

  const CarpoolPage({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.eventLocation,
    required this.eventDateTime,
  });

  @override
  State<CarpoolPage> createState() => _CarpoolPageState();
}

class _CarpoolPageState extends State<CarpoolPage> with SingleTickerProviderStateMixin {
  final _carpoolService = CarpoolMatchingService();
  final _auth = FirebaseAuth.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Carpool - ${widget.eventName}'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          // Debug button for testing
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: _debugCarpool,
            tooltip: 'Debug Carpool',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Find or offer rides to ${widget.eventName}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    FloatingActionButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreateRidePage(
                              eventId: widget.eventId,
                              eventName: widget.eventName,
                              eventLocation: widget.eventLocation,
                              eventTime: widget.eventDateTime,
                            ),
                          ),
                        );
                      },
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      mini: true,
                      child: const Icon(Icons.add),
                    ),
                  ],
                ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey[600],
                      tabs: const [
                        Tab(text: 'Available Rides'),
                        Tab(text: 'My Rides'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAvailableRidesTab(),
                _buildMyRidesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableRidesTab() {
    return StreamBuilder<List<DriverOffer>>(
      stream: _carpoolService.getAvailableDriverOffersForEvent(widget.eventId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final offers = snapshot.data!;
        if (offers.isEmpty) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.directions_car_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No rides available yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Be the first to offer a ride!',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateRidePage(
                            eventId: widget.eventId,
                            eventName: widget.eventName,
                            eventLocation: widget.eventLocation,
                            eventTime: widget.eventDateTime,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Offer a Ride'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: offers.length,
          itemBuilder: (context, index) {
            return _buildRideCard(offers[index]);
          },
        );
      },
    );
  }

  Widget _buildMyRidesTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _carpoolService.getActiveCarpoolsForUser(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final carpools = snapshot.data!;
        if (carpools.isEmpty) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.event_seat_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No active rides',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Join a ride or offer one to get started!',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: carpools.length,
          itemBuilder: (context, index) {
            return _buildMyRideCard(carpools[index]);
          },
        );
      },
    );
  }



  Widget _buildRideCard(DriverOffer offer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green,
                  radius: 20,
                  child: Text(
                    offer.driverName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Verified Driver',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'RM ${offer.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildLocationRow(Icons.location_on, Colors.red, offer.pickupLocation, 'Pickup'),
            const SizedBox(height: 8),
            _buildLocationRow(Icons.location_on, Colors.green, offer.dropoffLocation, 'Dropoff'),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM d, h:mm a').format(offer.departureTime),
                  style: const TextStyle(color: Colors.grey),
                ),
                const Spacer(),
                Text(
                  '${offer.availableSeats} seats available',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.directions_car, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    offer.vehicleDetails,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RideDetailsPage(
                        offer: offer,
                        eventName: widget.eventName,
                        eventLocation: widget.eventLocation,
                        eventDateTime: widget.eventDateTime,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('View Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyRideCard(Map<String, dynamic> carpool) {
    final isDriver = carpool['driverId'] == _auth.currentUser!.uid;
    final departureTime = (carpool['departureTime'] as Timestamp).toDate();
    final passengers = carpool['passengers'] as List<dynamic>? ?? [];
    final totalPassengers = passengers.fold<int>(0, (sum, passenger) => sum + (passenger['numberOfPassengers'] as int));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isDriver ? Icons.drive_eta : Icons.event_seat,
                  color: isDriver ? Colors.blue : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  isDriver ? 'You are the driver' : 'You are a passenger',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDriver ? Colors.blue : Colors.green,
                  ),
                ),
                const Spacer(),
                Text(
                  'RM ${carpool['costPerPerson'].toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildLocationRow(Icons.location_on, Colors.red, carpool['pickupLocation'], 'Pickup'),
            const SizedBox(height: 8),
            _buildLocationRow(Icons.location_on, Colors.green, carpool['dropoffLocation'], 'Dropoff'),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM d, h:mm a').format(departureTime),
                  style: const TextStyle(color: Colors.grey),
                ),
                const Spacer(),
                Text(
                  isDriver 
                    ? '$totalPassengers passengers'
                    : '${passengers.firstWhere((p) => p['userId'] == _auth.currentUser!.uid)['numberOfPassengers']} passenger(s)',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _cancelCarpool(carpool['id']),
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openCarpoolChat(carpool),
                    icon: const Icon(Icons.chat),
                    label: Text(isDriver ? 'Chat' : 'Chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildLocationRow(IconData icon, Color color, String location, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              Text(
                location,
                style: const TextStyle(
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _cancelCarpool(String carpoolId) async {
    try {
      await _carpoolService.cancelCarpool(carpoolId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Carpool cancelled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }



  void _openCarpoolChat(Map<String, dynamic> carpool) {
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

  void _createTestRide() async {
    try {
      await _carpoolService.createDriverOffer(
        eventId: widget.eventId,
        pickupLocation: 'Test Pickup Location',
        dropoffLocation: widget.eventLocation,
        departureTime: DateTime.now().add(const Duration(hours: 1)),
        availableSeats: 4,
        costPerPerson: 50.0,
        vehicleDetails: 'Test Vehicle (Red) - TEST123 - SEDAN',
        notes: 'Test ride for debugging',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test ride offer created!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating test ride: $e')),
        );
      }
    }
  }

  void _debugCarpool() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug Carpool'),
        content: const Text('Choose a debug action:'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _createTestRide();
            },
            child: const Text('Create Test Ride'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkDatabase();
            },
            child: const Text('Check Database'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _checkDatabase() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('driverOffers')
          .where('eventId', isEqualTo: widget.eventId)
          .where('driverId', isEqualTo: user.uid)
          .get();

      print('=== DATABASE CHECK ===');
      print('Found ${snapshot.docs.length} documents for user ${user.uid}');
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        print('Document ID: ${doc.id}');
        print('Raw data: $data');
        print('Fields:');
        data.forEach((key, value) {
          print('  $key: $value (${value.runtimeType})');
        });
        print('---');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Found ${snapshot.docs.length} rides. Check console for details.')),
        );
      }
    } catch (e) {
      print('Error checking database: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
} 