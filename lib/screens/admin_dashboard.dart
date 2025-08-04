import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late TabController _tabController;
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, pending, approved, rejected
  final String _selectedSort = 'date'; // date, participants, name

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _updateEventStatus(String eventId, String status) async {
    try {
      await _firestore.collection('events').doc(eventId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Event $status successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating event: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Admin Dashboard',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white),
                        onPressed: () async {
                          await _auth.signOut();
                          if (mounted) {
                            Navigator.pushReplacementNamed(context, '/auth');
                          }
                        },
                      ),
                    ],
                  ),
                ),

                // Search and Filter Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search events...',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                            prefixIcon: const Icon(Icons.search, color: Colors.white70),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (value) => setState(() => _searchQuery = value),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.filter_list, color: Colors.white),
                        onSelected: (value) => setState(() => _selectedFilter = value),
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'all', child: Text('All Events')),
                          const PopupMenuItem(value: 'pending', child: Text('Pending')),
                          const PopupMenuItem(value: 'approved', child: Text('Approved')),
                          const PopupMenuItem(value: 'rejected', child: Text('Rejected')),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tab Bar
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.white,
                  tabs: const [
                    Tab(text: 'Events'),
                    Tab(text: 'Participants'),
                    Tab(text: 'Statistics'),
                  ],
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Events Tab
                      _buildEventsList(),
                      
                      // Participants Tab
                      _buildParticipantsList(),
                      
                      // Statistics Tab
                      _buildStatistics(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('events')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final events = snapshot.data!.docs;
        final filteredEvents = events.where((doc) {
          final event = doc.data() as Map<String, dynamic>;
          final status = event['status']?.toString() ?? 'pending';
          final name = event['name']?.toString().toLowerCase() ?? '';
          final searchLower = _searchQuery.toLowerCase();
          
          if (_selectedFilter != 'all' && status != _selectedFilter) {
            return false;
          }
          
          if (_searchQuery.isNotEmpty && !name.contains(searchLower)) {
            return false;
          }
          
          return true;
        }).toList();

        if (filteredEvents.isEmpty) {
          return const Center(
            child: Text(
              'No events found',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredEvents.length,
          itemBuilder: (context, index) {
            final doc = filteredEvents[index];
            final event = doc.data() as Map<String, dynamic>;
            final eventId = doc.id;
            final status = event['status']?.toString() ?? 'pending';
            final date = (event['date'] as Timestamp?)?.toDate() ?? DateTime.now();
            final media = event['media'] as Map<String, dynamic>? ?? {};
            final posterUrl = media['posterUrl']?.toString();
            final participants = event['participants'] as Map<String, dynamic>? ?? {};
            final details = event['details'] as Map<String, dynamic>? ?? {};
            final maxParticipants = (details['maxParticipants'] as num?)?.toInt() ?? 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              color: Colors.white.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (posterUrl != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: posterUrl,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) => const Icon(Icons.error),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                event['name']?.toString() ?? 'Untitled Event',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            _buildStatusChip(status),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Date and Time
                        Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                color: Colors.white70, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('MMMM dd, yyyy').format(date),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Icon(Icons.people,
                                color: Colors.white70, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              '${participants.length}/$maxParticipants participants',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (status == 'pending')
                              ElevatedButton.icon(
                                onPressed: () => _updateEventStatus(eventId, 'approved'),
                                icon: const Icon(Icons.check, color: Colors.white),
                                label: const Text('Approve'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                              ),

                            ElevatedButton.icon(
                              onPressed: () => _viewEventDetails(eventId, event),
                              icon: const Icon(Icons.visibility, color: Colors.white),
                              label: const Text('View Details'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _showEventActions(eventId, event),
                              icon: const Icon(Icons.more_vert, color: Colors.white),
                              label: const Text('Actions'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildParticipantsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('participants').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final participants = snapshot.data!.docs;
        final filteredParticipants = participants.where((doc) {
          final participant = doc.data() as Map<String, dynamic>;
          final name = participant['name']?.toString().toLowerCase() ?? '';
          final email = participant['email']?.toString().toLowerCase() ?? '';
          final searchLower = _searchQuery.toLowerCase();
          
          return name.contains(searchLower) || email.contains(searchLower);
        }).toList();

        if (filteredParticipants.isEmpty) {
          return const Center(
            child: Text(
              'No participants found',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredParticipants.length,
          itemBuilder: (context, index) {
            final doc = filteredParticipants[index];
            final participant = doc.data() as Map<String, dynamic>;
            final participantId = doc.id;
            final name = participant['name']?.toString() ?? 'Unknown User';
            final email = participant['email']?.toString() ?? 'No email';
            final phone = participant['phone']?.toString() ?? 'No phone';

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              color: Colors.white.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  name,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  email,
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onPressed: () => _showParticipantActions(participantId, participant),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatistics() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('events').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final events = snapshot.data!.docs;
        int totalEvents = events.length;
        int approvedEvents = 0;
        int totalParticipants = 0;

        for (var doc in events) {
          final event = doc.data() as Map<String, dynamic>;
          final status = event['status']?.toString() ?? 'approved';
          final participants = event['participants'] as Map<String, dynamic>? ?? {};
          
          if (status == 'approved') {
            approvedEvents++;
          }
          
          totalParticipants += participants.length;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatCard(
                'Total Events',
                totalEvents.toString(),
                Icons.event,
                Colors.blue,
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                'Approved Events',
                approvedEvents.toString(),
                Icons.check_circle,
                Colors.green,
              ),

              _buildStatCard(
                'Total Participants',
                totalParticipants.toString(),
                Icons.people,
                Colors.purple,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      color: Colors.white.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _viewEventDetails(String eventId, Map<String, dynamic> event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Event Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Name', event['name']?.toString() ?? 'N/A'),
              _buildDetailRow('Date', event['date'] != null 
                ? DateFormat('MMMM dd, yyyy').format((event['date'] as Timestamp).toDate())
                : 'N/A'),
              _buildDetailRow('Location', event['location']?['address']?.toString() ?? 'N/A'),
              _buildDetailRow('Description', event['description']?.toString() ?? 'N/A'),
              _buildDetailRow('Status', event['status']?.toString() ?? 'N/A'),
              _buildDetailRow('Organizer', event['organizer']?['name']?.toString() ?? 'N/A'),
              _buildDetailRow('Max Participants', event['details']?['maxParticipants']?.toString() ?? 'N/A'),
              _buildDetailRow('Current Participants', (event['participants'] as Map<String, dynamic>?)?.length.toString() ?? '0'),
              _buildDetailRow('Event Fee', event['pricing']?['eventFee'] != null 
                ? 'RM${event['pricing']['eventFee']}'
                : 'Free'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  void _showEventActions(String eventId, Map<String, dynamic> event) {
    final currentStatus = event['status']?.toString() ?? 'pending';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Event Actions',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentStatus == 'pending') ...[
              ListTile(
                leading: Icon(Icons.check, color: Colors.green),
                title: Text('Approve Event', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _updateEventStatus(eventId, 'approved');
                },
              ),

            ],
            ListTile(
              leading: Icon(Icons.edit, color: Colors.blue),
              title: Text('Edit Event', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _editEvent(eventId, event);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Delete Event', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _deleteEvent(eventId, event['name']?.toString() ?? 'Event');
              },
            ),
            ListTile(
              leading: Icon(Icons.people, color: Colors.purple),
              title: Text('View Participants', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _viewEventParticipants(eventId, event);
              },
            ),
            ListTile(
              leading: Icon(Icons.copy, color: Colors.orange),
              title: Text('Duplicate Event', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _duplicateEvent(eventId, event);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _showParticipantActions(String participantId, Map<String, dynamic> participant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Participant Actions',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.visibility, color: Colors.blue),
              title: Text('View Profile', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _viewParticipantProfile(participantId, participant);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Delete Participant', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _deleteParticipant(participantId, participant);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _showUserActions(String userId, Map<String, dynamic> user) {
    final currentRole = user['role']?.toString() ?? 'participant';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'User Actions',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.visibility, color: Colors.blue),
              title: Text('View Profile', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _viewUserProfile(userId, user);
              },
            ),
            ListTile(
              leading: Icon(Icons.edit, color: Colors.orange),
              title: Text('Edit Role', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _editUserRole(userId, user);
              },
            ),
            ListTile(
              leading: Icon(Icons.block, color: Colors.red),
              title: Text('Suspend User', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _suspendUser(userId, user);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Delete User', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _deleteUser(userId, user);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _editEvent(String eventId, Map<String, dynamic> event) {
    // Navigate to event edit page or show edit dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Edit Event',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Event editing functionality will be implemented here.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  void _viewParticipantProfile(String participantId, Map<String, dynamic> participant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Participant Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Name', participant['name']?.toString() ?? 'N/A'),
            _buildDetailRow('Email', participant['email']?.toString() ?? 'N/A'),
            _buildDetailRow('Phone', participant['phone']?.toString() ?? 'N/A'),
            _buildDetailRow('Emergency Contact', participant['emergencyContactName']?.toString() ?? 'N/A'),
            _buildDetailRow('Emergency Phone', participant['emergencyContactPhone']?.toString() ?? 'N/A'),
            _buildDetailRow('Created', participant['createdAt'] != null 
              ? DateFormat('MMMM dd, yyyy').format((participant['createdAt'] as Timestamp).toDate())
              : 'N/A'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  void _deleteParticipant(String participantId, Map<String, dynamic> participant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Delete Participant',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${participant['name']}"? This will remove them from all events and send notifications to organizers.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // Delete participant from participants collection
                await _firestore.collection('participants').doc(participantId).delete();
                
                // Remove participant from all events they're registered for
                final eventsSnapshot = await _firestore.collection('events').get();
                for (var eventDoc in eventsSnapshot.docs) {
                  final eventData = eventDoc.data() as Map<String, dynamic>;
                  final participants = eventData['participants'] as Map<String, dynamic>? ?? {};
                  
                  // Find and remove this participant from the event
                  String? participantKeyToRemove;
                  participants.forEach((key, value) {
                    if (value is Map && value['email'] == participant['email']) {
                      participantKeyToRemove = key;
                    }
                  });
                  
                  if (participantKeyToRemove != null) {
                    await _firestore.collection('events').doc(eventDoc.id).update({
                      'participants.$participantKeyToRemove': FieldValue.delete(),
                    });
                    
                    // Send notification to organizer
                    final organizerId = eventData['organizer']?['id'];
                    if (organizerId != null) {
                      await _sendNotificationToOrganizer(
                        organizerId,
                        'Participant Removed',
                        '${participant['name']} has been removed from your event "${eventData['name']}" by admin.',
                      );
                    }
                  }
                }
                
                // Send notification to participant
                await _sendNotificationToParticipant(
                  participant['email'],
                  'Account Deleted',
                  'Your account has been deleted by admin. You will no longer have access to the app.',
                );
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Participant "${participant['name']}" deleted successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting participant: $e')),
                  );
                }
              }
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteEvent(String eventId, String eventName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Delete Event',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "$eventName"? This action cannot be undone and will notify the organizer.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // Get event data before deleting to send notification
                final eventDoc = await _firestore.collection('events').doc(eventId).get();
                final eventData = eventDoc.data() as Map<String, dynamic>?;
                final organizerId = eventData?['organizer']?['id'];
                
                // Delete the event
                await _firestore.collection('events').doc(eventId).delete();
                
                // Send notification to organizer
                if (organizerId != null) {
                  await _sendNotificationToOrganizer(
                    organizerId,
                    'Event Deleted',
                    'Your event "$eventName" has been deleted by admin.',
                  );
                }
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Event "$eventName" deleted successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting event: $e')),
                  );
                }
              }
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _viewEventParticipants(String eventId, Map<String, dynamic> event) {
    final participants = event['participants'] as Map<String, dynamic>? ?? {};
    final participantList = participants.entries.map((e) {
      final data = Map<String, dynamic>.from(e.value as Map);
      data['id'] = e.key;
      return data;
    }).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Event Participants (${participantList.length})',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: participantList.isEmpty
              ? Center(
                  child: Text(
                    'No participants registered',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : ListView.builder(
                  itemCount: participantList.length,
                  itemBuilder: (context, index) {
                    final participant = participantList[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text(
                          (participant['name']?.toString() ?? '?')[0].toUpperCase(),
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        participant['name']?.toString() ?? 'Unknown',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        participant['email']?.toString() ?? 'No email',
                        style: TextStyle(color: Colors.white70),
                      ),
                      trailing: _buildStatusChip(participant['status']?.toString() ?? 'registered'),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  void _duplicateEvent(String eventId, Map<String, dynamic> event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Duplicate Event',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to duplicate "${event['name']}"? This will create a copy of the event.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final duplicatedEvent = Map<String, dynamic>.from(event);
                duplicatedEvent['name'] = '${event['name']} (Copy)';
                duplicatedEvent['status'] = 'pending';
                duplicatedEvent['participants'] = {};
                duplicatedEvent['createdAt'] = FieldValue.serverTimestamp();
                duplicatedEvent['updatedAt'] = FieldValue.serverTimestamp();
                
                await _firestore.collection('events').add(duplicatedEvent);
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Event duplicated successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error duplicating event: $e')),
                  );
                }
              }
            },
            child: Text('Duplicate', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  void _viewUserProfile(String userId, Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'User Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Name', user['name']?.toString() ?? 'N/A'),
            _buildDetailRow('Email', user['email']?.toString() ?? 'N/A'),
            _buildDetailRow('Role', user['role']?.toString() ?? 'N/A'),
            _buildDetailRow('Phone', user['phone']?.toString() ?? 'N/A'),
            _buildDetailRow('Created', user['createdAt'] != null 
              ? DateFormat('MMMM dd, yyyy').format((user['createdAt'] as Timestamp).toDate())
              : 'N/A'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  void _editUserRole(String userId, Map<String, dynamic> user) {
    String selectedRole = user['role']?.toString() ?? 'participant';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Edit User Role',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current role: ${user['role']?.toString() ?? 'participant'}',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedRole,
              dropdownColor: const Color(0xFF2A2A2A),
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'New Role',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: 'participant', child: Text('Participant')),
                DropdownMenuItem(value: 'organizer', child: Text('Organizer')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: (value) {
                selectedRole = value ?? selectedRole;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _firestore.collection('users').doc(userId).update({
                  'role': selectedRole,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('User role updated to $selectedRole')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating user role: $e')),
                  );
                }
              }
            },
            child: Text('Update', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  void _suspendUser(String userId, Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Suspend User',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to suspend "${user['name']}"? They will not be able to access the app.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _firestore.collection('users').doc(userId).update({
                  'status': 'suspended',
                  'suspendedAt': FieldValue.serverTimestamp(),
                  'suspendedBy': _auth.currentUser?.uid,
                });
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('User "${user['name']}" suspended successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error suspending user: $e')),
                  );
                }
              }
            },
            child: Text('Suspend', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteUser(String userId, Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Delete User',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${user['name']}"? This action cannot be undone.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _firestore.collection('users').doc(userId).delete();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('User "${user['name']}" deleted successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting user: $e')),
                  );
                }
              }
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status.toLowerCase()) {
      case 'approved':
        color = Colors.green;
        label = 'Approved';
        break;
      case 'rejected':
        color = Colors.red;
        label = 'Rejected';
        break;
      case 'cancelled':
        color = Colors.grey;
        label = 'Cancelled';
        break;
      default:
        color = Colors.orange;
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role) {
    Color color;
    String label;

    switch (role.toLowerCase()) {
      case 'admin':
        color = Colors.red;
        label = 'Admin';
        break;
      case 'organizer':
        color = Colors.blue;
        label = 'Organizer';
        break;
      default:
        color = Colors.green;
        label = 'Participant';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _sendNotificationToOrganizer(String organizerId, String title, String message) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': organizerId,
        'title': title,
        'message': message,
        'type': 'admin_notification',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'sentBy': _auth.currentUser?.uid,
      });
    } catch (e) {
      print('Error sending notification to organizer: $e');
    }
  }

  Future<void> _sendNotificationToParticipant(String participantEmail, String title, String message) async {
    try {
      // Find participant by email
      final participantQuery = await _firestore
          .collection('participants')
          .where('email', isEqualTo: participantEmail)
          .get();
      
      if (participantQuery.docs.isNotEmpty) {
        final participantId = participantQuery.docs.first.id;
        await _firestore.collection('notifications').add({
          'userId': participantId,
          'title': title,
          'message': message,
          'type': 'admin_notification',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'sentBy': _auth.currentUser?.uid,
        });
      }
    } catch (e) {
      print('Error sending notification to participant: $e');
    }
  }
} 