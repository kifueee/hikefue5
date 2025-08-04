import 'package:flutter/material.dart';
import '../services/event_status_service.dart';
import '../screens/event_rating_page.dart';
import '../screens/organizer_profile_page.dart';
import 'qr_attendance_widget.dart';

class ProfessionalEventStatusWidget extends StatefulWidget {
  final String eventId;
  final String eventName;
  final String organizerId;
  final String organizerName;
  final bool isOrganizer;
  final Map<String, dynamic>? eventData;

  const ProfessionalEventStatusWidget({
    Key? key,
    required this.eventId,
    required this.eventName,
    required this.organizerId,
    required this.organizerName,
    required this.isOrganizer,
    this.eventData,
  }) : super(key: key);

  @override
  State<ProfessionalEventStatusWidget> createState() => _ProfessionalEventStatusWidgetState();
}

class _ProfessionalEventStatusWidgetState extends State<ProfessionalEventStatusWidget> {
  EventStatus _currentStatus = EventStatus.draft;
  bool _isLoading = true;
  Map<String, dynamic> _attendanceStats = {};

  @override
  void initState() {
    super.initState();
    _loadEventStatus();
  }

  Future<void> _loadEventStatus() async {
    try {
      setState(() => _isLoading = true);
      
      _currentStatus = await EventStatusService.getEventStatus(widget.eventId);
      _attendanceStats = await EventStatusService.getAttendanceStats(widget.eventId);
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Column(
      children: [
        _buildStatusCard(),
        const SizedBox(height: 16),
        if (widget.isOrganizer) ...[
          _buildOrganizerControls(),
          const SizedBox(height: 16),
        ],
        if (_shouldShowQRCode()) _buildQRSection(),
        if (_shouldShowRatingPrompt()) _buildRatingSection(),
        if (!widget.isOrganizer) _buildOrganizerProfileSection(),
      ],
    );
  }

  Widget _buildStatusCard() {
    final statusInfo = EventStatusService.getStatusDisplayInfo(_currentStatus);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusInfo['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusInfo['icon'],
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusInfo['title'],
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: statusInfo['color'],
                        ),
                      ),
                      Text(
                        statusInfo['description'],
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_attendanceStats.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildAttendanceStats(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceStats() {
    final total = _attendanceStats['total'] ?? 0;
    final checkedIn = _attendanceStats['checkedIn'] ?? 0;
    final rate = _attendanceStats['attendanceRate'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total', total.toString(), Icons.group),
          _buildStatItem('Checked In', checkedIn.toString(), Icons.check_circle),
          _buildStatItem('Rate', '$rate%', Icons.trending_up),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.green[700], size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildOrganizerControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Event Management',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _getAvailableActions(),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _getAvailableActions() {
    final actions = <Widget>[];

    switch (_currentStatus) {
      case EventStatus.draft:
        actions.add(_buildActionButton(
          'Publish Event',
          Icons.publish,
          Colors.blue,
          () => _updateStatus(EventStatus.published),
        ));
        break;
      
      case EventStatus.published:
        actions.add(_buildActionButton(
          'Start Event',
          Icons.play_arrow,
          Colors.orange,
          () => _updateStatus(EventStatus.started),
        ));
        break;
      
      case EventStatus.started:
        actions.add(_buildActionButton(
          'Mark Ongoing',
          Icons.directions_run,
          Colors.green,
          () => _updateStatus(EventStatus.ongoing),
        ));
        break;
      
      case EventStatus.ongoing:
        actions.add(_buildActionButton(
          'End Event',
          Icons.stop,
          Colors.purple,
          () => _updateStatus(EventStatus.ended),
        ));
        break;
      
      case EventStatus.ended:
        actions.add(_buildActionButton(
          'View Analytics',
          Icons.analytics,
          Colors.grey,
          () => _showAnalytics(),
        ));
        break;
    }

    return actions;
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildQRSection() {
    return QRAttendanceWidget(
      eventId: widget.eventId,
      isOrganizer: widget.isOrganizer,
    );
  }

  Widget _buildRatingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.star_rate,
              size: 48,
              color: Colors.amber,
            ),
            const SizedBox(height: 16),
            const Text(
              'How was your experience?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your feedback helps improve future events',
              style: TextStyle(
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showRatingPage,
              icon: const Icon(Icons.rate_review),
              label: const Text('Rate Event'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizerProfileSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green[100],
                  child: Text(
                    widget.organizerName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.organizerName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Event Organizer',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _showOrganizerProfile,
                  child: const Text('View Profile'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowQRCode() {
    return _currentStatus == EventStatus.started || _currentStatus == EventStatus.ongoing;
  }

  bool _shouldShowRatingPrompt() {
    return !widget.isOrganizer && _currentStatus == EventStatus.ended;
  }

  Future<void> _updateStatus(EventStatus newStatus) async {
    try {
      await EventStatusService.updateEventStatus(widget.eventId, newStatus);
      await _loadEventStatus();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Event status updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRatingPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventRatingPage(
          eventId: widget.eventId,
          eventName: widget.eventName,
          organizerName: widget.organizerName,
        ),
      ),
    );
  }

  void _showOrganizerProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OrganizerProfilePage(
          organizerId: widget.organizerId,
          organizerName: widget.organizerName,
        ),
      ),
    );
  }

  void _showAnalytics() {
    // TODO: Navigate to analytics page
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Analytics coming soon!')),
    );
  }
}