import 'package:cloud_firestore/cloud_firestore.dart';

class Component {
  final String id;
  final String name;
  final String description;
  final String category;
  final double price;
  final double costPrice;
  final int stock; // Será a soma das variações ou o estoque simples
  final String imageUrl;
  final Map<String, dynamic> attributes;
  final String? supplierLink;
  
  // --- NOVO CAMPO ---
  // Ex: {'Tamanho P': 10, 'Tamanho M': 5}
  final Map<String, int> variations; 

  Component({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    this.costPrice = 0.0,
    required this.stock,
    required this.imageUrl,
    required this.attributes,
    this.supplierLink,
    this.variations = const {}, // Padrão vazio
  });

  factory Component.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Converte o Map<String, dynamic> do firestore para Map<String, int>
    Map<String, int> parsedVariations = {};
    if (data['variations'] != null) {
      (data['variations'] as Map<String, dynamic>).forEach((key, value) {
        parsedVariations[key] = (value as num).toInt();
      });
    }

    return Component(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      costPrice: (data['costPrice'] ?? 0.0).toDouble(),
      stock: (data['stock'] ?? 0).toInt(),
      imageUrl: data['imageUrl'] ?? '',
      attributes: data['attributes'] ?? {},
      supplierLink: data['supplierLink'],
      variations: parsedVariations, // Carrega variações
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'costPrice': costPrice,
      'stock': stock,
      'imageUrl': imageUrl,
      'attributes': attributes,
      'supplierLink': supplierLink,
      'variations': variations, // Salva variações
    };
  }
}