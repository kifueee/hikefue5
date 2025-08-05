import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'event_details_page.dart';
import 'package:excel/excel.dart' as excel;
import 'package:url_launcher/url_launcher.dart';
import 'dart:html' as html;
import 'organizer_manage_event_page.dart';
import '../../models/tag.dart';
import '../../services/firestore_service.dart';
import '../../services/rating_service.dart';
import '../../utils/data_utils.dart';

const Color primaryColor = Color(0xFF004A4D);
const Color accentColor = Color(0xFF94BC45);
const Color darkBackgroundColor = Color(0xFF231F20);

class OrganizerEventManagement extends StatefulWidget {
  const OrganizerEventManagement({super.key});

  @override
  State<OrganizerEventManagement> createState() => _OrganizerEventManagementState();
}

class _OrganizerEventManagementState extends State<OrganizerEventManagement> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedFilter = 'all'; // all, active
  List<Tag> _allTags = [];
  bool _loadingTags = false;

  @override
  void initState() {
    super.initState();
    _fetchAllTags();
  }

  Future<void> _fetchAllTags() async {
    setState(() => _loadingTags = true);
    final tags = await FirestoreService().getAllTags();
    setState(() {
      _allTags = tags;
      _loadingTags = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackgroundColor,
      body: Stack(
        children: [
          // Blurred Background Image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/trees_background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(color: primaryColor.withOpacity(0.6)),
          ),
          SafeArea(
            child: Column(
              children: [
                // App Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: darkBackgroundColor.withOpacity(0.8),
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.event_note,
                        color: accentColor,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Manage Events',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: accentColor),
                        onPressed: () => Navigator.pushNamed(context, '/organizer_create_event'),
                        tooltip: 'Create New Event',
                      ),
                    ],
                  ),
                ),
                
                // Filter Tabs
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildFilterTab('all', 'All Events'),
                      const SizedBox(width: 8),
                      _buildFilterTab('active', 'Active'),
                    ],
                  ),
                ),
                
                // Content
                Expanded(
                  child: _buildEventsList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String value, String label) {
    final isSelected = _selectedFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? accentColor : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? accentColor : Colors.white.withOpacity(0.3),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildEventsList() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return const Center(
        child: Text('Please log in to view your events'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('events')
          .where('organizerId', isEqualTo: _auth.currentUser?.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: accentColor),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error:  ${snapshot.error}',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                  'No events found in database',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first hiking event to get started',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/organizer_create_event'),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Event'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          );
        }

        final now = DateTime.now();
        final events = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final eventDate = (data['date'] as Timestamp?)?.toDate();
          final status = data['status'] as String? ?? ''; // Approval status
          final eventStatus = data['eventStatus'] as String? ?? ''; // Lifecycle status
          
          // Only show approved events unless viewing all
          if (status != 'approved' && _selectedFilter != 'all') {
            return false;
          }
          
          if (_selectedFilter == 'active') {
            // Active: Published/started/ongoing events that are in the future or ongoing
            return (eventStatus == 'published' || eventStatus == 'started' || eventStatus == 'ongoing') &&
                   (eventDate == null || eventDate.isAfter(now) || eventStatus == 'ongoing');
          } else {
            // All events (regardless of approval status)
            return true;
          }
        }).toList();

        // Responsive grid layout
        return LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = 1;
            if (constraints.maxWidth > 1200) {
              crossAxisCount = 3;
            } else if (constraints.maxWidth > 700) {
              crossAxisCount = 2;
            }
            return GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
                childAspectRatio: 0.75, // More vertical card
              ),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final eventDoc = events[index];
                final eventData = eventDoc.data() as Map<String, dynamic>;
                return _buildEventCard(eventDoc.id, eventData);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEventCard(String eventId, Map<String, dynamic> eventData) {
    final eventName = eventData['name'] as String? ?? 'Unnamed Event';
    final eventDate = (eventData['date'] as Timestamp?)?.toDate();
    final description = eventData['description'] as String? ?? '';
    final location = eventData['location']?['address'] as String? ?? 'Location TBD';
    final currentParticipants = eventData['details']?['currentParticipants'] as int? ?? 0;
    final maxParticipants = eventData['details']?['maxParticipants'] as int? ?? 0;
    final eventFee = eventData['pricing']?['eventFee'] as num? ?? 0;
    final difficulty = eventData['details']?['difficulty'] as String? ?? '';
    final posterUrl = eventData['media']?['posterUrl'] as String?;
    final List<dynamic> tagIds = eventData['tags'] ?? [];
    final eventTags = _allTags.where((tag) => tagIds.contains(tag.id)).toList();

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner image
          if (posterUrl != null && posterUrl.isNotEmpty)
            SizedBox(
              height: 180,
              child: CachedNetworkImage(
                imageUrl: posterUrl,
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 180,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 180,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                ),
              ),
            )
          else
            Container(
              height: 180,
              color: Colors.grey.shade200,
              child: const Icon(Icons.image, size: 48, color: Colors.grey),
            ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eventName,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: accentColor),
                    const SizedBox(width: 6),
                    Text(
                      eventDate != null ? '${eventDate.day.toString().padLeft(2, '0')}/${eventDate.month.toString().padLeft(2, '0')}/${eventDate.year}' : 'Date TBD',
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: accentColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        location,
                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.people, size: 16, color: accentColor),
                    const SizedBox(width: 6),
                    Text(
                      '$currentParticipants/$maxParticipants',
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.monetization_on, size: 16, color: accentColor),
                    const SizedBox(width: 6),
                    Text(
                      eventFee > 0 ? 'RM${eventFee.toStringAsFixed(2)}' : 'Free',
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.flag, size: 16, color: accentColor),
                    const SizedBox(width: 6),
                    Text(
                      'Difficulty: $difficulty',
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (eventTags.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: eventTags.map((tag) => Chip(
                      label: Text(tag.name, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                      backgroundColor: Color(int.parse('0xff${tag.color.substring(1)}')),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    )).toList(),
                  ),
                
                // Rating display for ended events
                if (eventData['eventStatus'] == 'ended') _showEventRating(eventId),
                
                // Remove all action buttons, add only 'Manage Event'
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.settings),
                    label: const Text('Manage Event'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrganizerManageEventPage(eventId: eventId, eventData: eventData),
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
      case 'pending':
        color = Colors.orange;
        label = 'Pending';
        break;
      case 'rejected':
        color = Colors.red;
        label = 'Rejected';
        break;
      default:
        color = Colors.grey;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Date TBD';
    
    final now = DateTime.now();
    final difference = date.difference(now).inDays;
    
    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else if (difference == -1) {
      return 'Yesterday';
    } else if (difference > 0 && difference < 7) {
      return 'In $difference days';
    } else if (difference < 0 && difference > -7) {
      return '${difference.abs()} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _viewEventDetails(String eventId, Map<String, dynamic> eventData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailsPage(eventId: eventId, eventData: eventData),
      ),
    );
  }

  void _manageParticipants(String eventId, Map<String, dynamic> eventData) {
    showDialog(
      context: context,
      builder: (context) => _buildParticipantsDialog(eventId, eventData),
    );
  }

  void _handleMenuAction(String action, String eventId, Map<String, dynamic> eventData) {
    switch (action) {
      case 'edit':
        // Navigate to edit page or show edit dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Edit functionality coming soon!', style: GoogleFonts.poppins())),
        );
        break;
      case 'toggle_status':
        _toggleEventStatus(eventId, eventData);
        break;
      case 'delete':
        _showDeleteConfirmation(eventId, eventData);
        break;
    }
  }

  Future<void> _toggleEventStatus(String eventId, Map<String, dynamic> eventData) async {
    final currentStatus = eventData['metadata']?['isActive'] ?? true;
    
    try {
      await _firestore.collection('events').doc(eventId).update({
        'metadata.isActive': !currentStatus,
        'metadata.lastUpdated': FieldValue.serverTimestamp(),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentStatus ? 'Event deactivated' : 'Event activated',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: accentColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating event: $e', style: GoogleFonts.poppins())),
      );
    }
  }

  void _showDeleteConfirmation(String eventId, Map<String, dynamic> eventData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: darkBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Event',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${eventData['name']}"? This action cannot be undone.',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deleteEvent(eventId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete Event', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEvent(String eventId) async {
    try {
      await _firestore.collection('events').doc(eventId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Event deleted successfully', style: GoogleFonts.poppins()),
          backgroundColor: accentColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting event: $e', style: GoogleFonts.poppins())),
      );
    }
  }

  Widget _buildEventDetailsDialog(String eventId, Map<String, dynamic> eventData) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
        height: 500,
        decoration: BoxDecoration(
          color: darkBackgroundColor.withOpacity(0.8),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.8),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.event, color: accentColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Event Details',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
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
                    Text(
                      eventData['name'] ?? 'Unnamed Event',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      eventData['description'] ?? 'No description',
                      style: GoogleFonts.poppins(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    _buildDetailItem('Date', _formatDate((eventData['date'] as Timestamp?)?.toDate())),
                    _buildDetailItem('Location', eventData['location']?['address'] ?? 'Location TBD'),
                    _buildDetailItem('Meeting Point', eventData['meetingPoint']?['address'] ?? 'TBD'),
                    _buildDetailItem('Difficulty', eventData['details']?['difficulty'] ?? 'Not specified'),
                    _buildDetailItem('Distance', '${eventData['details']?['distance'] ?? 0} km'),
                    _buildDetailItem('Duration', '${eventData['details']?['duration'] ?? 0} hours'),
                    _buildDetailItem('Event Fee', 'RM${eventData['pricing']?['eventFee'] ?? 0}'),
                    _buildDetailItem('Participants', '${eventData['details']?['currentParticipants'] ?? 0}/${eventData['details']?['maxParticipants'] ?? 0}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                color: accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsDialog(String eventId, Map<String, dynamic> eventData) {
    final participants = eventData['participants'] as Map<String, dynamic>? ?? {};
    final participantList = participants.entries.map((e) {
      final data = e.value as Map<String, dynamic>;
      data['id'] = e.key;
      return data;
    }).toList();
    final paidCount = participantList.where((p) => DataUtils.safeBool(p['paymentDetails']?['paid'])).length;
    final unpaidCount = participantList.length - paidCount;
    Set<String> selected = {};
    bool allSelected = false;

    return StatefulBuilder(
      builder: (context, setState) {
        allSelected = selected.length == participantList.length && participantList.isNotEmpty;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
            width: 700,
            height: 600,
        decoration: BoxDecoration(
              color: darkBackgroundColor.withOpacity(0.8),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.8),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.group, color: accentColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                          'Participants (${participantList.length})',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
                // Stats
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Row(
                            children: [
                      Icon(Icons.check_circle, size: 16, color: Colors.green),
                      const SizedBox(width: 6),
                      Text('$paidCount paid', style: GoogleFonts.poppins(fontSize: 14, color: Colors.green)),
                      const SizedBox(width: 18),
                      Icon(Icons.cancel, size: 16, color: Colors.red),
                      const SizedBox(width: 6),
                      Text('$unpaidCount unpaid', style: GoogleFonts.poppins(fontSize: 14, color: Colors.red)),
                    ],
                  ),
                ),
                // Export button
                Padding(
                  padding: const EdgeInsets.only(left: 20, bottom: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Export to Excel'),
                      style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white),
                      onPressed: () => _exportParticipantsToExcel(eventData['name'] ?? 'event', participantList),
                    ),
                  ),
                ),
                // Bulk action bar
                if (selected.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildBulkActionBar(eventId, selected, participantList, setState),
                  ),
                // Table
                              Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(accentColor.withOpacity(0.15)),
                      columns: [
                        DataColumn(
                          label: Row(
                                  children: [
                              Checkbox(
                                value: allSelected,
                                onChanged: (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      selected = participantList.map((p) => p['id'] as String).toSet();
                                    } else {
                                      selected = <String>{};
                                    }
                                  });
                                },
                              ),
                              Text('Name', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        DataColumn(label: Text('Email', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Phone', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Role', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Payment', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Registered', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                      ],
                      rows: [
                        for (final p in participantList)
                          DataRow(
                            selected: selected.contains(p['id']),
                            onSelectChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  selected.add(p['id'] as String);
                                } else {
                                  selected.remove(p['id'] as String);
                                }
                              });
                            },
                            cells: [
                              DataCell(Row(
                                children: [
                                  Checkbox(
                                    value: selected.contains(p['id']),
                                    onChanged: (checked) {
                                      setState(() {
                                        if (checked == true) {
                                          selected.add(p['id'] as String);
                                        } else {
                                          selected.remove(p['id'] as String);
                                        }
                                      });
                                    },
                                  ),
                                  Text(p['name'] ?? '-', style: GoogleFonts.poppins()),
                                ],
                              )),
                              DataCell(Text(p['email'] ?? '-', style: GoogleFonts.poppins())),
                              DataCell(Text(p['phone'] ?? '-', style: GoogleFonts.poppins())),
                              DataCell(Text(p['role'] ?? '-', style: GoogleFonts.poppins())),
                              DataCell(_buildPaymentStatusChip(p['paymentDetails'])),
                              DataCell(Text(
                                p['registeredAt'] != null && p['registeredAt'] is Timestamp
                                    ? (p['registeredAt'] as Timestamp).toDate().toString().split(' ').first
                                    : '-',
                                style: GoogleFonts.poppins(),
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
      },
    );
  }

  void _exportParticipantsToExcel(String eventName, List<Map<String, dynamic>> participants) {
    final ex = excel.Excel.createExcel();
    final sheet = ex['Participants'];
    // Header
    sheet.appendRow([
      excel.TextCellValue('Name'),
      excel.TextCellValue('Email'),
      excel.TextCellValue('Phone'),
      excel.TextCellValue('Role'),
      excel.TextCellValue('Payment Status'),
      excel.TextCellValue('Registered'),
    ]);
    for (final p in participants) {
      sheet.appendRow([
        excel.TextCellValue(p['name'] ?? '-'),
        excel.TextCellValue(p['email'] ?? '-'),
        excel.TextCellValue(p['phone'] ?? '-'),
        excel.TextCellValue(p['role'] ?? '-'),
        excel.TextCellValue((p['paymentDetails']?['paymentStatus'] ?? (DataUtils.safeBool(p['paymentDetails']?['paid']) ? 'Paid' : 'Pending')).toString()),
        excel.TextCellValue(
          p['registeredAt'] != null && p['registeredAt'] is Timestamp
              ? (p['registeredAt'] as Timestamp).toDate().toString().split(' ').first
              : '-',
        ),
      ]);
    }
    final fileBytes = ex.encode();
    final blob = html.Blob([fileBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', '${eventName}_participants.xlsx')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Widget _buildBulkActionBar(String eventId, Set<String> selected, List<Map<String, dynamic>> participantList, void Function(void Function()) setState) {
    final selectedParticipants = participantList.where((p) => selected.contains(p['id'])).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text('${selected.length} selected', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          const SizedBox(width: 24),

          ElevatedButton.icon(
            icon: const Icon(Icons.edit),
            label: const Text('Update Status'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            onPressed: () => _handleBulkUpdateStatus(eventId, selected, participantList),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete),
            label: const Text('Remove'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => _handleBulkRemove(eventId, selected, participantList),
            ),
          ],
        ),
    );
  }

  Future<void> _launchBulkEmail(List<String> emails, {String? subject, String? body}) async {
    final mailtoUri = Uri(
      scheme: 'mailto',
      path: emails.join(','),
      query: [
        if (subject != null) 'subject=${Uri.encodeComponent(subject)}',
        if (body != null) 'body=${Uri.encodeComponent(body)}',
      ].join('&'),
    );
    if (await canLaunchUrl(mailtoUri)) {
      await launchUrl(mailtoUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open email client.')),
      );
    }
  }

  void _handleBulkUpdateStatus(String eventId, Set<String> selected, List<Map<String, dynamic>> participantList) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bulk status update functionality coming soon!', style: GoogleFonts.poppins()),
        backgroundColor: accentColor,
      ),
    );
  }

  void _handleBulkRemove(String eventId, Set<String> selected, List<Map<String, dynamic>> participantList) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bulk remove functionality coming soon!', style: GoogleFonts.poppins()),
        backgroundColor: accentColor,
      ),
    );
  }

  Widget _buildPaymentStatusChip(Map<String, dynamic>? paymentDetails) {
    final paid = DataUtils.safeBool(paymentDetails?['paid']);
    final status = paymentDetails?['paymentStatus'] ?? (paid ? 'Paid' : 'Pending');
    Color color;
    switch (status.toString().toLowerCase()) {
      case 'paid':
      case 'completed':
        color = Colors.green;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      case 'failed':
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toString().toUpperCase(),
        style: GoogleFonts.poppins(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _showEventRating(String eventId) {
    return FutureBuilder<List<EventRating>>(
      future: RatingService.getEventRatings(eventId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(8),
            child: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final ratings = snapshot.data;
        if (ratings == null || ratings.isEmpty) {
          return Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.star_outline, color: Colors.grey, size: 16),
                SizedBox(width: 4),
                Text('No ratings yet', style: TextStyle(fontSize: 12)),
              ],
            ),
          );
        }

        final totalRating = ratings.fold<int>(0, (sum, rating) => sum + rating.rating);
        final averageRating = totalRating / ratings.length;

        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.amber.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text(
                '${averageRating.toStringAsFixed(1)}/5.0 (${ratings.length} reviews)',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber[700],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Add this widget for the carpool tab
class EventCarpoolTab extends StatelessWidget {
  final String eventId;
  const EventCarpoolTab({required this.eventId, super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('driverOffers')
          .where('eventId', isEqualTo: eventId)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: accentColor),
            ),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Error loading carpools',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.red[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${snapshot.error}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }
        
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.directions_car_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Ride Offers Available',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No ride offers have been created for this event yet.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with stats
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                    children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.directions_car, color: accentColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ride Offers Management',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        Text(
                          '${docs.length} active ride offers for this event',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Active',
                          style: GoogleFonts.poppins(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Carpools list
            Expanded(
              child: ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: accentColor.withOpacity(0.1),
                                child: Text(
                                  (data['driverName'] as String?)?.isNotEmpty == true 
                                      ? data['driverName'][0].toUpperCase() 
                                      : 'D',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['driverName'] ?? 'Unknown Driver',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: primaryColor,
                                      ),
                                    ),
                                    Text(
                                      data['vehicleDetails'] ?? 'Vehicle details not available',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildStatusChip(data['status'] ?? 'active'),
                            ],
                          ),
                        ),
                        
                        // Content
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              // Ride offer details
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDetailCard(
                                      icon: Icons.location_on,
                                      title: 'Pickup Location',
                                      value: data['pickupLocation'] ?? 'Not specified',
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildDetailCard(
                                      icon: Icons.location_on,
                                      title: 'Dropoff Location',
                                      value: data['dropoffLocation'] ?? 'Not specified',
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDetailCard(
                                      icon: Icons.access_time,
                                      title: 'Departure Time',
                                      value: data['departureTime'] != null 
                                          ? _formatTimestamp(data['departureTime'])
                                          : 'Not specified',
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildDetailCard(
                                      icon: Icons.people,
                                      title: 'Available Seats',
                                      value: '${data['availableSeats'] ?? 0}',
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDetailCard(
                                      icon: Icons.attach_money,
                                      title: 'Cost per Person',
                                      value: 'RM ${data['costPerPerson']?.toStringAsFixed(2) ?? '0.00'}',
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildDetailCard(
                                      icon: Icons.email,
                                      title: 'Driver Email',
                                      value: data['driverEmail'] ?? 'Not provided',
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Action buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.info_outline, size: 18),
                                      label: const Text('View Details'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: () => _showRideOfferDetails(context, data, doc.id),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.email, size: 18),
                                      label: const Text('Contact Driver'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: () => _contactDriver(data['driverEmail']),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.download, size: 18),
                                      label: const Text('Export Data'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: () => _exportRideOfferData(data, doc.id),
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
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    
    switch (status.toLowerCase()) {
      case 'active':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'full':
        color = Colors.orange;
        icon = Icons.people;
        break;
      case 'cancelled':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: GoogleFonts.poppins(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: primaryColor,
            ),
          ),
            ],
          ),
        );
  }

  Widget _buildPassengersSection(List passengers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.people, color: accentColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'Passengers (${passengers.length})',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withOpacity(0.2)),
          ),
          child: Column(
            children: passengers.map<Widget>((passenger) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    passenger.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingRequestsSection(List pendingRequests, String carpoolId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.pending, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Text(
              'Pending Requests (${pendingRequests.length})',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.2)),
          ),
          child: Column(
            children: pendingRequests.map<Widget>((request) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.person_outline, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request.toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.orange[700],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => _handleRequest(carpoolId, request.toString(), 'accept'),
                        child: Text(
                          'Accept',
                          style: GoogleFonts.poppins(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _handleRequest(carpoolId, request.toString(), 'reject'),
                        child: Text(
                          'Reject',
                          style: GoogleFonts.poppins(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  void _showRideOfferDetails(BuildContext context, Map<String, dynamic> data, String offerId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ride Offer Details', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Driver', data['driverName'] ?? 'Unknown'),
              _buildDetailRow('Driver Email', data['driverEmail'] ?? 'Unknown'),
              _buildDetailRow('Vehicle Details', data['vehicleDetails'] ?? 'Not specified'),
              _buildDetailRow('Pickup Location', data['pickupLocation'] ?? 'Not specified'),
              _buildDetailRow('Dropoff Location', data['dropoffLocation'] ?? 'Not specified'),
              _buildDetailRow('Departure Time', data['departureTime'] != null 
                  ? _formatTimestamp(data['departureTime'])
                  : 'Not specified'),
              _buildDetailRow('Available Seats', '${data['availableSeats'] ?? 0}'),
              _buildDetailRow('Cost per Person', 'RM ${data['costPerPerson']?.toStringAsFixed(2) ?? '0.00'}'),
              if (data['notes']?.isNotEmpty == true)
                _buildDetailRow('Notes', data['notes']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  void _contactDriver(String? driverEmail) {
    if (driverEmail?.isNotEmpty == true) {
      final mailtoUri = Uri(
        scheme: 'mailto',
        path: driverEmail,
        query: 'subject=Carpool Inquiry from HikeFue',
      );
      launchUrl(mailtoUri);
    }
  }

  void _exportRideOfferData(Map<String, dynamic> data, String offerId) {
    // TODO: Implement export functionality
    print('Export ride offer data for: $offerId');
  }

  void _handleRequest(String carpoolId, String email, String action) {
    // TODO: Implement accept/reject request functionality
    print('$action request from $email for carpool $carpoolId');
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return 'Invalid date';
  }
} 