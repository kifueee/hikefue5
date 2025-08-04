import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/carpool_matching_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../carpool_chat_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JoinCarpoolFlowPage extends StatefulWidget {
  final DriverOffer offer;
  final String eventName;
  final String eventLocation;
  final DateTime eventDateTime;

  const JoinCarpoolFlowPage({
    super.key,
    required this.offer,
    required this.eventName,
    required this.eventLocation,
    required this.eventDateTime,
  });

  @override
  State<JoinCarpoolFlowPage> createState() => _JoinCarpoolFlowPageState();
}

class _JoinCarpoolFlowPageState extends State<JoinCarpoolFlowPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;

  // Form data
  int _numberOfPassengers = 1;
  final _notesController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  bool _acceptedTerms = false;
  bool _shareContact = true;
  String _pickupPreference = 'exact'; // 'exact' or 'nearby'
  String _pickupNotes = '';

  // User data
  Map<String, dynamic>? _userData;

  final Color primaryColor = const Color(0xFF004A4D);
  final Color accentColor = const Color(0xFF94BC45);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _phoneController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = AuthService().user;
      if (user != null) {
        final userData = await FirestoreService.getUserDataAuto(user.uid);
        setState(() {
          _userData = userData;
          if (userData != null) {
            _phoneController.text = userData['phone'] ?? '';
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  void _nextStep() {
    if (_currentStep < 4) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _joinCarpool() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final carpoolService = CarpoolMatchingService();
      await carpoolService.acceptDriverOffer(
        widget.offer.id,
        _numberOfPassengers,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      // Store additional passenger details
      await _storePassengerDetails();

      // Navigate to success step
      _nextStep();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _storePassengerDetails() async {
    // Store additional passenger contact and preference details
    // This could be stored in a separate collection for better organization
    final user = AuthService().user;
    if (user != null) {
      await FirestoreService.storePassengerJoinDetails(
        userId: user.uid,
        offerId: widget.offer.id,
        eventId: widget.offer.eventId,
        contactDetails: {
          'phone': _phoneController.text,
          'shareContact': _shareContact,
          'emergencyContact': _emergencyContactController.text,
          'emergencyPhone': _emergencyPhoneController.text,
          'pickupPreference': _pickupPreference,
          'pickupNotes': _pickupNotes,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: Text(
          'Join Carpool',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: List.generate(5, (index) {
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: index < 4 ? 8 : 0),
                    height: 4,
                    decoration: BoxDecoration(
                      color: index <= _currentStep ? accentColor : Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          
          // Content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1RideDetails(),
                _buildStep2ContactInfo(),
                _buildStep3PaymentConfirmation(),
                _buildStep4FinalConfirmation(),
                _buildStep5Success(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1RideDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Ride Details',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please review all details before joining this carpool',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Driver info card
                  _buildInfoCard(
                    title: 'Driver Information',
                    icon: Icons.person,
                    children: [
                      _buildDetailRow('Name', widget.offer.driverName),
                      _buildDetailRow('Vehicle', widget.offer.vehicleDetails),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Route info card
                  _buildInfoCard(
                    title: 'Route Details',
                    icon: Icons.route,
                    children: [
                      _buildDetailRow('From', widget.offer.pickupLocation),
                      _buildDetailRow('To', widget.offer.dropoffLocation),
                      _buildDetailRow('Departure', DateFormat('MMM d, h:mm a').format(widget.offer.departureTime)),
                      if (widget.offer.distanceInKm != null)
                        _buildDetailRow('Distance', '${widget.offer.distanceInKm!.toStringAsFixed(1)} km'),
                      if (widget.offer.durationInMinutes != null)
                        _buildDetailRow('Duration', '${widget.offer.durationInMinutes} min'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Event info card
                  _buildInfoCard(
                    title: 'Event Information',
                    icon: Icons.event,
                    children: [
                      _buildDetailRow('Event', widget.eventName),
                      _buildDetailRow('Location', widget.eventLocation),
                      _buildDetailRow('Date', DateFormat('MMM d, yyyy').format(widget.eventDateTime)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Pricing card
                  _buildInfoCard(
                    title: 'Pricing',
                    icon: Icons.payment,
                    children: [
                      _buildDetailRow('Cost per person', 'RM ${widget.offer.price.toStringAsFixed(2)}'),
                      _buildDetailRow('Available seats', '${widget.offer.availableSeats}'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Passengers selector
                  _buildInfoCard(
                    title: 'Number of Passengers',
                    icon: Icons.group,
                    children: [
                      Row(
                        children: [
                          Text(
                            'I need',
                            style: GoogleFonts.poppins(fontSize: 16),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: accentColor),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<int>(
                              value: _numberOfPassengers,
                              underline: const SizedBox(),
                              items: List.generate(
                                widget.offer.availableSeats,
                                (index) => DropdownMenuItem(
                                  value: index + 1,
                                  child: Text('${index + 1} seat${index + 1 > 1 ? 's' : ''}'),
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _numberOfPassengers = value!;
                                });
                              },
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Total: RM ${(widget.offer.price * _numberOfPassengers).toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Terms and conditions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _acceptedTerms,
                              onChanged: (value) {
                                setState(() {
                                  _acceptedTerms = value!;
                                });
                              },
                              activeColor: accentColor,
                            ),
                            Expanded(
                              child: Text(
                                'I agree to the carpool terms and conditions',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Be ready at pickup location 5 minutes early\n• Respect the driver and other passengers\n• Split costs fairly as agreed\n• Cancel at least 2 hours in advance if needed',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _acceptedTerms ? _nextStep : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Continue',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2ContactInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Information',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share your contact details for coordination',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Contact sharing preference
                  _buildInfoCard(
                    title: 'Contact Sharing',
                    icon: Icons.share,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _shareContact,
                            onChanged: (value) {
                              setState(() {
                                _shareContact = value!;
                              });
                            },
                            activeColor: accentColor,
                          ),
                          Expanded(
                            child: Text(
                              'Share my contact with the driver',
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      if (_shareContact) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _phoneController,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            hintText: '+60 12-345-6789',
                            prefixIcon: const Icon(Icons.phone),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Emergency contact
                  _buildInfoCard(
                    title: 'Emergency Contact',
                    icon: Icons.emergency,
                    children: [
                      TextField(
                        controller: _emergencyContactController,
                        decoration: InputDecoration(
                          labelText: 'Emergency Contact Name',
                          hintText: 'Family member or friend',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _emergencyPhoneController,
                        decoration: InputDecoration(
                          labelText: 'Emergency Contact Phone',
                          hintText: '+60 12-345-6789',
                          prefixIcon: const Icon(Icons.phone),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Pickup preferences
                  _buildInfoCard(
                    title: 'Pickup Preferences',
                    icon: Icons.location_on,
                    children: [
                      Text(
                        'Pickup Location: ${widget.offer.pickupLocation}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Exact location'),
                              value: 'exact',
                              groupValue: _pickupPreference,
                              onChanged: (value) {
                                setState(() {
                                  _pickupPreference = value!;
                                });
                              },
                              activeColor: accentColor,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Nearby area'),
                              value: 'nearby',
                              groupValue: _pickupPreference,
                              onChanged: (value) {
                                setState(() {
                                  _pickupPreference = value!;
                                });
                              },
                              activeColor: accentColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        onChanged: (value) {
                          _pickupNotes = value;
                        },
                        decoration: InputDecoration(
                          labelText: 'Pickup Notes (Optional)',
                          hintText: 'Any specific pickup instructions...',
                          prefixIcon: const Icon(Icons.note),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousStep,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Back',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Continue',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep3PaymentConfirmation() {
    final totalCost = widget.offer.price * _numberOfPassengers;
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Details',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Review payment information and method',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Cost breakdown
                  _buildInfoCard(
                    title: 'Cost Breakdown',
                    icon: Icons.receipt,
                    children: [
                      _buildDetailRow('Cost per person', 'RM ${widget.offer.price.toStringAsFixed(2)}'),
                      _buildDetailRow('Number of passengers', '$_numberOfPassengers'),
                      const Divider(),
                      _buildDetailRow(
                        'Total Cost', 
                        'RM ${totalCost.toStringAsFixed(2)}',
                        isTotal: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Payment method
                  _buildInfoCard(
                    title: 'Payment Method',
                    icon: Icons.payment,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: accentColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.money, color: accentColor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pay Directly to Driver',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Payment will be made directly to the driver during the trip',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Payment terms
                  _buildInfoCard(
                    title: 'Payment Terms',
                    icon: Icons.info,
                    children: [
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
                            Text(
                              'Important Payment Information:',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '• Payment is due at the start of the journey\n'
                              '• Bring exact change if possible\n'
                              '• Cost covers fuel and vehicle expenses\n'
                              '• No refund for no-shows without 2h notice',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousStep,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Back',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Continue',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep4FinalConfirmation() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Final Confirmation',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Review everything before joining the carpool',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Summary card
                  _buildInfoCard(
                    title: 'Trip Summary',
                    icon: Icons.summarize,
                    children: [
                      _buildDetailRow('Driver', widget.offer.driverName),
                      _buildDetailRow('From', widget.offer.pickupLocation),
                      _buildDetailRow('To', widget.offer.dropoffLocation),
                      _buildDetailRow('Departure', DateFormat('MMM d, h:mm a').format(widget.offer.departureTime)),
                      _buildDetailRow('Passengers', '$_numberOfPassengers'),
                      _buildDetailRow('Total Cost', 'RM ${(widget.offer.price * _numberOfPassengers).toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Contact summary
                  if (_shareContact)
                    _buildInfoCard(
                      title: 'Contact Details',
                      icon: Icons.contact_phone,
                      children: [
                        _buildDetailRow('Your Phone', _phoneController.text),
                        if (_emergencyContactController.text.isNotEmpty)
                          _buildDetailRow('Emergency Contact', '${_emergencyContactController.text} (${_emergencyPhoneController.text})'),
                        _buildDetailRow('Pickup Preference', _pickupPreference == 'exact' ? 'Exact location' : 'Nearby area'),
                      ],
                    ),
                  const SizedBox(height: 16),
                  
                  // Special notes
                  if (_notesController.text.isNotEmpty || _pickupNotes.isNotEmpty)
                    _buildInfoCard(
                      title: 'Special Notes',
                      icon: Icons.note,
                      children: [
                        if (_notesController.text.isNotEmpty)
                          _buildDetailRow('General Notes', _notesController.text),
                        if (_pickupNotes.isNotEmpty)
                          _buildDetailRow('Pickup Notes', _pickupNotes),
                      ],
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousStep,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Back',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _joinCarpool,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Submit Request',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep5Success() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          
          // Success animation/icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 60,
            ),
          ),
          
          const SizedBox(height: 24),
          
          Text(
            'Request Submitted!',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 12),
          
          Text(
            'Your request to join ${widget.offer.driverName}\'s carpool has been submitted for approval',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 40),
          
          // Next steps
          _buildInfoCard(
            title: 'Next Steps',
            icon: Icons.checklist,
            children: [
              _buildNextStepItem('1. Driver will review your request'),
              _buildNextStepItem('2. You\'ll receive a notification when approved/declined'),
              _buildNextStepItem('3. If approved, coordinate pickup details with driver'),
              _buildNextStepItem('4. Be ready at pickup location 5 minutes early'),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Contact driver card
          _buildInfoCard(
            title: 'Driver Contact',
            icon: Icons.contact_phone,
            children: [
              _buildDetailRow('Driver', widget.offer.driverName),
              _buildDetailRow('Pickup Time', DateFormat('MMM d, h:mm a').format(widget.offer.departureTime)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _messageDriver(),
                  icon: const Icon(Icons.message),
                  label: const Text('Message Driver'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          
          const Spacer(),
          
          // Action buttons
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Done',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    // Navigate to my carpools
                    Navigator.pop(context, true);
                    // TODO: Navigate to my carpools page
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'View My Carpools',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
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
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: isTotal ? 14 : 13,
                color: isTotal ? Colors.white : Colors.white.withOpacity(0.7),
                fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: isTotal ? 14 : 13,
                color: isTotal ? accentColor : Colors.white,
                fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextStepItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: accentColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _messageDriver() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to message driver')),
        );
        return;
      }

      // Check if a carpool already exists for this driver offer
      final carpoolQuery = await FirebaseFirestore.instance
          .collection('carpools')
          .where('eventId', isEqualTo: widget.offer.eventId)
          .where('driverId', isEqualTo: widget.offer.driverId)
          .where('status', isEqualTo: 'active')
          .get();

      if (carpoolQuery.docs.isNotEmpty) {
        // Carpool exists, navigate to chat
        final carpoolData = carpoolQuery.docs.first.data();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CarpoolChatPage(
              eventId: widget.offer.eventId,
              carpoolId: carpoolQuery.docs.first.id,
              driverEmail: carpoolData['driverEmail'],
            ),
          ),
        );
      } else {
        // No carpool yet, need to create one first or use alternative contact
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Join the ride first to access group chat'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}