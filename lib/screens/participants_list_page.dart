import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class ParticipantsListPage extends StatefulWidget {
  final Map<String, dynamic> event;
  final String eventId;

  const ParticipantsListPage({
    super.key,
    required this.event,
    required this.eventId,
  });

  @override
  State<ParticipantsListPage> createState() => _ParticipantsListPageState();
}

class _ParticipantsListPageState extends State<ParticipantsListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'name'; // 'name' or 'date'
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _removeParticipant(String participantId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Participant'),
        content: const Text('Are you sure you want to remove this participant from the event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId)
            .update({
          'participants.$participantId': FieldValue.delete(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Participant removed successfully')),
          );
        }
      } catch (e) {
        print('Error removing participant: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to remove participant')),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _exportParticipantsList() async {
    final participants = widget.event['participants'] as Map<String, dynamic>? ?? {};
    final eventName = widget.event['name'] as String;
    final date = (widget.event['date'] as Timestamp).toDate();
    final formattedDate = DateFormat('MMMM d, yyyy').format(date);

    final String exportText = '''
Event: $eventName
Date: $formattedDate
Total Participants: ${participants.length}

Participants List:
${participants.entries.map((entry) => '- ${entry.value['name'] ?? entry.key} (${entry.value['email'] ?? 'No email'})').join('\n')}
''';

    await Share.share(exportText, subject: 'Participants List - $eventName');
  }

  List<MapEntry<String, dynamic>> _getFilteredAndSortedParticipants() {
    final participants = widget.event['participants'] as Map<String, dynamic>? ?? {};
    var entries = participants.entries.toList();
    
    // Filter out the organizer and invalid entries
    entries = entries.where((entry) {
      final isOrganizer = entry.value['role'] == 'organizer';
      final hasValidStatus = entry.value['status'] != null && entry.value['status'] != 'unknown';
      final isNotOrganizerId = entry.key != widget.event['organizer']?['id'];
      final isRegistered = entry.value['status'] == 'registered';
      
      return !isOrganizer && hasValidStatus && isNotOrganizerId && isRegistered;
    }).toList();
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      entries = entries.where((entry) {
        final name = entry.value['name']?.toString().toLowerCase() ?? '';
        final email = entry.value['email']?.toString().toLowerCase() ?? '';
        final searchLower = _searchQuery.toLowerCase();
        return name.contains(searchLower) || email.contains(searchLower);
      }).toList();
    }

    // Apply sorting
    entries.sort((a, b) {
      if (_sortBy == 'name') {
        final nameA = a.value['name']?.toString().toLowerCase() ?? '';
        final nameB = b.value['name']?.toString().toLowerCase() ?? '';
        return nameA.compareTo(nameB);
      } else {
        // Sort by registration date
        final dateA = (a.value['registeredAt'] as Timestamp?)?.toDate() ?? DateTime(0);
        final dateB = (b.value['registeredAt'] as Timestamp?)?.toDate() ?? DateTime(0);
        return dateA.compareTo(dateB);
      }
    });

    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final participants = _getFilteredAndSortedParticipants();
    final organizer = widget.event['organizer'] as Map<String, dynamic>? ?? {};
    final organizerId = organizer['id'] as String?;
    final organizerDetails = widget.event['organizerDetails'] as Map<String, dynamic>?;
    final details = widget.event['details'] as Map<String, dynamic>? ?? {};
    final maxParticipants = (details['maxParticipants'] as num?)?.toInt() ?? 0;
    final currentParticipants = participants.length;

    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Spotify dark background
      body: SafeArea(
        child: Column(
          children: [
            // Professional Header
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
                      'Participants List',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DB954).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.share_rounded, color: Color(0xFF1DB954)),
                      onPressed: _exportParticipantsList,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search and Sort Bar
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Search participants...',
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
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
                            onChanged: (value) => setState(() => _searchQuery = value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1DB954).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: PopupMenuButton<String>(
                            icon: const Icon(Icons.sort_rounded, color: Color(0xFF1DB954)),
                            onSelected: (value) => setState(() => _sortBy = value),
                            color: const Color(0xFF282828),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'name',
                                child: Text('Sort by Name', style: TextStyle(color: Colors.white)),
                              ),
                              const PopupMenuItem(
                                value: 'date',
                                child: Text('Sort by Registration Date', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Event Info Card with Participant Count
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF282828),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF1DB954).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1DB954).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.event_rounded,
                                  color: Color(0xFF1DB954),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  widget.event['name'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.people_rounded, color: Color(0xFF1DB954)),
                              const SizedBox(width: 8),
                              Text(
                                'Participants: $currentParticipants/$maxParticipants',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Participants List
                    _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954)))
                        : participants.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.people_outline_rounded,
                                      size: 64,
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No participants yet',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Participants will appear here once they join',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                children: [
                                  // Organizer Card
                                  if (organizerId != null) _buildParticipantCard(
                                    name: organizerDetails?['name'] ?? 'Organizer',
                                    email: organizerDetails?['email'] ?? 'No email provided',
                                    phone: organizerDetails?['phone'] ?? 'No phone provided',
                                    isOrganizer: true,
                                  ),

                                  // Participants Cards
                                  ...participants.map((entry) => _buildParticipantCard(
                                    name: entry.value['name'] ?? 'Unknown Participant',
                                    email: entry.value['email'] ?? 'No email provided',
                                    phone: entry.value['phone'] ?? 'No phone provided',
                                    isOrganizer: false,
                                    onRemove: () => _removeParticipant(entry.key),
                                    emergencyContactName: entry.value['emergencyContactName'],
                                    emergencyContactPhone: entry.value['emergencyContactPhone'],
                                  )),
                                ],
                              ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantCard({
    required String name,
    required String email,
    required String phone,
    required bool isOrganizer,
    VoidCallback? onRemove,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF282828),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1DB954).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isOrganizer 
                        ? Colors.amber.withOpacity(0.2)
                        : const Color(0xFF1DB954).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isOrganizer ? Icons.star_rounded : Icons.person_rounded,
                    color: isOrganizer ? Colors.amber : const Color(0xFF1DB954),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isOrganizer)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Organizer',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!isOrganizer && onRemove != null)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red),
                      onPressed: onRemove,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.email_rounded, email),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.phone_rounded, phone),
            const SizedBox(height: 16),
            Container(
              height: 1,
              color: Colors.white.withOpacity(0.1),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.emergency_rounded,
                    color: Color(0xFF1DB954),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Emergency Contact',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.person_outline_rounded, emergencyContactName ?? 'Not provided'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.phone_outlined, emergencyContactPhone ?? 'Not provided'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF1DB954)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.white.withOpacity(0.8)),
          ),
        ),
      ],
    );
  }
} 