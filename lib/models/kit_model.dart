import 'package:cloud_firestore/cloud_firestore.dart';

class KitModel {
  final String id;
  final String name;
  final String description;
  final List<String> imageUrls; // Galeria de fotos do kit pronto
  
  // IDs e Variações dos componentes que compõem o kit
  final String blankId;
  final String? blankVariation;
  
  final String caboId;
  final String? caboVariation;
  final int caboQuantity;

  final String reelSeatId;
  final String? reelSeatVariation;

  // Listas armazenam Maps com {'id': '...', 'variation': '...', 'quantity': 1}
  final List<Map<String, dynamic>> passadoresIds; 
  final List<Map<String, dynamic>> acessoriosIds;

  KitModel({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrls,
    required this.blankId,
    this.blankVariation,
    required this.caboId,
    this.caboVariation,
    this.caboQuantity = 1,
    required this.reelSeatId,
    this.reelSeatVariation,
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
      
      blankId: data['blankId'] ?? '',
      blankVariation: data['blankVariation'],
      
      caboId: data['caboId'] ?? '',
      caboVariation: data['caboVariation'],
      caboQuantity: (data['caboQuantity'] ?? 1).toInt(),
      
      reelSeatId: data['reelSeatId'] ?? '',
      reelSeatVariation: data['reelSeatVariation'],
      
      passadoresIds: List<Map<String, dynamic>>.from(data['passadoresIds'] ?? []),
      acessoriosIds: List<Map<String, dynamic>>.from(data['acessoriosIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'imageUrls': imageUrls,
      'blankId': blankId,
      'blankVariation': blankVariation,
      'caboId': caboId,
      'caboVariation': caboVariation,
      'caboQuantity': caboQuantity,
      'reelSeatId': reelSeatId,
      'reelSeatVariation': reelSeatVariation,
      'passadoresIds': passadoresIds,
      'acessoriosIds': acessoriosIds,
    };
  }
}