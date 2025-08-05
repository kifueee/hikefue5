import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'event_details_page.dart';
import 'package:hikefue5/services/payment_service.dart';
import 'package:hikefue5/models/payment_status.dart';
import 'package:hikefue5/screens/toyyibpay_payment_page.dart';
import 'package:hikefue5/screens/event_rating_page.dart';
import 'package:hikefue5/services/rating_service.dart';
import 'package:hikefue5/services/event_status_service.dart';

// New Color Palette
const Color primaryColor = Color(0xFF004A4D);
const Color accentColor = Color(0xFF94BC45);
const Color darkBackgroundColor = Color(0xFF231F20);

class MyEventsPage extends StatefulWidget {
  const MyEventsPage({super.key});

  @override
  State<MyEventsPage> createState() => _MyEventsPageState();
}

class _MyEventsPageState extends State<MyEventsPage>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackgroundColor,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/trees_background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(color: primaryColor.withOpacity(0.6)),
          ),
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  title: Text('My Events',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  centerTitle: true,
                  elevation: 0,
                  pinned: true,
                  bottom: TabBar(
                    controller: _tabController,
                    indicatorColor: accentColor,
                    indicatorWeight: 3,
                    labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    unselectedLabelStyle: GoogleFonts.poppins(),
                    tabs: const [
                      Tab(text: 'Upcoming'),
                      Tab(text: 'Past'),
                    ],
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildEventsList(isUpcoming: true),
                _buildEventsList(isUpcoming: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList({required bool isUpcoming}) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return const Center(
        child: Text('Please log in to view your events'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('events')
          .where('status', isEqualTo: 'approved')
          .orderBy('date', descending: !isUpcoming)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: accentColor),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isUpcoming ? Icons.event_busy : Icons.history,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  isUpcoming ? 'No upcoming events' : 'No past events',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isUpcoming 
                    ? 'Join some events to see them here'
                    : 'Events you\'ve attended will appear here',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        // Filter events where user is a participant
        final allEvents = snapshot.data!.docs;
        final userEvents = allEvents.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final participants = data['participants'] as Map<String, dynamic>? ?? {};
          final userParticipant = participants[userId] as Map<String, dynamic>?;
          
          // Check if user is a participant with valid status
          if (userParticipant != null) {
            final userStatus = userParticipant['status'] as String?;
            return ['registered', 'confirmed', 'pending_payment', 'completed'].contains(userStatus);
          }
          return false;
        }).toList();

        final events = userEvents.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).where((event) {
          // Filter out events with null or invalid dates
          try {
            final dateTimestamp = event['date'] as Timestamp?;
            return dateTimestamp != null;
          } catch (e) {
            return false;
          }
        }).toList();

        // Filter events based on their status
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _filterEventsByStatus(events, isUpcoming),
          builder: (context, filteredSnapshot) {
            if (filteredSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: accentColor),
              );
            }

            final filteredEvents = filteredSnapshot.data ?? [];

            if (filteredEvents.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isUpcoming ? Icons.event_busy : Icons.history,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isUpcoming ? 'No upcoming events' : 'No past events',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isUpcoming 
                        ? 'Join some events to see them here'
                        : 'Events you\'ve attended will appear here',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredEvents.length,
              itemBuilder: (context, index) {
                return _buildEventListItem(filteredEvents[index]);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEventListItem(Map<String, dynamic> event) {
    DateTime? date;
    try {
      final dateTimestamp = event['date'] as Timestamp?;
      date = dateTimestamp?.toDate();
    } catch (e) {
      // If there's an error parsing the date, set it to null
      date = null;
    }
    
    final imageUrl =
        event['media']?['posterUrl'] ?? 'https://via.placeholder.com/100';
    final location = event['location']?['address'] ?? 'No location';
    final eventName = event['name']?.toString() ?? 'Untitled Event';
    
    return FutureBuilder<EventStatus>(
      future: EventStatusService.getEventStatus(event['id']),
      builder: (context, snapshot) {
        final eventStatus = snapshot.data ?? EventStatus.draft;
        final statusString = _getStatusString(eventStatus);
        
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
              color: darkBackgroundColor.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1))),
          child: Column(
            children: [
              GestureDetector(
                onTap: () {
                  if (event['id'] != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EventDetailsPage(eventId: event['id']),
                      ),
                    );
                  }
                },
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            Container(color: Colors.grey.shade800),
                        errorWidget: (context, url, error) => Container(
                          width: 70,
                          height: 70,
                          color: Colors.grey.shade800,
                          child: const Icon(Icons.image_not_supported_rounded,
                              color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            eventName,
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                                                     Row(
                             children: [
                               Icon(Icons.calendar_today_outlined,
                                   color: Colors.white70, size: 12),
                               const SizedBox(width: 6),
                               Text(
                                 date != null 
                                   ? DateFormat('EEE, MMM d, yyyy').format(date)
                                   : 'Date TBD',
                                 style: GoogleFonts.poppins(
                                     color: Colors.white70, fontSize: 12),
                               ),
                             ],
                           ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  color: Colors.white70, size: 12),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  location,
                                  style: GoogleFonts.poppins(
                                      color: Colors.white70, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _buildStatusChip(statusString),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Payment section - only show if event has fee and user has payment details
              if (event['pricing'] != null && 
                  event['pricing']['eventFee'] != null && 
                  event['pricing']['eventFee'] > 0 &&
                  event['participants']?[_auth.currentUser?.uid]?['paymentDetails'] != null)
                _buildParticipantPaymentSection(event),
              
              // Rating section for ended events only
              if (eventStatus == EventStatus.ended)
                _buildRatingSection(event),
              
              // Rating display for ended events only
              if (eventStatus == EventStatus.ended)
                _buildEventRatingDisplay(event),
            ],
          ),
        );
      },
    );
  }

  String _getStatusString(EventStatus status) {
    switch (status) {
      case EventStatus.draft:
        return 'Draft';
      case EventStatus.published:
        return 'Upcoming';
      case EventStatus.started:
        return 'Started';
      case EventStatus.ongoing:
        return 'Ongoing';
      case EventStatus.ended:
        return 'Completed';
    }
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'Upcoming':
        color = accentColor;
        label = 'Upcoming';
        break;
      case 'Completed':
        color = Colors.grey;
        label = 'Completed';
        break;
      case 'Started':
        color = Colors.orange;
        label = 'Started';
        break;
      case 'Ongoing':
        color = Colors.green;
        label = 'Ongoing';
        break;
      default:
        color = Colors.blue;
        label = 'Happening';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
            color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildParticipantPaymentSection(Map<String, dynamic> event) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    final participants = event['participants'] as Map<String, dynamic>? ?? {};
    final participantData = participants[userId] as Map<String, dynamic>?;
    
    if (participantData == null) return const SizedBox.shrink();

    final paymentDetails = participantData['paymentDetails'] as Map<String, dynamic>?;
    if (paymentDetails == null) return const SizedBox.shrink();

    PaymentInfo payment;
    try {
      payment = PaymentInfo.fromFirestore(paymentDetails, event['id']);
    } catch (e) {
      // If there's an error creating PaymentInfo, don't show the payment section
      return const SizedBox.shrink();
    }

    // Don't show payment section if amount is 0 or negative
    if (payment.amount <= 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Status',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: payment.statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: payment.statusColor),
                ),
                child: Text(
                  payment.statusText,
                  style: GoogleFonts.poppins(
                    color: payment.statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Amount:',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              Text(
                'RM ${payment.amount.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  color: accentColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (payment.status == PaymentStatus.pending)
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: double.infinity,
              height: 36,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToPayment(payment, event),
                icon: const Icon(Icons.payment, size: 16),
                label: const Text('Pay Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: darkBackgroundColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRatingSection(Map<String, dynamic> event) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rate, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                'Rate Your Experience',
                style: GoogleFonts.poppins(
                  color: Colors.amber,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'How was your experience at this event? Your feedback helps improve future events.',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton.icon(
              onPressed: () => _navigateToRating(event),
              icon: const Icon(Icons.rate_review, size: 16),
              label: const Text('Rate Event'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: darkBackgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventRatingDisplay(Map<String, dynamic> event) {
    return FutureBuilder<List<EventRating>>(
      future: RatingService.getEventRatings(event['id']),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final ratings = snapshot.data;
        if (ratings == null || ratings.isEmpty) return const SizedBox.shrink();

        final totalRating = ratings.fold<int>(0, (sum, rating) => sum + rating.rating);
        final averageRating = totalRating / ratings.length;
        final totalRatings = ratings.length;

        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                'Event Rating: ${averageRating.toStringAsFixed(1)}/5.0',
                style: GoogleFonts.poppins(
                  color: Colors.amber,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '($totalRatings ratings)',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToPayment(PaymentInfo payment, Map<String, dynamic> event) async {
    final eventDetails = await PaymentService.getEventDetails(payment.eventId);
    if (eventDetails != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ToyyibPayPaymentPage(
            eventId: payment.eventId,
            eventName: eventDetails['name'] ?? 'Unknown Event',
            amount: payment.amount,
            participantCount: 1, // Default to 1 for existing payments
          ),
        ),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _filterEventsByStatus(
    List<Map<String, dynamic>> events, 
    bool isUpcoming
  ) async {
    List<Map<String, dynamic>> filteredEvents = [];
    
    for (final event in events) {
      try {
        final eventStatus = await EventStatusService.getEventStatus(event['id']);
        
        if (isUpcoming) {
          // Show events that are NOT ended (draft, published, started, ongoing)
          if (eventStatus != EventStatus.ended) {
            filteredEvents.add(event);
          }
        } else {
          // Show only ended events
          if (eventStatus == EventStatus.ended) {
            filteredEvents.add(event);
          }
        }
      } catch (e) {
        // If there's an error getting the status, skip this event
        continue;
      }
    }
    
    return filteredEvents;
  }

  void _navigateToRating(Map<String, dynamic> event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventRatingPage(
          eventId: event['id'],
          eventName: event['name'] ?? 'Unknown Event',
          organizerName: event['organizerName'] ?? 'Organizer',
        ),
      ),
    );
  }
} 