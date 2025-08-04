import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/rating_service.dart';

class OrganizerProfilePage extends StatefulWidget {
  final String organizerId;
  final String? organizerName;

  const OrganizerProfilePage({
    Key? key,
    required this.organizerId,
    this.organizerName,
  }) : super(key: key);

  @override
  State<OrganizerProfilePage> createState() => _OrganizerProfilePageState();
}

class _OrganizerProfilePageState extends State<OrganizerProfilePage> {
  OrganizerRatingStats? _stats;
  Map<String, dynamic>? _organizerData;
  bool _isLoading = true;
  String _selectedTab = 'overview';

  @override
  void initState() {
    super.initState();
    _loadOrganizerProfile();
  }

  Future<void> _loadOrganizerProfile() async {
    try {
      setState(() => _isLoading = true);
      
      // Load organizer data
      final organizerDoc = await FirebaseFirestore.instance
          .collection('organizers')
          .doc(widget.organizerId)
          .get();
      
      if (organizerDoc.exists) {
        _organizerData = organizerDoc.data();
      }

      // Load rating stats
      _stats = await RatingService.getOrganizerStats(widget.organizerId);
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.organizerName ?? 'Organizer Profile'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildProfileHeader(),
                  _buildTabNavigation(),
                  _buildTabContent(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    final organizerName = _organizerData?['businessName'] ?? 
                          _organizerData?['name'] ?? 
                          widget.organizerName ?? 
                          'Organizer';
    
    final description = _organizerData?['description'] ?? 
                       _organizerData?['businessDescription'] ?? 
                       'Event organizer';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.green[700]!, Colors.green[500]!],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white,
              child: Text(
                organizerName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              organizerName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_stats != null) _buildRatingOverview(),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingOverview() {
    if (_stats!.totalRatings == 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No ratings yet',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text(
                  _stats!.averageRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
                _buildStarRating(_stats!.averageRating),
                Text(
                  '${_stats!.totalRatings} reviews',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 80,
              child: VerticalDivider(color: Colors.grey[300]),
            ),
            Expanded(
              child: Column(
                children: [
                  for (int i = 5; i >= 1; i--)
                    _buildRatingBar(i, _stats!.ratingDistribution[i] ?? 0, _stats!.totalRatings),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return const Icon(Icons.star, color: Colors.amber, size: 20);
        } else if (index < rating) {
          return const Icon(Icons.star_half, color: Colors.amber, size: 20);
        } else {
          return const Icon(Icons.star_border, color: Colors.amber, size: 20);
        }
      }),
    );
  }

  Widget _buildRatingBar(int stars, int count, int total) {
    final percentage = total > 0 ? (count / total) : 0.0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$stars', style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          const Icon(Icons.star, color: Colors.amber, size: 12),
          const SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          ),
          const SizedBox(width: 8),
          Text('$count', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTabNavigation() {
    return Container(
      color: Colors.white,
      child: Row(
        children: [
          _buildTabButton('overview', 'Overview'),
          _buildTabButton('reviews', 'Reviews'),
          _buildTabButton('events', 'Events'),
        ],
      ),
    );
  }

  Widget _buildTabButton(String tabId, String label) {
    final isSelected = _selectedTab == tabId;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = tabId),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.green[700]! : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.green[700] : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 'overview':
        return _buildOverviewTab();
      case 'reviews':
        return _buildReviewsTab();
      case 'events':
        return _buildEventsTab();
      default:
        return _buildOverviewTab();
    }
  }

  Widget _buildOverviewTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_stats != null && _stats!.aspectAverages.isNotEmpty) ...[
            const Text(
              'Rating Breakdown',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._stats!.aspectAverages.entries.map((entry) {
              final aspectName = RatingService.getAspectCategories()[entry.key] ?? entry.key;
              return _buildAspectRating(aspectName, entry.value);
            }).toList(),
            const SizedBox(height: 24),
          ],
          
          if (_organizerData != null) ...[
            const Text(
              'About',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoCard('Business Type', _organizerData!['businessType'] ?? 'Not specified'),
            _buildInfoCard('Location', _organizerData!['location'] ?? 'Not specified'),
            _buildInfoCard('Phone', _organizerData!['phone'] ?? 'Not specified'),
            _buildInfoCard('Email', _organizerData!['email'] ?? 'Not specified'),
          ],
        ],
      ),
    );
  }

  Widget _buildAspectRating(String aspect, double rating) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(aspect),
          ),
          Expanded(
            flex: 3,
            child: LinearProgressIndicator(
              value: rating / 5,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsTab() {
    if (_stats == null || _stats!.recentReviews.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text(
            'No reviews yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: _stats!.recentReviews.map((review) => _buildReviewCard(review)).toList(),
      ),
    );
  }

  Widget _buildReviewCard(EventRating review) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  review.isAnonymous ? 'Anonymous' : review.participantName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                _buildStarRating(review.rating.toDouble()),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              review.comment,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              '${review.timestamp.day}/${review.timestamp.month}/${review.timestamp.year}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('events')
            .where('organizerId', isEqualTo: widget.organizerId)
            .orderBy('date', descending: true)
            .limit(10)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No events found',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
            );
          }

          return Column(
            children: snapshot.data!.docs.map((doc) {
              final eventData = doc.data() as Map<String, dynamic>;
              return _buildEventCard(doc.id, eventData);
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildEventCard(String eventId, Map<String, dynamic> eventData) {
    final eventName = eventData['name'] ?? 'Untitled Event';
    final eventDate = (eventData['date'] as Timestamp?)?.toDate();
    final eventStatus = eventData['eventStatus'] ?? 'draft';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        title: Text(eventName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (eventDate != null)
              Text('${eventDate.day}/${eventDate.month}/${eventDate.year}'),
            Text(
              eventStatus.toUpperCase(),
              style: TextStyle(
                color: _getStatusColor(eventStatus),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          // Navigate to event details if needed
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.grey;
      case 'published':
        return Colors.blue;
      case 'started':
        return Colors.orange;
      case 'ongoing':
        return Colors.green;
      case 'ended':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}