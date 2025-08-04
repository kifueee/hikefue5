import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/carpool_matching_service.dart';
import '../carpool_chat_page.dart';

class MyRidesPage extends StatefulWidget {
  const MyRidesPage({super.key});

  @override
  State<MyRidesPage> createState() => _MyRidesPageState();
}

class _MyRidesPageState extends State<MyRidesPage> {
  final _carpoolService = CarpoolMatchingService();
  final _auth = FirebaseAuth.instance;

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

  Widget _buildPassengerList(List<dynamic> passengers) {
    if (passengers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No passengers yet',
          style: TextStyle(
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Passengers:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...passengers.map((passenger) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.green,
                radius: 20,
                child: Text(
                  (passenger['name'] as String)[0].toUpperCase(),
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
                      passenger['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${passenger['numberOfPassengers']} passenger${passenger['numberOfPassengers'] > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    if (passenger['notes']?.isNotEmpty ?? false)
                      Text(
                        'Notes: ${passenger['notes']}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                DateFormat('MMM d, h:mm a').format(
                  (passenger['joinedAt'] as Timestamp).toDate(),
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildCarpoolCard(Map<String, dynamic> carpool) {
    final isDriver = carpool['driverId'] == _auth.currentUser!.uid;
    final departureTime = (carpool['departureTime'] as Timestamp).toDate();
    final passengers = carpool['passengers'] as List<dynamic>? ?? [];
    final totalPassengers = passengers.fold<int>(0, (sum, passenger) => sum + (passenger['numberOfPassengers'] as int));
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isDriver ? Colors.blue : Colors.green,
                  ),
                ),
                const Spacer(),
                Text(
                  'RM ${carpool['costPerPerson'].toStringAsFixed(2)}/person',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on, size: 20, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    carpool['pickupLocation'],
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 20, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    carpool['dropoffLocation'],
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 20),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM d, h:mm a').format(departureTime),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.directions_car, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    carpool['vehicleDetails'],
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.people, size: 20),
                const SizedBox(width: 8),
                Text(
                  isDriver 
                    ? '$totalPassengers passengers • ${carpool['availableSeats']} seats available'
                    : '${passengers.firstWhere((p) => p['userId'] == _auth.currentUser!.uid)['numberOfPassengers']} passenger(s)',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            if (carpool['notes']?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Text(
                carpool['notes'],
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (isDriver && passengers.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildPassengerList(passengers),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _cancelCarpool(carpool['id']),
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _openCarpoolChat(carpool),
                  icon: const Icon(Icons.chat),
                  label: Text(isDriver ? 'Chat with Passengers' : 'Chat with Driver'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Rides'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _carpoolService.getActiveCarpoolsForUser(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final carpools = snapshot.data!;
          if (carpools.isEmpty) {
            return const Center(
              child: Text('You have no active rides'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: carpools.length,
            itemBuilder: (context, index) {
              return _buildCarpoolCard(carpools[index]);
            },
          );
        },
      ),
    );
  }
} 