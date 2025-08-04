import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminOrganizerEventsPage extends StatefulWidget {
  final String organizerId;
  final String organizerName;

  const AdminOrganizerEventsPage({
    super.key,
    required this.organizerId,
    required this.organizerName,
  });

  @override
  State<AdminOrganizerEventsPage> createState() => _AdminOrganizerEventsPageState();
}

class _AdminOrganizerEventsPageState extends State<AdminOrganizerEventsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _statusFilter = 'all';
  String _sortBy = 'date';
  bool _sortAscending = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.organizerName}\'s Events'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: _statusFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Status')),
                    DropdownMenuItem(value: 'approved', child: Text('Approved')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _statusFilter = value;
                      });
                    }
                  },
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _sortBy,
                  items: const [
                    DropdownMenuItem(value: 'date', child: Text('Sort by Date')),
                    DropdownMenuItem(value: 'name', child: Text('Sort by Name')),
                    DropdownMenuItem(value: 'participants', child: Text('Sort by Participants')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _sortBy = value;
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    color: Colors.deepPurple,
                  ),
                  onPressed: () {
                    setState(() {
                      _sortAscending = !_sortAscending;
                    });
                  },
                ),
              ],
            ),
          ),
          // Events List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('events')
                  .where('organizer.id', isEqualTo: widget.organizerId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var events = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'] as String? ?? 'pending';
                  return _statusFilter == 'all' || status == _statusFilter;
                }).toList();

                // Sort events
                events.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  int comparison = 0;

                  switch (_sortBy) {
                    case 'date':
                      final aDate = (aData['date'] as Timestamp?)?.toDate() ?? DateTime(0);
                      final bDate = (bData['date'] as Timestamp?)?.toDate() ?? DateTime(0);
                      comparison = aDate.compareTo(bDate);
                      break;
                    case 'name':
                      comparison = (aData['name'] as String? ?? '')
                          .compareTo(bData['name'] as String? ?? '');
                      break;
                    case 'participants':
                      final aParticipants = (aData['participants'] as Map<String, dynamic>?)?.length ?? 0;
                      final bParticipants = (bData['participants'] as Map<String, dynamic>?)?.length ?? 0;
                      comparison = aParticipants.compareTo(bParticipants);
                      break;
                  }

                  return _sortAscending ? comparison : -comparison;
                });

                if (events.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No events found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index].data() as Map<String, dynamic>;
                    final date = (event['date'] as Timestamp?)?.toDate();
                    final status = event['status'] as String? ?? 'pending';
                    final participants = (event['participants'] as Map<String, dynamic>?)?.length ?? 0;
                    final maxParticipants = event['maxParticipants'] as int? ?? 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event['name'] as String? ?? 'Untitled Event',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (date != null)
                                        Text(
                                          'Date: ${DateFormat('MMM dd, yyyy').format(date)}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                _statusChip(status),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _infoBox(
                                  'Participants',
                                  '$participants/$maxParticipants',
                                  Icons.people,
                                ),
                                const SizedBox(width: 16),
                                _infoBox(
                                  'Location',
                                  (event['location'] as Map<String, dynamic>?)?['address']?.toString() ?? 'Not specified',
                                  Icons.location_on,
                                ),
                                const SizedBox(width: 16),
                                _infoBox(
                                  'Category',
                                  (event['category'] as Map<String, dynamic>?)?['name']?.toString() ?? 'Not specified',
                                  Icons.category,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              event['description'] as String? ?? 'No description available',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'approved':
        color = Colors.green;
        label = 'Approved';
        break;
      case 'rejected':
        color = Colors.red;
        label = 'Rejected';
        break;
      default:
        color = Colors.orange;
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _infoBox(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.deepPurple.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 