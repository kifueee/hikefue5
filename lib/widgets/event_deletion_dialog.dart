import 'package:flutter/material.dart';
import 'package:hikefue5/services/event_deletion_service.dart';

class EventDeletionDialog extends StatefulWidget {
  final String eventId;
  final String eventName;

  const EventDeletionDialog({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<EventDeletionDialog> createState() => _EventDeletionDialogState();
}

class _EventDeletionDialogState extends State<EventDeletionDialog> {
  bool _isLoading = false;
  Map<String, dynamic>? _deletionInfo;

  @override
  void initState() {
    super.initState();
    _checkDeletionStatus();
  }

  Future<void> _checkDeletionStatus() async {
    setState(() => _isLoading = true);
    
    try {
      final result = await EventDeletionService.canDeleteEvent(widget.eventId);
      setState(() {
        _deletionInfo = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _deletionInfo = {
          'canDelete': false,
          'reason': 'Error checking event: $e',
        };
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteEvent() async {
    setState(() => _isLoading = true);
    
    try {
      print('Starting event deletion for event: ${widget.eventId}');
      final result = await EventDeletionService.deleteEvent(widget.eventId);
      print('Deletion result: $result');
      
      if (mounted) {
        if (result['success'] == true) {
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete event: ${result['message']}'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('Exception during event deletion: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting event: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelEvent() async {
    setState(() => _isLoading = true);
    
    try {
      final result = await EventDeletionService.cancelEvent(widget.eventId);
      
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling event: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange),
          SizedBox(width: 8),
          Text('Delete Event'),
        ],
      ),
      content: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _deletionInfo == null
              ? Text('Loading...')
              : _buildContent(),
      actions: _isLoading
          ? []
          : _deletionInfo == null
              ? []
              : _buildActions(),
    );
  }

  Widget _buildContent() {
    final canDelete = _deletionInfo!['canDelete'] ?? false;
    final reason = _deletionInfo!['reason'];
    final requiresRefund = _deletionInfo!['requiresRefund'] ?? false;
    final participantCount = _deletionInfo!['participantCount'] ?? 0;
    final paidCount = _deletionInfo!['paidCount'] ?? 0;

    if (!canDelete) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cannot delete "${widget.eventName}"',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(reason ?? 'Unknown error'),
          SizedBox(height: 16),
          Text(
            'Consider cancelling the event instead, which will notify participants but keep the event record.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Are you sure you want to delete "${widget.eventName}"?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16),
        if (participantCount > 0) ...[
          Text('⚠️ This event has $participantCount participant(s).'),
          SizedBox(height: 8),
        ],
        if (requiresRefund) ...[
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.payment, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Refunds Required',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  '$paidCount participant(s) have paid and will receive automatic refunds.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
        ],
        Text(
          'This action will:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        _buildActionItem('• Send event deletion notification to all participants'),
        _buildActionItem('• Send refund information notification to all participants'),
        _buildActionItem('• Process refunds (if applicable)'),
        _buildActionItem('• Delete carpool arrangements'),
        _buildActionItem('• Remove event from all records'),
        SizedBox(height: 12),
        Text(
          'This action cannot be undone!',
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildActionItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Text(text, style: TextStyle(fontSize: 12)),
    );
  }

  List<Widget> _buildActions() {
    final canDelete = _deletionInfo!['canDelete'] ?? false;

    if (!canDelete) {
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'),
        ),
        ElevatedButton(
          onPressed: _cancelEvent,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: Text('Cancel Event Instead'),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text('Keep Event'),
      ),
      ElevatedButton(
        onPressed: _cancelEvent,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
        child: Text('Cancel Event'),
      ),
      ElevatedButton(
        onPressed: _deleteEvent,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        child: Text('Delete Event'),
      ),
    ];
  }
} 