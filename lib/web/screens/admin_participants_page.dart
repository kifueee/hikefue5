import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminParticipantsPage extends StatefulWidget {
  const AdminParticipantsPage({super.key});

  @override
  State<AdminParticipantsPage> createState() => _AdminParticipantsPageState();
}

class _AdminParticipantsPageState extends State<AdminParticipantsPage> {
  final _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  String _sortBy = 'name'; // 'name' or 'date'
  bool _sortAscending = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MapEntry<String, dynamic>> _getFilteredAndSortedParticipants(List<QueryDocumentSnapshot> participants) {
    var entries = participants.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return MapEntry(doc.id, data);
    }).toList();

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      entries = entries.where((entry) {
        final name = entry.value['name']?.toString().toLowerCase() ?? '';
        final email = entry.value['email']?.toString().toLowerCase() ?? '';
        final phone = entry.value['phoneNumber']?.toString().toLowerCase() ?? '';
        final searchLower = _searchQuery.toLowerCase();
        return name.contains(searchLower) || 
               email.contains(searchLower) || 
               phone.contains(searchLower);
      }).toList();
    }

    // Apply sorting
    entries.sort((a, b) {
      int comparison = 0;
      if (_sortBy == 'name') {
        final nameA = a.value['name']?.toString().toLowerCase() ?? '';
        final nameB = b.value['name']?.toString().toLowerCase() ?? '';
        comparison = nameA.compareTo(nameB);
      } else if (_sortBy == 'date') {
        final dateA = (a.value['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
        final dateB = (b.value['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
        comparison = dateA.compareTo(dateB);
      }
      return _sortAscending ? comparison : -comparison;
    });

    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Participants'),
        actions: [
          // Search field
          SizedBox(
            width: 200,
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search participants...',
                prefixIcon: Icon(Icons.search),
                border: InputBorder.none,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(width: 16),
          // Sort dropdown
          DropdownButton<String>(
            value: _sortBy,
            items: const [
              DropdownMenuItem(value: 'name', child: Text('Sort by Name')),
              DropdownMenuItem(value: 'date', child: Text('Sort by Date')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _sortBy = value;
                });
              }
            },
          ),
          IconButton(
            icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () {
              setState(() {
                _sortAscending = !_sortAscending;
              });
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('participants').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final participants = snapshot.data!.docs;
          final filteredParticipants = _getFilteredAndSortedParticipants(participants);

          if (filteredParticipants.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty
                        ? 'No participants found'
                        : 'No participants match your search',
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
            itemCount: filteredParticipants.length,
            itemBuilder: (context, index) {
              final participant = filteredParticipants[index];
              final data = participant.value;
              final email = data['email']?.toString() ?? 'No email';
              final phone = data['phoneNumber']?.toString() ?? 'No phone';

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
                          Icon(Icons.email, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              email,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.phone, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            phone,
                            style: const TextStyle(
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
} 