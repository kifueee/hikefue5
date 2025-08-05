import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'admin_login_page.dart';
import 'admin_event_management.dart';
import 'admin_organizer_events_page.dart';
import '../scripts/fix_organizer_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  bool _isLoading = false;
  String _selectedTab = 'dashboard';
  String? _adminEmail;
  late TabController _organizerRequestTabController;
  late TabController _driverRequestTabController;
  final List<String> _organizerRequestTabs = ['Pending', 'Approved', 'Rejected'];
  final List<String> _driverRequestTabs = ['Pending', 'Approved', 'Rejected'];

  // Organizer list state
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _sortBy = 'name';
  bool _sortAscending = true;

  // Statistics
  int _totalEvents = 0;
  int _totalParticipants = 0;
  int _totalOrganizers = 0;
  int _pendingRequests = 0;

  @override
  void initState() {
    super.initState();
    _adminEmail = _auth.currentUser?.email;
    _organizerRequestTabController = TabController(length: 3, vsync: this);
    _driverRequestTabController = TabController(length: 3, vsync: this);
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);
    try {
      // Get total events
      final eventsSnapshot = await _firestore.collection('events').get();
      _totalEvents = eventsSnapshot.docs.length;

      // Get total participants
      final participantsSnapshot = await _firestore.collection('participants').get();
      _totalParticipants = participantsSnapshot.docs.length;

      // Get total organizers
      final organizersSnapshot = await _firestore.collection('organizers').get();
      _totalOrganizers = organizersSnapshot.docs.length;

      // Get pending requests
      final pendingRequestsSnapshot = await _firestore
          .collection('organizers')
          .where('status', isEqualTo: 'pending')
          .get();
      _pendingRequests = pendingRequestsSnapshot.docs.length;
    } catch (e) {
      print('Error loading statistics: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _organizerRequestTabController.dispose();
    _driverRequestTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        // Main background
        Container(color: const Color(0xFFF4F3EF)),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 1,
            shadowColor: Colors.black.withOpacity(0.1),
            title: Row(
              children: [
                const SizedBox(width: 260), // Space for sidebar
                const Text(
                  'Dashboard',
                  style: TextStyle(
                    color: Color(0xFF2C3E50),
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
                const Spacer(),
                // Search Bar
                SizedBox(
                  width: 250,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.all(8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                IconButton(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout_rounded),
                  color: Colors.grey.shade600,
                  tooltip: 'Sign Out',
                ),
                const SizedBox(width: 20),
              ],
            ),
          ),
          body: Row(
            children: [
              // Professional Dark Sidebar
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 260,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2833),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Sidebar Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          Icon(Icons.hiking_rounded, color: theme.primaryColor, size: 32),
                          const SizedBox(width: 12),
                          const Text(
                            'HikeFue Admin',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 1),
                    // User Profile
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Colors.white24,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _adminEmail ?? 'Administrator',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 1),
                    const SizedBox(height: 10),
                    // Navigation
                    _sidebarTile('Dashboard', Icons.dashboard_rounded, 'dashboard', theme),
                    _sidebarTile('Organizers', Icons.business_rounded, 'organizers', theme),
                    _sidebarTile('Participants', Icons.people_rounded, 'participants', theme),
                    _sidebarTile('Organizer Requests', Icons.assignment_rounded, 'organizer_requests', theme),
                    _sidebarTile('Driver Applications', Icons.drive_eta_rounded, 'driver_applications', theme),
                    _sidebarTile('Event Management', Icons.event_rounded, 'event_management', theme),
                  ],
                ),
              ),
              // Main content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: _buildCurrentTab(),
                ),
              ),
            ],
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: Card(
                elevation: 8,
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: Color(0xFF556B2F),
                        strokeWidth: 3,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Loading...',
                        style: TextStyle(
                          color: Color(0xFF2C3E50),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCurrentTab() {
    switch (_selectedTab) {
      case 'dashboard':
        return _buildDashboard();
      case 'organizers':
        return _buildOrganizersList();
      case 'participants':
        return _buildParticipantsList();
      case 'organizer_requests':
        return _buildOrganizerRequestsTabs();
      case 'driver_applications':
        return _buildDriverApplicationsTabs();
      case 'event_management':
        return const AdminEventManagement();
      default:
        return _buildDashboard();
    }
  }

  Widget _sidebarTile(String title, IconData icon, String tabName, ThemeData theme) {
    final bool isSelected = _selectedTab == tabName;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFE91E63) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white, size: 20),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
        onTap: () => setState(() => _selectedTab = tabName),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _hoverCard({required Widget child}) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool hovered = false;
        return MouseRegion(
          onEnter: (_) => setState(() => hovered = true),
          onExit: (_) => setState(() => hovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: hovered ? (Matrix4.identity()..scale(1.02)) : Matrix4.identity(),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: hovered
                      ? const Color(0xFF6B8E23).withOpacity(0.2)
                      : Colors.grey.shade200.withOpacity(0.3),
                  blurRadius: hovered ? 20 : 12,
                  offset: const Offset(0, 8),
                  spreadRadius: hovered ? 2 : 0,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
    );
  }

  Widget _statusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'approved':
      case 'OrganizerStatus.approved':
        color = const Color(0xFF228B22); // Forest green
        label = 'Approved';
        break;
      case 'rejected':
      case 'OrganizerStatus.rejected':
        color = const Color(0xFF8B4513); // Saddle brown
        label = 'Rejected';
        break;
      default:
        color = const Color(0xFF2E8B57); // Sea green instead of orange
        label = 'Pending';
    }
    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF556B2F).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF556B2F).withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.dashboard_rounded,
                  color: Color(0xFF556B2F),
                  size: 28,
                ),
              ),
              const SizedBox(width: 20),
              const Text(
                'System Overview',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C3E50),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Enhanced Statistics Cards
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 1.3,
            children: [
              _statCard(
                'Total Events',
                _totalEvents.toString(),
                Icons.event_rounded,
                const Color(0xFF556B2F),
              ),
              _statCard(
                'Total Participants',
                _totalParticipants.toString(),
                Icons.people_rounded,
                const Color(0xFF6B8E23),
              ),
              _statCard(
                'Active Organizers',
                _totalOrganizers.toString(),
                Icons.business_rounded,
                const Color(0xFF8FBC8F),
              ),
              _statCard(
                'Pending Requests',
                _pendingRequests.toString(),
                Icons.pending_actions_rounded,
                const Color(0xFF2E8B57),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Recent Events
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B8E23).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.event,
                  color: Color(0xFF6B8E23),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Recent Events',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF556B2F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRecentEvents(),
          const SizedBox(height: 32),
          // Recent Organizer Requests
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E8B57).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.assignment,
                  color: Color(0xFF2E8B57),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Recent Organizer Requests',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF556B2F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRecentOrganizerRequests(),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
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

  Widget _buildRecentEvents() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('events')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF6B8E23)));
        }

        final events = snapshot.data!.docs;
        if (events.isEmpty) {
          return const Center(child: Text('No events found'));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index].data() as Map<String, dynamic>;
            final date = (event['date'] as Timestamp?)?.toDate();
            final status = event['status']?.toString() ?? 'approved';

            return _hoverCard(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF6B8E23).withOpacity(0.1),
                  child: const Icon(Icons.event, color: Color(0xFF6B8E23)),
                ),
                title: Text(
                  event['name']?.toString() ?? 'Untitled Event',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF556B2F)),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (date != null)
                      Text('Date: ${DateFormat('MMM dd, yyyy').format(date)}'),
                    Text('Status: ${status.toUpperCase()}'),
                  ],
                ),
                trailing: _statusChip(status),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecentOrganizerRequests() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('organizers')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF6B8E23)));
        }

        final requests = snapshot.data!.docs;
        if (requests.isEmpty) {
          return const Center(child: Text('No pending requests'));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index].data() as Map<String, dynamic>;
            final createdAt = (request['createdAt'] as Timestamp?)?.toDate();

            return _hoverCard(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF2E8B57).withOpacity(0.1),
                  child: const Icon(Icons.person_add, color: Color(0xFF2E8B57)),
                ),
                title: Text(
                  request['name']?.toString() ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF556B2F)),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request['email']?.toString() ?? 'No email'),
                    if (createdAt != null)
                      Text('Requested: ${DateFormat('MMM dd, yyyy').format(createdAt)}'),
                  ],
                ),
                trailing: _statusChip('pending'),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOrganizerRequestsTabs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _organizerRequestTabController,
                  labelColor: Colors.deepPurple.shade700,
                  unselectedLabelColor: Colors.grey,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.deepPurple.shade200,
                  ),
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  tabs: _organizerRequestTabs.map((tab) => Tab(text: tab)).toList(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _fixOrganizerAuth,
              icon: const Icon(Icons.build),
              label: const Text('Fix Auth'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _organizerRequestTabController,
            children: [
              _buildOrganizerRequestsList('pending'),
              _buildApprovedOrganizersList(),
              _buildOrganizerRequestsList('rejected'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildApprovedOrganizersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('organizers').where('status', isEqualTo: 'approved').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final organizers = snapshot.data!.docs;
        if (organizers.isEmpty) {
          return const Center(child: Text('No approved organizers.'));
        }
        return ListView.builder(
          itemCount: organizers.length,
          itemBuilder: (context, index) {
            final data = organizers[index].data() as Map<String, dynamic>;
            final name = data['name'] ?? '';
            final email = data['email'] ?? '';
            final orgName = data['organizationName'] ?? '';
            final contact = data['contactNumber'] ?? '';
            final experiences = data['experiences'] as List<dynamic>? ?? [];
            final experienceText = experiences.isNotEmpty ? experiences.join(', ') : '';
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: ListTile(
                title: Text(name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Email: $email'),
                    Text('Organization: $orgName'),
                    Text('Contact: $contact'),
                    if (experienceText.isNotEmpty) Text('Experience: $experienceText'),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOrganizerRequestsList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('organizers').where('status', isEqualTo: status).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final requests = snapshot.data!.docs;
        if (requests.isEmpty) {
          return Center(child: Text('No ${status.toLowerCase()} organizer requests.'));
        }
        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final data = requests[index].data() as Map<String, dynamic>;
            final name = data['name'] ?? '';
            final email = data['email'] ?? '';
            final orgName = data['organizationName'] ?? '';
            final companyReg = data['companyRegNumber'] ?? '';
            final companyPhone = data['companyPhone'] ?? '';
            final experiences = data['experiences'] as List<dynamic>? ?? [];
            final experienceText = experiences.isNotEmpty ? experiences.join(', ') : '';
            final companyDocs = data['companyDocs'] as List<dynamic>? ?? [];
            final statusValue = data['status'] ?? '';
            return _hoverCard(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.orange.shade100,
                      child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 28, color: Colors.orange)),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 16),
                              _statusChip(statusValue),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(email, style: const TextStyle(color: Colors.black54, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text('Company: $orgName', style: const TextStyle(fontSize: 15)),
                          const SizedBox(height: 4),
                          Text('Company Reg. Number: $companyReg', style: const TextStyle(fontSize: 15)),
                          const SizedBox(height: 4),
                          Text('Company Phone: $companyPhone', style: const TextStyle(fontSize: 15)),
                          if (experienceText.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text('Experience: $experienceText', style: const TextStyle(fontSize: 15, color: Colors.black87)),
                            ),
                          if (companyDocs.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Company Documents:', style: TextStyle(fontSize: 15)),
                                  ...companyDocs.map((docUrl) {
                                    final fileName = Uri.decodeComponent(docUrl.split('%2F').last.split('?').first);
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: GestureDetector(
                                              onTap: () => _launchUrl(docUrl),
                                              child: Text(
                                                fileName,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 2,
                                                softWrap: true,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  color: Colors.blue,
                                                  decoration: TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.open_in_new, size: 18, color: Colors.blue),
                                            tooltip: 'View',
                                            onPressed: () => _launchUrl(docUrl),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        if (status == 'pending') ...[
                          const SizedBox(width: 16),
                          _actionIconButton(Icons.check, Colors.green, () => _handleApproveOrganizerRequest(requests[index].id, data)),
                          const SizedBox(width: 8),
                          _actionIconButton(Icons.close, Colors.red, () => _handleRejectOrganizerRequest(requests[index].id)),
                        ],
                      ],
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

  Widget _actionIconButton(IconData icon, Color color, VoidCallback onPressed) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
      ),
    );
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('IC Image'),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Flexible(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.error, size: 50, color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizersList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with search and filters
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search organizers...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.deepPurple.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.deepPurple.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.deepPurple.shade400),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
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
            Row(
              children: [
                DropdownButton<String>(
                  value: _sortBy,
                  items: const [
                    DropdownMenuItem(value: 'name', child: Text('Sort by Name')),
                    DropdownMenuItem(value: 'date', child: Text('Sort by Date')),
                    DropdownMenuItem(value: 'events', child: Text('Sort by Events')),
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
          ],
        ),
        const SizedBox(height: 24),
        // Organizers List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('organizers').where('status', isEqualTo: 'approved').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              // Filter and sort organizers
              var organizers = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = (data['name'] as String? ?? '').toLowerCase();
                final email = (data['email'] as String? ?? '').toLowerCase();
                final orgName = (data['organizationName'] as String? ?? '').toLowerCase();
                final status = data['status'] as String? ?? 'pending';

                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  if (!name.contains(_searchQuery) &&
                      !email.contains(_searchQuery) &&
                      !orgName.contains(_searchQuery)) {
                    return false;
                  }
                }

                // Apply status filter
                if (_statusFilter != 'all' && status != _statusFilter) {
                  return false;
                }

                return true;
              }).toList();

              // Sort organizers
              organizers.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                int comparison = 0;

                switch (_sortBy) {
                  case 'name':
                    comparison = (aData['name'] as String? ?? '')
                        .compareTo(bData['name'] as String? ?? '');
                    break;
                  case 'date':
                    final aDate = (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
                    final bDate = (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
                    comparison = aDate.compareTo(bDate);
                    break;
                  case 'events':
                    // This will be handled by the StreamBuilder for events
                    comparison = 0;
                    break;
                }

                return _sortAscending ? comparison : -comparison;
              });

              if (organizers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No organizers found',
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
                itemCount: organizers.length,
                itemBuilder: (context, index) {
                  final organizer = organizers[index].data() as Map<String, dynamic>;
                  final status = organizer['status'] as String? ?? 'pending';
                  final email = organizer['email'] as String? ?? 'No email';
                  final name = organizer['name'] as String? ?? 'No name';
                  final orgName = organizer['organizationName'] as String? ?? '-';
                  final contact = organizer['contactNumber'] as String? ?? '-';
                  final experience = organizer['experience'] as String? ?? '-';
                  final createdAt = (organizer['createdAt'] as Timestamp?)?.toDate();
                  
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
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.deepPurple.shade100,
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    fontSize: 24,
                                    color: Colors.deepPurple.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _statusChip(status),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      email,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (status == 'pending') ...[
                                _actionButton(
                                  'Approve',
                                  Colors.green,
                                  Icons.check,
                                  () => _showConfirmDialog(
                                    title: 'Approve Organizer',
                                    content: 'Are you sure you want to approve this organizer?',
                                    onConfirm: () => _updateRegistrationStatus(organizers[index].id, 'approved'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _actionButton(
                                  'Reject',
                                  Colors.red,
                                  Icons.close,
                                  () => _showConfirmDialog(
                                    title: 'Reject Organizer',
                                    content: 'Are you sure you want to reject this organizer?',
                                    onConfirm: () => _updateRegistrationStatus(organizers[index].id, 'rejected'),
                                  ),
                                ),
                              ],
                              if (status == 'approved') ...[
                                _actionButton(
                                  'Delete',
                                  Colors.red,
                                  Icons.delete,
                                  () => _showConfirmDialog(
                                    title: 'Delete Organizer',
                                    content: 'Are you sure you want to delete this organizer? This will also delete all their events and cannot be undone.',
                                    onConfirm: () => _deleteOrganizer(organizers[index].id, name),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const Divider(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: _infoColumn('Organization', orgName),
                              ),
                              Expanded(
                                child: _infoColumn('Contact', contact),
                              ),
                              Expanded(
                                child: _infoColumn('Experience', experience),
                              ),
                              Expanded(
                                child: _infoColumn(
                                  'Joined',
                                  createdAt != null
                                      ? DateFormat('MMM dd, yyyy').format(createdAt)
                                      : 'Unknown',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Organizer Statistics
                          StreamBuilder<QuerySnapshot>(
                            stream: _firestore
                                .collection('events')
                                .where('organizer.id', isEqualTo: organizers[index].id)
                                .snapshots(),
                            builder: (context, eventsSnapshot) {
                              if (!eventsSnapshot.hasData) {
                                return const SizedBox.shrink();
                              }
                              final events = eventsSnapshot.data!.docs;
                              final totalEvents = events.length;
                              final activeEvents = events.where((e) =>
                                  (e.data() as Map<String, dynamic>)['status'] == 'approved').length;
                              final totalParticipants = events.fold<int>(
                                0,
                                (sum, e) {
                                  final eventData = e.data() as Map<String, dynamic>;
                                  final participants = eventData['participants'] as Map<String, dynamic>? ?? {};
                                  return sum + participants.length;
                                },
                              );
                              
                              return Row(
                                children: [
                                  _statBox('Total Events', totalEvents.toString()),
                                  _statBox('Active Events', activeEvents.toString()),
                                  _statBox('Total Participants', totalParticipants.toString()),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          // View Events Button
                          Center(
                            child: TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AdminOrganizerEventsPage(
                                      organizerId: organizers[index].id,
                                      organizerName: name,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.event),
                              label: const Text('View Events'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.deepPurple,
                              ),
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
    );
  }

  Widget _infoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _statBox(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.deepPurple.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(String label, Color color, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
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
        if (participants.isEmpty) {
          return const Center(child: Text('No participants found.'));
        }
        return ListView.builder(
          itemCount: participants.length,
          itemBuilder: (context, index) {
            final participant = participants[index].data() as Map<String, dynamic>;
            final name = participant['name'] as String? ?? '-';
            final gender = participant['gender'] as String? ?? '-';
            final phone = participant['phone'] as String? ?? participant['phoneNumber'] as String? ?? '-';
            final email = participant['email'] as String? ?? 'No email';
            return Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.person, color: Colors.green),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Gender: $gender', style: const TextStyle(fontSize: 14)),
                          Text(email, style: const TextStyle(color: Colors.black54)),
                          Text('Phone: $phone', style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Delete Participant',
                      onPressed: () => _showConfirmDialog(
                        title: 'Delete Participant',
                        content: 'Are you sure you want to delete this participant?',
                        onConfirm: () => _deleteParticipant(participants[index].id),
                      ),
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

  void _showConfirmDialog({
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateRegistrationStatus(String registrationId, String status) async {
    try {
      setState(() => _isLoading = true);
      
      // Update the organizer's status
      await _firestore.collection('organizers').doc(registrationId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to $status')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteOrganizer(String organizerId, String organizerName) async {
    try {
      setState(() => _isLoading = true);
      
      // Get all events by this organizer
      final eventsQuery = await _firestore
          .collection('events')
          .where('organizer.id', isEqualTo: organizerId)
          .get();
      
      // Delete all events by this organizer
      final batch = _firestore.batch();
      for (final eventDoc in eventsQuery.docs) {
        batch.delete(eventDoc.reference);
      }
      
      // Delete the organizer document
      batch.delete(_firestore.collection('organizers').doc(organizerId));
      
      // Commit the batch delete
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Organizer "$organizerName" and ${eventsQuery.docs.length} events deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting organizer: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteParticipant(String participantId) async {
    try {
      setState(() => _isLoading = true);
      
      // Delete participant document
      await _firestore.collection('participants').doc(participantId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Participant deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting participant: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleApproveOrganizerRequest(String requestId, Map<String, dynamic> data) async {
    try {
      setState(() => _isLoading = true);
      
      print('Starting organizer approval process for: ${data['email']}');
      
      // Get the existing organizer document (should already have Firebase Auth UID from registration)
      final uid = data['uid'] as String?;
      if (uid == null) {
        throw Exception('Organizer UID not found. Please ensure registration was completed properly.');
      }
      
      // Update the organizer status to approved (no need to create auth account - already exists)
      await _firestore.collection('organizers').doc(uid).update({
        'status': 'approved',
        'updatedAt': FieldValue.serverTimestamp(),
        'approvedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });
      print('Organizer status updated to approved for UID: $uid');
      
      // Remove the old document if it has a different ID (cleanup from old system)
      if (requestId != uid) {
        await _firestore.collection('organizers').doc(requestId).delete();
      }
      
      // Send custom welcome email (no password information needed)
      try {
        // Safely extract strings to avoid timestamp/serialization issues
        String? organizerEmail;
        String? organizerName;
        String? organizationName;
        
        try {
          organizerEmail = data['email']?.toString();
          organizerName = data['name']?.toString();
          organizationName = data['organizationName']?.toString();
        } catch (e) {
          print('Error extracting organizer data: $e');
        }
        
        if (organizerEmail == null || organizerEmail.isEmpty || organizerName == null || organizerName.isEmpty) {
          throw Exception('Missing organizer email or name');
        }
        
        // Create clean data map with explicit string values
        final Map<String, String> cleanData = {};
        cleanData['organizerEmail'] = organizerEmail;
        cleanData['organizerName'] = organizerName;
        
        if (organizationName != null && organizationName.isNotEmpty) {
          cleanData['organizationName'] = organizationName;
        }
        
        print('Clean approval data to send: $cleanData');
        
        // Try Firebase Functions SDK first, fallback to HTTP if it fails
        try {
          final sendEmailFunction = _functions.httpsCallable('sendOrganizerApprovalEmail');
          final result = await sendEmailFunction.call(cleanData);
          print('Function call result: $result');
          print('Approval email sent successfully to: $organizerEmail');
        } catch (functionsError) {
          print('Firebase Functions SDK failed, trying HTTP approach: $functionsError');
          
          // Fallback to direct HTTP call
          final user = _auth.currentUser;
          if (user == null) throw Exception('User not authenticated');
          
          final idToken = await user.getIdToken();
          final functionUrl = 'https://us-central1-hikefue5-8f6ae.cloudfunctions.net/sendOrganizerApprovalEmail';
          
          final response = await http.post(
            Uri.parse(functionUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({'data': cleanData}),
          );
          
          if (response.statusCode == 200) {
            final result = jsonDecode(response.body);
            print('HTTP function call result: $result');
            print('Approval email sent successfully via HTTP to: $organizerEmail');
          } else {
            throw Exception('HTTP call failed: ${response.statusCode} - ${response.body}');
          }
        }
      } catch (emailError) {
        print('Failed to send approval email: $emailError');
        print('Error type: ${emailError.runtimeType}');
        print('Full error details: ${emailError.toString()}');
        
        // Show the error to user for debugging
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Email sending failed: ${emailError.toString()}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 7),
            ),
          );
        }
      }
      
      print('Organizer approval completed successfully');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Organizer approved successfully! They can now log in with their credentials. Welcome email sent to: ${data['email']}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth error during approval: ${e.code} - ${e.message}');
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'An account with this email already exists.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address.';
          break;
        case 'weak-password':
          errorMessage = 'Password is too weak.';
          break;
        default:
          errorMessage = 'Error creating user account: ${e.message}';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      print('General error during approval: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving organizer: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRejectOrganizerRequest(String requestId) async {
    try {
      setState(() => _isLoading = true);
      
      // Get organizer data first for email
      final organizerDoc = await _firestore.collection('organizers').doc(requestId).get();
      if (!organizerDoc.exists) {
        throw Exception('Organizer document not found');
      }
      
      final organizerData = organizerDoc.data() as Map<String, dynamic>;
      
      // Safely extract strings to avoid timestamp/serialization issues
      String? organizerEmail;
      String? organizerName;
      String? organizationName;
      
      try {
        organizerEmail = organizerData['email']?.toString();
        organizerName = organizerData['name']?.toString();
        organizationName = organizerData['organizationName']?.toString();
      } catch (e) {
        print('Error extracting organizer data: $e');
      }
      
      if (organizerEmail == null || organizerEmail.isEmpty || organizerName == null || organizerName.isEmpty) {
        throw Exception('Missing organizer email or name');
      }
      
      // Show dialog to get rejection reason
      final rejectionReason = await _showRejectionReasonDialog();
      if (rejectionReason == null) {
        setState(() => _isLoading = false);
        return; // User cancelled
      }
      
      // Update status to rejected in organizers
      await _firestore.collection('organizers').doc(requestId).update({
        'status': 'rejected',
        'rejectionReason': rejectionReason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Send rejection email
      try {
        print('Attempting to call rejection email function...');
        print('Data: organizerEmail=$organizerEmail, organizerName=$organizerName, rejectionReason=$rejectionReason');
        
        // Create completely new, clean data map with explicit string values
        final Map<String, String> cleanData = {};
        cleanData['organizerEmail'] = organizerEmail;
        cleanData['organizerName'] = organizerName;
        cleanData['rejectionReason'] = rejectionReason;
        
        if (organizationName != null && organizationName.isNotEmpty) {
          cleanData['organizationName'] = organizationName;
        }
        
        print('Clean data to send: $cleanData');
        
        // Try Firebase Functions SDK first, fallback to HTTP if it fails
        try {
          final sendEmailFunction = _functions.httpsCallable('sendOrganizerRejectionEmail');
          final result = await sendEmailFunction.call(cleanData);
          print('Function call result: $result');
          print('Rejection email sent successfully to: $organizerEmail');
        } catch (functionsError) {
          print('Firebase Functions SDK failed, trying HTTP approach: $functionsError');
          
          // Fallback to direct HTTP call
          final user = _auth.currentUser;
          if (user == null) throw Exception('User not authenticated');
          
          final idToken = await user.getIdToken();
          final functionUrl = 'https://us-central1-hikefue5-8f6ae.cloudfunctions.net/sendOrganizerRejectionEmail';
          
          final response = await http.post(
            Uri.parse(functionUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({'data': cleanData}),
          );
          
          if (response.statusCode == 200) {
            final result = jsonDecode(response.body);
            print('HTTP function call result: $result');
            print('Rejection email sent successfully via HTTP to: $organizerEmail');
          } else {
            throw Exception('HTTP call failed: ${response.statusCode} - ${response.body}');
          }
        }
      } catch (emailError) {
        print('Failed to send rejection email: $emailError');
        print('Error type: ${emailError.runtimeType}');
        print('Full error details: ${emailError.toString()}');
        
        // Show the error to user for debugging
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Email sending failed: ${emailError.toString()}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 7),
            ),
          );
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Organizer request rejected and notification email sent to: $organizerEmail'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting organizer: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String?> _showRejectionReasonDialog() async {
    final reasonController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejection Reason'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejecting this organizer application:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.of(context).pop(reasonController.text.trim());
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminLoginPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  Widget _buildDriverApplicationsTabs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Driver Applications',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        const SizedBox(height: 24),
        TabBar(
          controller: _driverRequestTabController,
          tabs: _driverRequestTabs.map((tab) => Tab(text: tab)).toList(),
          labelColor: Colors.deepPurple,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.deepPurple,
        ),
        Expanded(
          child: TabBarView(
            controller: _driverRequestTabController,
            children: _driverRequestTabs.map((status) {
              String firestoreStatus;
              switch (status) {
                case 'Pending':
                  firestoreStatus = 'pending';
                  break;
                case 'Approved':
                  firestoreStatus = 'approved';
                  break;
                case 'Rejected':
                  firestoreStatus = 'rejected';
                  break;
                default:
                  firestoreStatus = 'pending';
              }
              return _buildDriverApplicationsList(firestoreStatus);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDriverApplicationsList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('driver_applications')
          .where('status', isEqualTo: status)
          .orderBy('submittedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final applications = snapshot.data!.docs;
        if (applications.isEmpty) {
          return Center(child: Text('No ${status.toLowerCase()} driver applications.'));
        }

        return ListView.builder(
          itemCount: applications.length,
          itemBuilder: (context, index) {
            final data = applications[index].data() as Map<String, dynamic>;
            final name = data['name'] ?? '';
            final email = data['email'] ?? '';
            final licenseNumber = data['licenseNumber'] ?? '';
            final licensePhotoUrl = data['licensePhotoUrl'] ?? '';
            final vehicleDetails = data['vehicleDetails'] ?? '';
            final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();

            return _hoverCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: const Icon(Icons.drive_eta, color: Colors.blue),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(email),
                            ],
                          ),
                        ),
                        if (status == 'pending') ...[
                          _actionIconButton(
                            Icons.check,
                            Colors.green,
                            () => _handleApproveDriverApplication(applications[index].id, data),
                          ),
                          const SizedBox(width: 8),
                          _actionIconButton(
                            Icons.close,
                            Colors.red,
                            () => _handleRejectDriverApplication(applications[index].id),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(Icons.badge, 'License Number', licenseNumber),
                    _buildDetailRow(Icons.directions_car, 'Vehicle Details', vehicleDetails),
                    if (submittedAt != null)
                      _buildDetailRow(
                        Icons.access_time,
                        'Submitted',
                        DateFormat('MMM dd, yyyy HH:mm').format(submittedAt),
                      ),
                    if (licensePhotoUrl.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'License Photo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.deepPurple.shade100, width: 2),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurple.shade50,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(licensePhotoUrl, fit: BoxFit.cover),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleApproveDriverApplication(String applicationId, Map<String, dynamic> data) async {
    try {
      print('Approving driver application: $applicationId');
      await _firestore.collection('driver_applications').doc(applicationId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': _adminEmail,
      });
      print('Driver application status updated.');

      try {
        await _firestore.collection('users').doc(data['userId']).set({
          'isApprovedDriver': true,
          'driverDetails': {
            'licenseNumber': data['licenseNumber'],
            'vehicleDetails': data['vehicleDetails'],
            'vehicleMake': data['vehicleMake'],
            'vehicleModel': data['vehicleModel'],
            'vehicleColor': data['vehicleColor'],
            'vehiclePlate': data['vehiclePlate'],
            'vehicleType': data['vehicleType'],
          },
        }, SetOptions(merge: true));
        print('User document updated.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver application approved successfully')),
        );
      } catch (e) {
        print('Error updating user document: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Driver application approved, but failed to update user profile: $e')),
        );
      }
    } catch (e) {
      print('Error approving driver application: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error approving driver application: $e')),
      );
    }
  }

  Future<void> _handleRejectDriverApplication(String applicationId) async {
    try {
      await _firestore.collection('driver_applications').doc(applicationId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': _adminEmail,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver application rejected')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting driver application: $e')),
      );
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.deepPurple),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Text(value),
      ],
    );
  }



  Future<void> _fixOrganizerAuth() async {
    try {
      setState(() => _isLoading = true);
      
      await AdminDashboardHelper.fixOrganizerAuth();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Organizer authentication fix completed! Check console for details.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fixing organizer auth: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showDocumentDialog(String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Company Document'),
        content: SizedBox(
          width: 600,
          height: 800,
          child: Center(
            child: SelectableText(url), // You can replace with PDF/image preview widget if needed
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () => _launchUrl(url),
            child: const Text('Open in new tab'),
          ),
        ],
      ),
    );
  }

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Optionally show a snackbar or dialog if the URL can't be launched
      debugPrint('Could not launch $url');
    }
  }
} 