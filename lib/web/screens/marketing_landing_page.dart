import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'organizer_register_page.dart';

class MarketingLandingPage extends StatelessWidget {
  const MarketingLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background image (blurred for subtle effect)
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
          // Main content with top bar
          Column(
            children: [
              // Top Navigation Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Logo or App Name
                    Row(
                      children: [
                        const Icon(Icons.terrain, color: Color(0xFF4B7F3F), size: 32),
                        const SizedBox(width: 10),
                        Text(
                          'HikeFue',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2C3E50),
                          ),
                        ),
                      ],
                    ),
                    // Navigation Buttons
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const OrganizerRegisterPage()),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF4B7F3F),
                            textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                          child: const Text('Sign Up'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/organizer_login');
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF6B8E23),
                            textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                          child: const Text('Organizer Login'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/admin_login');
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2C3E50),
                            side: const BorderSide(color: Color(0xFF2C3E50), width: 1.5),
                            textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                          child: const Text('Admin Login'),
                        ),
                        const SizedBox(width: 8),
                        // Temporary logout button for debugging
                        if (FirebaseAuth.instance.currentUser != null)
                          OutlinedButton(
                            onPressed: () async {
                              await FirebaseAuth.instance.signOut();
                              if (context.mounted) {
                                Navigator.of(context).pushReplacementNamed('/');
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red, width: 1.5),
                              textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                            child: const Text('Logout'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Main content below the bar
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 40),
                    child: Column(
                      children: [
                        // Hero Section (Two Columns)
                        Container(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Left: Text (no buttons)
                              Expanded(
                                flex: 6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Build Your Hiking Event in Minutes',
                                      style: GoogleFonts.poppins(
                                        fontSize: 38,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      'HikeFue makes it easy to create, manage, and join hiking events with our simple, powerful platform.',
                                      style: GoogleFonts.poppins(
                                        fontSize: 20,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    // Feature list (bullets)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        _Bullet(text: '✓ Easy event creation and management'),
                                        _Bullet(text: '✓ Carpool coordination and real-time chat'),
                                        _Bullet(text: '✓ Participant registration and tracking'),
                                        _Bullet(text: '✓ Trusted by 1,000+ hikers and organizers'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 40),
                              // Right: Visual (styled card with image)
                              Expanded(
                                flex: 5,
                                child: Container(
                                  height: 400,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.18),
                                        blurRadius: 32,
                                        offset: const Offset(0, 12),
                                      ),
                                    ],
                                    image: const DecorationImage(
                                      image: AssetImage('assets/images/trees_background.jpg'),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      color: Colors.black.withOpacity(0.25),
                                    ),
                                    child: Center(
                                      child: Icon(Icons.hiking, color: Colors.white.withOpacity(0.8), size: 120),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 48),
                        // Features Section (Grid)
                        Container(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.92),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.07),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Why HikeFue?',
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2C3E50),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 24,
                                runSpacing: 24,
                                children: const [
                                  SizedBox(width: 220, child: _FeatureCard(
                                    icon: Icons.event_available,
                                    title: 'Easy Event Creation',
                                    description: 'Create and publish hiking events in just a few clicks. Customize details, dates, and more.',
                                  )),
                                  SizedBox(width: 220, child: _FeatureCard(
                                    icon: Icons.people_alt,
                                    title: 'Participant Management',
                                    description: 'Track registrations, manage attendees, and communicate with your hiking group easily.',
                                  )),
                                  SizedBox(width: 220, child: _FeatureCard(
                                    icon: Icons.directions_car,
                                    title: 'Carpool Coordination',
                                    description: 'Organize carpools for your events and help participants share rides efficiently.',
                                  )),
                                  SizedBox(width: 220, child: _FeatureCard(
                                    icon: Icons.chat_bubble_outline,
                                    title: 'Real-time Chat',
                                    description: 'Enable group chat for each event so everyone stays connected before and during the hike.',
                                  )),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 48),
                        // How It Works Section (Horizontal Steps)
                        Container(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.92),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.07),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                'How It Works',
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2C3E50),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 24,
                                runSpacing: 24,
                                children: const [
                                  SizedBox(width: 180, child: _StepCard(
                                    step: '1',
                                    title: 'Sign Up',
                                    description: 'Create your free organizer account in seconds.',
                                  )),
                                  SizedBox(width: 180, child: _StepCard(
                                    step: '2',
                                    title: 'Create or Join a Hike',
                                    description: 'Set up a new event or join an existing one.',
                                  )),
                                  SizedBox(width: 180, child: _StepCard(
                                    step: '3',
                                    title: 'Manage & Connect',
                                    description: 'Coordinate carpools, chat, and manage participants.',
                                  )),
                                  SizedBox(width: 180, child: _StepCard(
                                    step: '4',
                                    title: 'Enjoy the Adventure!',
                                    description: 'Hit the trail and make memories with your group.',
                                  )),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 48),
                        // Testimonial / Social Proof
                        Container(
                          constraints: const BoxConstraints(maxWidth: 700),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.07),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.star, color: Colors.amber, size: 28),
                                  Icon(Icons.star, color: Colors.amber, size: 28),
                                  Icon(Icons.star, color: Colors.amber, size: 28),
                                  Icon(Icons.star, color: Colors.amber, size: 28),
                                  Icon(Icons.star, color: Colors.amber, size: 28),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '“HikeFue made organizing our hiking group so much easier. The carpool and chat features are game changers!”',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '— Alex, Hiking Organizer',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Trusted by 1,000+ hikers and organizers',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Color(0xFF4B7F3F),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 60),
                      ],
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
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Text(
        text,
        style: GoogleFonts.poppins(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  const _FeatureCard({required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFF4B7F3F).withOpacity(0.12),
          radius: 32,
          child: Icon(icon, color: const Color(0xFF4B7F3F), size: 32),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF2C3E50)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  final String step;
  final String title;
  final String description;
  const _StepCard({required this.step, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFF6B8E23).withOpacity(0.15),
          radius: 24,
          child: Text(
            step,
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF4B7F3F)),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF2C3E50)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
} 