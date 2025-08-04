import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'notification_triggers.dart';

enum CarpoolStatus {
  active,
  completed,
  cancelled,
  expired
}

class CarpoolValidationError implements Exception {
  final String message;
  CarpoolValidationError(this.message);
  @override
  String toString() => message;
}

class DriverOffer {
  final String id;
  final String driverId;
  final String driverName;
  final String eventId;
  final String pickupLocation;
  final String dropoffLocation;
  final DateTime departureTime;
  final int availableSeats;
  final double price;
  final CarpoolStatus status;
  final Map<String, dynamic>? route;
  final double? distanceInKm;
  final int? durationInMinutes;
  final String vehicleDetails;
  final Map<String, dynamic>? pickupCoordinates;
  final Map<String, dynamic>? dropoffCoordinates;

  DriverOffer({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.eventId,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.departureTime,
    required this.availableSeats,
    required this.price,
    required this.status,
    required this.vehicleDetails,
    this.route,
    this.distanceInKm,
    this.durationInMinutes,
    this.pickupCoordinates,
    this.dropoffCoordinates,
  });

  factory DriverOffer.fromMap(String id, Map<String, dynamic> data) {
    return DriverOffer(
      id: id,
      driverId: data['driverId'],
      driverName: data['driverName'],
      eventId: data['eventId'],
      pickupLocation: data['pickupLocation'],
      dropoffLocation: data['dropoffLocation'],
      departureTime: (data['departureTime'] as Timestamp).toDate(),
      availableSeats: data['availableSeats'],
      price: data['costPerPerson'].toDouble(),
      status: CarpoolStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => CarpoolStatus.active,
      ),
      vehicleDetails: data['vehicleDetails'] ?? 'No vehicle details',
      route: data['route'],
      distanceInKm: data['distanceInKm']?.toDouble(),
      durationInMinutes: data['durationInMinutes']?.toInt(),
      pickupCoordinates: data['pickupCoordinates'] as Map<String, dynamic>?,
      dropoffCoordinates: data['dropoffCoordinates'] as Map<String, dynamic>?,
    );
  }
}

class CarpoolRequest {
  final String id;
  final String userId;
  final String userName;
  final String eventId;
  final String pickupLocation;
  final String dropoffLocation;
  final DateTime requestedTime;
  final int numberOfPassengers;
  final String? notes;
  final CarpoolStatus status;
  final Map<String, dynamic>? pickupCoordinates;
  final Map<String, dynamic>? dropoffCoordinates;

  CarpoolRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.eventId,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.requestedTime,
    required this.numberOfPassengers,
    this.notes,
    required this.status,
    this.pickupCoordinates,
    this.dropoffCoordinates,
  });

  factory CarpoolRequest.fromMap(String id, Map<String, dynamic> data) {
    return CarpoolRequest(
      id: id,
      userId: data['userId'],
      userName: data['userName'],
      eventId: data['eventId'],
      pickupLocation: data['pickupLocation'],
      dropoffLocation: data['dropoffLocation'],
      requestedTime: (data['requestedTime'] as Timestamp).toDate(),
      numberOfPassengers: data['numberOfPassengers'],
      notes: data['notes'],
      status: CarpoolStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => CarpoolStatus.active,
      ),
      pickupCoordinates: data['pickupCoordinates'] as Map<String, dynamic>?,
      dropoffCoordinates: data['dropoffCoordinates'] as Map<String, dynamic>?,
    );
  }
}

class CarpoolPassenger {
  final String id;
  final String name;
  final String email;
  final int numberOfPassengers;
  final DateTime joinedAt;
  final String? notes;

  CarpoolPassenger({
    required this.id,
    required this.name,
    required this.email,
    required this.numberOfPassengers,
    required this.joinedAt,
    this.notes,
  });

  factory CarpoolPassenger.fromMap(String id, Map<String, dynamic> data) {
    return CarpoolPassenger(
      id: id,
      name: data['name'],
      email: data['email'],
      numberOfPassengers: data['numberOfPassengers'],
      joinedAt: (data['joinedAt'] as Timestamp).toDate(),
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'numberOfPassengers': numberOfPassengers,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'notes': notes,
    };
  }
}

class CarpoolMatchingService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Create a new driver offer
  Future<void> createDriverOffer({
    required String eventId,
    required String pickupLocation,
    required String dropoffLocation,
    required DateTime departureTime,
    required int availableSeats,
    required double costPerPerson,
    required String vehicleDetails,
    Map<String, dynamic>? route,
    double? distanceInKm,
    int? durationInMinutes,
    String? notes,
    Map<String, dynamic>? pickupCoordinates,
    Map<String, dynamic>? dropoffCoordinates,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw CarpoolValidationError('User must be logged in');

    print('Creating driver offer for event: $eventId');
    print('User ID: ${user.uid}');
    print('Pickup: $pickupLocation');
    print('Dropoff: $dropoffLocation');
    print('Departure: $departureTime');
    print('Seats: $availableSeats');
    print('Cost: $costPerPerson');

    // Validate input parameters
    if (availableSeats <= 0) {
      throw CarpoolValidationError('Available seats must be greater than 0');
    }
    if (costPerPerson <= 0) {
      throw CarpoolValidationError('Cost per person must be greater than 0');
    }
    if (departureTime.isBefore(DateTime.now())) {
      throw CarpoolValidationError('Departure time must be in the future');
    }
    if (pickupLocation.isEmpty) {
      throw CarpoolValidationError('Pickup location is required');
    }
    if (dropoffLocation.isEmpty) {
      throw CarpoolValidationError('Dropoff location is required');
    }
    if (vehicleDetails.isEmpty) {
      throw CarpoolValidationError('Vehicle details are required');
    }

    try {
      // Get user profile to get the name
      String? driverName;
      String? userRole;
      
      // Check both collections for the user
      final organizerDoc = await _firestore.collection('organizers').doc(user.uid).get();
      final participantDoc = await _firestore.collection('participants').doc(user.uid).get();
      
      if (organizerDoc.exists) {
        final data = organizerDoc.data()!;
        driverName = data['name'];
        userRole = 'organizer';
        print('Found user in organizers collection: $driverName');
      } else if (participantDoc.exists) {
        final data = participantDoc.data()!;
        driverName = data['name'];
        userRole = 'participant';
        print('Found user in participants collection: $driverName');
      }
      
      // If user profile doesn't exist in either collection, create one in participants
      if (driverName == null) {
        print('User profile not found, creating new participant profile');
        await _createUserProfile(user);
        driverName = user.displayName ?? user.email?.split('@')[0] ?? 'Anonymous';
        userRole = 'participant';
      }

      final offerData = {
        'eventId': eventId,
        'driverId': user.uid,
        'driverEmail': user.email,
        'driverName': driverName,
        'pickupLocation': pickupLocation,
        'dropoffLocation': dropoffLocation,
        'pickupCoordinates': pickupCoordinates,
        'dropoffCoordinates': dropoffCoordinates,
        'departureTime': Timestamp.fromDate(departureTime),
        'availableSeats': availableSeats,
        'costPerPerson': costPerPerson,
        'vehicleDetails': vehicleDetails,
        'notes': notes,
        'status': CarpoolStatus.active.toString().split('.').last,
        'route': route,
        'distanceInKm': distanceInKm,
        'durationInMinutes': durationInMinutes,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      print('Adding driver offer to Firestore...');
      final docRef = await _firestore.collection('driverOffers').add(offerData);
      print('Driver offer created with ID: ${docRef.id}');
      
      // Verify the offer was created
      final createdDoc = await docRef.get();
      if (!createdDoc.exists) {
        throw Exception('Failed to create driver offer');
      }
      print('Driver offer verified in database');
    } catch (e) {
      print('Error creating driver offer: $e');
      if (e is CarpoolValidationError) rethrow;
      throw Exception('Failed to create driver offer: $e');
    }
  }

  Future<void> _createUserProfile(User user, {String role = 'participant'}) async {
    String collection = role == 'organizer' ? 'organizers' : (role == 'admin' ? 'admins' : 'participants');
    await _firestore.collection(collection).doc(user.uid).set({
      'name': user.displayName ?? user.email?.split('@')[0] ?? 'Anonymous',
      'email': user.email,
      'phone': '',
      'gender': 'Not specified',
      'profilePicture': '',
      'rating': 0.0,
      'totalRides': 0,
      'preferences': {
        'notifications': true,
        'language': 'English',
        'darkMode': false,
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
  }

  // Get available driver offers for an event
  Stream<List<DriverOffer>> getAvailableDriverOffersForEvent(String eventId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    print('Getting available driver offers for event: $eventId');
    print('Current user ID: ${user.uid}');

    return _firestore
        .collection('driverOffers')
        .where('eventId', isEqualTo: eventId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .asyncMap((snapshot) async {
          print('Received ${snapshot.docs.length} driver offers from Firestore');
          final offers = snapshot.docs.map((doc) {
            final data = doc.data();
            print('Processing offer ID: ${doc.id}');
            print('Offer driver ID: ${data['driverId']}');
            print('Offer status: ${data['status']}');
            print('Offer event ID: ${data['eventId']}');
            print('Offer pickup: ${data['pickupLocation']}');
            print('Offer dropoff: ${data['dropoffLocation']}');
            print('Offer departure: ${data['departureTime']}');
            print('Offer seats: ${data['availableSeats']}');
            print('Offer cost: ${data['costPerPerson']}');
            print('Offer driver name: ${data['driverName']}');
            return DriverOffer(
              id: doc.id,
              driverId: data['driverId'] ?? '',
              driverName: data['driverName'] ?? 'Unknown Driver',
              eventId: data['eventId'] ?? '',
              pickupLocation: data['pickupLocation'] ?? 'Unknown Pickup',
              dropoffLocation: data['dropoffLocation'] ?? 'Unknown Dropoff',
              departureTime: data['departureTime'] != null ? (data['departureTime'] as Timestamp).toDate() : DateTime.now(),
              availableSeats: data['availableSeats'] ?? 0,
              price: (data['costPerPerson'] ?? 0.0).toDouble(),
              status: CarpoolStatus.values.firstWhere(
                (e) => e.toString().split('.').last == data['status'],
                orElse: () => CarpoolStatus.active,
              ),
              vehicleDetails: data['vehicleDetails'] ?? 'No vehicle details',
              route: data['route'] != null ? Map<String, dynamic>.from(data['route']) : null,
              distanceInKm: data['distanceInKm']?.toDouble(),
              durationInMinutes: data['durationInMinutes']?.toInt(),
              pickupCoordinates: data['pickupCoordinates'] as Map<String, dynamic>?,
              dropoffCoordinates: data['dropoffCoordinates'] as Map<String, dynamic>?,
            );
          }).toList();
          
          // Sort by departure time manually since we removed the orderBy clause
          offers.sort((a, b) => a.departureTime.compareTo(b.departureTime));
          
          // Filter out the current user's offers
          final offersExcludingUserAsDriver = offers.where((offer) => offer.driverId != user.uid).toList();
          print('Filtered to ${offersExcludingUserAsDriver.length} available offers (excluding user\'s own offers)');
          print('User\'s own offers: ${offers.where((offer) => offer.driverId == user.uid).length}');
          
          // Get all active carpools for this event to check if user is already a passenger
          final carpoolsSnapshot = await _firestore
              .collection('carpools')
              .where('eventId', isEqualTo: eventId)
              .where('status', isEqualTo: 'active')
              .get();
          
          // Check which carpools the user is a passenger in
          final Set<String> joinedDriverIds = {};
          for (final carpoolDoc in carpoolsSnapshot.docs) {
            final passengersSnapshot = await carpoolDoc.reference
                .collection('passengers')
                .where('userId', isEqualTo: user.uid)
                .get();
            
            if (passengersSnapshot.docs.isNotEmpty) {
              final carpoolData = carpoolDoc.data();
              final driverId = carpoolData['driverId'] as String?;
              if (driverId != null) {
                joinedDriverIds.add(driverId);
              }
            }
          }
          
          // Filter out offers from drivers where user is already a passenger
          final finalFilteredOffers = offersExcludingUserAsDriver.where((offer) => 
            !joinedDriverIds.contains(offer.driverId)
          ).toList();
          
          print('Final filtered offers: ${finalFilteredOffers.length} (excluding joined carpools)');
          print('User is passenger in carpools with drivers: $joinedDriverIds');
          return finalFilteredOffers;
        }).handleError((error) {
          print('Error fetching driver offers: $error');
          return <DriverOffer>[];
        });
  }

  // Get user's active driver offers
  Stream<List<DriverOffer>> getUserDriverOffers(String eventId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    print('Getting user driver offers for event: $eventId');
    print('Current user ID: ${user.uid}');

    return _firestore
        .collection('driverOffers')
        .where('eventId', isEqualTo: eventId)
        .where('driverId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
          print('Received ${snapshot.docs.length} user driver offers from Firestore');
          final offers = snapshot.docs.map((doc) {
            final data = doc.data();
            print('Processing user offer ID: ${doc.id}');
            print('User offer driver ID: ${data['driverId']}');
            print('User offer status: ${data['status']}');
            print('User offer event ID: ${data['eventId']}');
            print('User offer pickup: ${data['pickupLocation']}');
            print('User offer dropoff: ${data['dropoffLocation']}');
            print('User offer departure: ${data['departureTime']}');
            print('User offer seats: ${data['availableSeats']}');
            print('User offer cost: ${data['costPerPerson']}');
            print('User offer driver name: ${data['driverName']}');
            return DriverOffer(
              id: doc.id,
              driverId: data['driverId'] ?? '',
              driverName: data['driverName'] ?? 'Unknown Driver',
              eventId: data['eventId'] ?? '',
              pickupLocation: data['pickupLocation'] ?? 'Unknown Pickup',
              dropoffLocation: data['dropoffLocation'] ?? 'Unknown Dropoff',
              departureTime: data['departureTime'] != null ? (data['departureTime'] as Timestamp).toDate() : DateTime.now(),
              availableSeats: data['availableSeats'] ?? 0,
              price: (data['costPerPerson'] ?? 0.0).toDouble(),
              status: CarpoolStatus.values.firstWhere(
                (e) => e.toString().split('.').last == data['status'],
                orElse: () => CarpoolStatus.active,
              ),
              vehicleDetails: data['vehicleDetails'] ?? 'No vehicle details',
              route: data['route'] != null ? Map<String, dynamic>.from(data['route']) : null,
              distanceInKm: data['distanceInKm']?.toDouble(),
              durationInMinutes: data['durationInMinutes']?.toInt(),
              pickupCoordinates: data['pickupCoordinates'] as Map<String, dynamic>?,
              dropoffCoordinates: data['dropoffCoordinates'] as Map<String, dynamic>?,
            );
          }).toList();
          
          // Sort by departure time manually since we removed the orderBy clause
          offers.sort((a, b) => a.departureTime.compareTo(b.departureTime));
          
          print('Returning ${offers.length} sorted user offers');
          return offers;
        }).handleError((error) {
          print('Error fetching user driver offers: $error');
          return <DriverOffer>[];
        });
  }

  // Accept a driver offer with multiple passengers (creates a request for driver approval)
  Future<void> acceptDriverOffer(String offerId, int numberOfPassengers, {String? notes}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in');

    final offerRef = _firestore.collection('driverOffers').doc(offerId);
    final offerDoc = await offerRef.get();
    
    if (!offerDoc.exists) {
      throw Exception('Offer not found');
    }

    final offer = offerDoc.data()!;
    if (offer['status'] != 'active') {
      throw Exception('Offer is no longer available');
    }

    if (offer['availableSeats'] < numberOfPassengers) {
      throw Exception('Not enough seats available. Only ${offer['availableSeats']} seats left.');
    }

    // Check if user already has a pending or approved request for this offer
    final existingRequest = await _firestore
        .collection('passengerRequests')
        .where('passengerId', isEqualTo: user.uid)
        .where('offerId', isEqualTo: offerId)
        .where('status', whereIn: ['pending', 'approved'])
        .get();
    
    if (existingRequest.docs.isNotEmpty) {
      throw Exception('You already have a pending or approved request for this ride');
    }

    // Get user profile to get the name
    String? userName;
    final organizerDoc = await _firestore.collection('organizers').doc(user.uid).get();
    final participantDoc = await _firestore.collection('participants').doc(user.uid).get();
    
    if (organizerDoc.exists) {
      userName = organizerDoc.data()!['name'];
    } else if (participantDoc.exists) {
      userName = participantDoc.data()!['name'];
    } else {
      userName = user.displayName ?? user.email?.split('@')[0] ?? 'Anonymous';
    }

    // Create a passenger request instead of directly joining
    await _firestore.collection('passengerRequests').add({
      'passengerId': user.uid,
      'passengerName': userName,
      'passengerEmail': user.email,
      'offerId': offerId,
      'driverId': offer['driverId'],
      'eventId': offer['eventId'],
      'numberOfPassengers': numberOfPassengers,
      'notes': notes,
      'status': 'pending',
      'requestedAt': FieldValue.serverTimestamp(),
      'pickupPreference': 'exact', // Default, should be passed from UI
      'contactShared': true, // Default, should be passed from UI
    });

    // Trigger notification for driver about new request
    try {
      await NotificationTriggers.onPassengerRequestedJoin(
        offer['eventId'],
        'Event', // You might want to get the actual event name
        userName ?? 'Anonymous',
        numberOfPassengers,
        offer['driverId'], // Pass the driver ID
      );
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  // New method: Driver approves a passenger request
  Future<void> approvePassengerRequest(String requestId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in');

    final requestRef = _firestore.collection('passengerRequests').doc(requestId);
    final requestDoc = await requestRef.get();
    
    if (!requestDoc.exists) {
      throw Exception('Request not found');
    }

    final request = requestDoc.data()!;
    if (request['driverId'] != user.uid) {
      throw Exception('Not authorized to approve this request');
    }

    if (request['status'] != 'pending') {
      throw Exception('Request is no longer pending');
    }

    // Get the offer details
    final offerRef = _firestore.collection('driverOffers').doc(request['offerId']);
    final offerDoc = await offerRef.get();
    
    if (!offerDoc.exists) {
      throw Exception('Original offer not found');
    }

    final offer = offerDoc.data()!;
    final numberOfPassengers = request['numberOfPassengers'] as int;

    // Check if still enough seats available
    if (offer['availableSeats'] < numberOfPassengers) {
      throw Exception('Not enough seats available anymore');
    }

    // Create or update carpool
    QuerySnapshot existingCarpools = await _firestore
        .collection('carpools')
        .where('driverId', isEqualTo: user.uid)
        .where('eventId', isEqualTo: request['eventId'])
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    DocumentReference carpoolRef;
    
    if (existingCarpools.docs.isEmpty) {
      // Create new carpool
      carpoolRef = await _firestore.collection('carpools').add({
        'eventId': offer['eventId'],
        'driverId': offer['driverId'],
        'driverEmail': offer['driverEmail'],
        'driverName': offer['driverName'],
        'pickupLocation': offer['pickupLocation'],
        'dropoffLocation': offer['dropoffLocation'],
        'departureTime': offer['departureTime'],
        'costPerPerson': offer['costPerPerson'],
        'vehicleDetails': offer['vehicleDetails'],
        'route': offer['route'],
        'distanceInKm': offer['distanceInKm'],
        'durationInMinutes': offer['durationInMinutes'],
        'status': 'active',
        'totalSeats': offer['availableSeats'],
        'availableSeats': offer['availableSeats'] - numberOfPassengers,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Use existing carpool
      carpoolRef = existingCarpools.docs.first.reference;
      final carpoolData = existingCarpools.docs.first.data() as Map<String, dynamic>;
      
      // Update available seats
      await carpoolRef.update({
        'availableSeats': carpoolData['availableSeats'] - numberOfPassengers,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Add passenger to the carpool
    await carpoolRef.collection('passengers').add({
      'userId': request['passengerId'],
      'name': request['passengerName'],
      'email': request['passengerEmail'],
      'numberOfPassengers': numberOfPassengers,
      'joinedAt': FieldValue.serverTimestamp(),
      'notes': request['notes'],
      'requestId': requestId,
    });

    // Update request status
    await requestRef.update({
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
      'carpoolId': carpoolRef.id,
    });

    // Update the offer's available seats
    final newAvailableSeats = offer['availableSeats'] - numberOfPassengers;
    if (newAvailableSeats <= 0) {
      await offerRef.update({
        'status': 'completed',
        'availableSeats': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await offerRef.update({
        'availableSeats': newAvailableSeats,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Notify passenger of approval
    try {
      await NotificationTriggers.onRequestApproved(
        request['eventId'],
        'Event',
        request['passengerName'],
        request['passengerId'],
      );
    } catch (e) {
      debugPrint('Error sending approval notification: $e');
    }
  }

  // New method: Driver declines a passenger request
  Future<void> declinePassengerRequest(String requestId, {String? reason}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in');

    final requestRef = _firestore.collection('passengerRequests').doc(requestId);
    final requestDoc = await requestRef.get();
    
    if (!requestDoc.exists) {
      throw Exception('Request not found');
    }

    final request = requestDoc.data()!;
    if (request['driverId'] != user.uid) {
      throw Exception('Not authorized to decline this request');
    }

    if (request['status'] != 'pending') {
      throw Exception('Request is no longer pending');
    }

    // Update request status
    await requestRef.update({
      'status': 'declined',
      'declinedAt': FieldValue.serverTimestamp(),
      'declineReason': reason,
    });

    // Notify passenger of decline
    try {
      await NotificationTriggers.onRequestDeclined(
        request['eventId'],
        'Event',
        request['passengerName'],
        request['passengerId'],
        reason,
      );
    } catch (e) {
      debugPrint('Error sending decline notification: $e');
    }
  }

  // Get active carpools for a user (as driver or passenger)
  Stream<List<Map<String, dynamic>>> getActiveCarpoolsForUser() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('carpools')
        .where('status', isEqualTo: 'active')
        .orderBy('departureTime')
        .snapshots()
        .asyncMap((snapshot) async {
          final List<Map<String, dynamic>> allCarpools = [];

          for (var doc in snapshot.docs) {
            final data = doc.data();
            data['id'] = doc.id;

            // Check if user is the driver
            if (data['driverId'] == user.uid) {
              data['userRole'] = 'driver';
              
              // Get passengers for this carpool
              final passengersSnapshot = await doc.reference.collection('passengers').get();
              final passengers = passengersSnapshot.docs.map((passengerDoc) {
                final passengerData = passengerDoc.data();
                passengerData['id'] = passengerDoc.id;
                return passengerData;
              }).toList();
              
              data['passengers'] = passengers;
              allCarpools.add(data);
            } else {
              // Check if user is a passenger in this carpool
              final passengerSnapshot = await doc.reference
                  .collection('passengers')
                  .where('userId', isEqualTo: user.uid)
                  .get();
              
              if (passengerSnapshot.docs.isNotEmpty) {
                data['userRole'] = 'passenger';
                
                // Get all passengers for this carpool
                final allPassengersSnapshot = await doc.reference.collection('passengers').get();
                final passengers = allPassengersSnapshot.docs.map((passengerDoc) {
                  final passengerData = passengerDoc.data();
                  passengerData['id'] = passengerDoc.id;
                  return passengerData;
                }).toList();
                
                data['passengers'] = passengers;
                allCarpools.add(data);
              }
            }
          }

          return allCarpools;
        });
  }

  // Cancel a carpool (for passengers)
  Future<void> cancelCarpool(String carpoolId) async {
    final user = _auth.currentUser;
    if (user == null) throw CarpoolValidationError('User must be logged in');

    final carpoolRef = _firestore.collection('carpools').doc(carpoolId);
    final carpoolDoc = await carpoolRef.get();
    
    if (!carpoolDoc.exists) {
      throw CarpoolValidationError('Carpool not found');
    }

    final carpool = carpoolDoc.data()!;
    final currentStatus = CarpoolStatus.values.firstWhere(
      (e) => e.toString().split('.').last == carpool['status'],
      orElse: () => CarpoolStatus.active,
    );

    if (currentStatus != CarpoolStatus.active) {
      throw CarpoolValidationError('Carpool is no longer active');
    }

    // Check if user is a passenger in this carpool
    final passengerSnapshot = await carpoolRef
        .collection('passengers')
        .where('userId', isEqualTo: user.uid)
        .get();

    if (passengerSnapshot.docs.isEmpty) {
      throw CarpoolValidationError('Not authorized to cancel this carpool');
    }

    final passengerData = passengerSnapshot.docs.first.data();
    final numberOfPassengers = passengerData['numberOfPassengers'] as int;

    // Remove passenger from carpool
    await passengerSnapshot.docs.first.reference.delete();

    // Notify driver about passenger cancellation
    try {
      final passengerName = passengerData['name'] ?? 'A passenger';
      await NotificationTriggers.onPassengerCancelledCarpool(
        carpool['eventId'],
        'Event', // You might want to get the actual event name
        passengerName,
        numberOfPassengers,
        carpool['driverId'],
      );
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }

    // Update carpool available seats
    final newAvailableSeats = carpool['availableSeats'] + numberOfPassengers;
    await carpoolRef.update({
      'availableSeats': newAvailableSeats,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update the original driver offer
    final offerQuery = await _firestore
        .collection('driverOffers')
        .where('eventId', isEqualTo: carpool['eventId'])
        .where('driverId', isEqualTo: carpool['driverId'])
        .where('status', isEqualTo: CarpoolStatus.active.toString().split('.').last)
        .get();

    if (offerQuery.docs.isNotEmpty) {
      final offerRef = offerQuery.docs.first.reference;
      final offer = offerQuery.docs.first.data();
      
      // Increment available seats
      await offerRef.update({
        'availableSeats': offer['availableSeats'] + numberOfPassengers,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Check if carpool has no more passengers, mark as cancelled
    final remainingPassengers = await carpoolRef.collection('passengers').get();
    if (remainingPassengers.docs.isEmpty) {
      await carpoolRef.update({
        'status': CarpoolStatus.cancelled.toString().split('.').last,
        'cancelledBy': user.uid,
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Cancel a ride request
  Future<void> cancelRideRequest(String requestId) async {
    final user = _auth.currentUser;
    if (user == null) throw CarpoolValidationError('User must be logged in');

    final requestRef = _firestore.collection('rideRequests').doc(requestId);
    final requestDoc = await requestRef.get();
    
    if (!requestDoc.exists) {
      throw CarpoolValidationError('Ride request not found');
    }

    final request = requestDoc.data()!;
    final currentStatus = CarpoolStatus.values.firstWhere(
      (e) => e.toString().split('.').last == request['status'],
      orElse: () => CarpoolStatus.active,
    );

    if (currentStatus != CarpoolStatus.active) {
      throw CarpoolValidationError('Ride request is no longer active');
    }

    // Only allow cancellation by the request owner
    if (request['userId'] != user.uid) {
      throw CarpoolValidationError('Not authorized to cancel this ride request');
    }

    // Mark the request as cancelled
    await requestRef.update({
      'status': CarpoolStatus.cancelled.toString().split('.').last,
      'cancelledBy': user.uid,
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Cancel a driver offer
  Future<void> cancelDriverOffer(String offerId) async {
    final user = _auth.currentUser;
    if (user == null) throw CarpoolValidationError('User must be logged in');

    final offerRef = _firestore.collection('driverOffers').doc(offerId);
    final offerDoc = await offerRef.get();
    
    if (!offerDoc.exists) {
      throw CarpoolValidationError('Driver offer not found');
    }

    final offer = offerDoc.data()!;
    final currentStatus = CarpoolStatus.values.firstWhere(
      (e) => e.toString().split('.').last == offer['status'],
      orElse: () => CarpoolStatus.active,
    );

    if (currentStatus != CarpoolStatus.active) {
      throw CarpoolValidationError('Driver offer is no longer active');
    }

    // Only allow cancellation by the driver
    if (offer['driverId'] != user.uid) {
      throw CarpoolValidationError('Not authorized to cancel this driver offer');
    }

    // Mark the offer as cancelled
    await offerRef.update({
      'status': CarpoolStatus.cancelled.toString().split('.').last,
      'cancelledBy': user.uid,
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Check if there are any active carpools using this offer
    final carpoolsQuery = await _firestore
        .collection('carpools')
        .where('eventId', isEqualTo: offer['eventId'])
        .where('driverId', isEqualTo: user.uid)
        .where('status', isEqualTo: CarpoolStatus.active.toString().split('.').last)
        .get();

    // Cancel all associated carpools
    for (var carpoolDoc in carpoolsQuery.docs) {
      await carpoolDoc.reference.update({
        'status': CarpoolStatus.cancelled.toString().split('.').last,
        'cancelledBy': user.uid,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancellationReason': 'Driver cancelled the offer',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Get all passengers in this carpool to notify them
      final passengersSnapshot = await carpoolDoc.reference.collection('passengers').get();
      final passengerIds = passengersSnapshot.docs.map((doc) => doc.data()['userId'] as String).toList();
      
      if (passengerIds.isNotEmpty) {
        try {
          // Get the actual event name
          String eventName = 'Event';
          try {
            final eventDoc = await _firestore.collection('events').doc(offer['eventId']).get();
            if (eventDoc.exists) {
              eventName = eventDoc.data()!['name'] ?? 'Event';
            }
          } catch (eventError) {
            debugPrint('Error getting event name: $eventError');
          }
          
          final driverName = offer['driverName'] ?? 'The driver';
          await NotificationTriggers.onCarpoolCancelled(
            offer['eventId'],
            eventName,
            driverName,
            passengerIds,
          );
          
          debugPrint('✅ Notifications sent to ${passengerIds.length} passengers for carpool cancellation');
        } catch (e) {
          debugPrint('❌ Error sending notifications to passengers: $e');
          // Re-throw to let the calling code know notifications failed
          rethrow;
        }
      }
    }
  }

  // Get available ride requests for an event
  Stream<List<Map<String, dynamic>>> getAvailableRideRequestsForEvent(String eventId) {
    return _firestore
        .collection('rideRequests')
        .where('eventId', isEqualTo: eventId)
        .where('status', isEqualTo: CarpoolStatus.active.toString().split('.').last)
        .orderBy('requestedTime')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  // Update an existing driver offer
  Future<void> updateDriverOffer({
    required String carpoolId,
    required String pickupLocation,
    required String dropoffLocation,
    required DateTime departureTime,
    required int availableSeats,
    required double costPerPerson,
    required String vehicleDetails,
    String? notes,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in');

    // Update the driver offer directly
    final offerRef = _firestore.collection('driverOffers').doc(carpoolId);
    final offerDoc = await offerRef.get();
    
    if (!offerDoc.exists) {
      throw Exception('Ride offer not found');
    }

    final offer = offerDoc.data()!;
    if (offer['status'] != 'active') {
      throw Exception('Ride offer is no longer active');
    }

    // Only allow updates by the driver
    if (offer['driverId'] != user.uid) {
      throw Exception('Not authorized to update this ride offer');
    }

    // Update the driver offer
    await offerRef.update({
      'pickupLocation': pickupLocation,
      'dropoffLocation': dropoffLocation,
      'departureTime': Timestamp.fromDate(departureTime),
      'availableSeats': availableSeats,
      'costPerPerson': costPerPerson,
      'vehicleDetails': vehicleDetails,
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update all associated active carpools
    final carpoolsQuery = await _firestore
        .collection('carpools')
        .where('driverId', isEqualTo: user.uid)
        .where('eventId', isEqualTo: offer['eventId'])
        .where('status', isEqualTo: 'active')
        .get();

    for (var carpoolDoc in carpoolsQuery.docs) {
      await carpoolDoc.reference.update({
        'pickupLocation': pickupLocation,
        'dropoffLocation': dropoffLocation,
        'departureTime': Timestamp.fromDate(departureTime),
        'costPerPerson': costPerPerson,
        'vehicleDetails': vehicleDetails,
        'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Legacy method - use acceptDriverOffer instead
  Future<void> requestRide(String offerId) async {
    await acceptDriverOffer(offerId, 1);
  }

  // Get passengers for a specific carpool
  Stream<List<CarpoolPassenger>> getCarpoolPassengers(String carpoolId) {
    return _firestore
        .collection('carpools')
        .doc(carpoolId)
        .collection('passengers')
        .orderBy('joinedAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CarpoolPassenger.fromMap(doc.id, doc.data()))
            .toList());
  }

  // Get carpool details with passengers
  Future<Map<String, dynamic>?> getCarpoolDetails(String carpoolId) async {
    final carpoolDoc = await _firestore.collection('carpools').doc(carpoolId).get();
    if (!carpoolDoc.exists) return null;

    final carpoolData = carpoolDoc.data()!;
    carpoolData['id'] = carpoolId;

    // Get passengers
    final passengersSnapshot = await carpoolDoc.reference.collection('passengers').get();
    final passengers = passengersSnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();

    carpoolData['passengers'] = passengers;
    return carpoolData;
  }

  // Update carpool status
  Future<void> updateCarpoolStatus(String carpoolId, CarpoolStatus newStatus) async {
    final user = _auth.currentUser;
    if (user == null) throw CarpoolValidationError('User must be logged in');

    final carpoolRef = _firestore.collection('carpools').doc(carpoolId);
    final carpoolDoc = await carpoolRef.get();
    
    if (!carpoolDoc.exists) {
      throw CarpoolValidationError('Carpool not found');
    }

    final carpool = carpoolDoc.data()!;
    final currentStatus = CarpoolStatus.values.firstWhere(
      (e) => e.toString().split('.').last == carpool['status'],
      orElse: () => CarpoolStatus.active,
    );

    // Validate status transition
    if (currentStatus == CarpoolStatus.cancelled || currentStatus == CarpoolStatus.expired) {
      throw CarpoolValidationError('Cannot update status of a cancelled or expired carpool');
    }

    // Only allow status updates by the driver
    if (carpool['driverId'] != user.uid) {
      throw CarpoolValidationError('Not authorized to update this carpool status');
    }

    // Update the carpool status
    await carpoolRef.update({
      'status': newStatus.toString().split('.').last,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // If completing the carpool, update the driver offer
    if (newStatus == CarpoolStatus.completed) {
      final offerQuery = await _firestore
          .collection('driverOffers')
          .where('eventId', isEqualTo: carpool['eventId'])
          .where('driverId', isEqualTo: user.uid)
          .where('status', isEqualTo: CarpoolStatus.active.toString().split('.').last)
          .get();

      if (offerQuery.docs.isNotEmpty) {
        final offerRef = offerQuery.docs.first.reference;
        await offerRef.update({
          'status': CarpoolStatus.completed.toString().split('.').last,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      // Try each collection
      final collections = ['organizers', 'participants', 'admins'];
      for (final collection in collections) {
        final doc = await _firestore.collection(collection).doc(uid).get();
        if (doc.exists) {
          return doc.data();
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      // Try each collection
      final collections = ['organizers', 'participants', 'admins'];
      for (final collection in collections) {
        final doc = await _firestore.collection(collection).doc(uid).get();
        if (doc.exists) {
          await _firestore.collection(collection).doc(uid).update({
            ...data,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      rethrow;
    }
  }
} 