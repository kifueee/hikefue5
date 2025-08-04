import 'package:cloud_firestore/cloud_firestore.dart';

class EventCategory {
  final String id;
  final String name;
  final String description;
  final String icon;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  EventCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EventCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EventCategory(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      icon: data['icon'] ?? 'event',
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'icon': icon,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
} 