import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

const String kGoogleApiKey = 'AIzaSyAE4jbrjU5QiNVa2EvocVgFdsR__c-kCRE';

class LocationPickerPage extends StatefulWidget {
  final LatLng? initialLocation;
  final String title;
  final String eventId;
  final bool isEventLocation;
  final String eventLocation;
  final bool showRouteOnly;
  final String pickupLocation;
  final String dropoffLocation;

  const LocationPickerPage({
    super.key,
    this.initialLocation,
    required this.title,
    required this.eventId,
    required this.isEventLocation,
    required this.eventLocation,
    this.showRouteOnly = false,
    required this.pickupLocation,
    required this.dropoffLocation,
  });

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  String? _routeDistance;
  String? _routeDuration;
  LatLng? _pickupLatLng;
  LatLng? _dropoffLatLng;

  @override
  void initState() {
    super.initState();
    _initializeLocations();
  }

  Future<void> _initializeLocations() async {
    try {
      // Get pickup location coordinates
      final pickupLocationList = await locationFromAddress(widget.pickupLocation);
      if (pickupLocationList.isNotEmpty) {
        final pickupLocation = pickupLocationList.first;
        setState(() {
          _pickupLatLng = LatLng(pickupLocation.latitude, pickupLocation.longitude);
          _markers.add(
            Marker(
              markerId: const MarkerId('pickup'),
              position: _pickupLatLng!,
              infoWindow: InfoWindow(
                title: 'Pickup Location',
                snippet: widget.pickupLocation,
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            ),
          );
        });
      }

      // Get dropoff location coordinates
      final dropoffLocationList = await locationFromAddress(widget.dropoffLocation);
      if (dropoffLocationList.isNotEmpty) {
        final dropoffLocation = dropoffLocationList.first;
        setState(() {
          _dropoffLatLng = LatLng(dropoffLocation.latitude, dropoffLocation.longitude);
          _markers.add(
            Marker(
              markerId: const MarkerId('dropoff'),
              position: _dropoffLatLng!,
              infoWindow: InfoWindow(
                title: 'Dropoff Location',
                snippet: widget.dropoffLocation,
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            ),
          );
        });
      }

      // Get route between pickup and dropoff locations
      if (_pickupLatLng != null && _dropoffLatLng != null) {
        await _getRoute(_pickupLatLng!, _dropoffLatLng!);
      }
    } catch (e) {
      print('Error initializing locations: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          // Route information
          if (_routeDistance != null && _routeDuration != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text(
                        'Distance',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        _routeDistance!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text(
                        'Duration',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        _routeDuration!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Map
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _pickupLatLng ?? const LatLng(3.1390, 101.6869), // Default to KL
                zoom: 15,
              ),
              onMapCreated: (controller) => _mapController = controller,
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              mapToolbarEnabled: false,
            ),
          ),
        ],
      ),
    );
  }
} 