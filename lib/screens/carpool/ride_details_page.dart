import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/carpool_matching_service.dart';
import 'join_carpool_flow_page.dart';

class RideDetailsPage extends StatefulWidget {
  final DriverOffer offer;
  final String eventName;
  final String eventLocation;
  final DateTime eventDateTime;

  const RideDetailsPage({
    super.key,
    required this.offer,
    required this.eventName,
    required this.eventLocation,
    required this.eventDateTime,
  });

  @override
  State<RideDetailsPage> createState() => _RideDetailsPageState();
}

class _RideDetailsPageState extends State<RideDetailsPage> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  LatLng? _currentLocation;
  LatLng? _pickupLocation;
  LatLng? _dropoffLocation;
  double _totalDistance = 0;
  bool _isLoading = true;
  String _routeInfo = '';

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      // Get current location
      Position position = await Geolocator.getCurrentPosition();
      _currentLocation = LatLng(position.latitude, position.longitude);

      // Convert pickup and dropoff addresses to coordinates
      List<Location> pickupLocations = await locationFromAddress(widget.offer.pickupLocation);
      List<Location> dropoffLocations = await locationFromAddress(widget.offer.dropoffLocation);

      if (pickupLocations.isNotEmpty && dropoffLocations.isNotEmpty) {
        _pickupLocation = LatLng(pickupLocations[0].latitude, pickupLocations[0].longitude);
        _dropoffLocation = LatLng(dropoffLocations[0].latitude, dropoffLocations[0].longitude);

        // Add markers
        _markers = {
          Marker(
            markerId: const MarkerId('current'),
            position: _currentLocation!,
            infoWindow: const InfoWindow(title: 'Current Location'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
          Marker(
            markerId: const MarkerId('pickup'),
            position: _pickupLocation!,
            infoWindow: const InfoWindow(title: 'Pickup Location'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ),
          Marker(
            markerId: const MarkerId('dropoff'),
            position: _dropoffLocation!,
            infoWindow: const InfoWindow(title: 'Dropoff Location'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        };

        // Get route information
        await _getRouteInfo();

        setState(() {
          _isLoading = false;
        });

        // Fit map to show all markers
        _fitMapToMarkers();
      }
    } catch (e) {
      print('Error initializing map: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getRouteInfo() async {
    try {
      // Get route from current location to pickup
      final currentToPickup = await _getRouteBetweenPoints(
        _currentLocation!,
        _pickupLocation!,
        'current_to_pickup',
      );

      // Get route from pickup to dropoff
      final pickupToDropoff = await _getRouteBetweenPoints(
        _pickupLocation!,
        _dropoffLocation!,
        'pickup_to_dropoff',
      );

      // Calculate total distance
      _totalDistance = currentToPickup['distance'] + pickupToDropoff['distance'];

      // Update route info text
      setState(() {
        _routeInfo = '''
Current Location → Pickup: ${currentToPickup['distance'].toStringAsFixed(1)} km (${currentToPickup['duration']} mins)
Pickup → Dropoff: ${pickupToDropoff['distance'].toStringAsFixed(1)} km (${pickupToDropoff['duration']} mins)
Total: ${_totalDistance.toStringAsFixed(1)} km
''';
      });
    } catch (e) {
      print('Error getting route info: $e');
    }
  }

  Future<Map<String, dynamic>> _getRouteBetweenPoints(
    LatLng start,
    LatLng end,
    String routeId,
  ) async {
    final String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&key=AIzaSyAE4jbrjU5QiNVa2EvocVgFdsR__c-kCRE';

    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);

    if (data['status'] == 'OK') {
      final route = data['routes'][0]['legs'][0];
      final distance = route['distance']['value'] / 1000; // Convert to km
      final duration = (route['duration']['value'] / 60).round(); // Convert to minutes

      // Decode polyline points
      final points = _decodePolyline(route['steps'][0]['polyline']['points']);
      
      // Add polyline to map
      _polylines.add(
        Polyline(
          polylineId: PolylineId(routeId),
          points: points,
          color: Colors.blue,
          width: 5,
        ),
      );

      return {
        'distance': distance,
        'duration': duration,
      };
    }

    throw Exception('Failed to get route');
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
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

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return poly;
  }

  void _fitMapToMarkers() {
    if (_mapController == null || _currentLocation == null || _pickupLocation == null || _dropoffLocation == null) return;

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(
        min(_currentLocation!.latitude, min(_pickupLocation!.latitude, _dropoffLocation!.latitude)),
        min(_currentLocation!.longitude, min(_pickupLocation!.longitude, _dropoffLocation!.longitude)),
      ),
      northeast: LatLng(
        max(_currentLocation!.latitude, max(_pickupLocation!.latitude, _dropoffLocation!.latitude)),
        max(_currentLocation!.longitude, max(_pickupLocation!.longitude, _dropoffLocation!.longitude)),
      ),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  void _showFullScreenMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Route Map'),
            backgroundColor: Colors.green,
          ),
          body: Stack(
            children: [
              GoogleMap(
                onMapCreated: (controller) => _mapController = controller,
                initialCameraPosition: CameraPosition(
                  target: _currentLocation!,
                  zoom: 12,
                ),
                markers: _markers,
                polylines: _polylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: true,
                mapToolbarEnabled: true,
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Route Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _routeInfo,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background1.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Ride Details',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEventInfo(),
                    const SizedBox(height: 16),
                    _buildMapSection(),
                    const SizedBox(height: 16),
                    _buildDriverInfo(),
                    const SizedBox(height: 16),
                    _buildRideDetails(),
                    const SizedBox(height: 16),
                    _buildVehicleDetails(),
                    const SizedBox(height: 24),
                    _buildJoinButton(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.eventName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.green),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.eventLocation,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.green),
              const SizedBox(width: 4),
              Text(
                DateFormat('MMM d, y • h:mm a').format(widget.eventDateTime),
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDriverInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Driver Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.green,
                radius: 30,
                child: Text(
                  widget.offer.driverName[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.offer.driverName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Verified Driver',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRideDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ride Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 16),
          _buildLocationRow(Icons.location_on, Colors.red, widget.offer.pickupLocation, 'Pickup'),
          const SizedBox(height: 12),
          _buildLocationRow(Icons.location_on, Colors.green, widget.offer.dropoffLocation, 'Dropoff'),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.access_time, size: 20, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                DateFormat('MMM d, h:mm a').format(widget.offer.departureTime),
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          if (widget.offer.distanceInKm != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.route, size: 20, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  '${widget.offer.distanceInKm!.toStringAsFixed(1)} km',
                  style: const TextStyle(fontSize: 16),
                ),
                if (widget.offer.durationInMinutes != null) ...[
                  const SizedBox(width: 16),
                  const Icon(Icons.timer, size: 20, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.offer.durationInMinutes!} mins',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.event_seat, size: 20, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                '${widget.offer.availableSeats} seats available',
                style: const TextStyle(fontSize: 16),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'RM ${widget.offer.price.toStringAsFixed(2)}/person',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vehicle Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.offer.vehicleDetails,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, Color color, String location, String label) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              Text(
                location,
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMapSection() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _currentLocation == null
                    ? const Center(child: Text('Unable to load map'))
                    : GoogleMap(
                        onMapCreated: (controller) => _mapController = controller,
                        initialCameraPosition: CameraPosition(
                          target: _currentLocation!,
                          zoom: 12,
                        ),
                        markers: _markers,
                        polylines: _polylines,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        zoomControlsEnabled: true,
                        mapToolbarEnabled: true,
                      ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: FloatingActionButton(
              heroTag: 'rideDetailsPageFab',
              onPressed: _showFullScreenMap,
              backgroundColor: Colors.green,
              child: const Icon(Icons.fullscreen),
            ),
          ),
          if (!_isLoading && _routeInfo.isNotEmpty)
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Total Distance: ${_totalDistance.toStringAsFixed(1)} km',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildJoinButton(BuildContext context) {
    final isCurrentUserDriver = widget.offer.driverId == FirebaseAuth.instance.currentUser?.uid;

    if (isCurrentUserDriver) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
                          onPressed: () => _navigateToJoinFlow(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: const Text(
          'Join Ride',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  void _navigateToJoinFlow(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JoinCarpoolFlowPage(
          offer: widget.offer,
          eventName: widget.eventName,
          eventLocation: widget.eventLocation,
          eventDateTime: widget.eventDateTime,
        ),
      ),
    );
    
    // If successful, navigate back
    if (result == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }
} 