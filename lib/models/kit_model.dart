import 'package:cloud_firestore/cloud_firestore.dart';

class KitModel {
  final String id;
  final String name;
  final String description;
  final List<String> imageUrls;
  
  // Listas armazenam Maps com {'id': '...', 'variation': '...', 'quantity': 1}
  final List<Map<String, dynamic>> blanksIds;
  final List<Map<String, dynamic>> cabosIds;
  final List<Map<String, dynamic>> reelSeatsIds;
  final List<Map<String, dynamic>> passadoresIds; 
  final List<Map<String, dynamic>> acessoriosIds;

  KitModel({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrls,
    required this.blanksIds,
    required this.cabosIds,
    required this.reelSeatsIds,
    required this.passadoresIds,
    required this.acessoriosIds,
  });

  factory KitModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return KitModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      blanksIds: List<Map<String, dynamic>>.from(data['blanksIds'] ?? []),
      cabosIds: List<Map<String, dynamic>>.from(data['cabosIds'] ?? []),
      reelSeatsIds: List<Map<String, dynamic>>.from(data['reelSeatsIds'] ?? []),
      passadoresIds: List<Map<String, dynamic>>.from(data['passadoresIds'] ?? []),
      acessoriosIds: List<Map<String, dynamic>>.from(data['acessoriosIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'imageUrls': imageUrls,
      'blanksIds': blanksIds,
      'cabosIds': cabosIds,
      'reelSeatsIds': reelSeatsIds,
      'passadoresIds': passadoresIds,
      'acessoriosIds': acessoriosIds,
    };
  }
}