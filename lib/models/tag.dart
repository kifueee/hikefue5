class Tag {
  final String id;
  final String name;
  final String color; // Hex string, e.g. #FF5733

  Tag({required this.id, required this.name, required this.color});

  factory Tag.fromMap(String id, Map<String, dynamic> data) {
    return Tag(
      id: id,
      name: data['name'] ?? '',
      color: data['color'] ?? '#000000',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'color': color,
    };
  }
} 