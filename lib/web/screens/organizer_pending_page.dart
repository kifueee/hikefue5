import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrganizerPendingPage extends StatefulWidget {
  const OrganizerPendingPage({super.key});

  @override
  State<OrganizerPendingPage> createState() => _OrganizerPendingPageState();
}

class _OrganizerPendingPageState extends State<OrganizerPendingPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String _status = 'pending';
  String? _rejectionReason;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrganizerStatus();
  }

  Future<void> _fetchOrganizerStatus() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final organizerDoc = await _firestore.collection('organizers').doc(user.uid).get();
        if (organizerDoc.exists) {
          final data = organizerDoc.data() as Map<String, dynamic>;
          setState(() {
            _status = data['status'] as String? ?? 'pending';
            _rejectionReason = data['rejectionReason'] as String?;
          });
        }
      }
    } catch (e) {
      print('Error fetching organizer status: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
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
            Container(
              color: Colors.black.withOpacity(0.7),
            ),
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    final isRejected = _status == 'rejected';
    final iconData = isRejected ? Icons.cancel : Icons.pending_actions;
    final iconColor = isRejected ? Colors.red : Colors.orange;
    final title = isRejected ? 'Account Rejected' : 'Account Pending Approval';
    final description = isRejected 
        ? 'Your organizer account has been rejected by the admin.'
        : 'Your organizer account is currently pending admin approval.';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background image (same as landing page)
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/trees_background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Dark overlay (same as landing page)
          Container(
            color: Colors.black.withOpacity(0.7),
          ),
          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Icon
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: iconColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: iconColor.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                iconData,
                                size: 48,
                                color: iconColor,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              title,
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2C3E50),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              description,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: const Color(0xFF6C757D),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (isRejected && _rejectionReason != null) ...[
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Rejection Reason:',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _rejectionReason!,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: const Color(0xFF6C757D),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (!isRejected) ...[
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.blue.withOpacity(0.3),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'What happens next?',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '• An admin will review your registration\n• You will be notified once approved\n• You can then log in to your organizer dashboard',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: const Color(0xFF6C757D),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 32),
                            ElevatedButton(
                              onPressed: () async {
                                await FirebaseAuth.instance.signOut();
                                if (context.mounted) {
                                  Navigator.of(context).popUntil((route) => route.isFirst);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4B7F3F),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: const Text('Return to Landing Page'),
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