import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hikefue5/models/event_category.dart';
import 'package:hikefue5/screens/event_details_page.dart';
import 'package:intl/intl.dart';
import '../../models/tag.dart';
import '../../services/firestore_service.dart';
import 'package:geolocator/geolocator.dart';

// New Color Palette
const Color primaryColor = Color(0xFF004A4D);
const Color accentColor = Color(0xFF94BC45);
const Color darkBackgroundColor = Color(0xFF231F20);

class ParticipantEventsPage extends StatefulWidget {
  const ParticipantEventsPage({super.key});

  @override
  State<ParticipantEventsPage> createState() => _ParticipantEventsPageState();
}

class _ParticipantEventsPageState extends State<ParticipantEventsPage> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _selectedCategory = 'All';
  List<EventCategory> _categories = [];
  List<Tag> _allTags = [];
  bool _loadingTags = false;
  final List<String> _selectedTagIds = [];

  // Location-based search variables
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  bool _sortByNearest = false;
  String _selectedDistance = 'All';
  final List<String> _distanceOptions = ['All', '5km', '10km', '25km', '50km'];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _searchController.addListener(() {
      setState(() {});
    });
    _fetchAllTags();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final snapshot = await _firestore.collection('event_categories').get();
      final categories =
          snapshot.docs.map((doc) => EventCategory.fromFirestore(doc)).toList();
      if (mounted) {
        setState(() {
          _categories = [
            EventCategory(
                id: 'all',
                name: 'All',
                description: '',
                icon: '',
                isActive: true,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now()),
            ...categories
          ];
        });
      }
    } catch (e) {
      // Handle error, maybe show a snackbar
    }
  }

  Future<void> _fetchAllTags() async {
    setState(() => _loadingTags = true);
    final tags = await FirestoreService().getAllTags();
    setState(() {
      _allTags = tags;
      _loadingTags = false;
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingLocation = false);
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingLocation = false);
        return;
      }
      
      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      print('Error getting location: $e');
    }
  }

  double _calculateDistance(Map<String, dynamic> eventData) {
    if (_currentPosition == null) return double.infinity;
    
    final location = eventData['location'] as Map<String, dynamic>?;
    final coordinates = location?['coordinates'] as Map<String, dynamic>?;
    
    if (coordinates == null) return double.infinity;
    
    final eventLat = (coordinates['latitude'] as num?)?.toDouble();
    final eventLng = (coordinates['longitude'] as num?)?.toDouble();
    
    if (eventLat == null || eventLng == null) return double.infinity;
    
    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      eventLat,
      eventLng,
    );
  }

  double _getDistanceInKm(String distanceOption) {
    switch (distanceOption) {
      case '5km': return 5.0;
      case '10km': return 10.0;
      case '25km': return 25.0;
      case '50km': return 50.0;
      default: return double.infinity;
    }
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
          SafeArea(
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    title: Text('Discover Events',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    centerTitle: true,
                    pinned: true,
                    floating: true,
                  ),
                ];
              },
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchField(),
                    const SizedBox(height: 16),
                    _buildCategoryFilters(),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _getEventsStream(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return _buildErrorWidget(
                                snapshot.error.toString());
                          }
                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return _buildEmptyWidget();
                          }

                          final allDocs = snapshot.data!.docs;
                          final currentUserId = _auth.currentUser?.uid;

                          final availableEvents = allDocs.where((doc) {
                            if (currentUserId == null) return true;
                            final data = doc.data() as Map<String, dynamic>;
                            final participants =
                                data['participants'] as Map<String, dynamic>? ??
                                    {};
                            return !participants.containsKey(currentUserId);
                          }).toList();

                          final filteredEvents =
                              _filterEvents(availableEvents);

                          return CustomScrollView(
                            slivers: [
                              if (_searchController.text.isEmpty &&
                                  _selectedCategory == 'All') ...[
                                SliverToBoxAdapter(
                                    child: _buildSectionHeader("All Events")),
                              ],
                              if (filteredEvents.isEmpty)
                                SliverToBoxAdapter(
                                    child: _buildEmptyWidget(isSearch: true))
                              else
                                SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      return _buildEventListItem(
                                          filteredEvents[index]);
                                    },
                                    childCount: filteredEvents.length,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }



  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.redAccent, size: 64),
          const SizedBox(height: 16),
          Text('Something went wrong',
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(error,
              style: GoogleFonts.poppins(color: Colors.white70),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget({bool isSearch = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_busy_rounded,
              color: Colors.white54, size: 64),
          const SizedBox(height: 16),
          Text(
            isSearch ? 'No Results Found' : 'No Events Available',
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            isSearch
                ? 'Try a different search term or filter.'
                : 'Check back later for new events.',
            style: GoogleFonts.poppins(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getEventsStream() {
    Query query = _firestore
        .collection('events')
        .where('status', isEqualTo: 'approved')
        .where('eventStatus', whereIn: ['published', 'started', 'ongoing'])
        .orderBy('date');

    if (_selectedCategory != 'All') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }
    return query.snapshots();
  }

  List<DocumentSnapshot> _filterEvents(List<DocumentSnapshot> docs) {
    final searchTerm = _searchController.text.toLowerCase();
    final hasSearchTerm = searchTerm.isNotEmpty;
    final hasSelectedTags = _selectedTagIds.isNotEmpty;
    final hasDistanceFilter = _selectedDistance != 'All';
    final maxDistance = _getDistanceInKm(_selectedDistance);
    
    if (!hasSearchTerm && !hasSelectedTags && !hasDistanceFilter && !_sortByNearest) {
      return docs;
    }
    
    List<DocumentSnapshot> filteredDocs = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      bool matchesSearch = true;
      bool matchesTags = true;
      bool matchesDistance = true;
      
      // Check search term
      if (hasSearchTerm) {
        final name = data['name']?.toString().toLowerCase() ?? '';
        final location = data['location']?['address']?.toString().toLowerCase() ?? '';
        matchesSearch = name.contains(searchTerm) || location.contains(searchTerm);
      }
      
      // Check tags
      if (hasSelectedTags) {
        final eventTagIds = List<String>.from(data['tags'] ?? []);
        matchesTags = _selectedTagIds.any((selectedTagId) => eventTagIds.contains(selectedTagId));
      }
      
      // Check distance
      if (hasDistanceFilter) {
        final distance = _calculateDistance(data);
        matchesDistance = distance <= maxDistance * 1000; // Convert km to meters
      }
      
      return matchesSearch && matchesTags && matchesDistance;
    }).toList();
    
    // Sort by nearest if enabled
    if (_sortByNearest && _currentPosition != null) {
      filteredDocs.sort((a, b) {
        final distanceA = _calculateDistance(a.data() as Map<String, dynamic>);
        final distanceB = _calculateDistance(b.data() as Map<String, dynamic>);
        return distanceA.compareTo(distanceB);
      });
    }
    
    return filteredDocs;
  }

  Widget _buildSearchField() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.poppins(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by event name or location...',
                  hintStyle: GoogleFonts.poppins(color: Colors.white.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
                  filled: true,
                  fillColor: darkBackgroundColor.withOpacity(0.7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accentColor),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  // This will trigger a rebuild and apply the current filters
                });
              },
              icon: const Icon(Icons.search, color: Colors.white),
              label: Text(
                'Search',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildLocationFilters(),
        const SizedBox(height: 12),
        _buildTagFilters(),
      ],
    );
  }

  Widget _buildLocationFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.location_on,
              color: _currentPosition != null ? accentColor : Colors.white70,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Location-based search',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_isLoadingLocation) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Sort by nearest toggle
            Expanded(
              child: Row(
                children: [
                  Switch(
                    value: _sortByNearest,
                    onChanged: _currentPosition != null ? (value) {
                      setState(() {
                        _sortByNearest = value;
                      });
                    } : null,
                    activeColor: accentColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sort by nearest',
                      style: GoogleFonts.poppins(
                        color: _currentPosition != null ? Colors.white : Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Distance filter dropdown
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: darkBackgroundColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedDistance,
                    isExpanded: true,
                    dropdownColor: darkBackgroundColor,
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
                    items: _distanceOptions.map((String option) {
                      return DropdownMenuItem<String>(
                        value: option,
                        child: Text(option),
                      );
                    }).toList(),
                    onChanged: _currentPosition != null ? (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedDistance = newValue;
                        });
                      }
                    } : null,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_currentPosition == null) ...[
          const SizedBox(height: 8),
          Text(
            'Enable location access to use location-based search',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTagFilters() {
    if (_allTags.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filter by tags:',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _allTags.map((tag) {
            final isSelected = _selectedTagIds.contains(tag.id);
            return FilterChip(
              label: Text(
                tag.name,
                style: GoogleFonts.poppins(
                  color: isSelected ? Colors.white : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedTagIds.add(tag.id);
                  } else {
                    _selectedTagIds.remove(tag.id);
                  }
                });
              },
              backgroundColor: Color(int.parse('0xff${tag.color.substring(1)}')).withOpacity(0.3),
              selectedColor: Color(int.parse('0xff${tag.color.substring(1)}')),
              checkmarkColor: Colors.white,
              side: BorderSide(
                color: Color(int.parse('0xff${tag.color.substring(1)}')),
                width: 1,
              ),
            );
          }).toList(),
        ),
        if (_selectedTagIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedTagIds.clear();
              });
            },
            icon: const Icon(Icons.clear, color: Colors.white70, size: 16),
            label: Text(
              'Clear all tags',
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryFilters() {
    if (_categories.isEmpty) {
      return const SizedBox(height: 40);
    }
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category.name;
          return ChoiceChip(
            label: Text(category.name, style: GoogleFonts.poppins()),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _selectedCategory = category.name;
                });
              }
            },
            backgroundColor: darkBackgroundColor.withOpacity(0.7),
            selectedColor: accentColor,
            labelStyle: TextStyle(
                color: isSelected ? darkBackgroundColor : Colors.white,
                fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                  color:
                      isSelected ? accentColor : Colors.white.withOpacity(0.2)),
            ),
          );
        },
      ),
    );
  }



  Widget _buildEventListItem(DocumentSnapshot event) {
    final data = event.data() as Map<String, dynamic>;
    final imageUrl =
        data['media']?['posterUrl'] ?? 'https://via.placeholder.com/100';
    final date = (data['date'] as Timestamp).toDate();
    final location = data['location']?['address'] ?? 'No location';
    final participantCount = data['participantsCount'] ?? 0;
    final List<dynamic> tagIds = data['tags'] ?? [];
    final eventTags = _allTags.where((tag) => tagIds.contains(tag.id)).toList();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                EventDetailsPage(eventId: event.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
            color: darkBackgroundColor.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1))),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                    width: 70,
                    height: 70,
                    color: Colors.grey.shade800,
                    child: const Icon(Icons.image_not_supported_rounded,
                        color: Colors.grey)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['name'],
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          color: Colors.white70, size: 12),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('EEE, MMM d, yyyy').format(date),
                        style: GoogleFonts.poppins(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people_outline,
                          color: Colors.white70, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        '$participantCount Participants',
                        style: GoogleFonts.poppins(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                 if (eventTags.isNotEmpty) ...[
                   const SizedBox(height: 6),
                   Wrap(
                     spacing: 4,
                     runSpacing: 2,
                     children: eventTags.take(3).map((tag) => Container(
                       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                       decoration: BoxDecoration(
                         color: Color(int.parse('0xff${tag.color.substring(1)}')),
                         borderRadius: BorderRadius.circular(8),
                       ),
                       child: Text(
                         tag.name,
                         style: GoogleFonts.poppins(
                           color: Colors.white,
                           fontWeight: FontWeight.w600,
                           fontSize: 10,
                         ),
                       ),
                     )).toList(),
                   ),
                 ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 