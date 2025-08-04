import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/event_status_service.dart';

class EventStatusManager extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> eventData;

  const EventStatusManager({
    super.key,
    required this.eventId,
    required this.eventData,
  });

  @override
  State<EventStatusManager> createState() => _EventStatusManagerState();
}

class _EventStatusManagerState extends State<EventStatusManager> {
  bool _isLoading = false;
  EventStatus _currentStatus = EventStatus.draft;
  Map<String, dynamic> _attendanceStats = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentStatus();
    _loadAttendanceStats();
  }

  Future<void> _loadCurrentStatus() async {
    try {
      final status = await EventStatusService.getEventStatus(widget.eventId);
      if (mounted) {
        setState(() {
          _currentStatus = status;
        });
      }
    } catch (e) {
      print('Error loading event status: $e');
    }
  }

  Future<void> _loadAttendanceStats() async {
    try {
      final stats = await EventStatusService.getAttendanceStats(widget.eventId);
      if (mounted) {
        setState(() {
          _attendanceStats = stats;
        });
      }
    } catch (e) {
      print('Error loading attendance stats: $e');
    }
  }

  Future<void> _updateEventStatus(EventStatus newStatus) async {
    try {
      setState(() => _isLoading = true);
      
      await EventStatusService.updateEventStatus(widget.eventId, newStatus);
      
      if (mounted) {
        setState(() {
          _currentStatus = newStatus;
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Event status updated to ${EventStatusService.getStatusDisplayInfo(newStatus)['title']}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating event status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusInfo = EventStatusService.getStatusDisplayInfo(_currentStatus);
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusInfo['color'].withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Header
          Row(
            children: [
              Text(
                statusInfo['icon'],
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Event Status',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      statusInfo['title'],
                      style: TextStyle(
                        color: statusInfo['color'],
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Text(
            statusInfo['description'],
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Attendance Stats
          if (_attendanceStats.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attendance',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total',
                          _attendanceStats['total'].toString(),
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Checked In',
                          _attendanceStats['checkedIn'].toString(),
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Rate',
                          '${_attendanceStats['attendanceRate']}%',
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          
          // Status Actions
          if (_currentStatus == EventStatus.draft) ...[
            _buildActionButton(
              'Publish Event',
              Icons.publish,
              Colors.blue,
              () => _updateEventStatus(EventStatus.published),
            ),
          ] else if (_currentStatus == EventStatus.published) ...[
            _buildActionButton(
              'Start Event',
              Icons.play_arrow,
              Colors.green,
              () async {
                final canStart = await EventStatusService.canStartEvent(widget.eventId);
                if (canStart) {
                  await _updateEventStatus(EventStatus.started);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cannot start event: No participants registered'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
            ),
          ] else if (_currentStatus == EventStatus.started) ...[
            _buildActionButton(
              'Set as Ongoing',
              Icons.settings,
              Colors.orange,
              () => _updateEventStatus(EventStatus.ongoing),
            ),
          ] else if (_currentStatus == EventStatus.ongoing) ...[
            _buildActionButton(
              'End Event',
              Icons.stop,
              Colors.red,
              () => _updateEventStatus(EventStatus.ended),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              'Manage Attendance',
              Icons.people,
              Colors.blue,
              () => _showAttendanceManager(),
            ),
          ] else if (_currentStatus == EventStatus.ended) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Event has ended',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          if (_isLoading) ...[
            const SizedBox(height: 16),
            const Center(
              child: CircularProgressIndicator(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _showAttendanceManager() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceManagerPage(
          eventId: widget.eventId,
          eventData: widget.eventData,
        ),
      ),
    ).then((_) {
      // Refresh attendance stats when returning
      _loadAttendanceStats();
    });
  }
}

class AttendanceManagerPage extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> eventData;

  const AttendanceManagerPage({
    super.key,
    required this.eventId,
    required this.eventData,
  });

  @override
  State<AttendanceManagerPage> createState() => _AttendanceManagerPageState();
}

class _AttendanceManagerPageState extends State<AttendanceManagerPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _participants = [];

  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }

  Future<void> _loadParticipants() async {
    try {
      setState(() => _isLoading = true);
      
      final participants = widget.eventData['participants'] as Map<String, dynamic>? ?? {};
      final participantList = participants.entries.map((e) {
        final data = Map<String, dynamic>.from(e.value as Map);
        data['id'] = e.key;
        return data;
      }).toList();
      
      setState(() {
        _participants = participantList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading participants: $e')),
      );
    }
  }

  Future<void> _toggleAttendance(String participantId) async {
    try {
      await EventStatusService.toggleAttendance(widget.eventId, participantId);
      _loadParticipants(); // Refresh the list
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance updated'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating attendance: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Attendance Manager'),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _participants.length,
              itemBuilder: (context, index) {
                final participant = _participants[index];
                final name = participant['name'] as String? ?? 'Unknown';
                final attendanceStatus = participant['attendanceStatus'] as String? ?? 'not_checked_in';
                final isCheckedIn = attendanceStatus == 'checked_in';
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCheckedIn ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: isCheckedIn ? Colors.green : Colors.grey,
                      child: Icon(
                        isCheckedIn ? Icons.check : Icons.person,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      isCheckedIn ? 'Checked In' : 'Not Checked In',
                      style: TextStyle(
                        color: isCheckedIn ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: ElevatedButton(
                      onPressed: () => _toggleAttendance(participant['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCheckedIn ? Colors.red : Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        isCheckedIn ? 'Check Out' : 'Check In',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
} 