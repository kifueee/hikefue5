import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/carpool_matching_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const String kGoogleApiKey = 'AIzaSyAE4jbrjU5QiNVa2EvocVgFdsR__c-kCRE';

// Theme colors
const Color primaryColor = Color(0xFF004A4D);
const Color accentColor = Color(0xFF94BC45);
const Color darkBackgroundColor = Color(0xFF231F20);

// Placeholder classes for Google Places API
class PlacesSearchResult {
  final String? name;
  final String? formattedAddress;
  final Geometry? geometry;
  final String? placeId;
  final String? reference;

  PlacesSearchResult({
    this.name,
    this.formattedAddress,
    this.geometry,
    this.placeId,
    this.reference,
  });
}

class Geometry {
  final Location location;

  Geometry({required this.location});
}

class Location {
  final double lat;
  final double lng;

  Location({required this.lat, required this.lng});
}

class CreateRidePage extends StatefulWidget {
  final String eventId;
  final String eventName;
  final DateTime eventTime;
  final String eventLocation;
  final Map<String, dynamic>? existingCarpool;

  const CreateRidePage({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.eventTime,
    required this.eventLocation,
    this.existingCarpool,
  });

  @override
  State<CreateRidePage> createState() => _CreateRidePageState();
}

class _CreateRidePageState extends State<CreateRidePage> {
  final _formKey = GlobalKey<FormState>();
  final _carpoolService = CarpoolMatchingService();
  
  final _pickupLocationController = TextEditingController();
  LatLng? _selectedPickupLocation;
  final _seatsController = TextEditingController(text: '1');
  final _costController = TextEditingController();
  final _notesController = TextEditingController();
  
  late DateTime _departureTime;
  bool _isLoading = false;
  Map<String, dynamic>? _driverDetails;
  Map<String, dynamic>? _eventData;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  String? _routeDistance;
  String? _routeDuration;
  double? _routeDistanceInKm;
  bool _isAutoCalculating = false;
  List<String> _carMakes = [];
  bool _isLoadingMakes = false;
  Timer? _makeDebounce;

  // Constants for cost calculation (in RM)
  static const double _baseRatePerKm = 1.20; // RM 1.20 per kilometer
  static const double _minimumFare = 10.00; // RM 10 minimum fare per passenger
  static const double _fuelEfficiency = 12.0; // km per liter (average car efficiency)
  static const double _fuelPrice = 2.05; // RM 2.05 per liter (current RON95 price)

  @override
  void initState() {
    super.initState();
    _selectedPickupLocation = null; // Don't set a default location
    _pickupLocationController.text = '';
    _seatsController.text = '1';
    _costController.text = '';
    _notesController.text = '';
    // Initialize departure time to event date with time 2 hours before event
    final eventDateTime = widget.eventTime;
    final defaultDepartureTime = eventDateTime.subtract(const Duration(hours: 2));
    _departureTime = DateTime(
      eventDateTime.year,
      eventDateTime.month,
      eventDateTime.day,
      defaultDepartureTime.hour.clamp(0, 23),
      defaultDepartureTime.minute,
    );
    _routeDistance = null;
    _routeDuration = null;
    _routeDistanceInKm = null;
    _loadCarMakes();
    _loadDriverDetails();
    _loadEventData();

    // Initialize form with existing carpool data if available
    if (widget.existingCarpool != null) {
      final carpool = widget.existingCarpool!;
      
      final pickupLocation = carpool['pickupLocation'] as String? ?? '';
      _pickupLocationController.text = pickupLocation;
      _seatsController.text = (carpool['availableSeats'] as num?)?.toString() ?? '1';
      _costController.text = (carpool['costPerPerson'] as num?)?.toString() ?? '';
      _notesController.text = carpool['notes'] as String? ?? '';
      
      // Restore pickup coordinates if available
      if (carpool.containsKey('pickupCoordinates') && carpool['pickupCoordinates'] != null) {
        final coords = carpool['pickupCoordinates'] as Map<String, dynamic>;
        if (coords.containsKey('latitude') && coords.containsKey('longitude')) {
          _selectedPickupLocation = LatLng(
            coords['latitude'].toDouble(),
            coords['longitude'].toDouble(),
          );
        }
      }
      
      // For existing carpool, preserve the time but ensure it's on the event date
      final existingDepartureTime = (carpool['departureTime'] as Timestamp).toDate();
      final eventDate = widget.eventTime;
      _departureTime = DateTime(
        eventDate.year,
        eventDate.month,
        eventDate.day,
        existingDepartureTime.hour,
        existingDepartureTime.minute,
      );
    }

    _updateMarkers();
  }

  @override
  void dispose() {
    _pickupLocationController.dispose();
    _seatsController.dispose();
    _costController.dispose();
    _notesController.dispose();
    _mapController?.dispose();
    _makeDebounce?.cancel();
    super.dispose();
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
    bool enabled = true,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      maxLines: maxLines,
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

  void _calculateCostPerPerson() {
    if (_routeDistanceInKm == null) return;

    setState(() {
      _isAutoCalculating = true;
    });

    // Calculate total cost
    double totalDistanceCost = _routeDistanceInKm! * _baseRatePerKm;
    double fuelCost = (_routeDistanceInKm! / _fuelEfficiency) * _fuelPrice;
    double totalCost = totalDistanceCost + fuelCost;

    // Get number of seats
    int seats = int.tryParse(_seatsController.text) ?? 1;
    if (seats < 1) seats = 1;

    // Calculate cost per person
    double costPerPerson = totalCost / seats;
    
    // Ensure minimum fare
    if (costPerPerson < _minimumFare) {
      costPerPerson = _minimumFare;
    }

    // Round to 2 decimal places
    costPerPerson = double.parse(costPerPerson.toStringAsFixed(2));

    setState(() {
      _costController.text = costPerPerson.toString();
      _isAutoCalculating = false;
    });

    // Show cost breakdown
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.transparent,
          content: _buildGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cost Breakdown',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Total Distance: ${_routeDistanceInKm!.toStringAsFixed(1)} km',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Base Rate: RM ${totalDistanceCost.toStringAsFixed(2)} (RM $_baseRatePerKm/km)',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  Text(
                    'Fuel Cost: RM ${fuelCost.toStringAsFixed(2)} (RM $_fuelPrice/liter)',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const Divider(color: Colors.white24),
                  Text(
                    'Total Cost: RM ${totalCost.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  Text(
                    'Number of Seats: $seats',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const Divider(color: Colors.white24),
                  Text(
                    'Cost per Person: RM ${costPerPerson.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                  if (costPerPerson == _minimumFare)
                    Text(
                      '(Minimum fare applied)',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(
                        'OK',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_departureTime),
    );
    if (picked != null) {
      setState(() {
        // Always use the event date, only update the time
        final eventDate = widget.eventTime;
        _departureTime = DateTime(
          eventDate.year,
          eventDate.month,
          eventDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _getRoute(LatLng origin, LatLng destination) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&key=$kGoogleApiKey',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          
          setState(() {
            _routeDistance = leg['distance']['text'];
            _routeDuration = leg['duration']['text'];
          });

          // Decode polyline points
          final points = _decodePolyline(route['overview_polyline']['points']);
          
          setState(() {
            _polylines = {
              Polyline(
                polylineId: const PolylineId('route'),
                points: points,
                color: Colors.blue,
                width: 5,
              ),
            };
          });

          // Fit the map bounds to show the entire route
          final bounds = _getBounds(points);
          _mapController?.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 50),
          );
        }
      }
    } catch (e) {
      print('Error getting route: $e');
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  LatLngBounds _getBounds(List<LatLng> points) {
    double? minLat, maxLat, minLng, maxLng;
    
    for (var point in points) {
      if (minLat == null || point.latitude < minLat) minLat = point.latitude;
      if (maxLat == null || point.latitude > maxLat) maxLat = point.latitude;
      if (minLng == null || point.longitude < minLng) minLng = point.longitude;
      if (maxLng == null || point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  Future<void> _selectPickupLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerPage(
          initialLocation: _selectedPickupLocation,
          title: 'Select Pickup Location',
          eventId: widget.eventId,
          isEventLocation: false,
          eventLocation: widget.eventLocation,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _selectedPickupLocation = result['latLng'] as LatLng;
        _pickupLocationController.text = result['address'] as String;
        _routeDistance = result['distance'] as String?;
        _routeDuration = result['duration'] as String?;
        _routeDistanceInKm = result['distanceInKm'] as double?;
        _updateMarkers();
      });

      // Auto-calculate cost when route is available
      if (_routeDistanceInKm != null) {
        _calculateCostPerPerson();
      }
    }
  }

  void _updateMarkers({LatLng? eventLatLng}) {
  setState(() {
    _markers = {};
    
    // Always show event location marker if available
    if (eventLatLng != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('event'),
          position: eventLatLng,
          infoWindow: InfoWindow(
            title: 'Event Location',
            snippet: widget.eventLocation,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }
    
    // Show organizer's meeting point marker if available
    if (_eventData != null) {
      final meetingPoint = _eventData!['meetingPoint'] as Map<String, dynamic>?;
      if (meetingPoint != null) {
        double? lat, lng;
        
        // Check nested coordinates object
        if (meetingPoint['coordinates'] != null) {
          final coords = meetingPoint['coordinates'] as Map<String, dynamic>?;
          if (coords?['latitude'] != null && coords?['longitude'] != null) {
            lat = (coords!['latitude'] as num).toDouble();
            lng = (coords['longitude'] as num).toDouble();
          }
        }
        
        if (lat != null && lng != null) {
          _markers.add(
            Marker(
              markerId: const MarkerId('organizer_meeting'),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(
                title: 'Organizer Meeting Point',
                snippet: meetingPoint['address']?.toString() ?? 'Meeting Point',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            ),
          );
        }
      }
    }
    
    // Show user's selected pickup location if available
    if (_selectedPickupLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('user_pickup'),
          position: _selectedPickupLocation!,
          infoWindow: InfoWindow(
            title: 'Your Pickup Location',
            snippet: _pickupLocationController.text,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }
  });
}

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPickupLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a pickup location')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Fetch driver details from approved application
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');
      
      // Check for approved driver application for this event
      final querySnapshot = await FirebaseFirestore.instance
          .collection('driver_applications')
          .where('userId', isEqualTo: user.uid)
          .where('eventId', isEqualTo: widget.eventId)
          .where('status', isEqualTo: 'approved')
          .get();
      
      String vehicleDetails;
      
      if (querySnapshot.docs.isEmpty) {
        // For testing purposes, create a default vehicle details
        // In production, this should require proper driver application approval
        vehicleDetails = 'Test Vehicle (Red) - TEST123 - SEDAN';
        
        // Show a warning to the user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Using test vehicle details. In production, driver application approval is required.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        final application = querySnapshot.docs.first.data();
        vehicleDetails = '${application['vehicleMake'] ?? 'Unknown'} ${application['vehicleModel'] ?? 'Unknown'} '
            '(${application['vehicleColor'] ?? 'Unknown'}) - ${application['vehiclePlate'] ?? 'Unknown'} '
            '- ${application['vehicleType']?.toString().toUpperCase() ?? 'UNKNOWN'}';
      }

      if (widget.existingCarpool != null) {
        // Update existing carpool
        await _carpoolService.updateDriverOffer(
          carpoolId: widget.existingCarpool!['id'],
          pickupLocation: _pickupLocationController.text,
          dropoffLocation: widget.eventLocation,
          departureTime: _departureTime,
          availableSeats: int.parse(_seatsController.text),
          costPerPerson: double.parse(_costController.text),
          vehicleDetails: vehicleDetails,
          notes: _notesController.text,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Carpool updated successfully!')),
          );
          Navigator.pop(context);
        }
      } else {
        // Create new carpool
        await _carpoolService.createDriverOffer(
          eventId: widget.eventId,
          pickupLocation: _pickupLocationController.text,
          dropoffLocation: widget.eventLocation,
          departureTime: _departureTime,
          availableSeats: int.parse(_seatsController.text),
          costPerPerson: double.parse(_costController.text),
          vehicleDetails: vehicleDetails,
          notes: _notesController.text,
          pickupCoordinates: _selectedPickupLocation != null ? {
            'latitude': _selectedPickupLocation!.latitude,
            'longitude': _selectedPickupLocation!.longitude,
          } : null,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ride offer created successfully!')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _getEventLocationAndRoute() async {
  try {
    final eventLocationList = await locationFromAddress(widget.eventLocation);
    if (eventLocationList.isNotEmpty) {
      final eventLocation = eventLocationList.first;
      final eventLatLng = LatLng(eventLocation.latitude, eventLocation.longitude);
      _updateMarkers(eventLatLng: eventLatLng);
      
      // Move camera to event location
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: eventLatLng,
              zoom: 12,
            ),
          ),
        );
      }
      
      // Get route between pickup and event location
      if (_selectedPickupLocation != null) {
        await _getRoute(_selectedPickupLocation!, eventLatLng);
      }
    }
  } catch (e) {
    print('Error getting event location coordinates: $e');
  }
}

  Future<void> _loadEventData() async {
    try {
      final eventDoc = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .get();
      
      if (eventDoc.exists) {
        setState(() {
          _eventData = eventDoc.data() as Map<String, dynamic>;
        });
        _updateMarkers();
      }
    } catch (e) {
      print('Error loading event data: $e');
    }
  }



  Future<void> _loadDriverDetails() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get approved driver application for this event
      final querySnapshot = await FirebaseFirestore.instance
          .collection('driver_applications')
          .where('userId', isEqualTo: user.uid)
          .where('eventId', isEqualTo: widget.eventId)
          .where('status', isEqualTo: 'approved')
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        final application = querySnapshot.docs.first.data();
        final driverDetails = {
          'vehicleMake': application['vehicleMake'],
          'vehicleModel': application['vehicleModel'],
          'vehicleColor': application['vehicleColor'],
          'vehiclePlate': application['vehiclePlate'],
          'vehicleType': application['vehicleType'],
          'licenseNumber': application['licenseNumber'],
        };
        
        setState(() {
          _driverDetails = driverDetails;
        });
      }
    } catch (e) {
      print('Error loading driver details: $e');
    }
  }

  Widget _buildDetailField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
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
              Icon(icon, color: accentColor, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadCarMakes() async {
    setState(() {
      _isLoadingMakes = true;
    });

    try {
      // Malaysian car makes
      final makes = [
        'Perodua',
        'Proton',
        'Toyota',
        'Honda',
        'Nissan',
        'Mitsubishi',
        'Mazda',
        'Hyundai',
        'Kia',
        'Suzuki',
        'Isuzu',
        'Ford',
        'Volkswagen',
        'BMW',
        'Mercedes-Benz',
        'Audi',
        'Lexus',
        'Subaru',
        'Chevrolet',
        'Peugeot',
      ];
      setState(() {
        _carMakes = makes;
        _isLoadingMakes = false;
      });
    } catch (e) {
      print('Error loading car makes: $e');
      setState(() {
        _isLoadingMakes = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/trees_background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Stack(
            children: [
              Container(
                color: Colors.black.withOpacity(0.85), // Much darker overlay
              ),
              Scaffold(
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  title: Text(
                    widget.existingCarpool != null ? 'Edit Ride' : 'Offer a Ride',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  iconTheme: const IconThemeData(color: Colors.white),
                ),
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [

                          
                          // Driver info card (if details are available)
                          if (_driverDetails != null) ...[
                            _buildGlassCard(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.check_circle, color: Colors.green, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Driver Information',
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            '${_driverDetails!['vehicleMake'] ?? 'Unknown'} ${_driverDetails!['vehicleModel'] ?? 'Unknown'}',
                                            style: GoogleFonts.poppins(
                                              color: Colors.white.withOpacity(0.8),
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          
                          // Driver Details Section
                          if (_driverDetails != null) ...[
                            _buildGlassCard(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.directions_car, color: accentColor, size: 24),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Vehicle Information',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    
                                    // Vehicle details in a grid
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildDetailField(
                                            label: 'Vehicle Make',
                                            value: _driverDetails?['vehicleMake'] ?? 'Not specified',
                                            icon: Icons.directions_car,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: _buildDetailField(
                                            label: 'Vehicle Model',
                                            value: _driverDetails?['vehicleModel'] ?? 'Not specified',
                                            icon: Icons.directions_car,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildDetailField(
                                            label: 'Vehicle Color',
                                            value: _driverDetails?['vehicleColor'] ?? 'Not specified',
                                            icon: Icons.palette,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: _buildDetailField(
                                            label: 'License Plate',
                                            value: _driverDetails?['vehiclePlate'] ?? 'Not specified',
                                            icon: Icons.confirmation_number,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildDetailField(
                                            label: 'Vehicle Type',
                                            value: (_driverDetails?['vehicleType'] ?? 'Not specified').toString().toUpperCase(),
                                            icon: Icons.category,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: _buildDetailField(
                                            label: 'License Number',
                                            value: _driverDetails?['licenseNumber'] ?? 'Not specified',
                                            icon: Icons.badge,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          
                          // Map
                          _buildGlassCard(
                            child: Container(
                              height: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target: const LatLng(3.1390, 101.6869), // Default to KL, will be updated
                                    zoom: 12,
                                  ),
                                  onMapCreated: (controller) {
                                    _mapController = controller;
                                    // Get event location coordinates and show route
                                    _getEventLocationAndRoute();
                                  },
                                  markers: _markers,
                                  polylines: _polylines,
                                  myLocationEnabled: true,
                                  myLocationButtonEnabled: true,
                                  zoomControlsEnabled: true,
                                  mapToolbarEnabled: false,
                                  compassEnabled: true,
                                  rotateGesturesEnabled: true,
                                  scrollGesturesEnabled: true,
                                  tiltGesturesEnabled: true,
                                  zoomGesturesEnabled: true,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Route information
                          if (_routeDistance != null && _routeDuration != null)
                            _buildGlassCard(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    Column(
                                      children: [
                                        Text(
                                          'Distance',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.white.withOpacity(0.7),
                                          ),
                                        ),
                                        Text(
                                          _routeDistance!,
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      children: [
                                        Text(
                                          'Duration',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.white.withOpacity(0.7),
                                          ),
                                        ),
                                        Text(
                                          _routeDuration!,
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),

                          // Event information
                          _buildGlassCard(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.eventName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('MMM d, y h:mm a').format(widget.eventTime),
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on, size: 16, color: accentColor),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          widget.eventLocation,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: Colors.white.withOpacity(0.8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Pickup location section
                          _buildGlassCard(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.meeting_room, color: accentColor, size: 24),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Pickup Location',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Show organizer's meeting point info
                                  if (_eventData != null && _eventData!['meetingPoint'] != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.info_outline, color: Colors.blue, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Organizer Meeting Point',
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.blue,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Text(
                                                  _eventData!['meetingPoint']['address'] ?? 'No address specified',
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white.withOpacity(0.8),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  
                                  // Current pickup location display
                                  _buildTextField(
                                    controller: _pickupLocationController,
                                    label: 'Your Pickup Location',
                                    icon: Icons.location_on,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please select a pickup location';
                                      }
                                      return null;
                                    },
                                    enabled: false,
                                  ),
                                                                    const SizedBox(height: 12),
                                  
                                  // Action button
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _selectPickupLocation,
                                      icon: const Icon(Icons.map),
                                      label: Text(
                                        'Choose Pickup Location',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: accentColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Departure time
                          _buildGlassCard(
                            child: ListTile(
                              leading: const Icon(Icons.access_time, color: accentColor),
                              title: Text(
                                'Departure Time',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                DateFormat('MMM d, h:mm a').format(_departureTime),
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                              onTap: _selectTime,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Available seats
                          _buildTextField(
                            controller: _seatsController,
                            label: 'Available Seats',
                            icon: Icons.event_seat,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter number of seats';
                              }
                              final seats = int.tryParse(value);
                              if (seats == null || seats < 1) {
                                return 'Please enter a valid number of seats';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Cost per person
                          _buildTextField(
                            controller: _costController,
                            label: 'Cost per Person (RM)',
                            icon: Icons.attach_money,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter cost per person';
                              }
                              final cost = double.tryParse(value);
                              if (cost == null || cost < 0) {
                                return 'Please enter a valid cost';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          if (_routeDistance != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Route distance: $_routeDistance ($_routeDuration)',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _routeDistanceInKm != null ? _calculateCostPerPerson : null,
                              icon: _isAutoCalculating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.calculate),
                              label: Text(
                                'Auto-calculate Cost',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Additional notes
                          _buildTextField(
                            controller: _notesController,
                            label: 'Additional Notes',
                            icon: Icons.note,
                            maxLines: 3,
                            validator: (value) => null,
                          ),
                          const SizedBox(height: 24),

                          // Submit button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _submitForm,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.check),
                              label: Text(
                                _isLoading 
                                  ? (widget.existingCarpool != null ? 'Updating...' : 'Creating...') 
                                  : (widget.existingCarpool != null ? 'Update Ride' : 'Create Offer'),
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Location Picker Page
class LocationPickerPage extends StatefulWidget {
  final LatLng? initialLocation;
  final String title;
  final String eventId;
  final bool isEventLocation;
  final String? eventLocation;

  const LocationPickerPage({
    super.key,
    this.initialLocation,
    required this.title,
    required this.eventId,
    required this.isEventLocation,
    this.eventLocation,
  });

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  List<PlacesSearchResult> _searchResults = [];
  LatLng? _selectedLocation;
  String? _selectedAddress;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  String? _routeDistance;
  String? _routeDuration;
  bool _isLocationConfirmed = false;
  LatLng? _eventLocationLatLng;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation ?? const LatLng(3.1390, 101.6869);
    _selectedAddress = null;
    _getCurrentLocation();
    _getEventLocationCoordinates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _getEventLocationCoordinates() async {
    if (widget.eventLocation != null) {
      try {
        final eventLocationList = await locationFromAddress(widget.eventLocation!);
        if (eventLocationList.isNotEmpty) {
          final eventLocation = eventLocationList.first;
          setState(() {
            _eventLocationLatLng = LatLng(eventLocation.latitude, eventLocation.longitude);
            _markers.add(
              Marker(
                markerId: const MarkerId('event'),
                position: _eventLocationLatLng!,
                infoWindow: InfoWindow(
                  title: 'Event Location',
                  snippet: widget.eventLocation,
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              ),
            );
          });
        }
      } catch (e) {
        print('Error getting event location coordinates: $e');
      }
    }
  }

  Future<void> _getRoute(LatLng origin, LatLng destination) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&key=$kGoogleApiKey',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          
          setState(() {
            _routeDistance = leg['distance']['text'];
            _routeDuration = leg['duration']['text'];
          });

          // Decode polyline points
          final points = _decodePolyline(route['overview_polyline']['points']);
          
          setState(() {
            _polylines = {
              Polyline(
                polylineId: const PolylineId('route'),
                points: points,
                color: Colors.blue,
                width: 5,
              ),
            };
          });

          // Fit the map bounds to show the entire route
          final bounds = _getBounds(points);
          _mapController?.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 50),
          );
        }
      }
    } catch (e) {
      print('Error getting route: $e');
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  LatLngBounds _getBounds(List<LatLng> points) {
    double? minLat, maxLat, minLng, maxLng;
    
    for (var point in points) {
      if (minLat == null || point.latitude < minLat) minLat = point.latitude;
      if (maxLat == null || point.latitude > maxLat) maxLat = point.latitude;
      if (minLng == null || point.longitude < minLng) minLng = point.longitude;
      if (maxLng == null || point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition();
      final location = LatLng(position.latitude, position.longitude);
      
      // Get address from coordinates
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        final address = '${place.street}, ${place.locality}, ${place.administrativeArea}';
        
        setState(() {
          _selectedLocation = location;
          _selectedAddress = address;
          _searchController.text = address;
          _updateMarker();
        });
        
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: location,
              zoom: 15,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }

  void _updateMarker() {
    if (_selectedLocation != null) {
      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId('selected'),
            position: _selectedLocation!,
            infoWindow: InfoWindow(
              title: widget.isEventLocation ? 'Event Location' : 'Pickup Location',
              snippet: _selectedAddress,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              widget.isEventLocation ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
            ),
          ),
        };
        // Add back the event location marker if it exists
        if (_eventLocationLatLng != null) {
          _markers.add(
            Marker(
              markerId: const MarkerId('event'),
              position: _eventLocationLatLng!,
              infoWindow: InfoWindow(
                title: 'Event Location',
                snippet: widget.eventLocation,
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            ),
          );
        }
      });
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=$query'
          '&key=$kGoogleApiKey'
          '&components=country:my',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          final results = await Future.wait(
            predictions.map((prediction) async {
              final placeId = prediction['place_id'];
              final detailsResponse = await http.get(
                Uri.parse(
                  'https://maps.googleapis.com/maps/api/place/details/json'
                  '?place_id=$placeId'
                  '&fields=geometry,name,formatted_address'
                  '&key=$kGoogleApiKey',
                ),
              );

              if (detailsResponse.statusCode == 200) {
                final details = json.decode(detailsResponse.body);
                if (details['status'] == 'OK') {
                  final result = details['result'];
                  final geometry = result['geometry'];
                  final location = geometry['location'];
                  return PlacesSearchResult(
                    name: result['name'],
                    formattedAddress: result['formatted_address'],
                    geometry: Geometry(
                      location: Location(
                        lat: location['lat'],
                        lng: location['lng'],
                      ),
                    ),
                    placeId: placeId,
                    reference: prediction['reference'],
                  );
                }
              }
              return null;
            }),
          );

          setState(() {
            _searchResults = results.whereType<PlacesSearchResult>().toList();
            _isSearching = false;
          });
        } else {
          setState(() {
            _searchResults = [];
            _isSearching = false;
          });
        }
      }
    } catch (e) {
      print('Error searching places: $e');
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (value.isNotEmpty) {
        setState(() => _isSearching = true);
        _searchPlaces(value);
      } else {
        setState(() => _searchResults.clear());
      }
    });
  }

  void _selectLocation(PlacesSearchResult place) {
    if (place.geometry?.location != null) {
      final lat = place.geometry!.location.lat;
      final lng = place.geometry!.location.lng;
      setState(() {
        _selectedLocation = LatLng(lat, lng);
        _selectedAddress = place.formattedAddress ?? place.name ?? '';
        _searchController.text = place.name ?? '';
        _searchResults.clear();
        _updateMarker();
      });

      // If event location is available, show route
      if (_eventLocationLatLng != null) {
        _getRoute(_selectedLocation!, _eventLocationLatLng!);
      }

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _selectedLocation!,
            zoom: 15,
          ),
        ),
      );
    }
  }

  void _confirmSelection() async {
    if (_selectedLocation != null && _selectedAddress != null) {
      setState(() {
        _isLocationConfirmed = true;
      });

      // Get route between pickup and event location
      if (_eventLocationLatLng != null) {
        await _getRoute(_selectedLocation!, _eventLocationLatLng!);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (!_isLocationConfirmed)
            TextButton.icon(
              onPressed: _confirmSelection,
              icon: const Icon(Icons.check),
              label: const Text('Confirm'),
            )
          else
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context, {
                  'latLng': _selectedLocation,
                  'address': _selectedAddress,
                  'distance': _routeDistance,
                  'duration': _routeDuration,
                  'distanceInKm': _routeDistance != null 
                      ? double.parse(_routeDistance!.replaceAll(' km', ''))
                      : null,
                });
              },
              icon: const Icon(Icons.check),
              label: const Text('Done'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          if (!_isLocationConfirmed)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search for a location',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.my_location),
                          onPressed: _getCurrentLocation,
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
            ),

          // Search results
          if (!_isLocationConfirmed && _searchResults.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final place = _searchResults[index];
                  return ListTile(
                    leading: const Icon(Icons.location_on),
                    title: Text(place.name ?? ''),
                    subtitle: Text(place.formattedAddress ?? ''),
                    onTap: () => _selectLocation(place),
                  );
                },
              ),
            ),

          // Map
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _selectedLocation ?? const LatLng(3.1390, 101.6869),
                    zoom: 15,
                  ),
                  onMapCreated: (controller) => _mapController = controller,
                  markers: _markers,
                  polylines: _polylines,
                  onTap: _isLocationConfirmed ? null : (LatLng location) async {
                    try {
                      final placemarks = await placemarkFromCoordinates(
                        location.latitude,
                        location.longitude,
                      );
                      
                      if (placemarks.isNotEmpty) {
                        final place = placemarks[0];
                        final address = '${place.street}, ${place.locality}, ${place.administrativeArea}';
                        
                        setState(() {
                          _selectedLocation = location;
                          _selectedAddress = address;
                          _searchController.text = address;
                          _updateMarker();
                        });

                        // If event location is available, show route
                        if (_eventLocationLatLng != null) {
                          _getRoute(_selectedLocation!, _eventLocationLatLng!);
                        }
                      }
                    } catch (e) {
                      print('Error getting address: $e');
                    }
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  mapToolbarEnabled: false,
                ),
                if (_routeDistance != null && _routeDuration != null)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.directions_car, size: 16, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Route: $_routeDistance ($_routeDuration)',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
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