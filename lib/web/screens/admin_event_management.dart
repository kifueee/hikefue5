import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/event_category.dart';
import 'admin_event_details_page.dart';

class AdminEventManagement extends StatefulWidget {
  const AdminEventManagement({super.key});

  @override
  State<AdminEventManagement> createState() => _AdminEventManagementState();
}

class _AdminEventManagementState extends State<AdminEventManagement> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late TabController _tabController;
  bool _isLoading = false;
  final String _selectedTab = 'pending';
  List<EventCategory> _categories = [];
  Map<String, dynamic> _eventStats = {
    'total': 0,
    'approved': 0,
    'rejected': 0,
    'featured': 0,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCategories();
    _loadEventStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final snapshot = await _firestore.collection('event_categories').get();
      setState(() {
        _categories = snapshot.docs.map((doc) => EventCategory.fromFirestore(doc)).toList();
      });
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  Future<void> _loadEventStats() async {
    try {
      final events = await _firestore.collection('events').get();
      setState(() {
        _eventStats = {
          'total': events.docs.length,
          'approved': events.docs.where((doc) => doc.data()['status'] == 'approved').length,
          'pending': events.docs.where((doc) => doc.data()['status'] == 'pending').length,
          'featured': events.docs.where((doc) => doc.data()['isFeatured'] == true).length,
        };
      });
    } catch (e) {
      print('Error loading event stats: $e');
    }
  }

  Future<void> _updateEventStatus(String eventId, String status) async {
    try {
      setState(() => _isLoading = true);
      await _firestore.collection('events').doc(eventId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _loadEventStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Event status updated to $status')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating event status: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleFeatured(String eventId, bool isFeatured) async {
    try {
      setState(() => _isLoading = true);
      await _firestore.collection('events').doc(eventId).update({
        'isFeatured': isFeatured,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _loadEventStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Event ${isFeatured ? 'featured' : 'unfeatured'}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating featured status: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildStatsCard(String title, int count, Color color) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  _getIconForTitle(title),
                  color: color,
                  size: 14,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForTitle(String title) {
    switch (title.toLowerCase()) {
      case 'total events':
        return Icons.event;
      case 'pending':
        return Icons.pending_actions;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'featured':
        return Icons.star;
      default:
        return Icons.info;
    }
  }

  Widget _buildEventList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('events').where('status', isEqualTo: status).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final events = snapshot.data!.docs;
        if (events.isEmpty) {
          return Center(child: Text('No $status events found.'));
        }

        return ListView.builder(
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index].data() as Map<String, dynamic>;
            final eventId = events[index].id;
            final media = event['media'] as Map<String, dynamic>? ?? {};
            final posterUrl = media['posterUrl']?.toString();
            final date = (event['date'] as Timestamp?)?.toDate() ?? DateTime.now();
            final participants = event['participants'] as Map<String, dynamic>? ?? {};
            final details = event['details'] as Map<String, dynamic>? ?? {};
            final maxParticipants = (details['maxParticipants'] as num?)?.toInt() ?? 0;

            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminEventDetailsPage(
                          eventId: eventId,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          Colors.blue.shade50,
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Event poster
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade300.withOpacity(0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: posterUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: posterUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: Colors.grey.shade200,
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF6B8E23),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.error, color: Colors.grey),
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: const Color(0xFF6B8E23).withOpacity(0.1),
                                    child: const Icon(
                                      Icons.event,
                                      color: Color(0xFF6B8E23),
                                      size: 32,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 16),
                          
                          // Event details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event['name']?.toString() ?? 'Untitled Event',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF556B2F),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormat('MMM dd, yyyy').format(date),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.people, size: 14, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${participants.length}/$maxParticipants participants',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          // Action buttons
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (status == 'pending') ...[
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ElevatedButton(
                                      onPressed: () => _updateEventStatus(eventId, 'approved'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF228B22).withOpacity(0.1),
                                        foregroundColor: const Color(0xFF228B22),
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: const Icon(Icons.check, size: 16),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () => _updateEventStatus(eventId, 'rejected'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF8B4513).withOpacity(0.1),
                                        foregroundColor: const Color(0xFF8B4513),
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: const Icon(Icons.close, size: 16),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                              ElevatedButton(
                                onPressed: () => _toggleFeatured(eventId, !(event['isFeatured'] ?? false)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: (event['isFeatured'] ?? false) 
                                      ? const Color(0xFF2E8B57).withOpacity(0.1)
                                      : Colors.grey.shade100,
                                  foregroundColor: (event['isFeatured'] ?? false) 
                                      ? const Color(0xFF2E8B57)
                                      : Colors.grey.shade600,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Icon(
                                  (event['isFeatured'] ?? false) ? Icons.star : Icons.star_border,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFeaturedEvents() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('events').where('isFeatured', isEqualTo: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final events = snapshot.data!.docs;
        if (events.isEmpty) {
          return const Center(child: Text('No featured events found.'));
        }

        return ListView.builder(
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index].data() as Map<String, dynamic>;
            final eventId = events[index].id;
            final media = event['media'] as Map<String, dynamic>? ?? {};
            final posterUrl = media['posterUrl']?.toString();
            final date = (event['date'] as Timestamp?)?.toDate() ?? DateTime.now();
            final participants = event['participants'] as Map<String, dynamic>? ?? {};
            final details = event['details'] as Map<String, dynamic>? ?? {};
            final maxParticipants = (details['maxParticipants'] as num?)?.toInt() ?? 0;

            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminEventDetailsPage(
                          eventId: eventId,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          Colors.blue.shade50,
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Event poster
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade300.withOpacity(0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: posterUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: posterUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: Colors.grey.shade200,
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF6B8E23),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.error, color: Colors.grey),
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: const Color(0xFF6B8E23).withOpacity(0.1),
                                    child: const Icon(
                                      Icons.event,
                                      color: Color(0xFF6B8E23),
                                      size: 32,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 16),
                          
                          // Event details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event['name']?.toString() ?? 'Untitled Event',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF556B2F),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormat('MMM dd, yyyy').format(date),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.people, size: 14, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${participants.length}/$maxParticipants participants',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          // Action button
                          ElevatedButton(
                            onPressed: () => _toggleFeatured(eventId, false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E8B57).withOpacity(0.1),
                              foregroundColor: const Color(0xFF2E8B57),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Icon(Icons.star, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6B8E23).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.event,
                color: Color(0xFF6B8E23),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            const Text(
              'Event Management',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF556B2F),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Statistics Cards
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: [
            _buildStatsCard('Total Events', _eventStats['total'], const Color(0xFF6B8E23)),
            _buildStatsCard('Approved', _eventStats['approved'], const Color(0xFF228B22)),
            _buildStatsCard('Pending', _eventStats['pending'], const Color(0xFFFF9800)),
            _buildStatsCard('Featured', _eventStats['featured'], const Color(0xFF8FBC8F)),
          ],
        ),
        const SizedBox(height: 24),
        
        // Tab Bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6B8E23).withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF6B8E23),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF6B8E23),
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            tabs: const [
              Tab(text: 'Approved'),
              Tab(text: 'Rejected'),
              Tab(text: 'Featured'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildEventList('approved'),
              _buildEventList('pending'),
              _buildFeaturedEvents(),
            ],
          ),
        ),
      ],
    );
  }
} 