import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/carpool_matching_service.dart';
import '../carpool_chat_page.dart';

class CarpoolDetailsPage extends StatefulWidget {
  final String carpoolId;
  final String eventName;
  final String eventLocation;
  final DateTime eventDateTime;

  const CarpoolDetailsPage({
    super.key,
    required this.carpoolId,
    required this.eventName,
    required this.eventLocation,
    required this.eventDateTime,
  });

  @override
  State<CarpoolDetailsPage> createState() => _CarpoolDetailsPageState();
}

class _CarpoolDetailsPageState extends State<CarpoolDetailsPage> {
  final _carpoolService = CarpoolMatchingService();
  final _auth = FirebaseAuth.instance;
  Map<String, dynamic>? _carpoolData;
  List<Map<String, dynamic>> _passengers = [];
  bool _isLoading = true;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadCarpoolDetails();
  }

  Future<void> _loadCarpoolDetails() async {
    try {
      final carpoolData = await _carpoolService.getCarpoolDetails(widget.carpoolId);
      if (carpoolData != null) {
        setState(() {
          _carpoolData = carpoolData;
          _passengers = List<Map<String, dynamic>>.from(carpoolData['passengers'] ?? []);
          
          // Determine user role
          if (carpoolData['driverId'] == _auth.currentUser?.uid) {
            _userRole = 'driver';
          } else {
            _userRole = 'passenger';
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading carpool details: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelCarpool() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Carpool'),
        content: const Text('Are you sure you want to cancel this carpool?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _carpoolService.cancelCarpool(widget.carpoolId);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Carpool cancelled successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error cancelling carpool: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarpoolChatPage(
          eventId: _carpoolData!['eventId'],
          carpoolId: widget.carpoolId,
          driverEmail: _carpoolData!['driverEmail'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Carpool Details'),
          backgroundColor: const Color(0xFF004A4D),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_carpoolData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Carpool Details'),
          backgroundColor: const Color(0xFF004A4D),
        ),
        body: const Center(
          child: Text('Carpool not found'),
        ),
      );
    }

    final departureTime = (_carpoolData!['departureTime'] as Timestamp).toDate();
    final totalSeats = _carpoolData!['totalSeats'] ?? 0;
    final availableSeats = _carpoolData!['availableSeats'] ?? 0;
    final occupiedSeats = totalSeats - availableSeats;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _userRole == 'driver' ? 'My Carpool' : 'Carpool Details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF004A4D),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: _openChat,
            tooltip: 'Open Chat',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Info Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF94BC45).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.event,
                            color: Color(0xFF94BC45),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.eventName,
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                widget.eventLocation,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: Color(0xFF94BC45)),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMM dd, yyyy - HH:mm').format(widget.eventDateTime),
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Driver Info Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Driver Information',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF004A4D),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0xFF94BC45),
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _carpoolData!['driverName'] ?? 'Unknown Driver',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                _carpoolData!['driverEmail'] ?? '',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.directions_car, color: Color(0xFF94BC45)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _carpoolData!['vehicleDetails'] ?? 'No vehicle details',
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Route Info Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Route Information',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF004A4D),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _carpoolData!['pickupLocation'] ?? '',
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _carpoolData!['dropoffLocation'] ?? '',
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: Color(0xFF94BC45)),
                        const SizedBox(width: 8),
                        Text(
                          'Departure: ${DateFormat('MMM dd, yyyy - HH:mm').format(departureTime)}',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      ],
                    ),
                    if (_carpoolData!['distanceInKm'] != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.straighten, color: Color(0xFF94BC45)),
                          const SizedBox(width: 8),
                          Text(
                            'Distance: ${_carpoolData!['distanceInKm'].toStringAsFixed(1)} km',
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Seats and Cost Info
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seats & Cost',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF004A4D),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Occupied Seats:',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        Text(
                          '$occupiedSeats / $totalSeats',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF94BC45),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Available Seats:',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        Text(
                          '$availableSeats',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: availableSeats > 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cost per person:',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        Text(
                          'RM ${_carpoolData!['costPerPerson'].toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF94BC45),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Passengers List (for drivers)
            if (_userRole == 'driver' && _passengers.isNotEmpty) ...[
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.people, color: Color(0xFF94BC45)),
                          const SizedBox(width: 8),
                          Text(
                            'Passengers (${_passengers.length})',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF004A4D),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._passengers.map((passenger) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 16,
                              backgroundColor: Color(0xFF94BC45),
                              child: Icon(Icons.person, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    passenger['name'] ?? 'Unknown',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    passenger['email'] ?? '',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  if (passenger['notes'] != null && passenger['notes'].isNotEmpty)
                                    Text(
                                      'Notes: ${passenger['notes']}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF94BC45).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${passenger['numberOfPassengers']} ${passenger['numberOfPassengers'] == 1 ? 'person' : 'people'}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF94BC45),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Buttons
            if (_userRole == 'passenger') ...[
              ElevatedButton(
                onPressed: _cancelCarpool,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Cancel Carpool',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
} 