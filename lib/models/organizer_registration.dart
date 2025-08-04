import 'package:cloud_firestore/cloud_firestore.dart';

enum OrganizerStatus {
  pending,
  approved,
  rejected
}

class OrganizerRegistration {
  final String id;
  final String name;
  final String email;
  final String organizationName;
  final String icNumber;
  final String contactNumber;
  final String? experience;
  final OrganizerStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? rejectionReason;
  final String password;

  OrganizerRegistration({
    required this.id,
    required this.name,
    required this.email,
    required this.organizationName,
    required this.icNumber,
    required this.contactNumber,
    this.experience,
    this.status = OrganizerStatus.pending,
    required this.createdAt,
    this.updatedAt,
    this.rejectionReason,
    required this.password,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'organizationName': organizationName,
      'icNumber': icNumber,
      'contactNumber': contactNumber,
      'experience': experience,
      'status': status.toString(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'rejectionReason': rejectionReason,
      'password': password,
    };
  }

  factory OrganizerRegistration.fromMap(String id, Map<String, dynamic> map) {
    return OrganizerRegistration(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      organizationName: map['organizationName'] ?? '',
      icNumber: map['icNumber'] ?? '',
      contactNumber: map['contactNumber'] ?? '',
      experience: map['experience'],
      status: OrganizerStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => OrganizerStatus.pending,
      ),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      rejectionReason: map['rejectionReason'],
      password: map['password'] ?? '',
    );
  }
} 