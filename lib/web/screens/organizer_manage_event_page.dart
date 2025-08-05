import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:excel/excel.dart' as excel;
import 'package:url_launcher/url_launcher.dart';
import 'dart:html' as html;
import 'dart:ui';
import '../widgets/carpool_map_widget.dart';
import '../../widgets/event_deletion_dialog.dart';
import '../../widgets/event_status_manager.dart';
import '../../widgets/professional_event_status_widget.dart';
import '../../utils/data_utils.dart';

const Color primaryColor = Color(0xFF004A4D);
const Color accentColor = Color(0xFF94BC45);
const Color darkBackgroundColor = Color(0xFF231F20);
const Color cardColor = Color(0xFFFAFAFA);
const Color borderColor = Color(0xFFE5E7EB);

class OrganizerManageEventPage extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> eventData;
  const OrganizerManageEventPage({super.key, required this.eventId, required this.eventData});

  @override
  State<OrganizerManageEventPage> createState() => _OrganizerManageEventPageState();
}

class _OrganizerManageEventPageState extends State<OrganizerManageEventPage> with TickerProviderStateMixin {
  late Map<String, dynamic> eventData;
  bool _loading = false;
  Set<String> selectedParticipants = {};
  late TabController _mainTabController;
  late TabController _carpoolTabController;
  
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    eventData = widget.eventData;
    _mainTabController = TabController(length: 4, vsync: this);
    _carpoolTabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _carpoolTabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = eventData['name'] as String? ?? 'Unnamed Event';
    final imageUrl = eventData['media']?['posterUrl'] as String?;
    final date = (eventData['date'] as dynamic)?.toDate();
    final location = eventData['location']?['address'] as String? ?? 'Location TBD';
    final status = eventData['status'] as String? ?? 'pending';
    final participants = eventData['participants'] as Map<String, dynamic>? ?? {};
    
    // Calculate current participants from the participants map
    final currentParticipants = participants.length;
    final maxParticipants = eventData['details']?['maxParticipants'] as int? ?? 0;
    
    // Debug info
    print('Event data participants: ${participants.length}');
    print('Current participants: $currentParticipants, Max participants: $maxParticipants');
    print('Event details: ${eventData['details']}');
    
    final participantList = participants.entries.map((e) {
      final data = e.value as Map<String, dynamic>;
      data['id'] = e.key;
      return data;
    }).toList();
    
    final paidCount = participantList.where((p) {
      final paymentDetails = p['paymentDetails'] as Map<String, dynamic>? ?? {};
      final paymentStatus = p['paymentStatus'] as String? ?? '';
      return DataUtils.safeBool(paymentDetails['paid']) ||
             paymentStatus == 'paid' ||
             paymentStatus == 'completed';
    }).length;
    final unpaidCount = participantList.length - paidCount;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Manage Event', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Analytics',
            onPressed: () => _mainTabController.animateTo(4),
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export',
            onPressed: _exportEventData,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: _showEventSettings,
          ),
        ],
      ),
      body: Stack(
        children: [
          SizedBox.expand(
            child: Image.asset(
              'assets/images/trees_background.jpg',
              fit: BoxFit.cover,
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(color: Colors.transparent),
          ),
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black.withOpacity(0.2),
          ),
          _loading
              ? const Center(child: CircularProgressIndicator(color: accentColor))
              : SingleChildScrollView(
                  controller: _scrollController,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 120),
                    child: Column(
                      children: [
                        // Dashboard Header with Key Metrics
                        _buildDashboardHeader(name, imageUrl, date, location, currentParticipants, maxParticipants, paidCount, unpaidCount),
                        
                        const SizedBox(height: 32),
                        
                                // Main Navigation Tabs
        _buildMainNavigationTabs(),
        
        const SizedBox(height: 24),
        
        // Tab Content - No separate scrolling, listen to tab changes
        AnimatedBuilder(
          animation: _mainTabController,
          builder: (context, child) {
            switch (_mainTabController.index) {
              case 0:
                return _buildOverviewTab();
              case 1:
                return _buildParticipantsTab(participantList, paidCount, unpaidCount);
              case 2:
                return _buildCarpoolManagementTab();
              case 3:
                return _buildAnalyticsTab(participantList, paidCount, unpaidCount);
              default:
                return _buildOverviewTab();
            }
          },
        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildModernAppBar(String name, String status) {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: primaryColor,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor.withOpacity(0.05),
                accentColor.withOpacity(0.05),
              ],
            ),
          ),
        ),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Event Management',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
            Text(
              name.length > 30 ? '${name.substring(0, 30)}...' : name,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        titlePadding: const EdgeInsets.only(left: 72, bottom: 16),
      ),
      actions: [
        _buildQuickActionButton(
          icon: Icons.analytics_outlined,
          label: 'Analytics',
          onPressed: () => _mainTabController.animateTo(4),
        ),
        _buildQuickActionButton(
          icon: Icons.download_outlined,
          label: 'Export',
          onPressed: _exportEventData,
        ),
        _buildQuickActionButton(
          icon: Icons.settings_outlined,
          label: 'Settings',
          onPressed: _showEventSettings,
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: label,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        child: IconButton(
          icon: Icon(icon, size: 20),
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: borderColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardHeader(String name, String? imageUrl, DateTime? date, String location, 
      int currentParticipants, int maxParticipants, int paidCount, int unpaidCount) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Event Header
          Row(
            children: [
              // Event Image
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 120,
                        height: 80,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 120,
                          height: 80,
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            _buildPlaceholderImage(120, 80),
                      )
                    : _buildPlaceholderImage(120, 80),
              ),
              
              const SizedBox(width: 24),
              
              // Event Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ),
                        _buildStatusBadge(eventData['status'] ?? 'pending'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          date != null ? _formatDate(date) : 'Date TBD',
                          style: GoogleFonts.poppins(color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 24),
                        Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            location,
                            style: GoogleFonts.poppins(color: Colors.grey[600]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Key Metrics
          Row(
            children: [
              Expanded(child: _buildMetricCard('Total Participants', '$currentParticipants / $maxParticipants', Icons.people, accentColor)),
              const SizedBox(width: 16),
              Expanded(child: _buildMetricCard('Paid', paidCount.toString(), Icons.payment, Colors.green)),
              const SizedBox(width: 16),
              Expanded(child: _buildMetricCard('Pending Payment', unpaidCount.toString(), Icons.pending, Colors.orange)),
              const SizedBox(width: 16),
              Expanded(child: _buildMetricCard('Revenue', 'RM${_calculateRevenue().toStringAsFixed(2)}', Icons.monetization_on, Colors.blue)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(Icons.image, size: 32, color: Colors.grey[400]),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    IconData icon;
    
    switch (status.toLowerCase()) {
      case 'approved':
        color = Colors.green;
        label = 'Live';
        icon = Icons.check_circle;
        break;
      case 'pending':
        color = Colors.orange;
        label = 'Pending Review';
        icon = Icons.pending;
        break;
      case 'rejected':
        color = Colors.red;
        label = 'Rejected';
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        label = status;
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
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
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

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMainNavigationTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _mainTabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[600],
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryColor, accentColor],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14),
        tabs: const [
          Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
          Tab(icon: Icon(Icons.people), text: 'Participants'),
          Tab(icon: Icon(Icons.directions_car), text: 'Carpools'),
          Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _buildEventDetailsCard(),
                  const SizedBox(height: 24),
                  _buildQuickActionsCard(),
                ],
              ),
            ),
            
            const SizedBox(width: 24),
            
            // Right Column
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  _buildEventStatusCard(),
                  const SizedBox(height: 24),
                  _buildRecentActivityCard(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildParticipantsTab(List<Map<String, dynamic>> participantList, int paidCount, int unpaidCount) {
    return _buildModernCard(
      title: 'Participants Management',
      icon: Icons.people,
      child: _buildParticipantsTable(participantList, paidCount, unpaidCount, selectedParticipants.length == participantList.length && participantList.isNotEmpty),
    );
  }

  Widget _buildCarpoolManagementTab() {
    return _buildModernCard(
      title: 'Carpool Management',
      icon: Icons.directions_car,
      child: Column(
        children: [
          // Carpool Tabs
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _carpoolTabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[600],
              indicator: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(12),
              ),
              tabs: const [
                Tab(text: 'Applications'),
                Tab(text: 'Active Rides'),
                Tab(text: 'Assignments'),
                Tab(text: 'Map View'),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          SizedBox(
            height: 600,
            child: TabBarView(
              controller: _carpoolTabController,
              children: [
                _buildDriverApplicationsTab(),
                _buildActiveRideOffersTab(),
                _buildCarpoolAssignmentsTab(),
                _buildCarpoolMapSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventDetailsSection({
    required String name,
    required String? imageUrl,
    required DateTime? date,
    required String location,
    required String meetingPoint,
    required int currentParticipants,
    required int maxParticipants,
    required String status,
    required String description,
    required String organizerName,
    required String? organizerLogo,
    required String difficulty,
    required num distance,
    required num duration,
    required num eventFee,
  }) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Image
            if (imageUrl != null && imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 220,
                  height: 140,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 220,
                    height: 140,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 220,
                    height: 140,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                  ),
                ),
              )
            else
              Container(
                width: 220,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.image, size: 48, color: Colors.grey),
              ),
            const SizedBox(width: 32),
            // Main Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildStatusChip(status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(description, style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade800)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, color: accentColor, size: 18),
                      const SizedBox(width: 8),
                      Text(date != null ? _formatDate(date) : 'Date TBD', style: GoogleFonts.poppins(color: Colors.grey.shade800, fontSize: 16)),
                      const SizedBox(width: 24),
                      Icon(Icons.people, color: accentColor, size: 18),
                      const SizedBox(width: 6),
                      Text('$currentParticipants/$maxParticipants', style: GoogleFonts.poppins(color: Colors.grey.shade800, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.monetization_on, color: accentColor, size: 18),
                      const SizedBox(width: 6),
                      Text(eventFee > 0 ? 'RM${eventFee.toStringAsFixed(2)}' : 'Free', style: GoogleFonts.poppins(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.directions_walk, color: accentColor, size: 20),
                      const SizedBox(width: 8),
                      Text('Difficulty: ', style: GoogleFonts.poppins(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                      Text(difficulty, style: GoogleFonts.poppins(color: Colors.grey.shade900)),
                      const SizedBox(width: 18),
                      Icon(Icons.timeline, color: accentColor, size: 20),
                      const SizedBox(width: 8),
                      Text('Distance: ', style: GoogleFonts.poppins(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                      Text('$distance km', style: GoogleFonts.poppins(color: Colors.grey.shade900)),
                      const SizedBox(width: 18),
                      Icon(Icons.timer, color: accentColor, size: 20),
                      const SizedBox(width: 8),
                      Text('Duration: ', style: GoogleFonts.poppins(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                      Text('$duration hours', style: GoogleFonts.poppins(color: Colors.grey.shade900)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: accentColor, size: 18),
                      const SizedBox(width: 8),
                      Text('Location: ', style: GoogleFonts.poppins(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                      Expanded(child: Text(location, style: GoogleFonts.poppins(color: Colors.grey.shade900), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.meeting_room, color: accentColor, size: 18),
                      const SizedBox(width: 8),
                      Text('Meeting Point: ', style: GoogleFonts.poppins(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                      Expanded(child: Text(meetingPoint, style: GoogleFonts.poppins(color: Colors.grey.shade900), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (organizerLogo != null && organizerLogo.isNotEmpty)
                        CircleAvatar(backgroundImage: NetworkImage(organizerLogo), radius: 16),
                      if (organizerLogo != null && organizerLogo.isNotEmpty) const SizedBox(width: 8),
                      Text('Organizer: ', style: GoogleFonts.poppins(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                      Expanded(child: Text(organizerName, style: GoogleFonts.poppins(color: Colors.grey.shade900), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Delete Event Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          print('Prominent delete button clicked!');
                          _showDeleteEventDialog();
                        },
                        icon: const Icon(Icons.delete, color: Colors.white),
                        label: Text(
                          'Delete Event',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
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

  Widget _buildEventStatusSection(String status) {
    return EventStatusManager(
      eventId: widget.eventId,
      eventData: eventData,
    );
  }

  Widget _buildAnalyticsSection(List<Map<String, dynamic>> participantList, int paidCount, int unpaidCount) {
    // Simple bar and pie chart using charts_flutter or similar (UI only, no package import here)
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Analytics', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: primaryColor)),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Icon(Icons.people, color: accentColor),
                  const SizedBox(width: 8),
                  Text('Total Participants: ${participantList.length}', style: GoogleFonts.poppins(fontSize: 16)),
                  const SizedBox(width: 24),
                  Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Text('Paid: $paidCount', style: GoogleFonts.poppins(fontSize: 16)),
                  const SizedBox(width: 24),
                  Icon(Icons.cancel, color: Colors.red),
                  const SizedBox(width: 8),
                  Text('Unpaid: $unpaidCount', style: GoogleFonts.poppins(fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Simple bar chart (UI only)
            SizedBox(
              height: 180,
              width: 320,
              child: CustomPaint(
                painter: _BarChartPainter(paidCount, unpaidCount),
              ),
            ),
            const SizedBox(height: 16),
            // Simple pie chart (UI only)
            SizedBox(
              height: 180,
              width: 180,
              child: CustomPaint(
                painter: _PieChartPainter(paidCount, unpaidCount),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsTable(List<Map<String, dynamic>> participantList, int paidCount, int unpaidCount, bool allSelected) {
    // Advanced participant table with search, sorting, bulk actions, and export
    TextEditingController searchController = TextEditingController();
    List<Map<String, dynamic>> filteredList = List.from(participantList);
    String sortBy = 'name';
    bool ascending = true;
    void sortList() {
      filteredList.sort((a, b) {
        if (sortBy == 'name') {
          return ascending
              ? (a['name'] ?? '').compareTo(b['name'] ?? '')
              : (b['name'] ?? '').compareTo(a['name'] ?? '');
        } else if (sortBy == 'registeredAt') {
          DateTime aDate = (a['registeredAt'] as Timestamp?)?.toDate() ?? DateTime(0);
          DateTime bDate = (b['registeredAt'] as Timestamp?)?.toDate() ?? DateTime(0);
          return ascending ? aDate.compareTo(bDate) : bDate.compareTo(aDate);
        }
        return 0;
      });
    }
    sortList();
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Participants', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: primaryColor)),
                const SizedBox(width: 16),
                Icon(Icons.people, color: accentColor),
                const Spacer(),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search participants...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    ),
                    onChanged: (value) {
                      filteredList = participantList.where((p) {
                        final name = (p['name'] ?? '').toString().toLowerCase();
                        final email = (p['email'] ?? '').toString().toLowerCase();
                        return name.contains(value.toLowerCase()) || email.contains(value.toLowerCase());
                      }).toList();
                      sortList();
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Export to Excel'),
                  style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white),
                  onPressed: () => _exportParticipantsToExcel(eventData['name'] ?? 'event', filteredList),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(accentColor.withOpacity(0.15)),
                sortColumnIndex: sortBy == 'name' ? 0 : 5,
                sortAscending: ascending,
                columns: [
                  DataColumn(
                    label: Row(
                      children: [
                        Checkbox(
                          value: allSelected,
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                selectedParticipants = filteredList.map((p) => p['id'] as String).toSet();
                              } else {
                                selectedParticipants = <String>{};
                              }
                            });
                          },
                        ),
                        GestureDetector(
                          onTap: () {
                            sortBy = 'name';
                            ascending = !ascending;
                            sortList();
                            setState(() {});
                          },
                          child: Row(
                            children: [
                              Text('Name', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                              Icon(sortBy == 'name' ? (ascending ? Icons.arrow_upward : Icons.arrow_downward) : Icons.unfold_more, size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataColumn(label: Text('Email', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Phone', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Role', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Payment', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                  DataColumn(
                    label: GestureDetector(
                      onTap: () {
                        sortBy = 'registeredAt';
                        ascending = !ascending;
                        sortList();
                        setState(() {});
                      },
                      child: Row(
                        children: [
                          Text('Registered', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                          Icon(sortBy == 'registeredAt' ? (ascending ? Icons.arrow_upward : Icons.arrow_downward) : Icons.unfold_more, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
                rows: [
                  for (final p in filteredList)
                    DataRow(
                      selected: selectedParticipants.contains(p['id']),
                      onSelectChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            selectedParticipants.add(p['id'] as String);
                          } else {
                            selectedParticipants.remove(p['id'] as String);
                          }
                        });
                      },
                      cells: [
                        DataCell(Row(
                          children: [
                            Checkbox(
                              value: selectedParticipants.contains(p['id']),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    selectedParticipants.add(p['id'] as String);
                                  } else {
                                    selectedParticipants.remove(p['id'] as String);
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
                        DataCell(_buildPaymentStatusChip(p['paymentDetails'], p['paymentStatus'])),
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
            const SizedBox(height: 16),
            if (selectedParticipants.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Row(
                      children: [
                        Text('${selectedParticipants.length} selected', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.email),
                          label: const Text('Email Selected'),
                          style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white),
                          onPressed: () {
                            final emails = filteredList
                                .where((p) => selectedParticipants.contains(p['id']))
                                .map((p) => p['email'])
                                .where((email) => email != null && email.toString().isNotEmpty)
                                .cast<String>()
                                .toList();
                            if (emails.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('No valid email addresses found for selected participants.')),
                              );
                              return;
                            }
                            _launchBulkEmail(emails, subject: 'Message from HikeFue', body: 'Hi,\n\nThis is a message from the event organizer.');
                          },
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.edit),
                          label: const Text('Update Status'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                          onPressed: selectedParticipants.isEmpty ? null : () => _showBulkStatusUpdateDialog(),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.delete),
                          label: const Text('Remove'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          onPressed: selectedParticipants.isEmpty ? null : () => _showBulkRemoveDialog(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarpoolSection() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Carpool Management',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: primaryColor,
                      ),
                    ),
                    Text(
                      'Manage driver applications and ride offers',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Add tabs for different carpool management sections
            DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey[600],
                      indicator: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tabs: const [
                        Tab(text: 'Driver Applications'),
                        Tab(text: 'Active Ride Offers'),
                        Tab(text: 'Carpool Assignments'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 400, // Fixed height for tab content
                    child: TabBarView(
                      children: [
                        _buildDriverApplicationsTab(),
                        _buildActiveRideOffersTab(),
                        _buildCarpoolAssignmentsTab(),
                      ],
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

  Widget _buildDriverApplicationsTab() {
    return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('driver_applications')
                  .where('eventId', isEqualTo: widget.eventId)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: accentColor),
            ),
          );
        }
        
                final applications = snapshot.data!.docs;
                if (applications.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No Pending Applications',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'All driver applications have been reviewed',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }
        
        return Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pending, color: Colors.orange, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${applications.length} Pending',
                        style: GoogleFonts.poppins(
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                  onPressed: () {
                    // Trigger rebuild
                    setState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                  itemCount: applications.length,
                  itemBuilder: (context, index) {
                  final doc = applications[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'Unknown';
                    final email = data['email'] ?? '';
                    final licenseNumber = data['licenseNumber'] ?? '';
                    final licensePhotoUrl = data['licensePhotoUrl'] ?? '';
                    final vehicleDetails = data['vehicleDetails'] ?? '';
                  final submittedAt = data['submittedAt'] as Timestamp?;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
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
                                radius: 24,
                                backgroundColor: accentColor.withOpacity(0.1),
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
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
                                      name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: primaryColor,
                                      ),
                                    ),
                                    Text(
                                      email,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Content
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoSection(
                                title: 'Driver Information',
                                icon: Icons.person,
                                children: [
                                  _buildInfoRow('License Number', licenseNumber),
                                  _buildInfoRow('Vehicle Details', vehicleDetails),
                                ],
                              ),
                              const SizedBox(height: 20),
                              if (licensePhotoUrl.isNotEmpty)
                                _buildInfoSection(
                                  title: 'License Photo',
                                  icon: Icons.photo,
                                  children: [
                                    Container(
                                      height: 200,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey[300]!),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: CachedNetworkImage(
                                          imageUrl: licensePhotoUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            color: Colors.grey[200],
                                            child: const Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) {
                                            return Container(
                                              color: Colors.grey[200],
                                              child: const Icon(Icons.error, color: Colors.grey),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text('Approve'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: () => _approveDriverApplication(doc.id, name, email),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.close, size: 16),
                                      label: const Text('Reject'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: () => _rejectDriverApplication(doc.id, name, email),
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

  Widget _buildActiveRideOffersTab() {
    print('=== BUILDING ACTIVE RIDE OFFERS TAB ===');
    print('Widget Event ID: ${widget.eventId}');
    print('Event ID type: ${widget.eventId.runtimeType}');
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('driverOffers')
          .where('eventId', isEqualTo: widget.eventId)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        // Debug information
        print('=== ACTIVE RIDE OFFERS DEBUG ===');
        print('Event ID: ${widget.eventId}');
        print('Snapshot has data: ${snapshot.hasData}');
        print('Snapshot connection state: ${snapshot.connectionState}');
        if (snapshot.hasError) {
          print('Snapshot error: ${snapshot.error}');
        }
        
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: accentColor),
            ),
          );
        }
        
        final offers = snapshot.data!.docs;
        print('Number of offers found: ${offers.length}');
        
        // Debug each offer
        for (int i = 0; i < offers.length; i++) {
          final data = offers[i].data() as Map<String, dynamic>;
          print('Offer $i:');
          print('  - ID: ${offers[i].id}');
          print('  - Event ID: ${data['eventId']}');
          print('  - Status: ${data['status']}');
          print('  - Driver: ${data['driverName']}');
          print('  - Pickup: ${data['pickupLocation']}');
          print('  - Available Seats: ${data['availableSeats']}');
        }
        if (offers.isEmpty) {
          // Let's also check if there are ANY driver offers for this event (any status)
          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('driverOffers')
                .where('eventId', isEqualTo: widget.eventId)
                .get(),
            builder: (context, allOffersSnapshot) {
              if (allOffersSnapshot.hasData) {
                final allOffers = allOffersSnapshot.data!.docs;
                print('=== ALL OFFERS DEBUG ===');
                print('Total driver offers for this event (any status): ${allOffers.length}');
                for (var doc in allOffers) {
                  final data = doc.data() as Map<String, dynamic>;
                  print('  - Offer ID: ${doc.id}, Status: ${data['status']}, Driver: ${data['driverName']}');
                }
              }
              
              return Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.directions_car_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Active Ride Offers',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No ride offers have been created for this event yet',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                    if (allOffersSnapshot.hasData && allOffersSnapshot.data!.docs.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Found ${allOffersSnapshot.data!.docs.length} offers with other statuses',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.orange[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        }
        
        return Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                        '${offers.length} Active',
                        style: GoogleFonts.poppins(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                  onPressed: () {
                    setState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: offers.length,
                itemBuilder: (context, index) {
                  final doc = offers[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final driverName = data['driverName'] ?? 'Unknown Driver';
                  final driverEmail = data['driverEmail'] ?? '';
                  final vehicleDetails = data['vehicleDetails'] ?? '';
                  final pickupLocation = data['pickupLocation'] ?? '';
                  final dropoffLocation = data['dropoffLocation'] ?? '';
                  final departureTime = data['departureTime'] as Timestamp?;
                  final availableSeats = data['availableSeats'] ?? 0;
                  final costPerPerson = data['costPerPerson'] ?? 0.0;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
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
                                radius: 24,
                                backgroundColor: Colors.green.withOpacity(0.1),
                                child: Text(
                                  driverName.isNotEmpty ? driverName[0].toUpperCase() : '?',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      driverName,
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: primaryColor,
                                      ),
                                    ),
                                    Text(
                                      driverEmail,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Content
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoSection(
                                title: 'Ride Details',
                                icon: Icons.directions_car,
                                children: [
                                  _buildInfoRow('Vehicle', vehicleDetails),
                                  _buildInfoRow('Pickup', pickupLocation),
                                  _buildInfoRow('Dropoff', dropoffLocation),
                                  _buildInfoRow('Departure', departureTime != null 
                                      ? _formatTimestamp(departureTime)
                                      : 'Not specified'),
                                  _buildInfoRow('Available Seats', availableSeats.toString()),
                                  _buildInfoRow('Cost per Person', 'RM ${costPerPerson.toStringAsFixed(2)}'),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.email, size: 16),
                                      label: const Text('Contact Driver'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: accentColor,
                                        side: BorderSide(color: accentColor),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: () => _contactDriver(driverEmail),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.info_outline, size: 16),
                                      label: const Text('View Details'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.blue,
                                        side: BorderSide(color: Colors.blue),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: () => _showRideOfferDetails(data, doc.id),
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

  void _contactDriver(String? driverEmail) {
    if (driverEmail?.isNotEmpty == true) {
      final mailtoUri = Uri(
        scheme: 'mailto',
        path: driverEmail,
        query: 'subject=Ride Offer Inquiry from HikeFue',
      );
      launchUrl(mailtoUri);
    }
  }

  void _showRideOfferDetails(Map<String, dynamic> data, String offerId) {
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

  Widget _buildCarpoolMapSection() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.map, color: accentColor, size: 28),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Carpool Routes Map',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: primaryColor,
                      ),
                    ),
                    Text(
                      'Visual overview of all pickup points and routes',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Map container
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('driverOffers')
                    .where('eventId', isEqualTo: widget.eventId)
                    .where('status', isEqualTo: 'active')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: accentColor),
                    );
                  }

                  final offers = snapshot.data!.docs;
                  if (offers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.map_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Active Ride Offers',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Map will show when ride offers are created',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Get event location
                  final eventLocation = eventData['location']?['address'] as String? ?? '';
                  final eventCoordinates = eventData['location']?['coordinates'] as Map<String, dynamic>?;
                  
                  return Column(
                    children: [
                      // Map header with legend
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                          border: Border(
                            bottom: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Row(
                               children: [
                                 Icon(Icons.location_on, color: Colors.red, size: 20),
                                 const SizedBox(width: 8),
                                 Expanded(
                                   child: Text(
                                     'Event Location: $eventLocation',
                                     style: GoogleFonts.poppins(
                                       fontSize: 14,
                                       fontWeight: FontWeight.w600,
                                       color: primaryColor,
                                     ),
                                     overflow: TextOverflow.ellipsis,
                                   ),
                                 ),
                               ],
                             ),
                              const SizedBox(height: 8),
                             Row(
                               children: [
                                 Container(
                                   width: 12,
                                   height: 12,
                                   decoration: BoxDecoration(
                                     color: Colors.blue,
                                     borderRadius: BorderRadius.circular(6),
                                   ),
                                 ),
                                 const SizedBox(width: 4),
                                 Text(
                                   'Pickup Points',
                                   style: GoogleFonts.poppins(
                                     fontSize: 12,
                                     color: Colors.grey[600],
                                   ),
                                 ),
                                 const SizedBox(width: 12),
                                 Container(
                                   width: 12,
                                   height: 12,
                                   decoration: BoxDecoration(
                                     color: Colors.red,
                                     borderRadius: BorderRadius.circular(6),
                                   ),
                                 ),
                                 const SizedBox(width: 4),
                                 Text(
                                   'Event',
                                   style: GoogleFonts.poppins(
                                     fontSize: 12,
                                     color: Colors.grey[600],
                                   ),
                                 ),
                               ],
                             ),
                           ],
                         ),
                      ),
                      
                      // Map content
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                          child: CarpoolMapWidget(
                            eventId: widget.eventId,
                            eventData: eventData,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Summary statistics
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('driverOffers')
                          .where('eventId', isEqualTo: widget.eventId)
                          .where('status', isEqualTo: 'active')
                          .snapshots(),
                      builder: (context, snapshot) {
                        final offerCount = snapshot.data?.docs.length ?? 0;
                        return Column(
                          children: [
                            Text(
                              '$offerCount',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                            Text(
                              'Active Rides',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.blue[600],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('driverOffers')
                          .where('eventId', isEqualTo: widget.eventId)
                          .where('status', isEqualTo: 'active')
                          .snapshots(),
                      builder: (context, snapshot) {
                        int totalPassengers = 0;
                        if (snapshot.hasData) {
                          for (final doc in snapshot.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            final passengers = List<String>.from(data['passengers'] ?? []);
                            totalPassengers += passengers.length;
                          }
                        }
                        return Column(
                          children: [
                            Text(
                              '$totalPassengers',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                            Text(
                              'Total Passengers',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.green[600],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarpoolAssignmentsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('carpools')
          .where('eventId', isEqualTo: widget.eventId)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: accentColor),
            ),
          );
        }
        
        final carpools = snapshot.data!.docs;
        if (carpools.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.directions_car_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No Active Carpools',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No carpools have been created for this event yet',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        // Get all participants for this event
        final participants = eventData['participants'] as Map<String, dynamic>? ?? {};
        final participantList = participants.entries.map((e) {
          final data = e.value as Map<String, dynamic>;
          data['id'] = e.key;
          return data;
        }).toList();

        return Column(
          children: [
            // Header with summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.people, color: Colors.blue, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Carpool Assignment Summary',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                        Text(
                          '${participantList.length} total participants, ${carpools.length} active carpools',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.blue[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                    onPressed: () {
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Carpool assignments table
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: carpools.map<Widget>((carpoolDoc) {
                    final carpoolData = carpoolDoc.data() as Map<String, dynamic>;
                    final driverName = carpoolData['driverName'] ?? 'Unknown Driver';
                    final driverEmail = carpoolData['driverEmail'] ?? '';
                    final vehicleDetails = carpoolData['vehicleDetails'] ?? '';
                    final pickupLocation = carpoolData['pickupLocation'] ?? '';
                    final dropoffLocation = carpoolData['dropoffLocation'] ?? '';
                    final departureTime = carpoolData['departureTime'] as Timestamp?;
                    final availableSeats = carpoolData['availableSeats'] ?? 0;
                    final totalSeats = carpoolData['totalSeats'] ?? 0;
                    final costPerPerson = carpoolData['costPerPerson'] ?? 0.0;
                    final occupiedSeats = totalSeats - availableSeats;
                    
                    return FutureBuilder<QuerySnapshot>(
                      future: carpoolDoc.reference.collection('passengers').get(),
                      builder: (context, passengersSnapshot) {
                        final passengers = passengersSnapshot.data?.docs ?? [];
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 24),
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
                              // Carpool header
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.05),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    topRight: Radius.circular(16),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.green.withOpacity(0.1),
                                      child: Text(
                                        driverName.isNotEmpty ? driverName[0].toUpperCase() : '?',
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Driver: $driverName',
                                            style: GoogleFonts.poppins(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: primaryColor,
                                            ),
                                          ),
                                          Text(
                                            vehicleDetails,
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          Text(
                                            '$pickupLocation → $dropoffLocation',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                          if (departureTime != null)
                                            Text(
                                              'Departure: ${_formatTimestamp(departureTime)}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                                          ),
                                          child: Text(
                                            '$occupiedSeats/$totalSeats seats',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'RM ${costPerPerson.toStringAsFixed(2)}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Passengers list
                              if (passengers.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.check_circle, color: Colors.green, size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Passengers (${passengers.length})',
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.green.withOpacity(0.2)),
                                        ),
                                        child: Column(
                                          children: passengers.map<Widget>((passengerDoc) {
                                            final passengerData = passengerDoc.data() as Map<String, dynamic>;
                                            final name = passengerData['name'] as String? ?? 'Unknown';
                                            final email = passengerData['email'] as String? ?? '';
                                            final numberOfPassengers = passengerData['numberOfPassengers'] as int? ?? 1;
                                            final notes = passengerData['notes'] as String? ?? '';
                                            final joinedAt = passengerData['joinedAt'] as Timestamp?;
                                            
                                            return Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  bottom: BorderSide(
                                                    color: Colors.green.withOpacity(0.1),
                                                    width: 1,
                                                  ),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 16,
                                                    backgroundColor: Colors.green.withOpacity(0.1),
                                                    child: Text(
                                                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.green,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          name,
                                                          style: GoogleFonts.poppins(
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w600,
                                                            color: primaryColor,
                                                          ),
                                                        ),
                                                        Text(
                                                          email,
                                                          style: GoogleFonts.poppins(
                                                            fontSize: 12,
                                                            color: Colors.grey[600],
                                                          ),
                                                        ),
                                                        if (numberOfPassengers > 1)
                                                          Text(
                                                            '$numberOfPassengers passengers',
                                                            style: GoogleFonts.poppins(
                                                              fontSize: 12,
                                                              color: Colors.grey[500],
                                                            ),
                                                          ),
                                                        if (notes.isNotEmpty)
                                                          Text(
                                                            'Notes: $notes',
                                                            style: GoogleFonts.poppins(
                                                              fontSize: 12,
                                                              color: Colors.grey[500],
                                                              fontStyle: FontStyle.italic,
                                                            ),
                                                          ),
                                                        if (joinedAt != null)
                                                          Text(
                                                            'Joined: ${_formatTimestamp(joinedAt)}',
                                                            style: GoogleFonts.poppins(
                                                              fontSize: 10,
                                                              color: Colors.grey[400],
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      'Confirmed',
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.green,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.people_outline,
                                          size: 48,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No passengers yet',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Passengers will appear here once they join this carpool',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: Colors.grey[500],
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: accentColor, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'Not provided',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: value.isNotEmpty ? primaryColor : Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection(DateTime? date, Map<String, dynamic>? schedule, {bool compact = false}) {
    final scheduleControllers = <String, TextEditingController>{};
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    // Initialize controllers for each field
    if (schedule != null) {
      schedule.forEach((key, value) {
        scheduleControllers[key] = TextEditingController(text: value?.toString() ?? '');
      });
    }

    Future<void> saveSchedule() async {
      if (!formKey.currentState!.validate()) return;
      final updatedSchedule = <String, dynamic>{};
      scheduleControllers.forEach((key, controller) {
        updatedSchedule[key] = controller.text;
      });
      isSaving = true;
      try {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId)
            .update({'schedule': updatedSchedule});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Schedule updated successfully!'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update schedule: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        isSaving = false;
        if (mounted) setState(() {});
      }
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Schedule', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: primaryColor)),
              const SizedBox(height: 16),
              if (schedule == null || schedule.isEmpty)
                Text('No schedule available.', style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[600])),
              if (schedule != null && schedule.isNotEmpty)
                ...schedule.keys.map((key) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text('$key:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, color: primaryColor)),
                      ),
                      Expanded(
                        child: TextFormField(
                          controller: scheduleControllers[key],
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                )),
              if (schedule != null && schedule.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: SizedBox(
                    width: 180,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : saveSchedule,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      child: isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save Schedule'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _approveDriverApplication(String applicationId, String driverName, String driverEmail) async {
    try {
      final organizerEmail = eventData['organizer']?['email'] ?? '';
      
      // First, get the driver application data
      final applicationDoc = await FirebaseFirestore.instance
          .collection('driver_applications')
          .doc(applicationId)
          .get();
      
      if (!applicationDoc.exists) {
        throw Exception('Driver application not found');
      }
      
      final applicationData = applicationDoc.data()!;
      final userId = applicationData['userId'] as String?;
      
      if (userId == null) {
        throw Exception('User ID not found in application');
      }
      
      // Update the driver application status
      await FirebaseFirestore.instance.collection('driver_applications').doc(applicationId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': organizerEmail,
      });
      
      // Update the user's profile with driver details
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'isApprovedDriver': true,
        'driverDetails': {
          'licenseNumber': applicationData['licenseNumber'],
          'vehicleDetails': applicationData['vehicleDetails'],
          'vehicleMake': applicationData['vehicleMake'],
          'vehicleModel': applicationData['vehicleModel'],
          'vehicleColor': applicationData['vehicleColor'],
          'vehiclePlate': applicationData['vehiclePlate'],
          'vehicleType': applicationData['vehicleType'],
        },
      }, SetOptions(merge: true));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Driver application approved for $driverName'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving application: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _rejectDriverApplication(String applicationId, String driverName, String driverEmail) async {
    try {
      final organizerEmail = eventData['organizer']?['email'] ?? '';
      await FirebaseFirestore.instance.collection('driver_applications').doc(applicationId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': organizerEmail,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Driver application rejected for $driverName'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting application: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _duplicateEvent() async {
    try {
      setState(() => _loading = true);
      
      // Create a copy of the event data
      final duplicatedEventData = Map<String, dynamic>.from(eventData);
      
      // Remove fields that shouldn't be duplicated
      duplicatedEventData.remove('id');
      duplicatedEventData.remove('createdAt');
      duplicatedEventData.remove('participants');
      duplicatedEventData.remove('carpools');
      
      // Update the name to indicate it's a copy
      final originalName = duplicatedEventData['name'] as String? ?? 'Event';
      duplicatedEventData['name'] = '$originalName (Copy)';
      
      // Set new creation timestamp
      duplicatedEventData['createdAt'] = FieldValue.serverTimestamp();
      duplicatedEventData['status'] = 'pending';
      
      // Add to Firestore
      final docRef = await FirebaseFirestore.instance.collection('events').add(duplicatedEventData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Event duplicated successfully! New event ID: ${docRef.id}'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate to the new event's manage page
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => OrganizerManageEventPage(
              eventId: docRef.id,
              eventData: duplicatedEventData,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error duplicating event: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _exportEventData() async {
    try {
      final eventName = eventData['name'] as String? ?? 'Event';
      final participants = eventData['participants'] as Map<String, dynamic>? ?? {};
      final participantList = participants.entries.map((e) {
        final data = e.value as Map<String, dynamic>;
        data['id'] = e.key;
        return data;
      }).toList();

      // Export event details
      final eventEx = excel.Excel.createExcel();
      final eventSheet = eventEx['Event Details'];
      
      // Event information
      eventSheet.appendRow([excel.TextCellValue('Event Information')]);
      eventSheet.appendRow([excel.TextCellValue('Name'), excel.TextCellValue(eventData['name'] ?? '')]);
      eventSheet.appendRow([excel.TextCellValue('Date'), excel.TextCellValue(eventData['date'] != null ? (eventData['date'] as Timestamp).toDate().toString() : '')]);
      eventSheet.appendRow([excel.TextCellValue('Location'), excel.TextCellValue(eventData['location']?['address'] ?? '')]);
      eventSheet.appendRow([excel.TextCellValue('Meeting Point'), excel.TextCellValue(eventData['meetingPoint']?['address'] ?? '')]);
      eventSheet.appendRow([excel.TextCellValue('Description'), excel.TextCellValue(eventData['description'] ?? '')]);
      eventSheet.appendRow([excel.TextCellValue('Status'), excel.TextCellValue(eventData['status'] ?? '')]);
      eventSheet.appendRow([excel.TextCellValue('Max Participants'), excel.TextCellValue(eventData['details']?['maxParticipants']?.toString() ?? '')]);
      eventSheet.appendRow([excel.TextCellValue('Current Participants'), excel.TextCellValue(eventData['details']?['currentParticipants']?.toString() ?? '')]);
      eventSheet.appendRow([excel.TextCellValue('Event Fee'), excel.TextCellValue(eventData['pricing']?['eventFee']?.toString() ?? '')]);

      // Export participants
      final participantsSheet = eventEx['Participants'];
      participantsSheet.appendRow([
        excel.TextCellValue('Name'),
        excel.TextCellValue('Email'),
        excel.TextCellValue('Phone'),
        excel.TextCellValue('Payment Status'),
        excel.TextCellValue('Registered Date'),
        excel.TextCellValue('Role'),
      ]);
      
      for (final participant in participantList) {
        participantsSheet.appendRow([
          excel.TextCellValue(participant['name'] ?? '-'),
          excel.TextCellValue(participant['email'] ?? '-'),
          excel.TextCellValue(participant['phone'] ?? '-'),
          excel.TextCellValue(participant['paymentStatus'] ?? 'pending'),
          excel.TextCellValue(participant['registeredAt'] != null && participant['registeredAt'] is Timestamp
              ? (participant['registeredAt'] as Timestamp).toDate().toString()
              : '-'),
          excel.TextCellValue(participant['role'] ?? 'participant'),
        ]);
      }

      final fileBytes = eventEx.encode();
      final blob = html.Blob([fileBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', '${eventName}_export.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Event data exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting event data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showStatusEditDialog() async {
    String selectedStatus = eventData['status'] ?? 'pending';
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Event Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Status: ${selectedStatus.toUpperCase()}'),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedStatus,
              decoration: InputDecoration(
                labelText: 'New Status',
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'approved', child: Text('Approved')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
              ],
              onChanged: (value) {
                selectedStatus = value ?? selectedStatus;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(selectedStatus),
            child: Text('Update Status'),
          ),
        ],
      ),
    );

    if (result != null && result != eventData['status']) {
      await _updateEventStatus(result);
    }
  }

  Future<void> _updateEventStatus(String newStatus) async {
    try {
      setState(() => _loading = true);
      
      await FirebaseFirestore.instance.collection('events').doc(widget.eventId).update({
        'status': newStatus,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'statusUpdatedBy': FirebaseAuth.instance.currentUser?.uid,
      });

      // Update local data
      eventData['status'] = newStatus;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Event status updated to ${newStatus.toUpperCase()}'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showBulkStatusUpdateDialog() async {
    String selectedStatus = 'paid';
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bulk Update Payment Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Update payment status for ${selectedParticipants.length} selected participant(s)'),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedStatus,
              decoration: InputDecoration(
                labelText: 'New Payment Status',
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: 'paid', child: Text('Paid')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'failed', child: Text('Failed')),
                DropdownMenuItem(value: 'refunded', child: Text('Refunded')),
              ],
              onChanged: (value) {
                selectedStatus = value ?? selectedStatus;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(selectedStatus),
            child: Text('Update'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _bulkUpdatePaymentStatus(result);
    }
  }

  Future<void> _bulkUpdatePaymentStatus(String newStatus) async {
    try {
      setState(() => _loading = true);
      
      final batch = FirebaseFirestore.instance.batch();
      final eventRef = FirebaseFirestore.instance.collection('events').doc(widget.eventId);
      
      for (final participantId in selectedParticipants) {
        batch.update(eventRef, {
          'participants.$participantId.paymentStatus': newStatus,
          'participants.$participantId.paymentDetails.paid': newStatus == 'paid',
          'participants.$participantId.paymentDetails.updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated payment status for ${selectedParticipants.length} participant(s)'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          selectedParticipants.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating payment status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showBulkRemoveDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Participants'),
        content: Text('Are you sure you want to remove ${selectedParticipants.length} selected participant(s) from this event? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Remove'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _bulkRemoveParticipants();
    }
  }

  Future<void> _bulkRemoveParticipants() async {
    try {
      setState(() => _loading = true);
      
      final batch = FirebaseFirestore.instance.batch();
      final eventRef = FirebaseFirestore.instance.collection('events').doc(widget.eventId);
      
      for (final participantId in selectedParticipants) {
        batch.update(eventRef, {
          'participants.$participantId': FieldValue.delete(),
        });
      }
      
      // Update current participants count
      final currentCount = (eventData['details']?['currentParticipants'] ?? 0) - selectedParticipants.length;
      batch.update(eventRef, {
        'details.currentParticipants': currentCount,
      });
      
      await batch.commit();
      
      // Update local data
      final participants = Map<String, dynamic>.from(eventData['participants'] ?? {});
      for (final participantId in selectedParticipants) {
        participants.remove(participantId);
      }
      eventData['participants'] = participants;
      eventData['details'] = {...eventData['details'] ?? {}, 'currentParticipants': currentCount};
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed ${selectedParticipants.length} participant(s) from the event'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          selectedParticipants.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing participants: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showDeleteEventDialog() async {
    try {
      print('Delete button pressed for event: ${widget.eventId}');
      final eventName = eventData['name'] as String? ?? 'Unnamed Event';
      print('Event name: $eventName');
      
      // First, show a simple test dialog to see if dialogs work at all
      final testResult = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Test Dialog'),
          content: Text('Testing if dialogs work. Event: $eventName'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Continue to Delete'),
            ),
          ],
        ),
      );
      
      if (testResult != true) {
        print('Test dialog cancelled');
        return;
      }
      
      // Now show the actual delete dialog
      final result = await showDialog(
        context: context,
        builder: (context) => EventDeletionDialog(
          eventId: widget.eventId,
          eventName: eventName,
        ),
      );

      print('Dialog result: $result');
      if (result == true) {
        // Event was deleted successfully, navigate back
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else if (result != null && result is Map && result['success'] == true && result['cancelled'] == true) {
        // Event was cancelled, refresh event data or show feedback
        if (mounted) {
          setState(() {
            eventData['status'] = 'cancelled';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Event has been cancelled.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('Error in _showDeleteEventDialog: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening delete dialog: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Utility methods restored after quick actions removal
  String _formatDate(dynamic date) {
    if (date is Timestamp) {
      return _formatTimestamp(date);
    } else if (date is DateTime) {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
    return 'Invalid date';
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${difference.inDays} days ago';
    }
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

  Widget _buildPaymentStatusChip(Map<String, dynamic>? paymentDetails, String? paymentStatus) {
    // Debug info
    print('Payment status chip: paymentDetails=$paymentDetails, paymentStatus=$paymentStatus');
    
    final paid = DataUtils.safeBool(paymentDetails?['paid']) || 
                  paymentStatus == 'paid' || 
                  paymentStatus == 'completed';
    
    // Determine the display status
    String status;
    if (paid) {
      status = 'Paid';
    } else if (paymentStatus == 'failed' || paymentStatus == 'cancelled') {
      status = paymentStatus!;
    } else {
      status = 'Pending';
    }
    
    Color color;
    switch (status.toLowerCase()) {
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
        status.toUpperCase(),
        style: GoogleFonts.poppins(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
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

  Widget _buildEventDetailsCard() {
    return _buildModernCard(
      title: 'Event Details',
      icon: Icons.event,
      child: Column(
        children: [
          _buildDetailRow('Description', eventData['description'] ?? 'No description provided'),
          _buildDetailRow('Difficulty', eventData['details']?['difficulty'] ?? 'Not specified'),
          _buildDetailRow('Distance', '${eventData['details']?['distance'] ?? 0} km'),
          _buildDetailRow('Duration', '${eventData['details']?['duration'] ?? 0} hours'),
          _buildDetailRow('Meeting Point', eventData['meetingPoint']?['address'] ?? 'TBD'),
          _buildDetailRow('Event Fee', eventData['pricing']?['eventFee'] != null && eventData['pricing']['eventFee'] > 0 
              ? 'RM${eventData['pricing']['eventFee'].toStringAsFixed(2)}' 
              : 'Free'),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return _buildModernCard(
      title: 'Quick Actions',
      icon: Icons.flash_on,
      child: Column(
        children: [
          _buildActionButton(
            'Edit Event Details',
            Icons.edit,
            Colors.blue,
            () => _editEventDetails(),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            'Send Bulk Email',
            Icons.email,
            accentColor,
            () => _sendBulkEmail(),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            'Export Participants',
            Icons.download,
            Colors.green,
            () => _exportParticipantsToExcel(eventData['name'] ?? 'event', []),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            'Delete Event',
            Icons.delete,
            Colors.red,
            () => _showDeleteEventDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildEventStatusCard() {
    return _buildModernCard(
      title: 'Event Status',
      icon: Icons.info,
      child: ProfessionalEventStatusWidget(
        eventId: widget.eventId,
        eventName: eventData['name'] ?? 'Event',
        organizerId: eventData['organizerId'] ?? '',
        organizerName: eventData['organizerName'] ?? 'Organizer',
        isOrganizer: true,
        eventData: eventData,
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    return _buildModernCard(
      title: 'Recent Activity',
      icon: Icons.history,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId)
            .collection('activity_log')
            .orderBy('timestamp', descending: true)
            .limit(5)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final activities = snapshot.data!.docs;
          
          if (activities.isEmpty) {
            return _buildEmptyState('No recent activity', Icons.history);
          }
          
          return Column(
            children: activities.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _buildActivityItem(
                data['action'] ?? 'Unknown action',
                data['description'] ?? '',
                (data['timestamp'] as Timestamp?)?.toDate(),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildActivityItem(String action, String description, DateTime? timestamp) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (description.isNotEmpty)
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                if (timestamp != null)
                  Text(
                    _formatTimestamp(Timestamp.fromDate(timestamp)),
                    style: GoogleFonts.poppins(
                      color: Colors.grey[500],
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon, [String? subtitle]) {
    return Container(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModernCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? action,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
                if (action != null) action,
              ],
            ),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab(List<Map<String, dynamic>> participantList, int paidCount, int unpaidCount) {
    return Column(
      children: [
        // Revenue Analytics
        Row(
          children: [
            Expanded(
              child: _buildModernCard(
                title: 'Revenue Analytics',
                icon: Icons.monetization_on,
                child: _buildRevenueChart(paidCount, unpaidCount),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildModernCard(
                title: 'Participation Analytics',
                icon: Icons.people,
                child: _buildParticipationChart(participantList),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Detailed Analytics
        _buildModernCard(
          title: 'Detailed Event Analytics',
          icon: Icons.analytics,
          child: _buildDetailedAnalytics(participantList, paidCount, unpaidCount),
        ),
      ],
    );
  }

  Widget _buildRevenueChart(int paidCount, int unpaidCount) {
    return Container(
      height: 200,
      child: const Center(child: Text('Revenue Chart')),
    );
  }

  Widget _buildParticipationChart(List<Map<String, dynamic>> participantList) {
    return Container(
      height: 200,
      child: const Center(child: Text('Participation Chart')),
    );
  }

  Widget _buildDetailedAnalytics(List<Map<String, dynamic>> participantList, int paidCount, int unpaidCount) {
    return Container(
      height: 300,
      child: const Center(child: Text('Detailed Analytics')),
    );
  }

  void _showEventSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings feature coming soon!')),
    );
  }

  void _editEventDetails() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit feature coming soon!')),
    );
  }

  void _sendBulkEmail() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bulk email feature coming soon!')),
    );
  }

  double _calculateRevenue() {
    final participants = eventData['participants'] as Map<String, dynamic>? ?? {};
    final eventFee = (eventData['pricing']?['eventFee'] as num?)?.toDouble() ?? 0.0;
    double total = 0.0;
    
    print('Event fee: $eventFee');
    print('Participants count: ${participants.length}');
    
    participants.forEach((key, value) {
      final participant = value as Map<String, dynamic>;
      final paymentDetails = participant['paymentDetails'] as Map<String, dynamic>? ?? {};
      final paymentStatus = participant['paymentStatus'] as String? ?? '';
      
      // Check if payment is marked as paid - safely handle mixed boolean/string types
      final isPaid = DataUtils.safeBool(paymentDetails['paid']) || 
                     paymentStatus == 'paid' ||
                     paymentStatus == 'completed';
      
      print('Participant $key: isPaid=$isPaid, paymentStatus=$paymentStatus, paymentDetails=$paymentDetails');
      
      if (isPaid) {
        // Try different amount sources
        final amount = (paymentDetails['amount'] as num?)?.toDouble() ?? eventFee;
        total += amount;
        print('Adding payment: $amount for participant $key, total now: $total');
      }
    });
    
    print('Final calculated revenue: $total');
    return total;
  }
}

class _BarChartPainter extends CustomPainter {
  final int paid;
  final int unpaid;
  _BarChartPainter(this.paid, this.unpaid);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.blue;
    final paidHeight = size.height * (paid.toDouble() / (paid + unpaid + 1).toDouble());
    final unpaidHeight = size.height * (unpaid.toDouble() / (paid + unpaid + 1).toDouble());
    canvas.drawRect(Rect.fromLTWH(40, size.height - paidHeight, 40, paidHeight), paint..color = Colors.green);
    canvas.drawRect(Rect.fromLTWH(120, size.height - unpaidHeight, 40, unpaidHeight), paint..color = Colors.red);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(text: 'Paid', style: TextStyle(color: Colors.green, fontSize: 14));
    textPainter.layout();
    textPainter.paint(canvas, Offset(40, size.height - paidHeight - 20));
    textPainter.text = TextSpan(text: 'Unpaid', style: TextStyle(color: Colors.red, fontSize: 14));
    textPainter.layout();
    textPainter.paint(canvas, Offset(120, size.height - unpaidHeight - 20));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PieChartPainter extends CustomPainter {
  final int paid;
  final int unpaid;
  _PieChartPainter(this.paid, this.unpaid);
  @override
  void paint(Canvas canvas, Size size) {
    final total = paid + unpaid;
    final paidAngle = (total == 0) ? 0.0 : ((paid / total) * 3.14159 * 2).toDouble();
    final unpaidAngle = (total == 0) ? 0.0 : ((unpaid / total) * 3.14159 * 2).toDouble();
    final paint = Paint()..style = PaintingStyle.fill;
    paint.color = Colors.green;
    canvas.drawArc(Rect.fromLTWH(0, 0, size.width.toDouble(), size.height.toDouble()), 0, paidAngle, true, paint);
    paint.color = Colors.red;
    canvas.drawArc(Rect.fromLTWH(0, 0, size.width.toDouble(), size.height.toDouble()), paidAngle, unpaidAngle, true, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 