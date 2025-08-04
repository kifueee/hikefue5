import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

// Theme colors
const Color primaryColor = Color(0xFF004A4D);
const Color accentColor = Color(0xFF94BC45);
const Color darkBackgroundColor = Color(0xFF1A1A1A);

class OrganizerRegisterPage extends StatefulWidget {
  const OrganizerRegisterPage({super.key});

  @override
  State<OrganizerRegisterPage> createState() => _OrganizerRegisterPageState();
}

class _OrganizerRegisterPageState extends State<OrganizerRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _organizationController = TextEditingController();
  final _companyRegController = TextEditingController();
  final _companyPhoneController = TextEditingController();
  List<XFile> _companyDocs = [];
  final Map<String, bool> _experiences = {
    'Organized hiking events': false,
    'Managed outdoor adventure activities': false,
    'Coordinated team building events': false,
    'Handled event logistics and planning': false,
    'Managed participant registrations': false,
    'Coordinated with vendors and suppliers': false,
    'Handled event safety and emergency procedures': false,
    'Managed event budgets and finances': false,
    'Organized corporate events': false,
    'Coordinated community events': false,
  };
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _pickCompanyDocs() async {
    final picked = await ImagePicker().pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _companyDocs = picked;
      });
    }
  }

  Future<List<String>> _uploadCompanyDocs() async {
    if (_companyDocs.isEmpty) return [];
    final storage = FirebaseStorage.instanceFor(
      bucket: 'gs://hikefue5-8f6ae',
    );
    List<String> urls = [];
    for (final doc in _companyDocs) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = storage.ref().child('organizer_company_docs').child('doc_${timestamp}_${doc.name}');
      if (kIsWeb) {
        final bytes = await doc.readAsBytes();
        await ref.putData(bytes);
      } else {
        final file = File(doc.path);
        await ref.putFile(file);
      }
      final downloadUrl = await ref.getDownloadURL();
      urls.add(downloadUrl);
    }
    return urls;
  }

  Future<void> _registerOrganizer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_companyDocs.isEmpty) {
      setState(() => _errorMessage = 'Please upload at least one company document.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final docUrls = await _uploadCompanyDocs();
      
      // Create Firebase Auth account with organizer's chosen password
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      final uid = userCredential.user!.uid;
      
      // Store organizer data in Firestore with 'pending' status
      final organizerData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'organizationName': _organizationController.text.trim(),
        'companyRegNumber': _companyRegController.text.trim(),
        'companyPhone': _companyPhoneController.text.trim(),
        'experiences': _experiences.entries
            .where((entry) => entry.value)
            .map((entry) => entry.key)
            .toList(),
        'companyDocs': docUrls,
        'status': 'pending',
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      // Use the Firebase Auth UID as the document ID
      await FirebaseFirestore.instance.collection('organizers').doc(uid).set(organizerData);
      
      // Sign out the user immediately (they shouldn't be logged in until approved)
      await FirebaseAuth.instance.signOut();
      
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() => _isLoading = false);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(
              'Registration Submitted Successfully!',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your company registration has been submitted and is pending admin approval.',
                  style: GoogleFonts.poppins(),
                ),
                const SizedBox(height: 12),
                Text(
                  'You will be able to log in once an admin approves your account.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF6C757D),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Registration failed: $e';
      });
    }
  }

  Widget _buildImagePreview() {
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackgroundColor,
      body: Stack(
        children: [
          // Background image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/trees_background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Dark overlay
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(color: primaryColor.withOpacity(0.7)),
          ),
          // Back button (top left)
          Positioned(
            top: 24,
            left: 24,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Back',
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 32,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header with icon
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: accentColor.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.business,
                                size: 48,
                                color: accentColor,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Company Organizer Registration',
                              style: GoogleFonts.poppins(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2C3E50),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Register your company to start organizing events',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: const Color(0xFF6C757D),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),

                            // Contact Person Information
                            Text(
                              'Contact Person Information',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Contact Person Name',
                                prefixIcon: const Icon(Icons.person, color: accentColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: accentColor, width: 2),
                                ),
                              ),
                              validator: (v) => v == null || v.isEmpty ? 'Enter contact person name' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: const Icon(Icons.email, color: accentColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: accentColor, width: 2),
                                ),
                              ),
                              validator: (v) => v == null || v.isEmpty ? 'Enter email address' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock, color: accentColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: accentColor, width: 2),
                                ),
                                helperText: 'Minimum 6 characters',
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Enter password';
                                if (v.length < 6) return 'Password must be at least 6 characters';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'Confirm Password',
                                prefixIcon: const Icon(Icons.lock_outline, color: accentColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: accentColor, width: 2),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Confirm your password';
                                if (v != _passwordController.text) return 'Passwords do not match';
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Company Information
                            Text(
                              'Company Information',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _organizationController,
                              decoration: InputDecoration(
                                labelText: 'Company Name',
                                prefixIcon: const Icon(Icons.business, color: accentColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: accentColor, width: 2),
                                ),
                              ),
                              validator: (v) => v == null || v.isEmpty ? 'Enter company name' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _companyRegController,
                              decoration: InputDecoration(
                                labelText: 'Company Registration Number',
                                prefixIcon: const Icon(Icons.numbers, color: accentColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: accentColor, width: 2),
                                ),
                              ),
                              validator: (v) => v == null || v.isEmpty ? 'Enter company registration number' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _companyPhoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: 'Company Phone Number',
                                prefixIcon: const Icon(Icons.phone, color: accentColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: accentColor, width: 2),
                                ),
                              ),
                              validator: (v) => v == null || v.isEmpty ? 'Enter company phone number' : null,
                            ),
                            const SizedBox(height: 24),

                            // Company Documents
                            Text(
                              'Company Documents',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Upload company documents (e.g. SSM certificate, company profile, etc.)',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: const Color(0xFF6C757D),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: accentColor.withOpacity(0.3)),
                                borderRadius: BorderRadius.circular(12),
                                color: accentColor.withOpacity(0.05),
                              ),
                              child: Column(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _pickCompanyDocs,
                                    icon: const Icon(Icons.upload_file),
                                    label: const Text('Upload Documents'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accentColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                  if (_companyDocs.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    ..._companyDocs.map((doc) => Container(
                                      padding: const EdgeInsets.all(8),
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.description, color: accentColor),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              doc.name,
                                              style: GoogleFonts.poppins(fontSize: 14),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Experience Section
                            Text(
                              'Relevant Experience (Optional)',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please tick the experiences your company has:',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: const Color(0xFF6C757D),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: accentColor.withOpacity(0.3)),
                                borderRadius: BorderRadius.circular(12),
                                color: accentColor.withOpacity(0.05),
                              ),
                              child: Column(
                                children: _experiences.entries.map((entry) => CheckboxListTile(
                                  title: Text(
                                    entry.key,
                                    style: GoogleFonts.poppins(fontSize: 14),
                                  ),
                                  value: entry.value,
                                  onChanged: (value) {
                                    setState(() {
                                      _experiences[entry.key] = value ?? false;
                                    });
                                  },
                                  controlAffinity: ListTileControlAffinity.leading,
                                  contentPadding: EdgeInsets.zero,
                                  activeColor: accentColor,
                                )).toList(),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Error Message
                            if (_errorMessage != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: GoogleFonts.poppins(
                                    color: Colors.red.shade700,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            if (_errorMessage != null) const SizedBox(height: 16),

                            // Submit Button
                            ElevatedButton(
                              onPressed: _isLoading ? null : _registerOrganizer,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
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
                                  : const Text('Register Company'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 