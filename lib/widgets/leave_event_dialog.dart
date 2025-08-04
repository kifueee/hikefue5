import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/leave_event_service.dart';

class LeaveEventDialog extends StatefulWidget {
  final String eventId;
  final String eventName;
  final VoidCallback? onEventLeft;

  const LeaveEventDialog({
    Key? key,
    required this.eventId,
    required this.eventName,
    this.onEventLeft,
  }) : super(key: key);

  @override
  State<LeaveEventDialog> createState() => _LeaveEventDialogState();
}

class _LeaveEventDialogState extends State<LeaveEventDialog> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isLoading = false;
  bool _canLeave = false;
  String _leaveStatus = '';
  String _selectedReason = 'Personal reasons';
  final List<String> _reasonOptions = [
    'Personal reasons',
    'Schedule conflict',
    'Emergency',
    'Financial reasons',
    'Health reasons',
    'Change of plans',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _checkLeaveEligibility();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _checkLeaveEligibility() async {
    setState(() => _isLoading = true);
    
    final result = await LeaveEventService.canLeaveEvent(widget.eventId);
    
    setState(() {
      _canLeave = result['canLeave'] ?? false;
      _leaveStatus = result['reason'] ?? result['message'] ?? '';
      _isLoading = false;
    });
  }

  Future<void> _leaveEvent() async {
    setState(() => _isLoading = true);

    final reason = _selectedReason == 'Other' 
        ? _reasonController.text.trim() 
        : _selectedReason;

    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reason for leaving')),
      );
      setState(() => _isLoading = false);
      return;
    }

    final result = await LeaveEventService.leaveEvent(
      eventId: widget.eventId,
      reason: reason,
    );

    setState(() => _isLoading = false);

    if (result['success']) {
      Navigator.of(context).pop();
      
      // Show success dialog with details
      _showSuccessDialog(result);
      
      // Notify parent widget
      widget.onEventLeft?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to leave event'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            Text(
              'Successfully Left Event',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have successfully left "${widget.eventName}".',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
            ),
            // Check if additional participants info is available in actions_taken
            if (result['actions_taken'] != null) ...[
              Builder(
                builder: (context) {
                  bool hasAdditionalParticipants = false;
                  for (final action in result['actions_taken']) {
                    if (action.toString().contains('additional participant')) {
                      hasAdditionalParticipants = true;
                      break;
                    }
                  }
                  
                  if (hasAdditionalParticipants) {
                    return Column(
                      children: [
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blue.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.group, color: Colors.blue, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Note: Additional participants you registered were also removed from the event.',
                                  style: GoogleFonts.poppins(color: Colors.blue, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
            if (result['actions_taken'] != null && result['actions_taken'].isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Actions taken:',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...((result['actions_taken'] as List).map((action) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: Colors.green)),
                    Expanded(
                      child: Text(
                        action.toString(),
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ))),
            ],
            if (result['warnings'] != null && result['warnings'].isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Important notices:',
                style: GoogleFonts.poppins(
                  color: Colors.orange,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...((result['warnings'] as List).map((warning) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('⚠ ', style: TextStyle(color: Colors.orange)),
                    Expanded(
                      child: Text(
                        warning.toString(),
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ))),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: GoogleFonts.poppins(color: const Color(0xFF00D4AA)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.exit_to_app, color: Colors.red, size: 28),
          const SizedBox(width: 12),
          Text(
            'Leave Event',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: _isLoading
          ? const SizedBox(
              height: 100,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D4AA)),
                ),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to leave "${widget.eventName}"?',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  if (!_canLeave) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _leaveStatus,
                              style: GoogleFonts.poppins(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Consequences explanation
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info, color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'What happens when you leave:',
                                style: GoogleFonts.poppins(
                                  color: Colors.orange,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildConsequenceItem('• Your event registration will be cancelled'),
                          _buildConsequenceItem('• Any additional participants you registered will also be removed'),
                          _buildConsequenceItem('• The organizer will be notified'),
                          _buildConsequenceItem('• Any payment made will be refunded (3-5 business days)'),
                          _buildConsequenceItem('• Your carpools will be cancelled and affected participants notified'),
                          _buildConsequenceItem('• You can re-register later if spots are available'),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Reason selection
                    Text(
                      'Reason for leaving:',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedReason,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF2A2A2A),
                          style: GoogleFonts.poppins(color: Colors.white),
                          items: _reasonOptions.map((reason) {
                            return DropdownMenuItem(
                              value: reason,
                              child: Text(reason),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedReason = value!;
                            });
                          },
                        ),
                      ),
                    ),
                    
                    if (_selectedReason == 'Other') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _reasonController,
                        style: GoogleFonts.poppins(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Please specify your reason...',
                          hintStyle: GoogleFonts.poppins(color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFF2A2A2A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF00D4AA)),
                          ),
                        ),
                        maxLines: 3,
                        maxLength: 200,
                      ),
                    ],
                  ],
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
        ),
        if (_canLeave)
          ElevatedButton(
            onPressed: _isLoading ? null : _leaveEvent,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Leave Event',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
          ),
      ],
    );
  }

  Widget _buildConsequenceItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: Colors.white70,
          fontSize: 13,
        ),
      ),
    );
  }
}