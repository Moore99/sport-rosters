import 'package:cloud_firestore/cloud_firestore.dart';

class Sport {
  final String sportId;
  final String name;
  final List<String> positions;
  /// Named position categories, e.g. {'Forward': ['Left Wing', 'Right Wing', 'Centre']}.
  final Map<String, List<String>> categories;

  const Sport({
    required this.sportId,
    required this.name,
    required this.positions,
    required this.categories,
  });

  factory Sport.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Sport(
      sportId:    doc.id,
      name:       d['name'] as String? ?? '',
      positions:  List<String>.from(d['positions'] as List? ?? []),
      categories: (d['categories'] as Map? ?? {}).map(
        (k, v) => MapEntry(k as String, List<String>.from(v as List? ?? [])),
      ),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name':       name,
    'positions':  positions,
    'categories': categories,
  };

  Map<String, dynamic> toJson() => toFirestore();

  factory Sport.fromJson(Map<String, dynamic> json) => Sport(
    sportId:    json['sportId'] as String? ?? '',
    name:       json['name'] as String? ?? '',
    positions:  List<String>.from(json['positions'] as List? ?? []),
    categories: (json['categories'] as Map? ?? {}).map(
      (k, v) => MapEntry(k as String, List<String>.from(v as List? ?? [])),
    ),
  );
}
