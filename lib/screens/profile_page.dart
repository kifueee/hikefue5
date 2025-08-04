import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_page.dart';
import '../services/auth_service.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  Map<String, dynamic> _userData = {};
  String? _userType;
  Stream<DocumentSnapshot>? _userStream;

  @override
  void initState() {
    super.initState();
    debugPrint('ProfilePage: initState called');
    _initializeUserStream();
  }

  void _initializeUserStream() {
    final user = _auth.currentUser;
    if (user != null) {
      _loadUserData().then((_) {
        if (_userType != null) {
          setState(() {
            _userStream = _firestore
                .collection(_userType!)
                .doc(user.uid)
                .snapshots();
          });
        }
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      setState(() => _isLoading = true);
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Try to get user data from all collections
      final collections = ['organizers', 'participants', 'admins'];
      DocumentSnapshot? userDoc;
      String? foundType;

      for (final collection in collections) {
        final doc = await _firestore.collection(collection).doc(user.uid).get();
        if (doc.exists) {
          userDoc = doc;
          foundType = collection;
          break;
        }
      }

      if (userDoc != null && foundType != null) {
        setState(() {
          _userData = userDoc!.data() as Map<String, dynamic>;
          _userType = foundType;
          _isLoading = false;
        });
      } else {
        debugPrint('ProfilePage: Creating new participant document...');
        // Create in participants collection by default
        await _firestore.collection('participants').doc(user.uid).set({
          'name': user.displayName ?? 'User',
          'email': user.email,
          'phoneNumber': '',
          'gender': 'Not specified',
          'profilePicture': '',
          'rating': 0.0,
          'totalRides': 0,
          'preferences': {
            'notifications': true,
            'language': 'English',
            'darkMode': false,
          },
          'bankDetails': {
            'bankName': '',
            'accountNumber': '',
            'accountName': '',
          },
          'stats': {
            'eventsOrganized': 0,
            'eventsParticipated': 0,
            'totalDistance': 0,
            'totalElevation': 0,
          },
          'emergencyContact': {
            'name': '',
            'phone': '',
            'relationship': '',
          },
          'memberSince': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isActive': true,
        });
        
        // Get the newly created document
        final newDoc = await _firestore.collection('participants').doc(user.uid).get();
        setState(() {
          _userData = newDoc.data()!;
          _userType = 'participants';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('ProfilePage: Error loading user data: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }

  Future<void> _refreshUserData() async {
    await _loadUserData();
    _initializeUserStream();
  }

  Future<void> _updateUserData(Map<String, dynamic> newData) async {
    if (_userType == null) return;
    
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection(_userType!).doc(user.uid).update({
          ...newData,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        setState(() {
          _userData = {..._userData, ...newData};
        });
      }
    } catch (e) {
      debugPrint('Error updating user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthPage()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error signing out: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshUserData,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/trees_background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            color: Colors.black.withOpacity(0.5),
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF94BC45)),
                    ),
                  )
                : _userStream != null
                    ? StreamBuilder<DocumentSnapshot>(
                        stream: _userStream,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Error loading profile',
                                style: GoogleFonts.poppins(color: Colors.white),
                              ),
                            );
                          }

                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF94BC45)),
                              ),
                            );
                          }

                          if (snapshot.hasData && snapshot.data!.exists) {
                            final userData = snapshot.data!.data() as Map<String, dynamic>;
                            return SafeArea(
                              child: ListView(
                                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                                children: [
                                  _buildProfileHeader(userData),
                                  const SizedBox(height: 30),
                                  _buildInfoCard(userData),
                                  const SizedBox(height: 20),
                                  _buildSectionTitle('Settings'),
                                  const SizedBox(height: 10),
                                  _buildSettingsList(),
                                  const SizedBox(height: 20),
                                  _buildLogoutButton(),
                                ],
                              ),
                            );
                          }

                          return Center(
                            child: Text(
                              'No profile data found',
                              style: GoogleFonts.poppins(color: Colors.white),
                            ),
                          );
                        },
                      )
                    : SafeArea(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                          children: [
                            _buildProfileHeader(_userData),
                            const SizedBox(height: 30),
                            _buildInfoCard(_userData),
                            const SizedBox(height: 20),
                            _buildSectionTitle('Settings'),
                            const SizedBox(height: 10),
                            _buildSettingsList(),
                            const SizedBox(height: 20),
                            _buildLogoutButton(),
                          ],
                        ),
                      ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> userData) {
    String name = userData['name'] ?? 'Hiker';
    String email = userData['email'] ?? 'No email';
    String profilePicUrl = userData['profilePicture'] ?? '';

    return Row(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: const Color(0xFF94BC45),
          backgroundImage:
              profilePicUrl.isNotEmpty ? NetworkImage(profilePicUrl) : null,
          child: profilePicUrl.isEmpty
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'H',
                  style: GoogleFonts.poppins(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF004A4D),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white70,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(Map<String, dynamic> userData) {
    debugPrint('ProfilePage: User data received: $userData');
    final isOrganizer = _userType == 'organizers';
    final bankDetails = userData['bankDetails'] ?? {};
    return _buildGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(28.0), // Increased padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Information',
              style: GoogleFonts.poppins(
                fontSize: 24, // Larger font
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const Divider(color: Colors.white24, height: 28),
            _buildInfoRow('Phone', _formatPhone(userData['phoneNumber'] ?? userData['phone']), fontSize: 18),
            _buildInfoRow('Gender', userData['gender'] ?? 'Not specified', fontSize: 18),
            _buildInfoRow('Member Since', _formatTimestamp(userData['memberSince'] ?? userData['createdAt']), fontSize: 18),
            if (userData['stats'] != null) ...[
              const SizedBox(height: 16),
              const Divider(color: Colors.white24, height: 28),
              Text(
                'Statistics',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoRow('Events Organized', '${userData['stats']['eventsOrganized'] ?? 0}', fontSize: 16),
              _buildInfoRow('Events Participated', '${userData['stats']['eventsParticipated'] ?? 0}', fontSize: 16),
              _buildInfoRow('Total Distance', '${userData['stats']['totalDistance'] ?? 0} km', fontSize: 16),
            ],
            if (isOrganizer && bankDetails != null && (bankDetails['bankName']?.toString().isNotEmpty ?? false)) ...[
              const SizedBox(height: 28),
              Text(
                'Bank Details',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF94BC45),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Bank Name', bankDetails['bankName'] ?? '-', fontSize: 18),
                    const SizedBox(height: 10),
                    _buildInfoRow('Account Number', bankDetails['accountNumber'] ?? '-', fontSize: 18),
                    const SizedBox(height: 10),
                    _buildInfoRow('Account Name', bankDetails['accountName'] ?? '-', fontSize: 18),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatPhone(dynamic phone) {
    if (phone == null || phone.toString().isEmpty) return 'Not set';
    return phone.toString();
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    
    try {
      DateTime date;
      
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is DateTime) {
        date = timestamp;
      } else if (timestamp is String) {
        // Try to parse ISO string
        date = DateTime.parse(timestamp);
      } else {
        debugPrint('ProfilePage: Unknown timestamp format: $timestamp (${timestamp.runtimeType})');
        return 'N/A';
      }
      
      // Format the date nicely
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      debugPrint('ProfilePage: Error formatting timestamp: $e');
      return 'N/A';
    }
  }

  Widget _buildInfoRow(String label, String value, {double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0), // Increased vertical padding
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                color: Colors.white70,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF94BC45),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSettingsList() {
    return _buildGlassCard(
      child: Column(
        children: [
          _buildSettingsItem(
            Icons.edit_outlined,
            'Edit Profile',
            () {
              // TODO: Implement navigation
            },
          ),
          _buildSettingsItem(
            Icons.notifications_outlined,
            'Notifications',
            () {
              // TODO: Implement navigation
            },
          ),
          _buildSettingsItem(
            Icons.security_outlined,
            'Privacy & Security',
            () {
              // TODO: Implement navigation
            },
          ),
          _buildSettingsItem(
            Icons.help_outline,
            'Help & Support',
            () {
              // TODO: Implement navigation
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton() {
    return ElevatedButton.icon(
      onPressed: _signOut,
      icon: const Icon(Icons.logout, color: Color(0xFF004A4D)),
      label: Text(
        'Sign Out',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          color: const Color(0xFF004A4D),
          fontSize: 16,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF94BC45),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
        minimumSize: const Size(double.infinity, 50),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
} 