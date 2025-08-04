import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// For easier sorting
// Assuming you might need auth later, adding it now
// import \'package:firebase_auth/firebase_auth.dart\';

class ParticipantListPage extends StatefulWidget {
  final String eventId;

  const ParticipantListPage({super.key, required this.eventId});

  @override
  State<ParticipantListPage> createState() => _ParticipantListPageState();
}

class _ParticipantListPageState extends State<ParticipantListPage> {
  final _firestore = FirebaseFirestore.instance;
  // final _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _participants = [];
  String _errorMessage = '';
  String _sortBy = 'Name'; // Default sorting
  List<Map<String, dynamic>> _filteredParticipants = []; // New list for filtered data
  final TextEditingController _searchController = TextEditingController(); // Controller for search bar

  @override
  void initState() {
    super.initState();
    _loadParticipants();
    // Add a listener to the search controller
    _searchController.addListener(_filterParticipants);
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadParticipants() async {
    if (!mounted) return;

    try {
      // Fetch the event document
      final eventDoc = await _firestore
          .collection('events')
          .doc(widget.eventId)
          .get();

      if (!eventDoc.exists) {
        if (mounted) {
           setState(() {
             _errorMessage = 'Event not found.';
             _isLoading = false;
           });
        }
        return;
      }

      final eventData = eventDoc.data();

      if (eventData == null || !eventData.containsKey('participants')) {
         if (mounted) {
           setState(() {
             _participants = []; // No participants map found
             _isLoading = false;
           });
         }
         return;
      }

      // Get the participants map
      final participantsMap = eventData['participants'] as Map<String, dynamic>;

      if (!mounted) return;

      setState(() {
        // Convert the map values to a list of participant data
        _participants = participantsMap.entries.map((entry) {
           // Add the participant ID (which is the map key) to the data
           final data = entry.value as Map<String, dynamic>;
           data['id'] = entry.key; // Add the user's UID as the participant ID
           return data;
        }).toList();

        _sortParticipants(); // Sort after loading
        _filterParticipants(); // Filter after loading and sorting
        _isLoading = false;
      });

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading participants: ${e.toString()}';
          _isLoading = false;
        });
        print('Error loading participants: $e');
      }
    }
  }

  void _sortParticipants() {
    _participants.sort((a, b) {
      if (_sortBy == 'Name') {
        final nameA = a['name']?.toString() ?? '';
        final nameB = b['name']?.toString() ?? '';
        return nameA.compareTo(nameB);
      } else if (_sortBy == 'Registration Date') {
        // Assuming a 'registeredAt' Timestamp field exists
        final dateA = (a['registeredAt'] as Timestamp?)?.toDate() ?? DateTime(0);
        final dateB = (b['registeredAt'] as Timestamp?)?.toDate() ?? DateTime(0);
        return dateA.compareTo(dateB);
      }
      return 0; // Should not happen
    });
  }

  void _filterParticipants() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredParticipants = _participants.where((participant) {
        final name = participant['name']?.toString().toLowerCase() ?? '';
        // You can add more fields to search here, e.g., email, phone
        final email = participant['email']?.toString().toLowerCase() ?? '';
        final phone = participant['phoneNumber']?.toString().toLowerCase() ?? '';
        return name.contains(query) || email.contains(query) || phone.contains(query);
      }).toList();
    });
  }

  Future<void> _toggleParticipantStatus(String participantId, String currentStatus) async {
    if (!mounted) return;

    try {
      String newStatus = currentStatus == 'Checked In' ? 'Registered' : 'Checked In';
      await _firestore
          .collection('events')
          .doc(widget.eventId)
          .collection('participants')
          .doc(participantId)
          .update({
        'status': newStatus,
        'checkedInAt': newStatus == 'Checked In' ? FieldValue.serverTimestamp() : null, // Optional: record check-in time
      });

      // Reload participants to update the UI
      _loadParticipants();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Participant status updated to \'$newStatus\'.')),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: ${e.toString()}')),
        );
        print('Error updating participant status: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Spotify dark background
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: const Color(0xFF1DB954).withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DB954).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1DB954)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Participants',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DB954).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String>(
                      value: _sortBy,
                      icon: const Icon(Icons.sort_rounded, color: Color(0xFF1DB954)),
                      elevation: 16,
                      dropdownColor: const Color(0xFF282828),
                      style: const TextStyle(color: Colors.white),
                      underline: Container(height: 2, color: Colors.transparent),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _sortBy = newValue;
                            _sortParticipants();
                          });
                        }
                      },
                      items: <String>['Name', 'Registration Date']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: const TextStyle(color: Colors.white)),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954)))
                  : _errorMessage.isNotEmpty
                      ? Center(
                          child: Text(
                            'Error: $_errorMessage',
                            style: const TextStyle(color: Colors.white),
                          ),
                        )
                      : Column(
                          children: [
                            // Search Bar
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: TextField(
                                controller: _searchController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Search Participants',
                                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF1DB954)),
                                  filled: true,
                                  fillColor: const Color(0xFF282828),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: const Color(0xFF1DB954).withOpacity(0.3)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: const Color(0xFF1DB954).withOpacity(0.3)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFF1DB954), width: 2),
                                  ),
                                ),
                              ),
                            ),
                            
                            // Participants List
                            Expanded(
                              child: _filteredParticipants.isEmpty && _searchController.text.isNotEmpty
                                  ? Center(
                                      child: Text(
                                        'No participants found for \'${_searchController.text}\'.',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    )
                                  : _filteredParticipants.isEmpty && _searchController.text.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'No participants registered yet.',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        itemCount: _filteredParticipants.length,
                                        itemBuilder: (context, index) {
                                          final participant = _filteredParticipants[index];
                                          final participantName = participant['name']?.toString() ?? 'Unknown Participant';
                                          final participantStatus = participant['status']?.toString() ?? 'Registered';
                                          final participantId = participant['id']?.toString();

                                          Color statusColor = Colors.grey;
                                          IconData statusIcon = Icons.radio_button_unchecked_rounded;
                                          if (participantStatus == 'Checked In') {
                                            statusColor = const Color(0xFF1DB954);
                                            statusIcon = Icons.check_circle_rounded;
                                          }

                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF282828),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: const Color(0xFF1DB954).withOpacity(0.2),
                                                width: 1,
                                              ),
                                            ),
                                            child: ListTile(
                                              contentPadding: const EdgeInsets.all(16),
                                              leading: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF1DB954).withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.person_rounded,
                                                  color: Color(0xFF1DB954),
                                                  size: 24,
                                                ),
                                              ),
                                              title: Text(
                                                participantName,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              subtitle: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const SizedBox(height: 4),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: statusColor.withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      participantStatus,
                                                      style: TextStyle(
                                                        color: statusColor,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  if (participant['email'] != null && participant['email'].isNotEmpty)
                                                    Text(
                                                      'Email: ${participant['email']}',
                                                      style: TextStyle(
                                                        color: Colors.white.withOpacity(0.7),
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  if (participant['phoneNumber'] != null && participant['phoneNumber'].isNotEmpty)
                                                    Text(
                                                      'Phone: ${participant['phoneNumber']}',
                                                      style: TextStyle(
                                                        color: Colors.white.withOpacity(0.7),
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  if (participant['emergencyContactName'] != null && participant['emergencyContactName'].isNotEmpty)
                                                    Text(
                                                      'Emergency: ${participant['emergencyContactName']}',
                                                      style: TextStyle(
                                                        color: Colors.white.withOpacity(0.7),
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              trailing: IconButton(
                                                icon: Icon(statusIcon, color: statusColor, size: 24),
                                                onPressed: () {
                                                  if (participantId != null) {
                                                    _toggleParticipantStatus(participantId, participantStatus);
                                                  }
                                                },
                                              ),
                                            ),
                                          );
                                        },
                                      ),
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