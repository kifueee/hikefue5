import 'package:flutter/material.dart';
import 'profile_page.dart';

class RideRequestsPage extends StatefulWidget {
  final String eventId;
  final String carpoolId;

  const RideRequestsPage({
    super.key,
    required this.eventId,
    required this.carpoolId,
  });

  @override
  State<RideRequestsPage> createState() => _RideRequestsPageState();
}

class _RideRequestsPageState extends State<RideRequestsPage> {
  // Sample data - Replace with Firestore data later
  final List<Map<String, dynamic>> _pendingRequests = [
    {
      'id': '1',
      'rideId': '2',
      'rideTitle': 'Kuala Lumpur to Event',
      'rideTime': '8:00 AM',
      'rideDate': '2024-03-20',
      'requesterName': 'Emma Davis',
      'requesterPhone': '+60123456789',
      'requesterLocation': 'KL Sentral',
      'passengers': 2,
      'notes': 'Will be waiting at the main entrance',
      'requestTime': '2024-03-19 10:30 AM',
    },
    {
      'id': '2',
      'rideId': '2',
      'rideTitle': 'Kuala Lumpur to Event',
      'rideTime': '8:00 AM',
      'rideDate': '2024-03-20',
      'requesterName': 'Frank Miller',
      'requesterPhone': '+60123456790',
      'requesterLocation': 'KL Sentral',
      'passengers': 1,
      'notes': 'Can meet at any location',
      'requestTime': '2024-03-19 11:15 AM',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background1.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withAlpha(77),
                Colors.black.withAlpha(128),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header with back button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Ride Requests',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.person_outline, color: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfilePage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Request Count Badge
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_pendingRequests.length} Pending Requests',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 14,
                    ),
                  ),
                ),

                // Requests List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingRequests.length,
                    itemBuilder: (context, index) {
                      final request = _pendingRequests[index];
                      return _buildRequestCard(request);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ride Info
            Text(
              request['rideTitle'],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.white70),
                const SizedBox(width: 8),
                Text(
                  '${request['rideTime']} on ${request['rideDate']}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Requester Info
            const Text(
              'Requester Details',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.person, 'Name', request['requesterName']),
            _buildDetailRow(Icons.phone, 'Phone', request['requesterPhone']),
            _buildDetailRow(Icons.location_on, 'Location', request['requesterLocation']),
            _buildDetailRow(Icons.people, 'Passengers', '${request['passengers']}'),
            if (request['notes'] != null) ...[
              const SizedBox(height: 8),
              _buildDetailRow(Icons.note, 'Notes', request['notes']),
            ],
            const SizedBox(height: 8),
            _buildDetailRow(Icons.access_time, 'Requested at', request['requestTime']),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _showRejectDialog(request),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cancel, color: Colors.red),
                      SizedBox(width: 4),
                      Text(
                        'Reject',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => _showAcceptDialog(request),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.withOpacity(0.8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Accept',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white70),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showAcceptDialog(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.9),
        title: const Text(
          'Accept Request',
          style: TextStyle(color: Colors.black),
        ),
        content: Text(
          'Are you sure you want to accept ${request['requesterName']}\'s request?',
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement acceptance in Firestore
              setState(() {
                _pendingRequests.removeWhere((r) => r['id'] == request['id']);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Request from ${request['requesterName']} accepted'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text(
              'Accept',
              style: TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.9),
        title: const Text(
          'Reject Request',
          style: TextStyle(color: Colors.black),
        ),
        content: Text(
          'Are you sure you want to reject ${request['requesterName']}\'s request?',
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement rejection in Firestore
              setState(() {
                _pendingRequests.removeWhere((r) => r['id'] == request['id']);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Request from ${request['requesterName']} rejected'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text(
              'Reject',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
} 