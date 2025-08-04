import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String kGoogleApiKey = 'AIzaSyAE4jbrjU5QiNVa2EvocVgFdsR__c-kCRE';

Future<List<LatLng>> getRoutePolyline(LatLng origin, LatLng destination) async {
  final url =
      'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$kGoogleApiKey';
  final response = await http.get(Uri.parse(url));
  final data = json.decode(response.body);

  if (data['status'] == 'OK') {
    final points = data['routes'][0]['overview_polyline']['points'];
    return decodePolyline(points);
  }
  return [];
}

List<LatLng> decodePolyline(String encoded) {
  List<LatLng> polyline = [];
  int index = 0, len = encoded.length;
  int lat = 0, lng = 0;

  while (index < len) {
    int b, shift = 0, result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lng += dlng;

    polyline.add(LatLng(lat / 1E5, lng / 1E5));
  }
  return polyline;
}

class CarpoolMapWidget extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> eventData;

  const CarpoolMapWidget({
    super.key,
    required this.eventId,
    required this.eventData,
  });

  @override
  State<CarpoolMapWidget> createState() => _CarpoolMapWidgetState();
}

class _CarpoolMapWidgetState extends State<CarpoolMapWidget> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  BitmapDescriptor? _blueMarkerIcon;

  @override
  void initState() {
    super.initState();
    _loadBlueMarkerIcon();
    _loadMapData();
  }

  Future<void> _loadBlueMarkerIcon() async {
    final icon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/images/bluemarker.png',
    );
    setState(() {
      _blueMarkerIcon = icon;
    });
  }

  void _loadMapData() {
    // Listen to driver offers for this event
    FirebaseFirestore.instance
        .collection('driverOffers')
        .where('eventId', isEqualTo: widget.eventId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snapshot) {
      _updateMapMarkers(snapshot.docs);
    });
  }

  void _updateMapMarkers(List<QueryDocumentSnapshot> offers) async {
    final Set<Marker> markers = {};

    // Get event coordinates
    final eventLocation = widget.eventData['location'] as Map<String, dynamic>?;
    final eventCoordinates = eventLocation?['coordinates'] as Map<String, dynamic>?;
    double eventLat = 3.1390; // Default to Malaysia
    double eventLng = 101.6869;
    if (eventCoordinates != null) {
      eventLat = (eventCoordinates['latitude'] as num?)?.toDouble() ?? 3.1390;
      eventLng = (eventCoordinates['longitude'] as num?)?.toDouble() ?? 101.6869;
    }
    // Add event location marker
    markers.add(
      Marker(
        markerId: const MarkerId('event'),
        position: LatLng(eventLat, eventLng),
        infoWindow: InfoWindow(
          title: 'Event Location',
          snippet: eventLocation?['address'] ?? 'Event destination',
        ),
        icon: BitmapDescriptor.defaultMarker,
      ),
    );

    // Add meetup location marker if available
    final meetupLocation = widget.eventData['meetingPoint'] as Map<String, dynamic>?;
    final meetupCoordinates = meetupLocation?['coordinates'] as Map<String, dynamic>?;
    if (meetupCoordinates != null) {
      final meetupLat = (meetupCoordinates['latitude'] as num?)?.toDouble();
      final meetupLng = (meetupCoordinates['longitude'] as num?)?.toDouble();
      if (meetupLat != null && meetupLng != null) {
        markers.add(
          Marker(
            markerId: const MarkerId('meetup'),
            position: LatLng(meetupLat, meetupLng),
            infoWindow: InfoWindow(
              title: 'Meetup Point',
              snippet: meetupLocation?['address'] ?? 'Meetup location',
            ),
            icon: BitmapDescriptor.defaultMarker,
          ),
        );
      }
    }

    // Add pickup point markers
    for (int i = 0; i < offers.length; i++) {
      final offerData = offers[i].data() as Map<String, dynamic>;
      final driverName = offerData['driverName'] ?? 'Unknown';
      final pickupLocation = offerData['pickupLocation'] ?? '';
      final passengers = List<String>.from(offerData['passengers'] ?? []);
      LatLng? pickupLatLng;
      final pickupCoordinates = offerData['pickupCoordinates'] as Map<String, dynamic>?;
      if (pickupCoordinates != null) {
        final lat = pickupCoordinates['latitude'];
        final lng = pickupCoordinates['longitude'];
        if (lat != null && lng != null) {
          pickupLatLng = LatLng((lat as num).toDouble(), (lng as num).toDouble());
        }
      }
      if (pickupLatLng != null) {
        markers.add(
          Marker(
            markerId: MarkerId('pickup_$i'),
            position: pickupLatLng,
            infoWindow: InfoWindow(
              title: 'Pickup Point: $driverName',
              snippet: 'Location: $pickupLocation • Passengers: ${passengers.length}',
            ),
            icon: BitmapDescriptor.defaultMarker,
          ),
        );
      }
    }

    setState(() {
      _markers = markers;
      _polylines = {}; // No polylines
    });

    if (_mapController != null && markers.isNotEmpty) {
      _fitMapToMarkers(markers);
    }
  }

  void _fitMapToMarkers(Set<Marker> markers) {
    if (markers.isEmpty) return;

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (final marker in markers) {
      minLat = min(minLat, marker.position.latitude);
      maxLat = max(maxLat, marker.position.latitude);
      minLng = min(minLng, marker.position.longitude);
      maxLng = max(maxLng, marker.position.longitude);
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat - 0.01, minLng - 0.01),
      northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  @override
  Widget build(BuildContext context) {
    final eventLocation = widget.eventData['location'] as Map<String, dynamic>?;
    final eventCoordinates = eventLocation?['coordinates'] as Map<String, dynamic>?;
    
    double initialLat = 3.1390; // Default to Malaysia
    double initialLng = 101.6869;
    
    if (eventCoordinates != null) {
      initialLat = (eventCoordinates['latitude'] as num?)?.toDouble() ?? 3.1390;
      initialLng = (eventCoordinates['longitude'] as num?)?.toDouble() ?? 101.6869;
    }

    return Container(
      height: 400,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(initialLat, initialLng),
            zoom: 10,
          ),
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
            if (_markers.isNotEmpty) {
              _fitMapToMarkers(_markers);
            }
          },
          markers: _markers,
          polylines: _polylines,
          mapType: MapType.normal,
          zoomControlsEnabled: true,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          compassEnabled: true,
          mapToolbarEnabled: false,
        ),
      ),
    );
  }
} 