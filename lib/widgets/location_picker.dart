import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_places_flutter/google_places_flutter.dart' as mobile_places;
import 'package:google_places_flutter/model/prediction.dart' as mobile_prediction;
import 'dart:ui' as ui;
import 'dart:html' as html;

class LocationPicker extends StatefulWidget {
  final String label;
  final String hint;
  final IconData icon;
  final Color iconColor;
  final Function(String, LatLng) onLocationSelected;
  final String? initialValue;
  final Set<Marker>? extraMarkers;
  final String searchBoxId;

  const LocationPicker({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.iconColor,
    required this.onLocationSelected,
    this.initialValue,
    this.extraMarkers,
    required this.searchBoxId,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  static const String _apiKey = 'AIzaSyAE4jbrjU5QiNVa2EvocVgFdsR__c-kCRE';
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  Set<Marker> _markers = {};
  late final String _searchBoxId;

  @override
  void initState() {
    super.initState();
    // Reset controller state
    _mapController = null;
    _selectedLocation = null;
    _markers.clear();
    
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
    _getCurrentLocation();
    _searchBoxId = widget.searchBoxId;
    if (kIsWeb) {
      // Register the view factory only once
      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(
        _searchBoxId,
        (int viewId) {
          final input = html.InputElement()
            ..id = _searchBoxId
            ..style.width = '100%'
            ..style.height = '40px'
            ..style.fontSize = '16px'
            ..placeholder = widget.hint;
          return input;
        },
      );
      // Listen for place selection from JS
      html.window.addEventListener('$_searchBoxId-selected', (event) {
        final customEvent = event as html.CustomEvent;
        final detail = customEvent.detail;
        final address = detail['address'] as String;
        final lat = detail['lat'] as num;
        final lng = detail['lng'] as num;
        setState(() {
          _controller.text = address;
          _selectedLocation = LatLng(lat.toDouble(), lng.toDouble());
        });
        widget.onLocationSelected(address, _selectedLocation!);
        _updateMarkers();
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_selectedLocation!, 15),
        );
      });
      // Call JS to initialize autocomplete after a short delay
      Future.delayed(Duration(milliseconds: 500), () {
        html.window.dispatchEvent(html.CustomEvent('init-autocomplete', detail: {'id': _searchBoxId, 'country': 'my'}));
      });
    }
  }

  @override
  void didUpdateWidget(LocationPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset autocomplete when widget is updated
    if (oldWidget.searchBoxId != widget.searchBoxId) {
      _resetAutocomplete();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    // Properly dispose the map controller
    if (_mapController != null) {
      _mapController!.dispose();
      _mapController = null;
    }
    // Clean up web-specific event listeners and autocomplete
    if (kIsWeb) {
      try {
        html.window.removeEventListener('$_searchBoxId-selected', (event) {});
        // Clean up autocomplete instance
        html.window.dispatchEvent(html.CustomEvent('cleanup-autocomplete', detail: {'id': _searchBoxId}));
      } catch (e) {
        // Ignore errors during cleanup
      }
    }
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition();
      _selectedLocation = LatLng(position.latitude, position.longitude);
      
      // Get address from coordinates
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address = [
          if (place.street?.isNotEmpty ?? false) place.street,
          if (place.locality?.isNotEmpty ?? false) place.locality,
          if (place.administrativeArea?.isNotEmpty ?? false) place.administrativeArea,
        ].where((s) => s != null).join(', ');

        _controller.text = address;
        widget.onLocationSelected(address, _selectedLocation!);
        _updateMarkers();
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_selectedLocation!, 15),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateMarkers() {
    if (_selectedLocation != null) {
      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId('selected_location'),
            position: _selectedLocation!,
            infoWindow: InfoWindow(
              title: _controller.text,
              snippet: 'Selected location',
            ),
          ),
        };
      });
    }
  }

  void _resetAutocomplete() {
    if (kIsWeb) {
      try {
        // Clear the input field
        final inputElement = html.document.getElementById(_searchBoxId) as html.InputElement?;
        if (inputElement != null) {
          inputElement.value = '';
        }
        // Clean up existing autocomplete instance
        html.window.dispatchEvent(html.CustomEvent('cleanup-autocomplete', detail: {'id': _searchBoxId}));
        // Re-initialize autocomplete
        Future.delayed(Duration(milliseconds: 100), () {
          html.window.dispatchEvent(html.CustomEvent('init-autocomplete', detail: {'id': _searchBoxId, 'country': 'my'}));
        });
      } catch (e) {
        print('Error resetting autocomplete: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (kIsWeb)
          SizedBox(
            height: 40,
            child: HtmlElementView(viewType: _searchBoxId),
          )
        else
          mobile_places.GooglePlaceAutoCompleteTextField(
            googleAPIKey: _apiKey,
            textEditingController: _controller,
            countries: const ['my'],
            inputDecoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: Icon(widget.icon, color: widget.iconColor),
              border: const OutlineInputBorder(),
            ),
            debounceTime: 800,
            isLatLngRequired: true,
            getPlaceDetailWithLatLng: (prediction) async {
              if (prediction.lat != null && prediction.lng != null) {
                _selectedLocation = LatLng(
                  double.parse(prediction.lat!),
                  double.parse(prediction.lng!),
                );
                _controller.text = prediction.description ?? '';
                widget.onLocationSelected(prediction.description ?? '', _selectedLocation!);
                _updateMarkers();
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(_selectedLocation!, 15),
                );
              }
            },
            itemClick: (prediction) async {
              if (prediction.lat != null && prediction.lng != null) {
                _selectedLocation = LatLng(
                  double.parse(prediction.lat!),
                  double.parse(prediction.lng!),
                );
                _controller.text = prediction.description ?? '';
                widget.onLocationSelected(prediction.description ?? '', _selectedLocation!);
                _updateMarkers();
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(_selectedLocation!, 15),
                );
              }
            },
          ),
        const SizedBox(height: 12),
        SizedBox(
          height: 250,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _selectedLocation ?? const LatLng(3.139, 101.6869), // Default to Kuala Lumpur
                zoom: 15,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
              },
              markers: widget.extraMarkers != null
                  ? {..._markers, ...widget.extraMarkers!}
                  : _markers,
              onTap: (LatLng position) async {
                _selectedLocation = position;
                try {
                  final placemarks = await placemarkFromCoordinates(
                    position.latitude,
                    position.longitude,
                  );
                  if (placemarks.isNotEmpty) {
                    final place = placemarks.first;
                    final address = [
                      if (place.street?.isNotEmpty ?? false) place.street,
                      if (place.locality?.isNotEmpty ?? false) place.locality,
                      if (place.administrativeArea?.isNotEmpty ?? false) place.administrativeArea,
                    ].where((s) => s != null).join(', ');
                    _controller.text = address;
                    widget.onLocationSelected(address, _selectedLocation!);
                  } else {
                    _controller.text = '${position.latitude}, ${position.longitude}';
                    widget.onLocationSelected(_controller.text, _selectedLocation!);
                  }
                } catch (e) {
                  _controller.text = '${position.latitude}, ${position.longitude}';
                  widget.onLocationSelected(_controller.text, _selectedLocation!);
                }
                _updateMarkers();
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              mapToolbarEnabled: true,
            ),
          ),
        ),
      ],
    );
  }
} 