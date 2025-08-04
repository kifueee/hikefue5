import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:hikefue5/services/payment_service.dart';
import 'package:hikefue5/screens/toyyibpay_payment_page.dart';

class EventRegistrationPage extends StatefulWidget {
  final Map<String, dynamic> event;
  final String eventId;

  const EventRegistrationPage({
    super.key,
    required this.event,
    required this.eventId,
  });

  @override
  State<EventRegistrationPage> createState() => _EventRegistrationPageState();
}

class _EventRegistrationPageState extends State<EventRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  bool _isLoading = false;

  // For multiple participants
  final List<Map<String, TextEditingController>> _additionalParticipants = [];

  // Theme colors
  static const Color primaryColor = Color(0xFF004A4D);
  static const Color accentColor = Color(0xFF94BC45);
  static const Color darkBackgroundColor = Color(0xFF231F20);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    for (var p in _additionalParticipants) {
      p['name']?.dispose();
      p['email']?.dispose();
      p['phone']?.dispose();
      p['emergencyName']?.dispose();
      p['emergencyPhone']?.dispose();
    }
    super.dispose();
  }

  Future<void> _prefillMyInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('participants').doc(user.uid).get();
    final data = doc.data();
    if (data != null) {
      setState(() {
        _nameController.text = data['name'] ?? '';
        _emailController.text = data['email'] ?? '';
        _phoneController.text = data['phone'] ?? data['phoneNumber'] ?? '';
      });
    }
  }

  void _addParticipant() {
    setState(() {
      _additionalParticipants.add({
        'name': TextEditingController(),
        'email': TextEditingController(),
        'phone': TextEditingController(),
        'emergencyName': TextEditingController(),
        'emergencyPhone': TextEditingController(),
      });
    });
  }

  void _removeParticipant(int index) {
    setState(() {
      _additionalParticipants[index]['name']?.dispose();
      _additionalParticipants[index]['email']?.dispose();
      _additionalParticipants[index]['phone']?.dispose();
      _additionalParticipants[index]['emergencyName']?.dispose();
      _additionalParticipants[index]['emergencyPhone']?.dispose();
      _additionalParticipants.removeAt(index);
    });
  }

  Future<void> _registerForEvent() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('You must be logged in to register for an event');
      }
      final eventDoc = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .get();
      if (!eventDoc.exists) {
        throw Exception('Event not found');
      }
      final eventData = eventDoc.data() as Map<String, dynamic>;
      final participants = eventData['participants'] as Map<String, dynamic>? ?? {};
      final details = eventData['details'] as Map<String, dynamic>? ?? {};
      final maxParticipants = (details['maxParticipants'] as num?)?.toInt() ?? 0;
      // Count all registered participants
      final registeredParticipants = participants.entries.where((entry) {
        final status = entry.value['status'] as String?;
        return status == 'registered';
      }).length;
      // Check if event is full
      int totalToRegister = 1 + _additionalParticipants.length;
      if (registeredParticipants + totalToRegister > maxParticipants) {
        throw Exception('Not enough slots for all participants.');
      }
      // Check if user is already registered
      final existingParticipant = participants[currentUser.uid] as Map<String, dynamic>?;
      if (existingParticipant != null) {
        final status = existingParticipant['status'] as String?;
        if (status == 'registered' || status == 'pending_payment' || status == 'completed') {
          throw Exception('You are already registered for this event');
        }
      }
      // Main participant data
      final participantData = {
        'name': _nameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'emergencyContactName': _emergencyNameController.text,
        'emergencyContactPhone': _emergencyPhoneController.text,
        'status': 'pending_payment',
        'registeredAt': FieldValue.serverTimestamp(),
        'userId': currentUser.uid,
        'addedBy': currentUser.uid,
      };
      // Add main participant
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .update({
        'participants.${currentUser.uid}': participantData,
      });
      // Add additional participants
      for (int i = 0; i < _additionalParticipants.length; i++) {
        final p = _additionalParticipants[i];
        final id = '${currentUser.uid}_extra_$i';
        final data = {
          'name': p['name']!.text,
          'email': p['email']!.text,
          'phone': p['phone']!.text,
          'emergencyContactName': p['emergencyName']!.text,
          'emergencyContactPhone': p['emergencyPhone']!.text,
          'status': 'pending_payment',
          'registeredAt': FieldValue.serverTimestamp(),
          'userId': id,
          'addedBy': currentUser.uid,
        };
        await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId)
            .update({
          'participants.$id': data,
        });
      }
      // Payment for all participants (main user + additional participants)
      final pricing = eventData['pricing'] as Map<String, dynamic>?;
      print('Event Pricing: $pricing');
      if (pricing != null && pricing['eventFee'] != null) {
        final baseAmount = (pricing['eventFee'] as num).toDouble();
        print('Base Amount: RM $baseAmount');
        if (baseAmount > 0) {
          // Calculate total amount for all participants
          final totalParticipants = 1 + _additionalParticipants.length;
          final totalAmount = baseAmount * totalParticipants;
          print('Total Amount: RM $totalAmount');
          
          // Ensure minimum amount of RM1.00
          if (totalAmount < 1.0) {
            throw Exception('Payment amount must be at least RM1.00. Current amount: RM${totalAmount.toStringAsFixed(2)}');
          }
          
          // Navigate to ToyyibPay payment page
          if (mounted) {
            final paymentResult = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ToyyibPayPaymentPage(
                  eventId: widget.eventId,
                  eventName: widget.event['name'],
                  amount: totalAmount,
                  participantCount: totalParticipants,
                ),
              ),
            );
            
            // If payment was successful, complete the registration and navigate to events
            if (paymentResult == true) {
              // Payment was successful, show success message and navigate to events
              if (mounted) {
                final totalParticipants = 1 + _additionalParticipants.length;
                final participantText = totalParticipants == 1 ? 'participant' : 'participants';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Successfully registered $totalParticipants $participantText for the event! Payment completed.',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
                
                // Navigate to events page with back button
                Navigator.of(context).pushReplacementNamed('/my_events');
              }
              return;
            } else {
              // Payment was cancelled or failed, rollback registration
              throw Exception('Payment was not completed. Registration cancelled.');
            }
          }
        }
      }
      // If no payment is required, show success message
      if (mounted) {
        final totalParticipants = 1 + _additionalParticipants.length;
        final participantText = totalParticipants == 1 ? 'participant' : 'participants';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully registered $totalParticipants $participantText for the event!',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: accentColor,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString()}',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          color: Colors.white.withOpacity(0.7),
          fontSize: 14,
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: accentColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        prefixIcon: Icon(icon, color: accentColor),
        errorStyle: GoogleFonts.poppins(color: Colors.red.shade300),
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    final participants = widget.event['participants'] as Map<String, dynamic>? ?? {};
    final registeredParticipants = participants.entries.where((entry) {
      final status = entry.value['status'] as String?;
      return status == 'registered' || status == 'pending_payment' || status == 'completed';
    }).length;
    final details = widget.event['details'] as Map<String, dynamic>? ?? {};
    final maxParticipants = (details['maxParticipants'] as num?)?.toInt() ?? 0;

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/trees_background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Blur and overlay
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(
              color: primaryColor.withOpacity(0.7),
            ),
          ),
          // Content
          SafeArea(
            child: CustomScrollView(
              slivers: [
                // App Bar
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  title: Text(
                    'Event Registration',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  centerTitle: true,
                  floating: true,
                  snap: true,
                ),
                // Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Event Info Card
                        _buildGlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: accentColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.event,
                                        color: accentColor,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        widget.event['name'],
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    const Icon(Icons.people, color: accentColor, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Participants: $registeredParticipants/$maxParticipants',
                                      style: GoogleFonts.poppins(
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
                        ),
                        const SizedBox(height: 24),

                        // Registration Form
                        _buildGlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Personal Information Section
                                  Text(
                                    'Personal Information',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // Name Field
                                  _buildTextField(
                                    controller: _nameController,
                                    label: 'Full Name',
                                    icon: Icons.person,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your name';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Email Field
                                  _buildTextField(
                                    controller: _emailController,
                                    label: 'Email',
                                    icon: Icons.email,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your email';
                                      }
                                      if (!value.contains('@')) {
                                        return 'Please enter a valid email';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Phone Field
                                  _buildTextField(
                                    controller: _phoneController,
                                    label: 'Phone Number',
                                    icon: Icons.phone,
                                    keyboardType: TextInputType.phone,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your phone number';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 32),

                                  // Prefill Button
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: _prefillMyInfo,
                                      icon: const Icon(Icons.auto_fix_high, color: accentColor),
                                      label: Text('Prefill My Info', style: GoogleFonts.poppins(color: accentColor)),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Emergency Contact Section
                                  Text(
                                    'Emergency Contact',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Emergency Contact Name
                                  _buildTextField(
                                    controller: _emergencyNameController,
                                    label: 'Emergency Contact Name',
                                    icon: Icons.person_outline,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter emergency contact name';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Emergency Contact Phone
                                  _buildTextField(
                                    controller: _emergencyPhoneController,
                                    label: 'Emergency Contact Phone',
                                    icon: Icons.phone_outlined,
                                    keyboardType: TextInputType.phone,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter emergency contact phone';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 32),

                                  // Additional Participants Section
                                  Text(
                                    'Add Family/Friends',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ..._additionalParticipants.asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final p = entry.value;
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Divider(color: Colors.white24),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Participant ${idx + 2}', style: GoogleFonts.poppins(color: accentColor, fontWeight: FontWeight.bold)),
                                            IconButton(
                                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                                              onPressed: () => _removeParticipant(idx),
                                              tooltip: 'Remove',
                                            ),
                                          ],
                                        ),
                                        _buildTextField(
                                          controller: p['name']!,
                                          label: 'Full Name',
                                          icon: Icons.person,
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Please enter name';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                        _buildTextField(
                                          controller: p['email']!,
                                          label: 'Email',
                                          icon: Icons.email,
                                          keyboardType: TextInputType.emailAddress,
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Please enter email';
                                            }
                                            if (!value.contains('@')) {
                                              return 'Please enter a valid email';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                        _buildTextField(
                                          controller: p['phone']!,
                                          label: 'Phone Number',
                                          icon: Icons.phone,
                                          keyboardType: TextInputType.phone,
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Please enter phone number';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                    );
                                  }),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: _addParticipant,
                                      icon: const Icon(Icons.group_add, color: accentColor),
                                      label: Text('Add Participant', style: GoogleFonts.poppins(color: accentColor)),
                                    ),
                                  ),
                                  const SizedBox(height: 32),

                                  // Register Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _registerForEvent,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: accentColor,
                                        foregroundColor: darkBackgroundColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        elevation: 0,
                                        shadowColor: Colors.transparent,
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(darkBackgroundColor),
                                              ),
                                            )
                                          : Text(
                                              'Register for Event',
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: darkBackgroundColor,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 