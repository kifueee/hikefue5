import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CarpoolCostPage extends StatefulWidget {
  final String eventId;
  final String carpoolId;
  final String driverEmail;
  final List<String> passengers;

  const CarpoolCostPage({
    super.key,
    required this.eventId,
    required this.carpoolId,
    required this.driverEmail,
    required this.passengers,
  });

  @override
  State<CarpoolCostPage> createState() => _CarpoolCostPageState();
}

class _CarpoolCostPageState extends State<CarpoolCostPage> {
  final _totalCostController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  bool _isDriver = false;

  @override
  void initState() {
    super.initState();
    _isDriver = _auth.currentUser?.email == widget.driverEmail;
  }

  @override
  void dispose() {
    _totalCostController.dispose();
    super.dispose();
  }

  Future<void> _updateTotalCost() async {
    if (_totalCostController.text.isEmpty) return;

    try {
      final totalCost = double.parse(_totalCostController.text);
      final costPerPerson = totalCost / (widget.passengers.length + 1); // +1 for driver

      await _firestore
          .collection('events')
          .doc(widget.eventId)
          .collection('carpools')
          .doc(widget.carpoolId)
          .update({
        'totalCost': totalCost,
        'costPerPerson': costPerPerson,
        'costUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cost updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating cost: $e')),
        );
      }
    }
  }

  Future<void> _markAsPaid(String passengerEmail) async {
    try {
      await _firestore
          .collection('events')
          .doc(widget.eventId)
          .collection('carpools')
          .doc(widget.carpoolId)
          .collection('payments')
          .add({
        'passengerEmail': passengerEmail,
        'amount': 0, // Will be updated with actual cost
        'status': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment marked as paid')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error marking payment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cost Sharing'),
        backgroundColor: Colors.blue.withOpacity(0.8),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore
            .collection('events')
            .doc(widget.eventId)
            .collection('carpools')
            .doc(widget.carpoolId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final carpool = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final totalCost = (carpool['totalCost'] as num?)?.toDouble() ?? 0.0;
          final costPerPerson = (carpool['costPerPerson'] as num?)?.toDouble() ?? 0.0;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isDriver) ...[
                  const Text(
                    'Set Total Cost',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _totalCostController,
                    decoration: InputDecoration(
                      hintText: 'Enter total cost',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[800],
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _updateTotalCost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Update Cost'),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Cost Breakdown',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  color: Colors.grey[800],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildCostRow('Total Cost', '\$${totalCost.toStringAsFixed(2)}'),
                        const Divider(color: Colors.white24),
                        _buildCostRow('Cost per Person', '\$${costPerPerson.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Payment Status',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.passengers.length + 1, // +1 for driver
                    itemBuilder: (context, index) {
                      final email = index == 0 ? widget.driverEmail : widget.passengers[index - 1];
                      final isPaid = false; // TODO: Check payment status from Firestore

                      return Card(
                        color: Colors.grey[800],
                        child: ListTile(
                          title: Text(
                            email,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            isPaid ? 'Paid' : 'Pending',
                            style: TextStyle(
                              color: isPaid ? Colors.green : Colors.orange,
                            ),
                          ),
                          trailing: _isDriver && !isPaid && email != widget.driverEmail
                              ? TextButton(
                                  onPressed: () => _markAsPaid(email),
                                  child: const Text('Mark as Paid'),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCostRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
} 